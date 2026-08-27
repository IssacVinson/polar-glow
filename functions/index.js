const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const Stripe = require("stripe");

initializeApp();

const stripeSecret = defineSecret("STRIPE_SECRET");

exports.createPaymentIntent = onCall(
  {
    cors: true,
    secrets: [stripeSecret],
    region: "us-west1",
    enforceAppCheck: false,
  },
  async (request) => {
    try {
      const { amount, bookingId } = request.data;

      if (!amount || typeof amount !== "number" || amount <= 0) {
        throw new HttpsError(
          "invalid-argument",
          "Amount must be a positive number",
        );
      }
      if (!bookingId || typeof bookingId !== "string") {
        throw new HttpsError("invalid-argument", "bookingId is required");
      }

      const stripe = new Stripe(stripeSecret.value());

      const paymentIntent = await stripe.paymentIntents.create({
        amount: amount,
        currency: "usd",
        metadata: { bookingId: bookingId },
        automatic_payment_methods: { enabled: true },
      });

      return {
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      };
    } catch (error) {
      logger.error("Error in createPaymentIntent:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      if (
        error.message &&
        (error.message.includes("secret") ||
          error.message.includes("STRIPE_SECRET"))
      ) {
        throw new HttpsError(
          "internal",
          "Stripe secret is missing. Run: firebase functions:secrets:set STRIPE_SECRET",
        );
      }

      throw new HttpsError(
        "internal",
        error.message || "Failed to create payment intent",
      );
    }
  },
);

/**
 * Deletes every document in a collection in pages of 200.
 * @param {FirebaseFirestore.CollectionReference} col Collection ref.
 * @return {Promise<void>}
 */
async function deleteCollection(col) {
  let snap = await col.limit(200).get();
  while (!snap.empty) {
    const batch = col.firestore.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    snap = await col.limit(200).get();
  }
}

/**
 * Deletes every document matching a query in pages of 200.
 * @param {FirebaseFirestore.Query} query Query ref.
 * @return {Promise<void>}
 */
async function deleteQuery(query) {
  let snap = await query.limit(200).get();
  while (!snap.empty) {
    const batch = query.firestore.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    snap = await query.limit(200).get();
  }
}

/**
 * Apple Guideline 5.1.1(v): fully delete the signed-in Auth user and
 * associated Firestore / Storage personal data from within the app.
 */
exports.deleteOwnAccount = onCall(
  {
    cors: true,
    region: "us-west1",
    enforceAppCheck: false,
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }

    const uid = request.auth.uid;
    const db = getFirestore();
    const auth = getAuth();

    try {
      const userRef = db.collection("users").doc(uid);
      const userSnap = await userRef.get();
      const userData = userSnap.exists ? userSnap.data() : {};
      const username = (userData.username || "").toString().toLowerCase();

      await deleteCollection(userRef.collection("clock_events"));
      await deleteCollection(userRef.collection("availability"));
      await deleteQuery(
        db.collection("reviews").where("customerId", "==", uid),
      );
      await deleteQuery(
        db.collection("reimbursements").where("employeeId", "==", uid),
      );

      const bookings = await db
        .collection("bookings")
        .where("customerId", "==", uid)
        .get();

      const bookingBatch = db.batch();
      bookings.docs.forEach((doc) => {
        const data = doc.data();
        const status = (data.status || "").toString().toLowerCase();
        const paid = data.paymentStatus === "paid" || data.paid === true;
        if (paid || status === "completed") {
          bookingBatch.update(doc.ref, {
            customerId: "deleted_user",
            address: "",
            notes: "",
            customerDeletedAt: FieldValue.serverTimestamp(),
          });
        } else {
          bookingBatch.delete(doc.ref);
        }
      });
      if (!bookings.empty) {
        await bookingBatch.commit();
      }

      if (username) {
        await db.collection("usernames").doc(username).delete();
      }

      await userRef.delete();

      try {
        const bucket = getStorage().bucket();
        await bucket.deleteFiles({ prefix: `reimbursements/${uid}/` });
      } catch (storageError) {
        logger.warn("Storage cleanup skipped:", storageError.message);
      }

      await auth.deleteUser(uid);
      logger.info(`Deleted account ${uid}`);
      return { ok: true };
    } catch (error) {
      logger.error("deleteOwnAccount failed:", error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        "internal",
        error.message || "Failed to delete account",
      );
    }
  },
);
