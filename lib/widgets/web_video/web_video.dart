/// A video that plays on the web without the video_player plugin.
///
/// The plugin's web registration silently fails in some browsers — the whole
/// plugin chain does; it is what made Olivia mute, and in Pradeep's own Chrome
/// it replaced her clip with the still photo
/// (UnimplementedError: init() has not been implemented). A raw HTML video
/// element depends on nothing but the browser itself: muted, looping, inline,
/// covering its box, playing or paused as told.
///
/// Exports [WebVideoView] and [webVideoSupported]. On non-web builds the stub
/// exports supported=false and a view that never builds — callers keep using
/// video_player there, where the plugin works reliably.
library;

export 'web_video_stub.dart' if (dart.library.js_interop) 'web_video_web.dart';
