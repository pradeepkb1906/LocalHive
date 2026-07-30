/// Hearing the customer, without the speech_to_text plugin on the web.
///
/// The plugin's web registration is lost to the same silent failure that
/// killed text-to-speech and video playback in some browsers — meaning "Hold
/// to talk" would do nothing on exactly the phones Pradeep's friends test on.
/// The web implementation talks to the browser's own SpeechRecognition API
/// directly; Android and iOS native builds keep the plugin, where it works.
///
/// Exports [SpeechRecognizerImpl] as `SpeechRecognizer` plus
/// [speechRecognizerIsWeb].
library;

export 'speech_recognizer_native.dart'
    if (dart.library.js_interop) 'speech_recognizer_web.dart';
