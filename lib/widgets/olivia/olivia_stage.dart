import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// The frame Olivia sits in, and the state colour around her.
///
/// Shared by every version of her face — the video clip, the mouth frames and
/// the drawn avatar — so all three sit in the same place, at the same size, with
/// the same colour telling the customer whether she is listening, thinking or
/// speaking. Swapping between them should be invisible.
class OliviaStage extends StatelessWidget {
  /// Fills the box it is given, cropping to do so, instead of keeping the
  /// source's own shape. Her footage is a tall portrait, so honouring its shape
  /// inside a phone-width column leaves broad empty margins either side of her.
  final bool expand;

  final bool speaking;
  final bool listening;
  final bool thinking;

  /// The pixel size of what [child] draws, needed to crop it in [expand] mode.
  final Size naturalSize;

  /// True when [child] does its own cover-cropping (a raw web video element
  /// with CSS object-fit). The stage then skips its sizing math and just fills
  /// the box — doing both would crop twice.
  final bool rawCover;

  final Widget child;

  const OliviaStage({
    super.key,
    required this.naturalSize,
    required this.child,
    this.expand = false,
    this.rawCover = false,
    this.speaking = false,
    this.listening = false,
    this.thinking = false,
  });

  /// The shape of her footage, and of the mouth frames cut from it. Used to
  /// work out how tall her frame wants to be — see [heightIn].
  static const portrait = Size(464, 688);

  /// How tall her frame wants to be in a window of [screen]: the height at
  /// which the WHOLE portrait fits the width, capped by what the window can
  /// spare. Pradeep wants everything visible — the bee, the LocalHive sign,
  /// her face and her sweater — so nothing is ever cropped away; a wider
  /// window letterboxes her instead.
  static double heightIn(Size screen) {
    const reserve = 400.0;
    final whole = screen.width * portrait.height / portrait.width;
    return (screen.height - reserve).clamp(200.0, whole);
  }

  Color get _ring {
    if (listening) return LhColors.green;
    if (thinking) return LhColors.blue;
    if (speaking) return LhColors.navy;
    return LhColors.hairline;
  }

  bool get _active => listening || thinking || speaking;

  @override
  Widget build(BuildContext context) {
    final ring = _ring;
    // Driven by these steady per-turn flags rather than by anything that
    // changes per word, which made the ring flicker several times a second.
    final active = _active;

    if (expand) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (rawCover)
            // The raw web element letterboxes itself (object-fit: contain).
            Positioned.fill(child: child)
          else
            // The whole frame, as large as fits, centred. Sized explicitly
            // rather than with FittedBox: a video is a platform view on the
            // web, and a scaled platform view paints nothing.
            LayoutBuilder(
              builder: (context, box) {
                final scale = math.min(
                  box.maxWidth / naturalSize.width,
                  box.maxHeight / naturalSize.height,
                );
                final size = naturalSize * scale;
                return Center(
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: child,
                  ),
                );
              },
            ),
          // A full-bleed frame has no room for a border, so her state shows as
          // a line under her. It is positioned, so it costs no layout.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 3,
              color: ring.withValues(alpha: active ? 0.9 : 0.2),
            ),
          ),
        ],
      );
    }

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
        child: AspectRatio(
          aspectRatio: naturalSize.width / naturalSize.height,
          child: child,
        ),
      ),
    );
  }
}
