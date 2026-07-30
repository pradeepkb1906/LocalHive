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

  /// The part of her footage worth showing, measured down the frame: from a
  /// little above her head to the bottom, which is the bottom of her sweater.
  ///
  /// Her head starts around 0.37 and her mouth is around 0.62. Above 0.30 is
  /// the LocalHive sign on the wall behind her, which only looks like branding
  /// when it is whole — there is no room for all of it *and* her, and a sign
  /// sliced through the middle of its letters just looks like a mistake.
  static const _bandTop = 0.30;
  static const _bandBottom = 1.0;

  /// The middle of her face, used to decide what to keep when the box is too
  /// short even for the band above.
  static const _faceCentre = 0.53;

  /// How tall her frame wants to be in a window of [screen].
  ///
  /// Tall enough for that whole band when the window can spare it: she reads as
  /// a person you are talking to when her face, shoulders and sweater are all
  /// there, and as a passport photo when she is cropped to a strip. The reserve
  /// is the app bar, the status line, the talk button and the text field, plus
  /// enough of the conversation to read her last answer.
  static double heightIn(Size screen) {
    const reserve = 400.0;
    final scale = screen.width / portrait.width;
    final band = portrait.height * scale * (_bandBottom - _bandTop);
    return (screen.height - reserve).clamp(200.0, band);
  }

  /// Which slice of a [full]-tall frame to show in a [visible]-tall box.
  ///
  /// Keeps her sweater at the bottom of the frame while the box is tall enough
  /// for that, and slides down to centre on her face when it is not — a short
  /// window should lose her sweater, not her expression.
  static Alignment cropFor(double full, double visible) {
    final excess = full - visible;
    if (excess <= 0) return Alignment.center;
    final top = math
        .min(
          _bandBottom * full - visible,
          math.max(_bandTop * full, _faceCentre * full - visible / 2),
        )
        .clamp(0.0, excess);
    // OverflowBox places the child at (1 + y) / 2 of the excess.
    return Alignment(0, (2 * top / excess - 1).clamp(-1.0, 1.0));
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
            Positioned.fill(child: child)
          else
            // Covered by giving the child a real size larger than this box and
            // clipping, rather than by scaling it with a transform. A video is a
            // platform view on the web, and a scaled platform view paints
            // nothing — she came out as an empty white rectangle.
            LayoutBuilder(
              builder: (context, box) {
                final scale = math.max(
                  box.maxWidth / naturalSize.width,
                  box.maxHeight / naturalSize.height,
                );
                final size = naturalSize * scale;
                return ClipRect(
                  child: OverflowBox(
                    alignment: cropFor(size.height, box.maxHeight),
                    maxWidth: size.width,
                    maxHeight: size.height,
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      child: child,
                    ),
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
