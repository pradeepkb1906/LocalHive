import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../web_video/web_video.dart';
import 'olivia_stage.dart';

/// Olivia as a looping video clip.
///
/// A real clip of her talking beats anything that can be faked on a still: the
/// lip movement, blinking and hand gestures are hers. The clip plays while she
/// is speaking and holds on a frame when she is not, so she does not gesture at
/// the customer in silence.
///
/// The clip's own audio is muted — Olivia's voice comes from text-to-speech, and
/// the two together would talk over each other.
class OliviaVideo extends StatefulWidget {
  final bool speaking;
  final bool listening;
  final bool thinking;

  /// Drop a clip here and Olivia uses it in preference to the photo.
  static const asset = 'assets/brand/olivia.mp4';

  /// Fills whatever box it is given, cropping the clip rather than letterboxing
  /// it. Her portrait clip is much taller than it is wide, so keeping its own
  /// shape leaves wide empty margins either side of her.
  final bool expand;

  /// Shown while the clip loads, and if it cannot be played at all.
  final Widget fallback;

  const OliviaVideo({
    super.key,
    required this.fallback,
    this.expand = false,
    this.speaking = false,
    this.listening = false,
    this.thinking = false,
  });

  @override
  State<OliviaVideo> createState() => _OliviaVideoState();
}

class _OliviaVideoState extends State<OliviaVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // On the web the raw element needs no loading at all; the plugin path is
    // only for Android and iOS, where it works reliably.
    if (!webVideoSupported) _load();
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.asset(OliviaVideo.asset);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      // Her voice is the TTS voice; the clip's own audio would clash with it.
      await controller.setVolume(0);
    } catch (e) {
      // Only a failure to LOAD the clip demotes her to the still frames.
      debugPrint('Olivia video unavailable, using the still image: $e');
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);

    // A paused video paints nothing on the web until it has played at least
    // one frame, which left Olivia as an empty rectangle. Nudge it forward,
    // then settle to whatever her current state calls for. A mobile browser
    // may refuse this first play() — that is a POLICY refusal, not a broken
    // clip, so she keeps the video and simply tries again when she next
    // speaks, by which point the customer has tapped something.
    try {
      await controller.play();
      await Future.delayed(const Duration(milliseconds: 120));
    } catch (e) {
      debugPrint('Olivia video first play deferred: $e');
    }
    if (!mounted) return;
    _syncPlayback();
  }

  /// Plays only while she is actually saying something.
  void _syncPlayback() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (widget.speaking) {
      if (!c.value.isPlaying) {
        c.play().catchError((Object e) {
          debugPrint('Olivia video play refused: $e');
        });
      }
    } else if (c.value.isPlaying) {
      c.pause();
      // Rewind so every reply starts from the same expression rather than
      // resuming mid-gesture.
      c.seekTo(Duration.zero);
    }
  }

  @override
  void didUpdateWidget(OliviaVideo old) {
    super.didUpdateWidget(old);
    if (old.speaking != widget.speaking) _syncPlayback();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (webVideoSupported) {
      // The element does its own cover-crop; '50% 100%' pins the bottom of the
      // frame — her sweater — matching what OliviaStage does for the plugin
      // path. The stage still draws her state (the line under her).
      return OliviaStage(
        expand: widget.expand,
        speaking: widget.speaking,
        listening: widget.listening,
        thinking: widget.thinking,
        naturalSize: OliviaStage.portrait,
        rawCover: true,
        child: WebVideoView(
          assetPath: OliviaVideo.asset,
          playing: widget.speaking,
          objectPosition: '50% 100%',
        ),
      );
    }

    final c = _controller;
    if (_failed || c == null || !c.value.isInitialized) {
      return widget.fallback;
    }

    return OliviaStage(
      expand: widget.expand,
      speaking: widget.speaking,
      listening: widget.listening,
      thinking: widget.thinking,
      naturalSize: c.value.size,
      child: VideoPlayer(c),
    );
  }
}
