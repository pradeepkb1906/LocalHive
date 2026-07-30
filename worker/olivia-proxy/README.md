# Olivia's Groq proxy

A ~130-line Cloudflare Worker that stands between the LocalHive app and Groq.

## Why this exists

Anything compiled into the Flutter app ships to every user. The web build's
JavaScript can be read in any browser's dev tools, and an APK can be unzipped.
So a Groq API key placed in the app is effectively public — and it is billed to
whoever owns the Groq account.

This Worker holds the key instead. The app calls the Worker; the Worker calls
Groq. The key never leaves Cloudflare.

It also verifies the caller's Firebase ID token, so someone who discovers the
Worker URL cannot use it without a LocalHive account.

## Deploying it

Free tier is 100,000 requests/day and needs no credit card.

```bash
cd worker/olivia-proxy

# One-off: sign in to Cloudflare (opens a browser)
npx wrangler login

# Store the key. Paste it when prompted — it is never written to a file.
npx wrangler secret put GROQ_API_KEY

npx wrangler deploy
```

Deploy prints a URL like `https://localhive-olivia.<subdomain>.workers.dev`.
Put it in `lib/olivia_config.dart`:

```dart
static const proxyUrl = 'https://localhive-olivia.<subdomain>.workers.dev';
static const groqKey = '';   // must be empty in anything you publish
```

Then rebuild. Olivia's screen shows an orange "development build" warning
whenever `groqKey` is set, so it is obvious if a build still carries the key.

## What it enforces

| Guard | Why |
|---|---|
| Firebase ID token required | Strangers cannot spend the quota |
| Token audience must match the project | A token from another Firebase app is refused |
| Model allowlist | A tampered client cannot switch to a costlier model |
| `max_tokens` capped at 900 | Bounds the cost of any single call |
| Max 40 messages | Bounds the cost of a long conversation |
| Origin allowlist for CORS | Other websites cannot call it from a browser |
| Upstream headers not forwarded | Avoids echoing key metadata back |

Rate-limit responses (429) pass straight through so Olivia can tell the
customer to try again in a moment rather than showing a generic failure.

## Changing the allowed origins

`ALLOWED_ORIGINS` in `src/index.js` lists the GitHub Pages origin and localhost.
Add any new web origin there. Native apps send no `Origin` header and are
unaffected.
