/**
 * Olivia's Groq proxy.
 *
 * Exists for one reason: a Groq API key must never ship inside the LocalHive
 * web bundle or APK. Anything compiled into the app is readable by anyone who
 * installs it, and a leaked key is charged to the project owner's account.
 * The key lives here as a Worker secret and never reaches a customer's device.
 *
 * It also checks that the caller is a signed-in LocalHive user, so a stranger
 * who finds this URL cannot spend the quota.
 *
 * Deploy:
 *   cd worker/olivia-proxy
 *   npx wrangler secret put GROQ_API_KEY     # paste the key when prompted
 *   npx wrangler deploy
 * Then put the printed URL into lib/olivia_config.dart as proxyUrl and blank
 * out groqKey.
 */

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';

// Only these origins may call the proxy from a browser.
const ALLOWED_ORIGINS = [
  'https://pradeepkb1906.github.io',
  'http://localhost:8090',
  'http://127.0.0.1:8090',
];

// Models the proxy is willing to forward. Stops a tampered client from
// switching to something far more expensive.
// Must match OliviaConfig.models in the app, or a fallback would be refused
// here at the proxy.
const ALLOWED_MODELS = new Set([
  'openai/gpt-oss-120b',
  'openai/gpt-oss-20b',
  'llama-3.3-70b-versatile',
  'qwen/qwen3.6-27b',
  'llama-3.1-8b-instant',
]);

const MAX_TOKENS = 900;
const MAX_MESSAGES = 40;

function corsHeaders(origin) {
  // Native apps send no Origin header, so allow those through without one.
  const allow = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, content-type',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}

function json(body, status, origin) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
  });
}

/**
 * Verifies a Firebase ID token by asking Firebase itself.
 *
 * accounts:lookup validates the token's signature, expiry AND that it was
 * minted for this project (the API key identifies the project, so a token from
 * someone else's Firebase app comes back INVALID_ID_TOKEN). One round trip, no
 * crypto dependencies, and it cannot drift from Firebase's own rules.
 *
 * Google's generic oauth2 tokeninfo endpoint does NOT work here — Firebase ID
 * tokens are signed by the securetoken service, not Google's OAuth keys, so
 * tokeninfo rejects every one of them. That mistake shipped once; hence this
 * comment.
 */
async function verifyFirebaseUser(request, apiKey) {
  const auth = request.headers.get('Authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  if (!token) return { ok: false, reason: 'missing token' };
  if (!apiKey) return { ok: false, reason: 'proxy missing FIREBASE_API_KEY' };

  try {
    const resp = await fetch(
      'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' +
        encodeURIComponent(apiKey),
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken: token }),
      },
    );
    if (!resp.ok) return { ok: false, reason: 'token rejected' };
    const info = await resp.json();
    const uid = info.users && info.users[0] && info.users[0].localId;
    if (!uid) return { ok: false, reason: 'no user' };
    return { ok: true, uid };
  } catch (e) {
    return { ok: false, reason: 'verification failed' };
  }
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin');

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }
    if (request.method !== 'POST') {
      return json({ error: 'POST only' }, 405, origin);
    }
    if (!env.GROQ_API_KEY) {
      return json({ error: 'Proxy is missing GROQ_API_KEY' }, 500, origin);
    }

    // A signed-in LocalHive user, unless the deployment explicitly opts out.
    if (env.REQUIRE_AUTH !== 'false') {
      const user = await verifyFirebaseUser(request, env.FIREBASE_API_KEY);
      if (!user.ok) {
        return json({ error: 'Sign-in required: ' + user.reason }, 401, origin);
      }
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'Body must be JSON' }, 400, origin);
    }

    // Olivia's spoken voice: text in, WAV out, everything else pinned here.
    // The model is fixed so a tampered client cannot pick something pricier,
    // and the input is capped because Olivia's replies are short by design —
    // anything longer than this is not her talking.
    if (new URL(request.url).pathname === '/tts') {
      const input = typeof body.input === 'string' ? body.input.trim() : '';
      if (!input) return json({ error: 'input required' }, 400, origin);
      if (input.length > 600) {
        return json({ error: 'input too long' }, 400, origin);
      }
      const voice = ['autumn', 'diana', 'hannah'].includes(body.voice)
        ? body.voice
        : 'autumn';

      let upstream;
      try {
        upstream = await fetch('https://api.groq.com/openai/v1/audio/speech', {
          method: 'POST',
          headers: {
            Authorization: 'Bearer ' + env.GROQ_API_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model: 'canopylabs/orpheus-v1-english',
            voice,
            input,
            response_format: 'wav',
          }),
        });
      } catch {
        return json({ error: 'Could not reach the voice service' }, 502, origin);
      }
      if (!upstream.ok) {
        return json({ error: 'Voice service error' }, upstream.status, origin);
      }
      return new Response(upstream.body, {
        status: 200,
        headers: { 'Content-Type': 'audio/wav', ...corsHeaders(origin) },
      });
    }

    if (!ALLOWED_MODELS.has(body.model)) {
      return json({ error: 'Model not allowed' }, 400, origin);
    }
    if (!Array.isArray(body.messages) || body.messages.length === 0) {
      return json({ error: 'messages required' }, 400, origin);
    }
    if (body.messages.length > MAX_MESSAGES) {
      return json({ error: 'Too many messages' }, 400, origin);
    }

    // Cap spend per call regardless of what the client asked for.
    const payload = {
      ...body,
      max_tokens: Math.min(Number(body.max_tokens) || MAX_TOKENS, MAX_TOKENS),
      stream: false,
    };

    let upstream;
    try {
      upstream = await fetch(GROQ_URL, {
        method: 'POST',
        headers: {
          Authorization: 'Bearer ' + env.GROQ_API_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });
    } catch {
      return json({ error: 'Could not reach the model service' }, 502, origin);
    }

    // Pass the status through so the app can tell a rate limit from a fault,
    // but never leak upstream headers (which can echo key metadata).
    const text = await upstream.text();
    return new Response(text, {
      status: upstream.status,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  },
};
