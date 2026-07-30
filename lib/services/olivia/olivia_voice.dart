import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Olivia's ears and mouth.
///
/// Speech recognition runs on the device, so it needs no API key and costs
/// nothing. Speech output uses the platform voice, and its word-boundary
/// callbacks drive [mouthOpen] so the avatar's lips move roughly in time with
/// what is being said.
class OliviaVoice {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _handlersWired = false;
  bool _speaking = false;

  /// 0 closed to 1 wide. The avatar listens to this.
  final ValueNotifier<double> mouthOpen = ValueNotifier(0);

  Timer? _mouthTimer;
  final _rng = math.Random();

  bool get isListening => _stt.isListening;
  bool get isSpeaking => _speaking;

  // ------------------------------------------------------------------ speech

  /// Asks for the microphone and initialises recognition. Returns false when
  /// permission is refused or the platform has no recogniser.
  Future<bool> prepareMic() async {
    if (_sttReady) return true;
    try {
      _sttReady = await _stt.initialize(
        onError: (e) => debugPrint('Olivia speech error: ${e.errorMsg}'),
        onStatus: (s) => debugPrint('Olivia speech status: $s'),
      );
    } catch (e) {
      debugPrint('Olivia speech init failed: $e');
      _sttReady = false;
    }
    return _sttReady;
  }

  /// Listens until the customer stops talking. [onPartial] fires as words
  /// arrive; [onFinal] fires once with the complete utterance.
  Future<bool> listen({
    required void Function(String) onPartial,
    required void Function(String) onFinal,
  }) async {
    if (!await prepareMic()) return false;
    await stopSpeaking();

    var lastHeard = '';
    try {
      await _stt.listen(
        onResult: (result) {
          lastHeard = result.recognizedWords;
          if (result.finalResult) {
            onFinal(lastHeard);
          } else {
            onPartial(lastHeard);
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          // Ordering food involves proper nouns the recogniser guesses at, so
          // prefer dictation-style handling over command matching.
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          localeId: 'en_US',
          // Long enough to describe a whole order in one breath, then a few
          // seconds of silence to decide they have finished.
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Olivia listen failed: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }

  Future<void> cancelListening() async {
    try {
      await _stt.cancel();
    } catch (_) {}
  }

  // ------------------------------------------------------------------- voice

  Future<void> _wireHandlers() async {
    if (_handlersWired) return;
    _handlersWired = true;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.50);
      await _tts.setPitch(1.06);
      await _tts.setVolume(1.0);
    } catch (_) {}

    // Word boundaries are reported on Android and on the web; where they are
    // not, the timer below carries the animation on its own.
    _tts.setProgressHandler((text, start, end, word) {
      final len = word.trim().length;
      // Longer words open the mouth wider, with a little variation so it does
      // not look mechanical.
      final target = (0.34 + math.min(len, 9) / 9 * 0.5).clamp(0.0, 0.95);
      mouthOpen.value = target * (0.85 + _rng.nextDouble() * 0.15);
    });

    _tts.setStartHandler(() {
      _speaking = true;
      _startMouthTimer();
    });
    _tts.setCompletionHandler(_finishSpeaking);
    _tts.setCancelHandler(_finishSpeaking);
    _tts.setErrorHandler((msg) {
      debugPrint('Olivia speak error: $msg');
      _finishSpeaking();
    });
  }

  /// Keeps the mouth moving between word callbacks, and is the only driver on
  /// platforms that report no word boundaries at all.
  void _startMouthTimer() {
    _mouthTimer?.cancel();
    var tick = 0;
    _mouthTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!_speaking) return;
      tick++;
      // A syllable-ish rhythm: open, half, closed, repeat, with jitter.
      final base = switch (tick % 4) {
        0 => 0.62,
        1 => 0.30,
        2 => 0.72,
        _ => 0.18,
      };
      final jitter = (_rng.nextDouble() - 0.5) * 0.18;
      final next = (base + jitter).clamp(0.05, 0.95);
      // Ease toward the target so it never snaps.
      mouthOpen.value = mouthOpen.value + (next - mouthOpen.value) * 0.65;
    });
  }

  void _finishSpeaking() {
    _speaking = false;
    _mouthTimer?.cancel();
    _mouthTimer = null;
    mouthOpen.value = 0;
  }

  /// Says something out loud. Safe to call when muted or unsupported — the
  /// transcript on screen carries the conversation either way.
  Future<void> speak(String text) async {
    final say = text.trim();
    if (say.isEmpty) return;
    await _wireHandlers();
    try {
      await _tts.stop();
      _speaking = true;
      _startMouthTimer();
      await _tts.speak(say);
    } catch (e) {
      debugPrint('Olivia could not speak: $e');
      _finishSpeaking();
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _finishSpeaking();
  }

  void dispose() {
    _mouthTimer?.cancel();
    mouthOpen.dispose();
    _tts.stop();
    _stt.cancel();
  }
}
