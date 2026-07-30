import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

const bool webVideoSupported = true;

@JS('document')
external _Document get _document;

extension type _Document(JSObject _) implements JSObject {
  external _VideoElement createElement(String tag);
}

extension type _VideoElement(JSObject _) implements JSObject {
  external set src(String value);
  external set muted(bool value);
  external set loop(bool value);
  external set autoplay(bool value);
  external set playsInline(bool value);
  external JSPromise<JSAny?> play();
  external void pause();
  external _Style get style;
  external void setAttribute(String name, String value);
}

extension type _Style(JSObject _) implements JSObject {
  external set width(String value);
  external set height(String value);
  external set objectFit(String value);
  external set objectPosition(String value);
  external set pointerEvents(String value);
}

/// One video element per view instance, held here so the widget can reach it
/// across rebuilds to play and pause. Entries are removed on dispose.
final Map<String, _VideoElement> _elements = {};
final Set<String> _registeredFactories = {};
int _nextId = 0;

/// Her clip as a raw, plugin-free browser video: created directly on the
/// document, registered as a platform view with the engine's own registry —
/// an API that is part of Flutter web itself and cannot be lost the way
/// plugin registration can.
class WebVideoView extends StatefulWidget {
  final String assetPath;
  final bool playing;
  final String objectPosition;

  /// 'cover' fills the box and crops; 'contain' shows the WHOLE frame with
  /// letterboxing. Olivia uses contain — Pradeep wants the full portrait,
  /// bee and sign and sweater and all.
  final String fit;

  const WebVideoView({
    super.key,
    required this.assetPath,
    required this.playing,
    this.objectPosition = '50% 50%',
    this.fit = 'cover',
  });

  @override
  State<WebVideoView> createState() => _WebVideoViewState();
}

class _WebVideoViewState extends State<WebVideoView> {
  late final String _viewType = 'localhive-video-${_nextId++}';

  @override
  void initState() {
    super.initState();
    // Flutter serves bundle assets under assets/ relative to the page.
    final url = 'assets/${widget.assetPath}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final video = _document.createElement('video');
      video.src = url;
      video.muted = true;
      video.loop = true;
      video.playsInline = true;
      // The attribute forms as well: iOS Safari honours these more reliably
      // than the properties.
      video.setAttribute('muted', '');
      video.setAttribute('playsinline', '');
      // Fetch enough to paint the first frame even before play() is ever
      // called — Olivia sits paused until she speaks, and metadata-only
      // preloading would leave her box blank until then.
      video.setAttribute('preload', 'auto');
      video.style.width = '100%';
      video.style.height = '100%';
      video.style.objectFit = widget.fit;
      video.style.objectPosition = widget.objectPosition;
      // Taps must fall through to the Flutter surface, not the element.
      video.style.pointerEvents = 'none';
      _elements[_viewType] = video;
      _sync(video);
      return video;
    });
    _registeredFactories.add(_viewType);
  }

  void _sync(_VideoElement video) {
    if (widget.playing) {
      // The promise rejects when the browser wants a user gesture first;
      // that is fine — the next tap-driven state change tries again.
      video.play().toDart.catchError((Object e) => null);
    } else {
      video.pause();
    }
  }

  @override
  void didUpdateWidget(WebVideoView old) {
    super.didUpdateWidget(old);
    final video = _elements[_viewType];
    if (video != null &&
        (old.playing != widget.playing ||
            old.objectPosition != widget.objectPosition)) {
      video.style.objectPosition = widget.objectPosition;
      _sync(video);
    }
  }

  @override
  void dispose() {
    _elements.remove(_viewType)?.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
