const MAX_MESSAGES = 20;
const MAX_CONTENT_CHARS = 4000;
const CLAUDE_MODEL = "claude-sonnet-4-20250514";
const GEMINI_MODEL = "gemini-2.0-flash";
const DEFAULT_RPM_LIMIT = 10;
const DEFAULT_DAILY_LIMIT = 120;

function json(body, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...extraHeaders,
    },
  });
}

function corsHeaders(origin) {
  return {
    "access-control-allow-origin": origin || "*",
    "access-control-allow-methods": "POST,OPTIONS",
    "access-control-allow-headers": "content-type,authorization",
  };
}

function cleanText(value) {
  if (typeof value !== "string") return "";
  return value.trim();
}

function getIntEnv(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

async function checkRateLimit(env, key, rpmLimit, dailyLimit) {
  const id = env.RATE_LIMITER.idFromName("global-rate-limiter");
  const stub = env.RATE_LIMITER.get(id);
  const response = await stub.fetch("https://rate-limiter/check", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ key, rpmLimit, dailyLimit }),
  });

  const data = await response.json().catch(() => ({}));
  return {
    ok: response.ok,
    status: response.status,
    error: data?.error || "Rate limit exceeded",
  };
}

function validateMessages(rawMessages) {
  if (!Array.isArray(rawMessages) || rawMessages.length === 0) {
    throw new Error("messages must be a non-empty array");
  }
  if (rawMessages.length > MAX_MESSAGES) {
    throw new Error(`messages exceeds limit (${MAX_MESSAGES})`);
  }

  return rawMessages.map((m, idx) => {
    const role = m?.role === "assistant" ? "assistant" : "user";
    const content = cleanText(m?.content);
    if (!content) throw new Error(`messages[${idx}].content is required`);
    if (content.length > MAX_CONTENT_CHARS) {
      throw new Error(`messages[${idx}].content too long`);
    }
    return { role, content };
  });
}

function buildSystemPrompt(petName, petSpecies, petContext) {
  const safeName = cleanText(petName) || "the pet";
  const safeSpecies = cleanText(petSpecies) || "pet";
  const context = cleanText(petContext);
  const contextBlock = context
    ? `

---
Petpal app data (owner-entered notes/records summary):
${context}
`
    : "";

  return `You are a veterinary information assistant helping with a ${safeSpecies} named ${safeName}.
Provide accurate, empathetic general guidance.
Always advise contacting a licensed veterinarian for diagnosis, treatment, emergencies, or medication decisions.
Do not claim to be a veterinarian.${contextBlock}`;
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("origin");
    const cors = corsHeaders(origin);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }

    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/v1/vet-chat") {
      return json({ error: "Not found" }, 404, cors);
    }

    if (!env.CLAUDE_API_KEY && !env.GEMINI_API_KEY) {
      return json(
        { error: "Server not configured: set CLAUDE_API_KEY and/or GEMINI_API_KEY" },
        500,
        cors
      );
    }

    // Public app endpoint: no token required.
    // Abuse is controlled through Durable Object rate limits per client IP.
    const ip = cleanText(request.headers.get("cf-connecting-ip")) || "unknown";
    const limitKey = `ip:${ip}`;
    const rpmLimit = getIntEnv(env.RATE_LIMIT_RPM, DEFAULT_RPM_LIMIT);
    const dailyLimit = getIntEnv(env.RATE_LIMIT_DAILY, DEFAULT_DAILY_LIMIT);
    const limit = await checkRateLimit(env, limitKey, rpmLimit, dailyLimit);
    if (!limit.ok) {
      return json({ error: limit.error }, limit.status || 429, cors);
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json({ error: "Invalid JSON body" }, 400, cors);
    }

    let messages;
    try {
      messages = validateMessages(payload.messages);
    } catch (err) {
      return json({ error: err.message || "Invalid payload" }, 400, cors);
    }

    const system = buildSystemPrompt(payload.petName, payload.petSpecies, payload.petContext);
    const requestedProvider = cleanText(payload.provider).toLowerCase();

    let providerOrder;
    if (requestedProvider === "claude") {
      providerOrder = ["claude", "gemini"];
    } else if (requestedProvider === "gemini") {
      providerOrder = ["gemini", "claude"];
    } else {
      // Default: Claude first, Gemini fallback
      providerOrder = ["claude", "gemini"];
    }

    const providers = {
      claude: async () => {
        if (!env.CLAUDE_API_KEY) {
          return { ok: false, status: 500, error: "CLAUDE_API_KEY not configured" };
        }
        const claudeBody = {
          model: CLAUDE_MODEL,
          max_tokens: 1024,
          system,
          messages,
        };
        try {
          const upstream = await fetch("https://api.anthropic.com/v1/messages", {
            method: "POST",
            headers: {
              "content-type": "application/json",
              "x-api-key": env.CLAUDE_API_KEY,
              "anthropic-version": "2023-06-01",
            },
            body: JSON.stringify(claudeBody),
          });
          const data = await upstream.json().catch(() => ({}));
          if (!upstream.ok) {
            const message =
              data?.error?.message ||
              data?.error?.type ||
              `Claude HTTP ${upstream.status}`;
            return { ok: false, status: upstream.status, error: message };
          }
          const reply = data?.content?.[0]?.text?.trim();
          if (!reply) {
            return { ok: false, status: 502, error: "Claude returned empty response" };
          }
          return { ok: true, reply, provider: "claude" };
        } catch {
          return { ok: false, status: 502, error: "Claude request failed" };
        }
      },
      gemini: async () => {
        if (!env.GEMINI_API_KEY) {
          return { ok: false, status: 500, error: "GEMINI_API_KEY not configured" };
        }

        const geminiContents = messages.map((m) => ({
          role: m.role === "assistant" ? "model" : "user",
          parts: [{ text: m.content }],
        }));

        const geminiBody = {
          systemInstruction: { parts: [{ text: system }] },
          contents: geminiContents,
          generationConfig: { maxOutputTokens: 1024, temperature: 0.7 },
        };

        try {
          const endpoint =
            `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent` +
            `?key=${encodeURIComponent(env.GEMINI_API_KEY)}`;
          const upstream = await fetch(endpoint, {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify(geminiBody),
          });
          const data = await upstream.json().catch(() => ({}));
          if (!upstream.ok) {
            const message =
              data?.error?.message ||
              data?.error?.status ||
              `Gemini HTTP ${upstream.status}`;
            return { ok: false, status: upstream.status, error: message };
          }
          const reply = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
          if (!reply) {
            return { ok: false, status: 502, error: "Gemini returned empty response" };
          }
          return { ok: true, reply, provider: "gemini" };
        } catch {
          return { ok: false, status: 502, error: "Gemini request failed" };
        }
      },
    };

    let firstError = "Upstream request failed";
    let firstStatus = 502;
    for (const providerName of providerOrder) {
      const result = await providers[providerName]();
      if (result.ok) {
        return json({ reply: result.reply, provider: result.provider }, 200, cors);
      }
      if (result.error) firstError = result.error;
      if (result.status) firstStatus = result.status;
    }

    return json({ error: firstError }, firstStatus, cors);
  },
};

export class RateLimiter {
  constructor(state) {
    this.state = state;
  }

  async fetch(request) {
    if (request.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json({ error: "Invalid JSON body" }, 400);
    }

    const key = cleanText(payload?.key);
    const rpmLimit = getIntEnv(payload?.rpmLimit, DEFAULT_RPM_LIMIT);
    const dailyLimit = getIntEnv(payload?.dailyLimit, DEFAULT_DAILY_LIMIT);
    if (!key) return json({ error: "Missing key" }, 400);

    const nowMs = Date.now();
    const minuteBucket = Math.floor(nowMs / 60000);
    const dayBucket = Math.floor(nowMs / 86400000);

    const minuteKey = `m:${key}:${minuteBucket}`;
    const dayKey = `d:${key}:${dayBucket}`;

    const [minuteCountRaw, dayCountRaw] = await Promise.all([
      this.state.storage.get(minuteKey),
      this.state.storage.get(dayKey),
    ]);

    const minuteCount = Number(minuteCountRaw || 0);
    const dayCount = Number(dayCountRaw || 0);

    if (minuteCount >= rpmLimit) {
      return json(
        { error: "Rate limit exceeded. Please wait a minute and try again." },
        429
      );
    }
    if (dayCount >= dailyLimit) {
      return json(
        { error: "Daily AI limit reached. Please try again tomorrow." },
        429
      );
    }

    await Promise.all([
      this.state.storage.put(minuteKey, minuteCount + 1, {
        expiration: Math.floor(nowMs / 1000) + 120,
      }),
      this.state.storage.put(dayKey, dayCount + 1, {
        expiration: Math.floor(nowMs / 1000) + 172800,
      }),
    ]);

    return json({ ok: true });
  }
}
