// Vercel serverless proxy for the Auralings web build. The browser never sees the
// Groq key: the game POSTs a creature's traits here, this function injects the key
// (from the GROQ_API_KEY env var), asks Groq to author the identity, and returns
// just the identity JSON. On any failure it returns {} so the game falls back to
// its procedural name/ability and still works.

const SYS =
  "You are the loremaster of Auralings: tiny, cute elemental spirit-creatures. " +
  "Given a creature's traits, invent its identity. Keep it whimsical and warm. " +
  "Return ONLY JSON with keys: name (one invented cute word, 2 syllables), " +
  "title (a 2-3 word epithet), lore (one vivid sentence, max 16 words), " +
  "ability_name (2 words), ability_desc (one short sentence, max 12 words).";

module.exports = async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({});
    return;
  }
  const key = process.env.GROQ_API_KEY;
  if (!key) {
    res.status(200).json({}); // no key configured -> graceful fallback
    return;
  }

  let body = req.body;
  if (typeof body === "string") {
    try { body = JSON.parse(body); } catch (_) { body = {}; }
  }
  body = body || {};
  const element = body.element || "spirit";
  const archetype = body.archetype || "Wanderer";
  const hp = Number(body.hp) || 80;
  const atk = Number(body.atk) || 18;
  const name = body.name || "Auraling";

  const usr =
    `element: ${element}\narchetype: ${archetype}\n` +
    `hp: ${hp}\natk: ${atk}\nseed-hint-name: ${name}`;

  try {
    const r = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${key}`,
      },
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
    });

    if (!r.ok) {
      res.status(200).json({});
      return;
    }
    const data = await r.json();
    const content = data?.choices?.[0]?.message?.content ?? "{}";
    let identity;
    try { identity = JSON.parse(content); } catch (_) { identity = {}; }
    res.status(200).json(identity && typeof identity === "object" ? identity : {});
  } catch (_) {
    res.status(200).json({});
  }
};
