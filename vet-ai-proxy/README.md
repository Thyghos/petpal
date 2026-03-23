# Petpal Vet AI Proxy (Cloudflare Worker)

Server-side proxy for Vet AI so API keys are not shipped in the iOS app.

## What it supports

- `CLAUDE_API_KEY` (Anthropic)
- `GEMINI_API_KEY` (Google Gemini)
- Optional shared bearer token via `APP_SHARED_SECRET`

Provider behavior:

- Default order: Claude first, then Gemini fallback
- You can request a provider by sending `"provider": "claude"` or `"provider": "gemini"` in the request body

## Deploy

```bash
cd vet-ai-proxy
npx wrangler secret put CLAUDE_API_KEY
npx wrangler secret put GEMINI_API_KEY
npx wrangler secret put APP_SHARED_SECRET
npx wrangler deploy
```

## Request

`POST /v1/vet-chat`

Headers:

- `Content-Type: application/json`
- `Authorization: Bearer <APP_SHARED_SECRET>` (if configured)

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
