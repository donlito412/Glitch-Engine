// ============================================================
// Glitch Engine API — /api/trial
// Returns trial status for a given email
// ============================================================

const Stripe = require("stripe");
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

const FREE_TRIAL_LIMIT = 10;
const FIREBASE_URL = `https://firestore.googleapis.com/v1/projects/${process.env.FIREBASE_PROJECT_ID}/databases/(default)/documents`;
const FIREBASE_KEY = process.env.FIREBASE_API_KEY;
const ADMIN_EMAILS = (process.env.ADMIN_EMAILS || "").toLowerCase().split(",").map(e => e.trim());

module.exports = async function handler(req, res) {
  if (req.method === "OPTIONS") return res.status(200).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const { email } = req.body;
  if (!email) return res.status(400).json({ error: "Email required" });

  const normalizedEmail = email.toLowerCase().trim();

  try {
    // Admin
    if (ADMIN_EMAILS.includes(normalizedEmail)) {
      return res.status(200).json({ status: "admin", unlimited: true });
    }

    // Check Stripe
    const customers = await stripe.customers.list({ email: normalizedEmail, limit: 5 });
    for (const customer of customers.data) {
      const subs = await stripe.subscriptions.list({
        customer: customer.id,
        status: "active",
        price: process.env.STRIPE_PRICE_ID,
        limit: 1
      });
      if (subs.data.length > 0) {
        return res.status(200).json({ status: "subscribed", unlimited: true });
      }
    }

    // Check trial
    const docId = encodeURIComponent(normalizedEmail.replace(/[.#$[\]]/g, "_"));
    const url = `${FIREBASE_URL}/trials/${docId}?key=${FIREBASE_KEY}`;
    const fireRes = await fetch(url);
    let used = 0;
    if (fireRes.ok) {
      const data = await fireRes.json();
      used = data.fields?.used?.integerValue ? parseInt(data.fields.used.integerValue) : 0;
    }

    return res.status(200).json({
      status: used < FREE_TRIAL_LIMIT ? "trial" : "expired",
      used,
      limit: FREE_TRIAL_LIMIT,
      remaining: Math.max(0, FREE_TRIAL_LIMIT - used)
    });

  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
};
