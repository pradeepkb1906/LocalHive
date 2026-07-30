import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

const bool speechRecognizerIsWeb = false;

/// Android/iOS speech recognition through the platform recognisers, where the
/// speech_to_text plugin is reliable.
class SpeechRecognizerImpl {
  final SpeechToText _stt = SpeechToText();
  bool _ready = false;

  bool get isListening => _stt.isListening;
  bool get isSupported => true;

  /// Initialises the recogniser, which triggers the platform's microphone
  /// permission dialog. Returns false when refused or unavailable.
  Future<bool> requestPermission() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(
        onError: (e) => debugPrint('Speech recognition error: ${e.errorMsg}'),
        onStatus: (s) => debugPrint('Speech recognition status: $s'),
      );
    } catch (e) {
      debugPrint('Speech recognition init failed: $e');
      _ready = false;
    }
    return _ready;
  }

  Future<bool> listen({
    required void Function(String) onPartial,
    required void Function(String) onFinal,
  }) async {
    if (!await requestPermission()) return false;
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
      debugPrint('Speech recognition listen failed: $e');
      return false;
    }
  }

  void stop() {
    _stt.stop();
  }

  void cancel() {
    _stt.cancel();
  }
}
