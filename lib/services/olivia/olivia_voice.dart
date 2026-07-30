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

  /// Voices that sound like a natural young American woman, best first.
  ///
  /// Every platform ships a different set, so this is a preference order rather
  /// than a single choice: the first one actually installed wins, and if none
  /// are, any US English female voice will do. Matching is on substrings
  /// because the exact names vary by OS version.
  static const _preferredVoices = <String>[
    // Apple's natural-sounding US voices (iOS, macOS, Safari).
    'samantha',
    'ava',
    'allison',
    'susan',
    // Google's US female voices (Android, Chrome). The -tpf-/-tpd- variants
    // are the female ones.
    'en-us-x-tpf-local',
    'en-us-x-tpf-network',
    'en-us-x-tpd-local',
    'google us english',
    // Microsoft (Windows, Edge).
    'aria',
    'jenny',
    'zira',
  ];

  Future<void> _wireHandlers() async {
    if (_handlersWired) return;
    _handlersWired = true;
    try {
      // iOS shares one audio session between recording and playback. Without
      // this, Olivia goes silent after the first time the customer speaks,
      // because the session is still in record mode.
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    } catch (_) {
      // Not iOS, or the platform does not expose it.
    }
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.50);
      await _tts.setPitch(1.06);
      await _tts.setVolume(1.0);
      await _chooseVoice();
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
      // The usual Android symptom of a voice whose data is not installed is an
      // async error rather than a thrown exception, so recover here too.
      _fallBackToDeviceVoice();
    });
  }

  /// Names that identify a female voice on the platforms we ship to. Used when
  /// a voice entry carries no gender field, which is common on Android.
  static const _femaleNames = <String>[
    'samantha', 'ava', 'allison', 'susan', 'karen', 'moira', 'tessa',
    'fiona', 'serena', 'zoe', 'nicky', 'joelle',
    'aria', 'jenny', 'zira', 'michelle', 'clara',
    'tpf', 'tpd', 'sfg', // Google's female voice codes
    'female',
  ];

  /// True once a chosen voice has been rejected and we have reverted to the
  /// platform default, so we do not fight the OS on every utterance.
  bool _voiceFellBack = false;

  bool _isFemale(Map<String, dynamic> v) {
    final gender = (v['gender'] ?? '').toString().toLowerCase();
    if (gender.contains('female')) return true;
    if (gender.contains('male')) return false; // explicit male, not female
    final name = (v['name'] ?? '').toString().toLowerCase();
    return _femaleNames.any(name.contains);
  }

  /// Picks the most natural American English voice the device has.
  ///
  /// The default voice is whatever the OS chose, which is often a flat robotic
  /// one, sometimes male, and sometimes not even US English. Preference order:
  /// a known-good US voice, then any US English female, then any English
  /// female, then any US English, and finally the platform default. Olivia is
  /// a woman, so a female voice is preferred at every step before locale is.
  Future<void> _chooseVoice() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return;
      final voices = raw
          .map((v) => Map<String, dynamic>.from(v as Map))
          .where((v) => (v['name'] ?? '').toString().isNotEmpty)
          .toList();
      if (voices.isEmpty) return;

      String nameOf(Map<String, dynamic> v) =>
          (v['name'] ?? '').toString().toLowerCase();
      String localeOf(Map<String, dynamic> v) =>
          (v['locale'] ?? v['language'] ?? '').toString().toLowerCase();
      bool isUs(Map<String, dynamic> v) =>
          localeOf(v).startsWith('en-us') || localeOf(v).startsWith('en_us');

      bool isEnglish(Map<String, dynamic> v) => localeOf(v).startsWith('en');

      Map<String, dynamic>? pick;
      // 1. A voice we know sounds good, US English.
      for (final wanted in _preferredVoices) {
        pick = voices
            .where((v) => nameOf(v).contains(wanted) && isUs(v))
            .firstOrNull;
        if (pick != null) break;
        // Some platforms report no locale on the voice at all.
        pick = voices.where((v) => nameOf(v).contains(wanted)).firstOrNull;
        if (pick != null) break;
      }
      // 2. Any US English female. 3. Any English female — better a British
      // woman than an American man, for a character who is a woman.
      pick ??= voices.where((v) => isUs(v) && _isFemale(v)).firstOrNull;
      pick ??= voices.where((v) => isEnglish(v) && _isFemale(v)).firstOrNull;
      // 4. Any US English at all.
      pick ??= voices.where(isUs).firstOrNull;
      if (pick == null) return;

      await _tts.setVoice({
        'name': pick['name'].toString(),
        'locale': (pick['locale'] ?? pick['language'] ?? 'en-US').toString(),
      });
      debugPrint('Olivia is using the "${pick['name']}" voice');
    } catch (e) {
      // Not every platform exposes voice selection; the default still speaks.
      debugPrint('Could not choose a voice for Olivia: $e');
    }
  }

  /// Abandons the chosen voice and lets the device use whichever voice it would
  /// normally use.
  ///
  /// Android in particular will accept [FlutterTts.setVoice] for a voice whose
  /// data is not actually installed and then simply say nothing. Silence is far
  /// worse than a plainer voice, so the moment speaking fails we hand control
  /// back to the platform and try again.
  Future<void> _fallBackToDeviceVoice() async {
    if (_voiceFellBack) return;
    _voiceFellBack = true;
    debugPrint('Olivia: chosen voice did not speak, using the device default');
    try {
      await _tts.setLanguage('en-US');
    } catch (_) {}
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

  /// Says something out loud.
  ///
  /// If the chosen voice fails, retries once on the device's own default voice
  /// rather than leaving her silent. Safe to call when muted or unsupported —
  /// the transcript on screen carries the conversation either way.
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
      debugPrint('Olivia could not speak with the chosen voice: $e');
      await _fallBackToDeviceVoice();
      try {
        _speaking = true;
        _startMouthTimer();
        await _tts.speak(say);
      } catch (e2) {
        debugPrint('Olivia cannot speak on this device at all: $e2');
        _finishSpeaking();
      }
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
