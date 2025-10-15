# Member-Get-Member (Flutter + Firebase + AI Agent)

A demo-ready **referrals** app that lets users share a referral code, tracks signups/conversions, shows **gamified rewards** (points, tiers, badges), and exposes an **AI data agent** for insights (CR, top referrers, forecasts, ROI).

* **Frontend:** Flutter (web/desktop)
* **Backend:** Firebase Auth, Firestore, Cloud Functions
* **AI Agent:** FastAPI (Python) pulling data from Firestore
* **Data model:** `users/{uid}`, `referrals/{refereeUid}`, `ledgers/{uid}/entries/{entryId}`

---

## ✨ What the app does

* **Onboarding/Auth:** Anonymous sign-in for quick demo. E-mail sign-in for deployment.
* **Referral flow:** Show my **referral code (UID)** → share/copy → referee applies code → backend validates and records the referral.
* **Metrics:** Invites, conversions, points.
* **Rewards:** Points = conversions × 100; **tier every 200 points** with badges + progress bar; snackbar when a new tier unlocks.
* **Ask the Agent:** Natural language questions (e.g., “What’s our CR and next-week forecast?”).

---

## 🧱 Repo layout (suggested)

```text
getMemberApp/
├─ app/                     # Flutter app
│  └─ lib/main.dart         # UI & client logic
│
├─ infra/
│  └─ functions/            # Firebase Cloud Functions (TypeScript)
│     └─ src/index.ts       # creditReferral, award points, user triggers
│
├─ agent/                   # FastAPI AI data agent
│  ├─ main.py               # endpoints: /health, /insights, /ask
│  └─ requirements.txt
│
├─ firestore.rules          # Firestore Security Rules (optional, if using CLI)
└─ firebase.json            # Points to firestore.rules (if using CLI)
```

---

## 🛠 Prerequisites

* **Flutter** (any recent stable). Target: **web** or **Windows** desktop.

  * `flutter doctor`
* **Firebase project** created with:

  * Authentication → **Anonymous** sign-in **enabled** (for demo)
  * Firestore Database → in **Production** or **Test** mode
* **Node 18+** and Firebase CLI for Functions (`npm i -g firebase-tools`)
* **Python 3.10+** for the agent (FastAPI)
* (Optional) **gcloud** CLI if you prefer Application Default Credentials

---

## 🔐 Firestore Security Rules

Paste these in **Console → Firestore Database → Rules → Publish**, or keep in `firestore.rules` and deploy with CLI.

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() { return request.auth != null; }

    // users/{uid}
    match /users/{uid} {
      allow read: if isSignedIn() && uid == request.auth.uid;
      allow create: if isSignedIn() && uid == request.auth.uid;
      // Example: allow setting referrerId once; tighten as needed
      allow update: if isSignedIn()
        && uid == request.auth.uid
        && !('referrerId' in resource.data)
        && ('referrerId' in request.resource.data)
        && request.resource.data.referrerId is string
        && request.resource.data.referrerId != request.auth.uid;
      allow delete: if false;
    }

    // referrals/{refereeUid} (doc id == referee uid)
    match /referrals/{refereeUid} {
      allow read: if isSignedIn() && request.auth.uid == refereeUid;
      allow create: if isSignedIn()
        && request.auth.uid == refereeUid
        && request.resource.id == refereeUid
        && request.resource.data.refereeId == refereeUid
        && request.resource.data.referrerId is string
        && request.resource.data.referrerId != refereeUid;
      allow update, delete: if false;
    }

    // ledgers/{uid}/entries/{entryId} — read-only from client
    match /ledgers/{uid} {
      allow read: if isSignedIn() && request.auth.uid == uid;
      allow create, update, delete: if false;

      match /entries/{entryId} {
        allow read: if isSignedIn() && request.auth.uid == uid;
        allow create, update, delete: if false;
      }
    }
  }
}
```

---

## 🚀 Running everything locally

### 1) Flutter app (web)

From `app/`:

```bash
flutter pub get
flutter run -d chrome
```

**What it does:** Initializes Firebase (using `firebase_options.dart` from `flutterfire configure`), signs in anonymously, shows UI.

> You’ll see your **UID** (your referral code) at the top.

#### Two profiles (to demo referrals)

* Open the app in **two different browsers** (e.g., Chrome and Edge), or use Chrome’s **Guest** profile for the second user.
* In **Profile A**, copy UID; in **Profile B**, paste UID into “Apply referral code” and submit.
* In Profile A, press **Refresh metrics**; you should see **Conversions** increase and **Rewards** progress.

---

### 2) Cloud Functions (backend)

From `infra/functions/`:

```bash
npm install
npm run build
firebase deploy --only functions
```

**Minimal functions:**

* `creditReferral` (callable): validates & records `/referrals/{refereeUid}` and sets `users/{refereeUid}.referrerId` if empty.
* `onUserCreate`: creates `users/{uid}` on auth sign-up.
* `awardReferralPoints`: writes `ledgers/{referrer}/entries/{refereeUid}` (+100) and updates balance **idempotently**.

> If you use **non-default region**, match it in Flutter:
> `FirebaseFunctions.instanceFor(region: 'southamerica-east1')` (already in code).

---

### 3) AI Data Agent (FastAPI)

From `agent/`:

```bash
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

Set environment variables in **PowerShell** (same session):

```powershell
# Required
$env:GCP_PROJECT = "<your-firebase-project-id>"
$env:API_TOKEN = "dev-token"

# Auth: Service account JSON (download from Firebase Console > Project settings > Service accounts)
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"

# LLM support in /ask
# $env:OPENAI_API_KEY = "sk-..."
```

Run:

```bash
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

Quick checks:

```powershell
# health
curl.exe http://127.0.0.1:8000/health

# insights (replace token if you changed API_TOKEN)
curl.exe --% -X GET "http://127.0.0.1:8000/insights?avg_ltv=120&incentive_cost_per_conversion=15&baseline_cac=5" -H "Authorization: Bearer dev-token"

# ask (one-liner)
curl.exe --% -X POST http://127.0.0.1:8000/ask -H "Authorization: Bearer dev-token" -H "Content-Type: application/json" --data-raw "{\"question\":\"What's our CR and next-week forecast?\"}"
```

**Connect from Flutter:** the app already calls:

* `GET http://127.0.0.1:8000/insights?...` (in `_loadInsight()`)
* `POST http://127.0.0.1:8000/ask` (in `_sendQuestion()`)

> Use `127.0.0.1` (not `localhost`) to avoid CORS/host header quirks in some setups.

---

## 🗃 Firestore data model (created automatically as you use the app)

* `users/{uid}`

  * `referrerId: string | null`
  * `joinedAt: timestamp`
* `referrals/{refereeUid}` (doc id == the **referee**’s UID)

  * `referrerId, refereeId, status, createdAt`
* `ledgers/{uid}`

  * `balance, updatedAt`
  * `entries/{entryId}` (for referrals, use `entryId = refereeUid` for idempotency)

    * `type, delta, balance, at, meta`

---

## 🧪 Demo script (5 minutes)

1. Open two browsers (A/B).
2. In A, copy the **referral code** (UID).
3. In B, **Apply referral code** with A’s UID.
4. Back to A → **Refresh metrics** → see **Conversions** + **Rewards** update; tier toast appears if crossed threshold.
5. Ask the agent: “What’s our CR and next-week forecast?”

Optional: show Leaderboard / Activity cards if enabled.

---

## 🧰 Troubleshooting

* **Web app shows “Loading…”**
  Ensure Firebase initialized + anonymous auth enabled in Firebase Console.

* **Callable returns UNAUTHENTICATED**
  Confirm you signed in (`FirebaseAuth.instance.currentUser` exists).

* **CORS / “Agent not reachable”**
  Make sure FastAPI runs on `127.0.0.1:8000` and you use that URL in Flutter.

* **Rules deny read/write**
  Publish the rules above (or start the **Firestore Emulator** during dev).

* **Functions deploy errors (lint/tsconfig)**
  Update `firebase-functions` / `firebase-admin`, or use v1 alternatives per your setup.

---

## 🙌 Credits

Built with Flutter, Firebase, and FastAPI. Designed for fast demos and extendable to production patterns.
