import 'speech_engine_native.dart'
    if (dart.library.js_interop) 'speech_engine_web.dart';

/// The app's one way of saying something out loud.
///
/// Two implementations, chosen at compile time:
///
/// * On Android and iOS, a wrapper around flutter_tts — the platform speech
///   engines behave well there and the plugin is a thin veneer over them.
/// * On the web, the browser's SpeechSynthesis API driven directly. The plugin
///   is NOT used on web: its web code keeps one SpeechSynthesisUtterance for
///   the life of the page and mutates it for every sentence, and Chrome
///   silently drops a reused utterance once it has been through a cancel() —
///   no audio, no events, nothing. That one object made Olivia and the demo
///   tour mute in every browser. Driving the API ourselves costs ~100 lines
///   and lets us do the one thing that matters: a fresh utterance per
///   sentence.
///
/// Callbacks, not streams: there is exactly one listener (the voice layer),
/// and callbacks keep the web implementation free of dart:async plumbing.
abstract class SpeechEngine {
  /// Playback genuinely started — the engine is producing audio.
  void Function()? onStart;

  /// The utterance finished, was cancelled, or failed. Always fires after
  /// [onStart], and also fires when playback never managed to start.
  void Function()? onDone;

  /// A word boundary, where the platform reports them (web and Android do,
  /// iOS mostly does not). Drives the mouth animation.
  void Function(String word)? onWord;

  /// True from just before audio starts until [onDone].
  bool get isSpeaking;

  /// Says [text], replacing anything currently being said. Resolves when the
  /// utterance has been handed to the platform, not when it finishes.
  Future<void> speak(String text);

  Future<void> stop();

  void dispose();

  factory SpeechEngine() = SpeechEngineImpl;
}
