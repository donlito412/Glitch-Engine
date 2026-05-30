// ============================================================
// Glitch Engine API — /api/subscribe
// Creates a Stripe Checkout session for $9.99/month
// ============================================================

const Stripe = require("stripe");
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

module.exports = async function handler(req, res) {
  if (req.method === "OPTIONS") return res.status(200).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const { email } = req.body;
  if (!email) return res.status(400).json({ error: "Email required" });

  try {
    // Find or create Stripe customer
    let customer;
    const existing = await stripe.customers.list({ email, limit: 1 });
    if (existing.data.length > 0) {
      customer = existing.data[0];
    } else {
      customer = await stripe.customers.create({ email });
    }

    // Create checkout session
    const session = await stripe.checkout.sessions.create({
      customer: customer.id,
      payment_method_types: ["card"],
      line_items: [{
        price: process.env.STRIPE_PRICE_ID,
        quantity: 1
      }],
      mode: "subscription",
      success_url: "https://glitch-engine.vercel.app/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "https://glitch-engine.vercel.app/cancelled",
      customer_email: customer.email ? undefined : email,
      allow_promotion_codes: true,
      subscription_data: {
        metadata: { source: "glitch_engine_app" }
      }
    });

    return res.status(200).json({ url: session.url });

  } catch (err) {
    console.error("[GlitchAI] Subscribe error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};
