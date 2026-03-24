const { onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const Stripe = require("stripe");

// === PASTE YOUR FULL SECRET KEY HERE (replace the line below) ===
const stripe = new Stripe("sk_test_51TEEFFAmlYRxjwqhy3hKwLwS3whXIgOistkbGNjZs8GH8zpukHMvMMap2acO1ZZnEL7hwd1SgaAYrjTe8kj235bl00G1fSxUqq");

exports.createPaymentIntent = onCall({ cors: true }, async (request) => {
  try {
    const { amount, bookingId } = request.data;

    if (!amount || !bookingId) {
      throw new Error("Missing amount or bookingId");
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: "usd",
      metadata: { bookingId: bookingId },
      automatic_payment_methods: { enabled: true }
    });

    logger.info(`PaymentIntent created for booking ${bookingId}`);

    return {
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id
    };
  } catch (error) {
    logger.error("Error creating payment intent:", error);
    throw new Error(error.message || "Failed to create payment");
  }
});