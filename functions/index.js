const { onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { defineSecret } = require("firebase-functions/params");
const Stripe = require("stripe");

// Define the secret (this is the modern v2 way)
const stripeSecret = defineSecret("STRIPE_SECRET");

exports.createPaymentIntent = onCall(
  {
    cors: true,
    secrets: [stripeSecret],           // ← tells Firebase to inject the secret
  },
  async (request) => {
    try {
      const { amount, bookingId } = request.data;

      if (!amount || !bookingId) {
        throw new Error("Missing amount or bookingId");
      }

      const stripe = new Stripe(stripeSecret.value());

      const paymentIntent = await stripe.paymentIntents.create({
        amount: amount,
        currency: "usd",
        metadata: { bookingId: bookingId },
        automatic_payment_methods: { enabled: true },
      });

      logger.info(`PaymentIntent created for booking ${bookingId}`);

      return {
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      };
    } catch (error) {
      logger.error("Error creating payment intent:", error);
      throw new Error(error.message || "Failed to create payment");
    }
  }
);