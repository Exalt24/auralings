// Vercel serverless proxy for the Auralings web build. The browser never sees the
// Groq key: the game POSTs a creature's traits here, this function injects the key
// (from GROQ_API_KEY), asks Groq to author the identity, and returns just the
// identity JSON. On ANY failure it returns {} so the game falls back to its
// procedural name/ability and still works (graceful degradation, always 200-with-{}).
//
// Hardening: an 8s abort timeout (never hang the function), a warm-instance LRU cache
// keyed by the creature's traits (idempotent + cuts Groq cost/quota on repeat/shared
// seeds), a per-IP token bucket (a public endpoint anyone can spam, so cap abuse), one
// retry on 429/5xx, and input clamping (bounded prompt, no injection via long strings).

const SYS =
  "You are the loremaster of Auralings: tiny, cute elemental spirit-creatures. " +
  "Given a creature's traits, invent its identity. Keep it whimsical and warm. " +
  "Return ONLY JSON with keys: name (one invented cute word, 2 syllables), " +
  "title (a 2-3 word epithet), lore (one vivid sentence, max 16 words), " +
  "ability_name (2 words), ability_desc (one short sentence, max 12 words).";

// --- warm-instance state (best-effort; resets on cold start, which is fine) ---
const CACHE = new Map();          // key -> identity object
const CACHE_MAX = 500;
const BUCKETS = new Map();        // ip -> { tokens, ts }
const RATE_MAX = 30;              // burst
const RATE_REFILL_PER_SEC = 0.5;  // ~30/min sustained

function clampStr(v, max) {
  return String(v == null ? "" : v).slice(0, max);
}
function clampNum(v, lo, hi, dflt) {
  const n = Number(v);
  if (!Number.isFinite(n)) return dflt;
  return Math.min(hi, Math.max(lo, Math.round(n)));
}
function allow(ip) {
  const now = Date.now() / 1000;
  let b = BUCKETS.get(ip);
  if (!b) { b = { tokens: RATE_MAX, ts: now }; BUCKETS.set(ip, b); }
  b.tokens = Math.min(RATE_MAX, b.tokens + (now - b.ts) * RATE_REFILL_PER_SEC);
  b.ts = now;
  if (BUCKETS.size > 5000) BUCKETS.clear(); // crude memory guard
  if (b.tokens < 1) return false;
  b.tokens -= 1;
  return true;
}

async function callGroq(key, usr, signal) {
  return fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model: "llama-3.3-70b-versatile",
      messages: [
        { role: "system", content: SYS },
        { role: "user", content: usr },
      ],
      response_format: { type: "json_object" },
      temperature: 1.1,
      max_tokens: 220,
    }),
    signal,
  });
}

module.exports = async (req, res) => {
  if (req.method !== "POST") { res.status(405).json({}); return; }

  const ip = (req.headers["x-forwarded-for"] || "").split(",")[0].trim() || "anon";
  if (!allow(ip)) { res.status(200).json({}); return; } // over budget -> graceful fallback

  const key = process.env.GROQ_API_KEY;
  if (!key) { res.status(200).json({}); return; }

  let body = req.body;
  if (typeof body === "string") { try { body = JSON.parse(body); } catch (_) { body = {}; } }
  body = body || {};

  const element = clampStr(body.element || "spirit", 24);
  const archetype = clampStr(body.archetype || "Wanderer", 24);
  const name = clampStr(body.name || "Auraling", 24);
  const hp = clampNum(body.hp, 1, 9999, 80);
  const atk = clampNum(body.atk, 1, 9999, 18);

  const cacheKey = `${element}|${archetype}|${hp}|${atk}|${name}`;
  if (CACHE.has(cacheKey)) { res.status(200).json(CACHE.get(cacheKey)); return; }

  const usr =
    `element: ${element}\narchetype: ${archetype}\n` +
    `hp: ${hp}\natk: ${atk}\nseed-hint-name: ${name}`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    let r = await callGroq(key, usr, controller.signal);
    if (r.status === 429 || r.status >= 500) {
      await new Promise((done) => setTimeout(done, 400)); // one gentle retry
      r = await callGroq(key, usr, controller.signal);
    }
    if (!r.ok) { res.status(200).json({}); return; }
    const data = await r.json();
    const content = data?.choices?.[0]?.message?.content ?? "{}";
    let identity;
    try { identity = JSON.parse(content); } catch (_) { identity = {}; }
    if (!identity || typeof identity !== "object") identity = {};
    if (CACHE.size >= CACHE_MAX) CACHE.delete(CACHE.keys().next().value); // evict oldest
    CACHE.set(cacheKey, identity);
    res.status(200).json(identity);
  } catch (_) {
    res.status(200).json({}); // abort/timeout/network -> graceful fallback
  } finally {
    clearTimeout(timer);
  }
};
