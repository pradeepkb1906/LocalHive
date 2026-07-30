import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../theme.dart';

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

  /// Shown while the clip loads, and if it cannot be played at all.
  final Widget fallback;

  const OliviaVideo({
    super.key,
    required this.fallback,
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
    _load();
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.asset(OliviaVideo.asset);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      // Her voice is the TTS voice; the clip's own audio would clash with it.
      await controller.setVolume(0);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);

      // A paused video paints nothing on the web until it has played at least
      // one frame, which left Olivia as an empty rectangle. Nudge it forward,
      // then settle to whatever her current state calls for.
      await controller.play();
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      _syncPlayback();
    } catch (e) {
      debugPrint('Olivia video unavailable, using the still image: $e');
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Plays only while she is actually saying something.
  void _syncPlayback() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (widget.speaking) {
      if (!c.value.isPlaying) c.play();
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
    final c = _controller;
    if (_failed || c == null || !c.value.isInitialized) {
      return widget.fallback;
    }

    final Color ring;
    if (widget.listening) {
      ring = LhColors.green;
    } else if (widget.thinking) {
      ring = LhColors.blue;
    } else if (widget.speaking) {
      ring = LhColors.navy;
    } else {
      ring = LhColors.hairline;
    }
    final active = widget.listening || widget.thinking || widget.speaking;
    final radius = BorderRadius.circular(16);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
            color: ring.withValues(alpha: active ? 0.75 : 0.55),
            width: active ? 3 : 1.5),
        boxShadow: [
          if (active)
            BoxShadow(
              color: ring.withValues(alpha: 0.22),
              blurRadius: 18,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      ),
    );
  }
}
