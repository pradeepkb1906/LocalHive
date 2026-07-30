import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../olivia_config.dart';
import '../firebase_service.dart';
import 'speech_engine.dart';

// Hand-rolled bindings for the three Web Speech types we touch. Written here
// rather than pulled from a package so this file has no dependencies and no
// version skew with the browser API, which has been stable for a decade.

@JS('speechSynthesis')
external _Synth get _synth;

@JS()
extension type _Synth(JSObject _) implements JSObject {
  external void speak(_Utterance utterance);
  external void cancel();
  external void resume();
  external JSArray<_Voice> getVoices();
  external bool get paused;
  external set onvoiceschanged(JSFunction? handler);
}

@JS('SpeechSynthesisUtterance')
extension type _Utterance._(JSObject _) implements JSObject {
  external factory _Utterance(String text);
  external set rate(num value);
  external set pitch(num value);
  external set volume(num value);
  external set lang(String value);
  external set voice(_Voice? value);
  external set onstart(JSFunction? handler);
  external set onend(JSFunction? handler);
  external set onerror(JSFunction? handler);
  external set onboundary(JSFunction? handler);
}

@JS()
extension type _Voice(JSObject _) implements JSObject {
  external String get name;
  external String get lang;
  external bool get localService;
}

@JS()
extension type _BoundaryEvent(JSObject _) implements JSObject {
  external int get charIndex;
  external String get name;
}

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSUint8Array> parts, _BlobOptions options);
}

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}

@JS('URL.createObjectURL')
external String _createObjectURL(_Blob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectURL(String url);

@JS('Audio')
extension type _Audio._(JSObject _) implements JSObject {
  external factory _Audio(String src);
  external JSPromise<JSAny?> play();
  external void pause();
  external set onplay(JSFunction? handler);
  external set onended(JSFunction? handler);
  external set onerror(JSFunction? handler);
}

/// The web speech engine: the browser's SpeechSynthesis, driven directly.
///
/// The rules this file lives by, each one earned:
///
/// * A FRESH utterance for every sentence. Chrome silently kills a reused
///   utterance object after a cancel — the exact failure that made Olivia
///   mute. The current utterance is also held in a field, because Chrome has
///   been known to garbage-collect an in-flight utterance and stop mid-word.
/// * resume() before every speak. A page's synthesis can be left paused (the
///   state survives navigation within the page), and speak() while paused
///   queues forever without a sound.
/// * rate 1.0 is normal speed here. flutter_tts trained the app to say 0.5,
///   which on the web is genuinely half speed — one more reason not to share
///   numbers between the implementations.
class SpeechEngineImpl implements SpeechEngine {
  @override
  void Function()? onStart;
  @override
  void Function()? onDone;
  @override
  void Function(String word)? onWord;

  bool _speaking = false;
  @override
  bool get isSpeaking => _speaking;

  /// Strong reference to the in-flight utterance — see the GC note above.
  _Utterance? _current;

  _Voice? _chosen;
  bool _voicePicked = false;

  /// Olivia is a young American woman; prefer voices that sound like one.
  /// Substring matches, best first, against whatever this browser ships.
  static const _preferred = <String>[
    'samantha', // macOS / iOS Safari + Chrome
    'google us english', // Chrome's own female US voice
    'ava',
    'allison',
    'susan',
    'aria', // Windows / Edge
    'jenny',
    'zira',
  ];

  SpeechEngineImpl() {
    _pickVoice();
    // Chrome loads the voice list asynchronously; getVoices() is often empty
    // at startup. Re-pick when the list actually arrives.
    _synth.onvoiceschanged = (() => _pickVoice()).toJS;
  }

  void _pickVoice() {
    final voices = _synth.getVoices().toDart;
    if (voices.isEmpty) return;

    _Voice? pick;
    for (final wanted in _preferred) {
      for (final v in voices) {
        if (v.name.toLowerCase().contains(wanted)) {
          pick = v;
          break;
        }
      }
      if (pick != null) break;
    }
    // Any US English, then any English, before giving up and letting the
    // browser choose.
    pick ??= voices
        .where((v) => v.lang.toLowerCase().startsWith('en-us'))
        .firstOrNull;
    pick ??=
        voices.where((v) => v.lang.toLowerCase().startsWith('en')).firstOrNull;

    _chosen = pick;
    if (pick != null && !_voicePicked) {
      _voicePicked = true;
      debugPrint('Olivia speaks with the "${pick.name}" browser voice');
    }
  }

  /// The Orpheus audio being played, if her human voice is on. Kept as a
  /// field so stop() can silence it and the element cannot be collected
  /// mid-sentence.
  _Audio? _audio;
  String? _audioUrl;

  /// Speaks with her real recorded-quality voice — Groq's Orpheus model,
  /// generated server-side by the same worker that guards the chat key — and
  /// returns true when the audio is actually playing. Falls back to browser
  /// synthesis on any failure: not signed in, offline, worker down, or the
  /// browser refusing playback. Silence is never an acceptable outcome.
  Future<bool> _speakHuman(String say) async {
    if (OliviaConfig.proxyUrl.isEmpty || say.length > 600) return false;
    try {
      final token = await FirebaseService.instance.currentUser?.getIdToken();
      if (token == null) return false;

      final resp = await http
          .post(
            Uri.parse('${OliviaConfig.proxyUrl}/tts'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: '{"input": ${_jsonString(say)}}',
          )
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200 || resp.bodyBytes.length < 1000) return false;

      final blob = _Blob(
        [resp.bodyBytes.toJS].toJS,
        _BlobOptions(type: 'audio/wav'),
      );
      final url = _createObjectURL(blob);
      final audio = _Audio(url);
      _audio = audio;
      _audioUrl = url;

      audio.onplay = (JSAny e) {
        if (_audio == audio) {
          _speaking = true;
          onStart?.call();
        }
      }.toJS;
      audio.onended = (JSAny e) {
        if (_audio == audio) {
          _speaking = false;
          _disposeAudio();
          onDone?.call();
        }
      }.toJS;
      audio.onerror = (JSAny e) {
        if (_audio == audio) {
          _speaking = false;
          _disposeAudio();
          onDone?.call();
        }
      }.toJS;

      await audio.play().toDart;
      return true;
    } catch (e) {
      debugPrint('Olivia human voice unavailable, using browser voice: $e');
      _disposeAudio();
      return false;
    }
  }

  static String _jsonString(String s) {
    final b = StringBuffer('"');
    for (final code in s.codeUnits) {
      switch (code) {
        case 0x22:
          b.write(r'\"');
        case 0x5c:
          b.write(r'\\');
        case >= 0x00 && <= 0x1f:
          b.write('\\u${code.toRadixString(16).padLeft(4, '0')}');
        default:
          b.writeCharCode(code);
      }
    }
    b.write('"');
    return b.toString();
  }

  void _disposeAudio() {
    _audio = null;
    final url = _audioUrl;
    _audioUrl = null;
    if (url != null) _revokeObjectURL(url);
  }

  @override
  Future<void> speak(String text) async {
    final say = text.trim();
    if (say.isEmpty) return;

    await stop();

    // Her human voice first; the browser's synthetic one only as a fallback.
    if (await _speakHuman(say)) return;

    // Never speak without an explicitly chosen English voice if it can be
    // helped. Android Chrome often reports an EMPTY voice list until the
    // first utterance, and an utterance with no voice object falls back to
    // the phone's default speech voice — whatever language that happens to
    // be. Olivia introduced herself in Spanish on exactly this path. Waiting
    // a moment for the list beats speaking wrongly right away.
    if (_chosen == null) {
      for (var attempt = 0; attempt < 10 && _chosen == null; attempt++) {
        _pickVoice();
        if (_chosen != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    final u = _Utterance(say);
    _current = u;
    if (_chosen != null) {
      u.voice = _chosen;
      u.lang = _chosen!.lang;
    } else {
      u.lang = 'en-US';
    }
    u.rate = 1.0;
    u.pitch = 1.05;
    u.volume = 1.0;

    u.onstart = (JSAny e) {
      _speaking = true;
      onStart?.call();
    }.toJS;
    u.onend = (JSAny e) {
      if (_current == u) {
        _speaking = false;
        _current = null;
        onDone?.call();
      }
    }.toJS;
    u.onerror = (JSAny e) {
      // 'interrupted' and 'canceled' arrive here on every stop(); that is the
      // normal end of a replaced utterance, not a failure worth surfacing.
      if (_current == u) {
        _speaking = false;
        _current = null;
        onDone?.call();
      }
    }.toJS;
    u.onboundary = (_BoundaryEvent e) {
      if (e.name == 'sentence') return;
      final i = e.charIndex;
      if (i < 0 || i >= say.length) return;
      var end = i;
      while (end < say.length && !' ,.!?;:'.contains(say[end])) {
        end++;
      }
      if (end > i) onWord?.call(say.substring(i, end));
    }.toJS;

    // A paused synthesis swallows speak() without a sound.
    if (_synth.paused) _synth.resume();
    _synth.speak(u);
  }

  @override
  Future<void> stop() async {
    // Silence the human voice if it is playing.
    final audio = _audio;
    if (audio != null) {
      _disposeAudio();
      try {
        audio.pause();
      } catch (_) {}
      if (_speaking) {
        _speaking = false;
        onDone?.call();
      }
    }
    // Detach first: the cancel fires this utterance's end/error, and that must
    // not be reported as the NEXT utterance finishing.
    final old = _current;
    _current = null;
    if (old != null || _speaking) {
      _speaking = false;
      _synth.cancel();
      onDone?.call();
    }
  }

  @override
  void dispose() {
    final audio = _audio;
    _disposeAudio();
    try {
      audio?.pause();
    } catch (_) {}
    _current = null;
    _synth.onvoiceschanged = null;
    _synth.cancel();
  }
}
