import * as admin from "firebase-admin";
import {onCall} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";

admin.initializeApp();
const db = admin.firestore();

// Set region and concurrency as desired
setGlobalOptions({region: "southamerica-east1"});

/**
 * creditReferral({ referrerId })
 * Creates /users/{uid}.referrerId if empty and /referrals/{uid} once.
 */


export const creditReferral = onCall(async (request) => {
  const uid = request.auth?.uid;
  const referrerId = String(request.data?.referrerId ?? "");

  if (!uid) {
    return {ok: false, error: "UNAUTHENTICATED"};
  }
  if (!referrerId || referrerId === uid) {
    return {ok: false, error: "INVALID"};
  }

  const userRef = db.collection("users").doc(uid);
  const referralRef = db.collection("referrals").doc(uid);

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (userSnap.exists && userSnap.get("referrerId")) {
      return; // already credited
    }

    const referralSnap = await tx.get(referralRef);
    if (!referralSnap.exists) {
      tx.set(referralRef, {
        referrerId: referrerId,
        refereeId: uid,
        status: "signed_up",
        createdAt: admin.firestore.Timestamp.now(),
      });
    }

    tx.set(
      userRef,
      {
        referrerId: referrerId,
        joinedAt: admin.firestore.Timestamp.now(),
      },
      {merge: true},
    );
  });

  return {ok: true};
});
