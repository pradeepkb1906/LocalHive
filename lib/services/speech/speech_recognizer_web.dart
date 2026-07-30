import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

const bool speechRecognizerIsWeb = true;

// ---- Bindings for the browser's own speech recognition. ----
//
// Bound to the webkit-prefixed name deliberately: Chrome ships BOTH names and
// iOS Safari ships ONLY the prefixed one, so the prefix is the one spelling
// that works everywhere recognition exists at all.

@JS('webkitSpeechRecognition')
external JSAny? get _recognitionCtor;

@JS('webkitSpeechRecognition')
extension type _Recognition._(JSObject _) implements JSObject {
  external factory _Recognition();
  external set lang(String value);
  external set continuous(bool value);
  external set interimResults(bool value);
  external set maxAlternatives(int value);
  external void start();
  external void stop();
  external void abort();
  external set onresult(JSFunction? handler);
  external set onerror(JSFunction? handler);
  external set onend(JSFunction? handler);
}

extension type _ResultEvent(JSObject _) implements JSObject {
  external _ResultList get results;
}

extension type _ResultList(JSObject _) implements JSObject {
  external int get length;
}

@JS('Reflect.get')
external JSAny? _reflectGet(JSObject target, JSAny key);

extension type _ErrorEvent(JSObject _) implements JSObject {
  external String get error;
}

// getUserMedia, used only to surface the permission dialog the moment Olivia
// opens instead of on the first press of the talk button.
@JS('navigator.mediaDevices.getUserMedia')
external JSPromise<_MediaStream> _getUserMedia(JSObject constraints);

@JS('navigator.mediaDevices')
external JSAny? get _mediaDevices;

extension type _MediaStream(JSObject _) implements JSObject {
  external JSArray<_MediaTrack> getTracks();
}

extension type _MediaTrack(JSObject _) implements JSObject {
  external void stop();
}

/// The browser's speech recognition, driven directly.
class SpeechRecognizerImpl {
  _Recognition? _active;
  bool _permissionAsked = false;

  bool get isListening => _active != null;

  /// Whether this browser can recognise speech at all. Chrome and Safari can;
  /// Firefox cannot, and the talk button explains itself there.
  bool get isSupported => _recognitionCtor != null;

  /// Surfaces the microphone permission dialog now, so the customer grants it
  /// while reading Olivia's greeting rather than mid-sentence later. The
  /// stream is stopped immediately — this is only about the prompt. Returns
  /// false when the customer refuses or no mic exists.
  Future<bool> requestPermission() async {
    if (_mediaDevices == null) return false;
    if (_permissionAsked) return true;
    try {
      final stream =
          await _getUserMedia({'audio': true}.jsify() as JSObject).toDart;
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
      _permissionAsked = true;
      return true;
    } catch (e) {
      debugPrint('Mic permission not granted: $e');
      return false;
    }
  }

  /// Listens for one utterance. [onPartial] fires as words firm up;
  /// [onFinal] fires once with the whole thing. Returns false when the
  /// browser cannot listen (unsupported, or permission refused).
  Future<bool> listen({
    required void Function(String) onPartial,
    required void Function(String) onFinal,
  }) async {
    if (!isSupported) return false;
    stop();

    final rec = _Recognition();
    _active = rec;
    rec.lang = 'en-US';
    rec.continuous = false;
    rec.interimResults = true;
    rec.maxAlternatives = 1;

    var finalSent = false;
    var latest = '';

    rec.onresult = (JSObject e) {
      final event = _ResultEvent(e);
      final results = event.results;
      // Concatenate every result chunk; read transcript/isFinal reflectively
      // because SpeechRecognitionResultList is index-accessed, not an array.
      final buffer = StringBuffer();
      var sawFinal = false;
      for (var i = 0; i < results.length; i++) {
        final result = _reflectGet(results, i.toJS) as JSObject?;
        if (result == null) continue;
        final alt = _reflectGet(result, 0.toJS) as JSObject?;
        if (alt == null) continue;
        final transcript =
            (_reflectGet(alt, 'transcript'.toJS) as JSString?)?.toDart ?? '';
        buffer.write(transcript);
        final isFinal =
            (_reflectGet(result, 'isFinal'.toJS) as JSBoolean?)?.toDart ??
                false;
        sawFinal = sawFinal || isFinal;
      }
      latest = buffer.toString().trim();
      if (latest.isEmpty) return;
      if (sawFinal) {
        finalSent = true;
        onFinal(latest);
      } else {
        onPartial(latest);
      }
    }.toJS;

    rec.onerror = (JSObject e) {
      debugPrint('Speech recognition error: ${_ErrorEvent(e).error}');
    }.toJS;

    rec.onend = (JSAny e) {
      if (_active == rec) _active = null;
      // Safari often ends without flagging the last result final; whatever
      // was heard is the utterance.
      if (!finalSent && latest.isNotEmpty) {
        finalSent = true;
        onFinal(latest);
      }
    }.toJS;

    try {
      rec.start();
      return true;
    } catch (e) {
      debugPrint('Speech recognition failed to start: $e');
      if (_active == rec) _active = null;
      return false;
    }
  }

  /// Stops listening; whatever was heard so far arrives through onend.
  void stop() {
    final rec = _active;
    if (rec != null) {
      try {
        rec.stop();
      } catch (_) {}
    }
  }

  /// Stops listening and discards anything heard.
  void cancel() {
    final rec = _active;
    _active = null;
    if (rec != null) {
      try {
        rec.abort();
      } catch (_) {}
    }
  }
}
