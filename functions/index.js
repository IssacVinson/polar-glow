const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { defineSecret } = require("firebase-functions/params");
const Stripe = require("stripe");

// Define the secret (modern v2 way)
const stripeSecret = defineSecret("STRIPE_SECRET");

exports.createPaymentIntent = onCall(
  {
    cors: true,
    secrets: [stripeSecret],
    region: "us-west1",              
  },
  async (request) => {
    try {
      const { amount, bookingId } = request.data;

      // Input validation
      if (!amount || typeof amount !== "number" || amount <= 0) {
        throw new HttpsError("invalid-argument", "Amount must be a positive number");
      }
      if (!bookingId || typeof bookingId !== "string") {
        throw new HttpsError("invalid-argument", "bookingId is required");
      }

      const stripe = new Stripe(stripeSecret.value());

      logger.info(`Creating PaymentIntent for booking ${bookingId} | amount: $${(amount / 100).toFixed(2)}`);

      const paymentIntent = await stripe.paymentIntents.create({
        amount: amount,
        currency: "usd",
        metadata: { bookingId: bookingId },
        automatic_payment_methods: { enabled: true },
      });

      logger.info(`✅ PaymentIntent created successfully for booking ${bookingId}`);

      return {
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      };

    } catch (error) {
      logger.error("❌ Error in createPaymentIntent:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      if (error.message?.includes("secret") || error.message?.includes("STRIPE_SECRET")) {
        throw new HttpsError(
          "internal",
          "Stripe secret is missing or invalid. Run: firebase functions:secrets:set STRIPE_SECRET"
        );
      }

      throw new HttpsError("internal", error.message || "Failed to create payment intent");
    }
  }
);