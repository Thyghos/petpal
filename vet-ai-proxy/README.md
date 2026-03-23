# Petpal Vet AI Proxy (Cloudflare Worker)

Server-side proxy for Vet AI so API keys are not shipped in the iOS app.

## What it supports

- `CLAUDE_API_KEY` (Anthropic)
- `GEMINI_API_KEY` (Google Gemini)
- Built-in rate limiting per client IP (Durable Object)

Provider behavior:

- Default order: Claude first, then Gemini fallback
- You can request a provider by sending `"provider": "claude"` or `"provider": "gemini"` in the request body

## Deploy

```bash
cd vet-ai-proxy
npx wrangler secret put CLAUDE_API_KEY
npx wrangler secret put GEMINI_API_KEY
npx wrangler deploy
```

## Optional limits

You can configure limits in Wrangler as worker vars:

- `RATE_LIMIT_RPM` (default `10`) — requests per minute per IP
- `RATE_LIMIT_DAILY` (default `120`) — requests per day per IP

If not set, defaults are used.

## Request

`POST /v1/vet-chat`

Headers:

- `Content-Type: application/json`

Body:

```json
{
  "messages": [
    { "role": "user", "content": "My dog has diarrhea, what should I watch for?" }
  ],
  "petName": "Milo",
  "petSpecies": "Dog",
  "petContext": "recent diet change",
  "provider": "claude"
}
```

Response:

```json
{
  "reply": "....",
  "provider": "claude"
}
```
