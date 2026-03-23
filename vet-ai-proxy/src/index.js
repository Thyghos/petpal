const MAX_MESSAGES = 20;
const MAX_CONTENT_CHARS = 4000;
const CLAUDE_MODEL = "claude-sonnet-4-20250514";
const GEMINI_MODEL = "gemini-2.0-flash";

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

    const expectedToken = cleanText(env.APP_SHARED_SECRET || "");
    if (expectedToken) {
      const auth = cleanText(request.headers.get("authorization"));
      if (!auth.startsWith("Bearer ")) {
        return json({ error: "Unauthorized" }, 401, cors);
      }
      const provided = cleanText(auth.replace(/^Bearer\s+/i, ""));
      if (!provided || provided !== expectedToken) {
        return json({ error: "Unauthorized" }, 401, cors);
      }
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
