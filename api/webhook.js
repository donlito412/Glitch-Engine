// ============================================================
// Glitch Engine API — /api/webhook
// Handles Stripe events (subscription created, cancelled, etc.)
// ============================================================

const Stripe = require("stripe");
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

module.exports = async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).end();

  const sig = req.headers["stripe-signature"];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let event;
  try {
    const rawBody = await getRawBody(req);
    if (webhookSecret && sig) {
      event = stripe.webhooks.constructEvent(rawBody, sig, webhookSecret);
    } else {
      // Dev mode — no webhook secret set yet
      event = req.body;
    }
  } catch (err) {
    console.error("[GlitchAI] Webhook signature error:", err.message);
    return res.status(400).json({ error: "Webhook error: " + err.message });
  }

  console.log("[GlitchAI] Webhook event:", event.type);

  switch (event.type) {
    case "customer.subscription.created":
      console.log("[GlitchAI] New subscription:", event.data.object.customer);
      break;
    case "customer.subscription.deleted":
      console.log("[GlitchAI] Subscription cancelled:", event.data.object.customer);
      break;
    case "invoice.payment_failed":
      console.log("[GlitchAI] Payment failed:", event.data.object.customer_email);
      break;
    default:
      console.log("[GlitchAI] Unhandled event type:", event.type);
  }

  return res.status(200).json({ received: true });
};

async function getRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", chunk => chunks.push(chunk));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}
