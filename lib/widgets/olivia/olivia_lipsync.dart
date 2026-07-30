import 'package:flutter/material.dart';

import '../../theme.dart';

/// Olivia's face with her mouth driven by what she is actually saying.
///
/// Four frames were cut from one pose-stable run of her video clip — the same
/// head position throughout, her mouth going from closed to wide — so swapping
/// between them moves only her mouth. [mouthOpen] comes from the text-to-speech
/// word stream, which is what makes the movement match her speech rather than
/// looping regardless of it.
///
/// This is the same trick hand-drawn animation uses: a small set of mouth
/// shapes, chosen per sound. It is not phoneme-accurate — that needs a
/// talking-head model — but it opens and closes on her real words, in time with
/// her real emphasis and pauses.
class OliviaLipSync extends StatefulWidget {
  final double mouthOpen;

  /// Steady for the whole utterance. The ring is driven by this rather than by
  /// [mouthOpen], which changes many times a second.
  final bool speaking;
  final bool listening;
  final bool thinking;

  /// Closed, barely parted, mid, wide.
  static const frames = <String>[
    'assets/brand/olivia_mouth0.jpg',
    'assets/brand/olivia_mouth1.jpg',
    'assets/brand/olivia_mouth2.jpg',
    'assets/brand/olivia_mouth3.jpg',
  ];

  /// Shown if the frames are not bundled.
  final Widget fallback;

  const OliviaLipSync({
    super.key,
    required this.fallback,
    this.mouthOpen = 0,
    this.speaking = false,
    this.listening = false,
    this.thinking = false,
  });

  @override
  State<OliviaLipSync> createState() => _OliviaLipSyncState();
}

class _OliviaLipSyncState extends State<OliviaLipSync> {
  bool _ready = false;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _warmUp();
  }

  /// Every frame is decoded up front. Without this the first swap of each shape
  /// arrives a frame or two late, which reads as her mouth stuttering.
  Future<void> _warmUp() async {
    if (_ready || _failed) return;
    try {
      for (final f in OliviaLipSync.frames) {
        await precacheImage(AssetImage(f), context);
      }
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      debugPrint('Olivia lip-sync frames unavailable: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Which mouth shape suits this much openness.
  ///
  /// The thresholds are deliberately uneven: most speech sits in the lower
  /// range, so giving the quieter shapes more of the scale keeps her from
  /// gaping through an ordinary sentence.
  int _frameFor(double open) {
    if (open < 0.14) return 0;
    if (open < 0.38) return 1;
    if (open < 0.66) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback;
    if (!_ready) return widget.fallback;

    final open = widget.mouthOpen.clamp(0.0, 1.0);
    final index = _frameFor(open);

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
    // Driven by the steady per-utterance flags, not by mouthOpen — reacting to
    // mouthOpen made the ring flicker several times a second.
    final active = widget.listening || widget.thinking || widget.speaking;
    final radius = BorderRadius.circular(16);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      // The border width is deliberately constant: it is part of layout, so
      // animating it resized the image on every change and made her visibly
      // shake. Only the colour and the shadow react, and neither affects
      // layout.
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
            color: ring.withValues(alpha: active ? 0.85 : 0.45), width: 2),
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
        // Stacked rather than swapped so there is never a blank frame between
        // shapes; only the opacity of the top layers changes.
        child: AspectRatio(
          aspectRatio: 464 / 688,
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < OliviaLipSync.frames.length; i++)
                AnimatedOpacity(
                  // Fast enough to keep up with speech, slow enough not to
                  // flicker between neighbouring shapes.
                  duration: const Duration(milliseconds: 45),
                  opacity: i == index ? 1 : 0,
                  child: Image.asset(
                    OliviaLipSync.frames[i],
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
