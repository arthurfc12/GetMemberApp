import os
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Dict, Any

from fastapi import FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from collections import Counter


# Storage: Firestore (could swap for BigQuery later)
from google.cloud import firestore

# Optional: OpenAI for NLQ
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
try:
    from openai import OpenAI
    _openai_client = OpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None
except Exception:
    _openai_client = None  # still works without NLQ

API_TOKEN = os.getenv("API_TOKEN", "dev-token")
GCP_PROJECT = os.getenv("GCP_PROJECT")

# -------- App setup --------
app = FastAPI(title="MGM AI Data Agent", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],            # demo-friendly; tighten later
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB = firestore.Client(project=GCP_PROJECT)  # needs GOOGLE_APPLICATION_CREDENTIALS

def _auth(authorization: Optional[str]):
    if authorization != f"Bearer {API_TOKEN}":
        raise HTTPException(status_code=401, detail="Unauthorized")

# --------- Models ----------
class ROIParams(BaseModel):
    avg_ltv: float = Field(100.0, description="Average LTV (currency units)")
    incentive_cost_per_conversion: float = Field(10.0, description="Reward cost per successful referral")
    baseline_cac: float = Field(0.0, description="Baseline CAC to compare against (optional)")

class ForecastParams(BaseModel):
    horizon_days: int = Field(7, ge=1, le=60)


class TopReferrer(BaseModel):
    uid: str
    conversions: int

class CohortCR(BaseModel):
    last7: float
    prev7: float
    delta_pp: float  # last7 - prev7, in percentage points

class LiftEstimate(BaseModel):
    uplift_pct: float                # e.g., +5.0 (%)
    expected_conversions: int        # baseline_conversions * (1 + uplift)

class InsightsResponse(BaseModel):
    invites: int
    conversions: int
    conversion_rate: float
    cohort_cr: CohortCR
    top_referrers_7d: List[TopReferrer]
    top_referrers_30d: List[TopReferrer]
    best_day_of_week: str            # e.g., "Tuesday"
    churn_risk_rate: float
    referral_roi: float
    expected_lift_plus10: LiftEstimate
    forecast_next_conversions: int
    recommendation: str


# -------- Cleaning & ETL ----
def fetch_referrals() -> List[Dict[str, Any]]:
    """Pull referrals/* from Firestore and clean."""
    docs = DB.collection("referrals").stream()
    out = []
    seen_referees = set()
    for d in docs:
        row = d.to_dict()
        referrer = row.get("referrerId")
        referee = row.get("refereeId") or d.id
        status = row.get("status", "clicked")
        created = row.get("createdAt")
        # Normalization
        if hasattr(created, "to_datetime"):
            created = created.to_datetime()
        if isinstance(created, datetime):
            created = created.astimezone(timezone.utc)
        # Basic cleaning rules
        if not referrer or not referee:
            continue
        if referrer == referee:
            continue  # self-referral
        if referee in seen_referees:
            continue  # de-dupe multiple rows per referee
        seen_referees.add(referee)
        out.append({
            "referrerId": referrer,
            "refereeId": referee,
            "status": status,
            "createdAt": created or datetime.now(timezone.utc),
        })
    return out

def fetch_users() -> Dict[str, Dict[str, Any]]:
    """Optional enrichment from users/*."""
    docs = DB.collection("users").stream()
    users = {}
    for d in docs:
        row = d.to_dict()
        joined = row.get("joinedAt")
        if hasattr(joined, "to_datetime"):
            joined = joined.to_datetime().astimezone(timezone.utc)
        users[d.id] = {
            "joinedAt": joined,
            "referrerId": row.get("referrerId"),
            "email": row.get("email"),
        }
    return users

# ---------- Metrics ----------
WEEKDAYS = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]

def _count_conversions_in_window(referrals, since_dt, until_dt):
    return sum(
        1 for r in referrals
        if r["status"] in {"signed_up","active"}
        and isinstance(r["createdAt"], datetime)
        and since_dt <= r["createdAt"] < until_dt
    )

def _weekday_histogram(referrals, days:int=56):
    """Histogram of conversions by weekday over recent N days (default ~8 weeks)."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    counter = Counter()
    for r in referrals:
        if r["status"] in {"signed_up","active"} and isinstance(r["createdAt"], datetime):
            if r["createdAt"] >= cutoff:
                counter[r["createdAt"].weekday()] += 1  # 0 = Monday
    if not counter:
        return None, {wd:0 for wd in WEEKDAYS}
    best_idx, _ = max(counter.items(), key=lambda kv: kv[1])
    hist = {WEEKDAYS[i]: counter.get(i,0) for i in range(7)}
    return WEEKDAYS[best_idx], hist

def _top_referrers(referrals, days:int):
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    counter = Counter()
    for r in referrals:
        if r["status"] in {"signed_up","active"} and isinstance(r["createdAt"], datetime):
            if r["createdAt"] >= cutoff:
                counter[r["referrerId"]] += 1
    top = counter.most_common(5)
    return [{"uid": uid, "conversions": conv} for uid, conv in top]



def compute_metrics(referrals: List[Dict[str, Any]], users: Dict[str, Dict[str, Any]], roi: ROIParams):
    total_invites = len(referrals)
    conversions = sum(1 for r in referrals if r["status"] in {"signed_up", "active"})
    cr = (conversions / total_invites) * 100 if total_invites else 0.0

    # Active referrers in last 30d
    cutoff30 = datetime.now(timezone.utc) - timedelta(days=30)
    active_referrers = len({ r["referrerId"] for r in referrals
                             if (r["createdAt"] or cutoff30) >= cutoff30 })

    # Churn risk (simple demo heuristic)
    churn_cut = datetime.now(timezone.utc) - timedelta(days=21)
    referred_users = [u for u in users.values() if u.get("referrerId")]
    churn_risk = (sum(1 for u in referred_users if (u.get("joinedAt") or churn_cut) < churn_cut) / len(referred_users)) if referred_users else 0.0

    # ROI (demo math)
    unit_margin = (roi.avg_ltv - roi.incentive_cost_per_conversion) - roi.baseline_cac
    referral_roi = unit_margin / max(roi.incentive_cost_per_conversion, 1e-9)

    # --- Cohort CR: last 7 vs prior 7 ---
    today = datetime.now(timezone.utc)
    start_last7  = (today - timedelta(days=7)).replace(hour=0, minute=0, second=0, microsecond=0)
    start_prev7  = (today - timedelta(days=14)).replace(hour=0, minute=0, second=0, microsecond=0)
    invites_last7 = sum(1 for r in referrals
                        if isinstance(r["createdAt"], datetime) and start_last7 <= r["createdAt"] < today)
    invites_prev7 = sum(1 for r in referrals
                        if isinstance(r["createdAt"], datetime) and start_prev7 <= r["createdAt"] < start_last7)

    conv_last7 = _count_conversions_in_window(referrals, start_last7, today)
    conv_prev7 = _count_conversions_in_window(referrals, start_prev7, start_last7)

    cr_last7 = (conv_last7 / invites_last7) * 100 if invites_last7 else 0.0
    cr_prev7 = (conv_prev7 / invites_prev7) * 100 if invites_prev7 else 0.0
    delta_pp = cr_last7 - cr_prev7

    # --- Best day of week (by recent conversions) ---
    best_day, weekday_hist = _weekday_histogram(referrals, days=56)
    best_day = best_day or "—"

    # --- Top referrers ---
    top7  = _top_referrers(referrals, days=7)
    top30 = _top_referrers(referrals, days=30)

    # Naive forecast (last 7 daily avg)
    today_date = today.date()
    last7_daily = [0]*7
    for r in referrals:
        if r["status"] in {"signed_up","active"} and isinstance(r["createdAt"], datetime):
            d = (today_date - r["createdAt"].date()).days
            if 0 <= d < 7:
                last7_daily[6 - d] += 1
    daily_avg = sum(last7_daily)/7 if last7_daily else 0.0
    forecast_next_conversions = int(round(daily_avg * 7))

    # --- Expected lift with +10% incentive (simple elasticity) ---
    # Assumption: +10% incentive cost -> +5% conversions (elasticity 0.5). Tweakable.
    elasticity = 0.5
    uplift_pct = 10.0 * elasticity      # percent
    exp_conversions = int(round(conversions * (1 + uplift_pct/100.0)))

    # Recommendation (kept succinct)
    if cr_last7 < 5:
        rec = "Boost top-of-funnel: shorten invite copy and simplify signup."
    elif churn_risk > 0.3:
        rec = "Add D1/D3/D7 nudges to reduce early churn from referred users."
    else:
        rec = "Scale incentives for top referrers and A/B higher reward tiers."

    return {
        "invites": total_invites,
        "conversions": conversions,
        "conversion_rate": round(cr, 1),
        "cohort_cr": {
            "last7": round(cr_last7, 1),
            "prev7": round(cr_prev7, 1),
            "delta_pp": round(delta_pp, 1),
        },
        "top_referrers_7d": top7,
        "top_referrers_30d": top30,
        "best_day_of_week": best_day,
        "active_referrers": active_referrers,
        "churn_risk_rate": round(churn_risk, 2),
        "referral_roi": round(referral_roi, 2),
        "expected_lift_plus10": {
            "uplift_pct": round(uplift_pct, 1),
            "expected_conversions": exp_conversions,
        },
        "forecast_next_conversions": forecast_next_conversions,
        "recommendation": rec,
        "weekday_hist": weekday_hist,  # internal, handy for /ask "sources"
    }

# ---------- Endpoints ----------
@app.get("/health")
def health():
    return {"ok": True}

@app.get("/insights", response_model=InsightsResponse)
def insights(
    authorization: Optional[str] = Header(None),
    avg_ltv: float = Query(100.0),
    incentive_cost_per_conversion: float = Query(10.0),
    baseline_cac: float = Query(0.0)
):
    _auth(authorization)
    referrals = fetch_referrals()
    users = fetch_users()
    roi = ROIParams(
        avg_ltv=avg_ltv,
        incentive_cost_per_conversion=incentive_cost_per_conversion,
        baseline_cac=baseline_cac,
    )
    m = compute_metrics(referrals, users, roi)
    return InsightsResponse(
        invites=m["invites"],
        conversions=m["conversions"],
        conversion_rate=m["conversion_rate"],
        cohort_cr=CohortCR(**m["cohort_cr"]),
        top_referrers_7d=[TopReferrer(**x) for x in m["top_referrers_7d"]],
        top_referrers_30d=[TopReferrer(**x) for x in m["top_referrers_30d"]],
        best_day_of_week=m["best_day_of_week"],
        churn_risk_rate=m["churn_risk_rate"],
        referral_roi=m["referral_roi"],
        expected_lift_plus10=LiftEstimate(**m["expected_lift_plus10"]),
        forecast_next_conversions=m["forecast_next_conversions"],
        recommendation=m["recommendation"],
    )

@app.get("/echo")
def echo(q: str = ""):
    return {"echo": q}


@app.post("/forecast")
def forecast(
    params: ForecastParams,
    authorization: Optional[str] = Header(None),
):
    _auth(authorization)
    referrals = fetch_referrals()
    # reuse same naive logic as insights
    today = datetime.now(timezone.utc).date()
    last7 = [0]*7
    for r in referrals:
        if r["status"] in {"signed_up", "active"} and isinstance(r["createdAt"], datetime):
            d = (today - r["createdAt"].date()).days
            if 0 <= d < 7:
                last7[6 - d] += 1
    daily_avg = sum(last7) / 7 if last7 else 0.0
    return {"daily_avg": daily_avg, "horizon_days": params.horizon_days,
            "forecast_conversions": int(round(daily_avg * params.horizon_days))}

# --------- Natural Language Q&A ----------
class NLQRequest(BaseModel):
    question: str
    avg_ltv: Optional[float] = 100.0
    incentive_cost_per_conversion: Optional[float] = 10.0
    baseline_cac: Optional[float] = 0.0

@app.post("/ask")
def ask(req: NLQRequest, authorization: Optional[str] = Header(None)):
    _auth(authorization)

    referrals = fetch_referrals()
    users = fetch_users()
    metrics = compute_metrics(
        referrals,
        users,
        ROIParams(
            avg_ltv=req.avg_ltv or 100.0,
            incentive_cost_per_conversion=req.incentive_cost_per_conversion or 10.0,
            baseline_cac=req.baseline_cac or 0.0,
        ),
    )

    # Always include "sources" (what we computed)
    sources = {
        "invites": metrics["invites"],
        "conversions": metrics["conversions"],
        "conversion_rate": metrics["conversion_rate"],
        "cohort_cr": metrics["cohort_cr"],
        "top_referrers_7d": metrics["top_referrers_7d"],
        "top_referrers_30d": metrics["top_referrers_30d"],
        "best_day_of_week": metrics["best_day_of_week"],
        "churn_risk_rate": metrics["churn_risk_rate"],
        "referral_roi": metrics["referral_roi"],
        "expected_lift_plus10": metrics["expected_lift_plus10"],
        "forecast_next_conversions": metrics["forecast_next_conversions"],
        "weekday_hist": metrics.get("weekday_hist", {}),
    }

    if not _openai_client:
        # Heuristic answer referencing the key bits
        ans = (
            f"CR {metrics['conversion_rate']}% (7d {metrics['cohort_cr']['last7']}%, "
            f"prev7 {metrics['cohort_cr']['prev7']}%, Δ {metrics['cohort_cr']['delta_pp']}pp). "
            f"Best day: {metrics['best_day_of_week']}. "
            f"+10% incentive → ~{metrics['expected_lift_plus10']['uplift_pct']}% lift, "
            f"≈{metrics['expected_lift_plus10']['expected_conversions']} conversions. "
            f"Forecast next week: {metrics['forecast_next_conversions']}. "
            f"Rec: {metrics['recommendation']}"
        )
        return {"answer": ans, "used_llm": False, "sources": sources}

    system = (
        "You are a growth analyst. Be concise. Use the provided metrics JSON, "
        "compare last7 vs prev7, mention best day-of-week, and quantify the +10% incentive lift."
    )
    user = f"Question: {req.question}\nMetrics JSON: {sources}"

    chat = _openai_client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role":"system","content":system},{"role":"user","content":user}],
        temperature=0.2,
    )
    answer = chat.choices[0].message.content
    return {"answer": answer, "used_llm": True, "sources": sources}
