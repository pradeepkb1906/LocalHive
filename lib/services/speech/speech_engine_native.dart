import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'speech_engine.dart';

/// The Android/iOS speech engine: flutter_tts over the platform synthesizers.
///
/// Everything here is about sounding like Olivia and refusing to go silent:
/// prefer a natural female American voice at every fallback step, and if the
/// chosen voice fails to actually produce sound (Android will happily accept a
/// voice whose data is not installed and then say nothing), hand control back
/// to the device default and try again.
class SpeechEngineImpl implements SpeechEngine {
  final FlutterTts _tts = FlutterTts();

  @override
  void Function()? onStart;
  @override
  void Function()? onDone;
  @override
  void Function(String word)? onWord;

  bool _speaking = false;
  @override
  bool get isSpeaking => _speaking;

  bool _wired = false;
  bool _voiceFellBack = false;

  /// Voices that sound like a natural young American woman, best first.
  static const _preferredVoices = <String>[
    'samantha', 'ava', 'allison', 'susan', // Apple
    'en-us-x-tpf-local', 'en-us-x-tpf-network', 'en-us-x-tpd-local', // Google
    'aria', 'jenny', 'zira', // Microsoft
  ];

  /// Names that identify a female voice when the platform reports no gender
  /// field, which is common on Android.
  static const _femaleNames = <String>[
    'samantha', 'ava', 'allison', 'susan', 'karen', 'moira', 'tessa',
    'fiona', 'serena', 'zoe', 'nicky', 'joelle',
    'aria', 'jenny', 'zira', 'michelle', 'clara',
    'tpf', 'tpd', 'sfg', // Google's female voice codes
    'female',
  ];

  Future<void> _wire() async {
    if (_wired) return;
    _wired = true;
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
      // Not iOS.
    }
    try {
      await _tts.setLanguage('en-US');
      // Native engines treat ~0.5 as conversational pace.
      await _tts.setSpeechRate(0.50);
      await _tts.setPitch(1.06);
      await _tts.setVolume(1.0);
      await _chooseVoice();
    } catch (_) {}

    _tts.setStartHandler(() {
      _speaking = true;
      onStart?.call();
    });
    _tts.setProgressHandler((text, start, end, word) {
      final w = word.trim();
      if (w.isNotEmpty) onWord?.call(w);
    });
    _tts.setCompletionHandler(_finish);
    _tts.setCancelHandler(_finish);
    _tts.setErrorHandler((msg) {
      debugPrint('Olivia speak error: $msg');
      _finish();
      // The usual Android symptom of a voice whose data is not installed is an
      // async error rather than a thrown exception, so recover here too.
      _fallBackToDeviceVoice();
    });
  }

  void _finish() {
    if (!_speaking) return;
    _speaking = false;
    onDone?.call();
  }

  bool _isFemale(Map<String, dynamic> v) {
    final gender = (v['gender'] ?? '').toString().toLowerCase();
    if (gender.contains('female')) return true;
    if (gender.contains('male')) return false; // explicit male, not female
    final name = (v['name'] ?? '').toString().toLowerCase();
    return _femaleNames.any(name.contains);
  }

  /// Picks the most natural American English voice the device has: a
  /// known-good US voice, then any US English female, then any English female
  /// — better a British woman than an American man, for a character who is a
  /// woman — then any US English, and finally the platform default.
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
      for (final wanted in _preferredVoices) {
        pick = voices
            .where((v) => nameOf(v).contains(wanted) && isUs(v))
            .firstOrNull;
        if (pick != null) break;
        pick = voices.where((v) => nameOf(v).contains(wanted)).firstOrNull;
        if (pick != null) break;
      }
      pick ??= voices.where((v) => isUs(v) && _isFemale(v)).firstOrNull;
      pick ??= voices.where((v) => isEnglish(v) && _isFemale(v)).firstOrNull;
      pick ??= voices.where(isUs).firstOrNull;
      if (pick == null) return;

      await _tts.setVoice({
        'name': pick['name'].toString(),
        'locale': (pick['locale'] ?? pick['language'] ?? 'en-US').toString(),
      });
      debugPrint('Olivia is using the "${pick['name']}" voice');
    } catch (e) {
      debugPrint('Could not choose a voice for Olivia: $e');
    }
  }

  /// Abandons the chosen voice and lets the device use its own default.
  /// Silence is far worse than a plainer voice.
  Future<void> _fallBackToDeviceVoice() async {
    if (_voiceFellBack) return;
    _voiceFellBack = true;
    debugPrint('Olivia: chosen voice did not speak, using the device default');
    try {
      await _tts.setLanguage('en-US');
    } catch (_) {}
  }

  @override
  Future<void> speak(String text) async {
    final say = text.trim();
    if (say.isEmpty) return;
    await _wire();
    try {
      await _tts.stop();
      _speaking = true;
      await _tts.speak(say);
    } catch (e) {
      debugPrint('Olivia could not speak with the chosen voice: $e');
      await _fallBackToDeviceVoice();
      try {
        _speaking = true;
        await _tts.speak(say);
      } catch (e2) {
        debugPrint('Olivia cannot speak on this device at all: $e2');
        _finish();
      }
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _finish();
  }

  @override
  void dispose() {
    _tts.stop();
  }
}
