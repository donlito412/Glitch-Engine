// ============================================================
// Glitch Engine API — /api/chat
// Handles AI requests. Checks: admin bypass → Stripe sub → free trial
// ============================================================

const Stripe = require("stripe");

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const FREE_TRIAL_LIMIT = 10;
const FIREBASE_URL = `https://firestore.googleapis.com/v1/projects/${process.env.FIREBASE_PROJECT_ID}/databases/(default)/documents`;
const FIREBASE_KEY = process.env.FIREBASE_API_KEY;
const ADMIN_EMAILS = (process.env.ADMIN_EMAILS || "").toLowerCase().split(",").map(e => e.trim());

module.exports = async function handler(req, res) {
  // Handle CORS preflight
  if (req.method === "OPTIONS") return res.status(200).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const { email, messages, system } = req.body;

  if (!email || !messages) {
    return res.status(400).json({ error: "Missing email or messages" });
  }

  const normalizedEmail = email.toLowerCase().trim();

  try {
    // 1. Admin bypass — owner always gets access
    if (ADMIN_EMAILS.includes(normalizedEmail)) {
      return await sendToAnthropic(req, res, messages, system);
    }

    // 2. Check active Stripe subscription
    const hasSubscription = await checkStripeSubscription(normalizedEmail);
    if (hasSubscription) {
      return await sendToAnthropic(req, res, messages, system);
    }

    // 3. Check free trial
    const trialData = await getTrialData(normalizedEmail);
    const used = trialData?.used || 0;

    if (used < FREE_TRIAL_LIMIT) {
      // Increment trial count
      await incrementTrialCount(normalizedEmail, used + 1);
      // Add trial info to response headers
      res.setHeader("X-Trial-Used", String(used + 1));
      res.setHeader("X-Trial-Limit", String(FREE_TRIAL_LIMIT));
      return await sendToAnthropic(req, res, messages, system);
    }

    // 4. Trial exhausted — prompt to subscribe
    return res.status(402).json({
      error: "trial_expired",
      message: "Your 10 free messages have been used. Subscribe for $9.99/month to continue.",
      trial_used: used,
      trial_limit: FREE_TRIAL_LIMIT
    });

  } catch (err) {
    console.error("[GlitchAI] Error:", err.message);
    return res.status(500).json({ error: "Server error: " + err.message });
  }
};

async function sendToAnthropic(req, res, messages, system) {
  const response = await fetch(ANTHROPIC_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": process.env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01"
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-6",
      max_tokens: 2048,
      system: system || "You are GlitchAI, the AI assistant built into Glitch Engine.",
      messages
    })
  });

  if (!response.ok) {
    const err = await response.text();
    return res.status(response.status).json({ error: "Anthropic error: " + err });
  }

  const data = await response.json();
  return res.status(200).json({
    text: data.content[0].text,
    usage: data.usage
  });
}

async function checkStripeSubscription(email) {
  try {
    const customers = await stripe.customers.list({ email, limit: 5 });
    for (const customer of customers.data) {
      const subs = await stripe.subscriptions.list({
        customer: customer.id,
        status: "active",
        price: process.env.STRIPE_PRICE_ID,
        limit: 1
      });
      if (subs.data.length > 0) return true;
    }
    return false;
  } catch (err) {
    console.error("[GlitchAI] Stripe check error:", err.message);
    return false;
  }
}

async function getTrialData(email) {
  try {
    const docId = encodeURIComponent(email.replace(/[.#$[\]]/g, "_"));
    const url = `${FIREBASE_URL}/trials/${docId}?key=${FIREBASE_KEY}`;
    const res = await fetch(url);
    if (!res.ok) return null;
    const data = await res.json();
    return {
      used: data.fields?.used?.integerValue ? parseInt(data.fields.used.integerValue) : 0
    };
  } catch (err) {
    return null;
  }
}

async function incrementTrialCount(email, newCount) {
  try {
    const docId = encodeURIComponent(email.replace(/[.#$[\]]/g, "_"));
    const url = `${FIREBASE_URL}/trials/${docId}?key=${FIREBASE_KEY}`;
    await fetch(url, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        fields: {
          email: { stringValue: email },
          used: { integerValue: String(newCount) },
          updatedAt: { stringValue: new Date().toISOString() }
        }
      })
    });
  } catch (err) {
    console.error("[GlitchAI] Firebase write error:", err.message);
  }
}
