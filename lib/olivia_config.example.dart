/// Configuration for Olivia, the in-app voice assistant.
///
/// Copy this file to `lib/olivia_config.dart` and fill it in. That file is
/// gitignored, exactly like `firebase_config.dart`.
///
/// IMPORTANT — unlike the Firebase values, a Groq API key is a real secret.
/// Anything compiled into the app ships to every user: it is readable in the
/// web bundle's JavaScript and extractable from the APK. So `groqKey` below is
/// for LOCAL DEVELOPMENT ONLY. For anything you deploy, leave `groqKey` empty
/// and point `proxyUrl` at the Cloudflare Worker in `worker/olivia-proxy/`,
/// which holds the key server-side.
library;

class OliviaConfig {
  /// The Cloudflare Worker endpoint that forwards to Groq. Preferred.
  /// Example: 'https://localhive-olivia.<your-subdomain>.workers.dev'
  static const proxyUrl = '';

  /// Local-development escape hatch. Calls api.groq.com directly with this key
  /// baked into the build. Never set this in a build you publish.
  static const groqKey = '';

  /// Models tried in order, most capable first. Olivia falls through to the
  /// next one when a model is rate-limited, over capacity, or garbles its own
  /// tool-call syntax — so one model having a bad day never takes her offline.
  ///
  /// Order is based on measured tool-calling reliability with this prompt and
  /// tool set: gpt-oss was clean 18/18, llama-3.3 garbled 5 of 18. llama and
  /// qwen sit lower as backups because they are faster but less dependable.
  static const models = <String>[
    'openai/gpt-oss-120b',
    'openai/gpt-oss-20b',
    'llama-3.3-70b-versatile',
    'qwen/qwen3.6-27b',
    'llama-3.1-8b-instant',
  ];

  /// Set false to hide Olivia entirely (e.g. if the proxy is not deployed yet).
  static const enabled = true;
}
