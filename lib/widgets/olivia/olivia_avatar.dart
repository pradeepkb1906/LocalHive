import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// Olivia's face.
///
/// Uses the photograph at [photoAsset] when it is present, and falls back to a
/// drawn face when it is not — so dropping the file in is all that is needed to
/// switch, and a missing file never breaks the screen.
///
/// [mouthOpen] is 0 (closed) to 1 (wide), driven by the text-to-speech word
/// stream. The drawn face moves its lips with it; the photograph has its jaw
/// strip warped by the same signal.
/// [listening] shows the headset mic lit while the customer is talking.
class OliviaAvatar extends StatefulWidget {
  final double size;
  final double mouthOpen;
  final bool listening;
  final bool thinking;

  /// Drop a portrait here and Olivia uses it automatically.
  static const photoAsset = 'assets/brand/olivia.png';

  const OliviaAvatar({
    super.key,
    this.size = 180,
    this.mouthOpen = 0,
    this.listening = false,
    this.thinking = false,
  });

  @override
  State<OliviaAvatar> createState() => _OliviaAvatarState();
}

class _OliviaAvatarState extends State<OliviaAvatar>
    with SingleTickerProviderStateMixin {
  /// One controller drives the blink, the idle breathing sway and the
  /// thinking pulse, so an idle Olivia costs a single ticker.
  late final AnimationController _idle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4200))
    ..repeat();

  /// The decoded photo, needed because warping her jaw means redrawing part of
  /// the image itself rather than painting over it.
  ui.Image? _photo;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    if (mounted) setState(() => _photo = info.image);
  }, onError: (_, __) {
    // No photo bundled: the drawn face takes over via errorBuilder.
  });

  @override
  void initState() {
    super.initState();
    _stream = const AssetImage(OliviaAvatar.photoAsset)
        .resolve(ImageConfiguration.empty)
      ..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _idle.dispose();
    super.dispose();
  }

  /// Presents the photograph of Olivia in full — the whole frame, nothing
  /// cropped away.
  ///
  /// Three things make a still photograph feel alive: her eyes blink, her jaw
  /// moves with her speech, and a border brightens with each word. The blink
  /// paints eyelids over her eyes; the mouth cannot be painted over, so the
  /// photo's own pixels are warped instead.
  Widget _photoFrame(Widget image, double t) {
    final speaking = widget.mouthOpen.clamp(0.0, 1.0);
    final pulse =
        math.sin(t * 2 * math.pi * (widget.thinking ? 3 : 2)) * 0.5 + 0.5;

    final Color ring;
    final double ringStrength;
    if (widget.listening) {
      ring = LhColors.green;
      ringStrength = 0.45 + 0.35 * pulse;
    } else if (widget.thinking) {
      ring = LhColors.blue;
      ringStrength = 0.35 + 0.35 * pulse;
    } else if (speaking > 0.05) {
      ring = LhColors.navy;
      ringStrength = 0.30 + 0.55 * speaking;
    } else {
      ring = LhColors.hairline;
      ringStrength = 0.6;
    }

    final radius = BorderRadius.circular(16);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
            color: ring.withValues(alpha: ringStrength),
            width: 1.5 + 2 * speaking),
        boxShadow: [
          BoxShadow(
            color: ring.withValues(alpha: 0.16 * ringStrength),
            blurRadius: 8 + 20 * speaking,
            spreadRadius: 4 * speaking,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            image,
            // Both painted in the photo's own coordinate space, so they stay
            // on her face whatever size it is displayed at.
            if (_photo != null)
              Positioned.fill(
                child: _LipWarp(photo: _photo!, mouthOpen: speaking),
              ),
            Positioned.fill(child: _BlinkOverlay(eyeOpen: _blink(t))),
          ],
        ),
      ),
    );
  }

  /// Eyes stay open for most of the cycle and snap shut briefly, which reads
  /// as a natural blink rather than a slow wink.
  double _blink(double t) {
    const blinkAt = 0.86;
    const width = 0.05;
    if (t < blinkAt || t > blinkAt + width) return 1;
    final p = (t - blinkAt) / width;
    return (math.cos(p * 2 * math.pi) + 1) / 2;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _idle,
      builder: (context, _) {
        final t = _idle.value;
        // errorBuilder is the whole switching mechanism: if the portrait is not
        // in the bundle, Image.asset fails and the drawn face renders instead.
        // No config flag to forget to set.
        return Image.asset(
          OliviaAvatar.photoAsset,
          errorBuilder: (context, _, __) => SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _OliviaPainter(
                mouthOpen: widget.mouthOpen.clamp(0, 1),
                eyeOpen: _blink(t),
                // A slow rise and fall so she looks alive when silent.
                breath: math.sin(t * 2 * math.pi) * 0.5 + 0.5,
                listening: widget.listening,
                thinking: widget.thinking,
                thinkPhase: t,
              ),
            ),
          ),
          frameBuilder: (context, child, frame, _) => _photoFrame(child, t),
        );
      },
    );
  }
}

/// Where Olivia's eyes are in the photograph, as fractions of its width and
/// height, so the blink lands correctly at any display size.
///
/// Measured from the still photo Olivia used before her video clip. These are
/// only used by the drawn-face path now, which has no photo to match.
class _EyeGeometry {
  static const leftCentre = Offset(0.4746, 0.2594);
  static const rightCentre = Offset(0.5342, 0.2612);
  static const halfWidth = 0.0175;
  static const halfHeight = 0.0170;

  /// Each eye gets the skin tone sampled from just below it in the photo. Her
  /// left side is lit and her right is in shadow, so one shared colour left an
  /// obvious dark patch on one eye.
  static const leftLid = Color(0xFFAD8275);
  static const rightLid = Color(0xFF9D7160);
  static const lashColour = Color(0xFF7A5446);
}

/// Closes Olivia's eyes over the photograph for a moment.
///
/// A photo cannot blink, so this paints her own eyelid colour across the eyes
/// with a lash line at the leading edge. Kept small, fast and infrequent —
/// a slow or oversized version reads as uncanny rather than alive.
class _BlinkOverlay extends StatelessWidget {
  /// 1 = fully open, 0 = fully closed.
  final double eyeOpen;
  const _BlinkOverlay({required this.eyeOpen});

  @override
  Widget build(BuildContext context) {
    if (eyeOpen > 0.97) return const SizedBox.shrink();
    return CustomPaint(painter: _BlinkPainter(eyeOpen: eyeOpen));
  }
}

/// Where Olivia's jaw is in the photograph, as fractions of its size.
///
/// Closing a mouth raises the jaw, so the speech animation squashes this strip
/// — from just under her nose down past her chin to her collar — towards its
/// top. Warping the actual photo pixels is the only way a photograph's mouth
/// can move; painting over it the way the eyelids do would look like a wound.
class _JawGeometry {
  static const top = 198 / 559;
  static const bottom = 300 / 559;
  static const left = 470 / 1024;
  static const right = 600 / 1024;

  /// Vertical scale of the strip at fully closed and fully open. Kept subtle:
  /// past about 12% the chin visibly detaches from the neck.
  static const closedScale = 0.92;
  static const openScale = 1.02;
}

/// Squashes the jaw strip of the photograph so her mouth appears to move.
class _LipWarp extends StatelessWidget {
  final ui.Image photo;
  final double mouthOpen;
  const _LipWarp({required this.photo, required this.mouthOpen});

  @override
  Widget build(BuildContext context) {
    if (mouthOpen <= 0.02) return const SizedBox.shrink();
    return CustomPaint(
        painter: _LipWarpPainter(photo: photo, mouthOpen: mouthOpen));
  }
}

class _LipWarpPainter extends CustomPainter {
  final ui.Image photo;
  final double mouthOpen;
  const _LipWarpPainter({required this.photo, required this.mouthOpen});

  @override
  void paint(Canvas canvas, Size size) {
    final iw = photo.width.toDouble();
    final ih = photo.height.toDouble();

    // The strip in the photo's own pixels…
    final src = Rect.fromLTRB(
      _JawGeometry.left * iw,
      _JawGeometry.top * ih,
      _JawGeometry.right * iw,
      _JawGeometry.bottom * ih,
    );
    // …and where it lands on screen.
    final dstLeft = _JawGeometry.left * size.width;
    final dstTop = _JawGeometry.top * size.height;
    final dstWidth = (_JawGeometry.right - _JawGeometry.left) * size.width;
    final dstHeight = (_JawGeometry.bottom - _JawGeometry.top) * size.height;

    final scale = _JawGeometry.closedScale +
        (_JawGeometry.openScale - _JawGeometry.closedScale) * mouthOpen;
    final warped = dstHeight * scale;

    canvas.save();
    // Clip to the strip so a stretched jaw cannot spill over her collar.
    canvas.clipRect(Rect.fromLTWH(dstLeft, dstTop, dstWidth, dstHeight));
    canvas.drawImageRect(
      photo,
      src,
      Rect.fromLTWH(dstLeft, dstTop, dstWidth, warped),
      Paint()..filterQuality = FilterQuality.medium,
    );
    // Compressing leaves a sliver at the bottom; fill it by stretching the
    // strip's last couple of rows, so there is no seam or double chin.
    if (warped < dstHeight) {
      final tailSrc = Rect.fromLTRB(
          src.left, src.bottom - ih * 0.004, src.right, src.bottom);
      canvas.drawImageRect(
        photo,
        tailSrc,
        Rect.fromLTWH(
            dstLeft, dstTop + warped - 1, dstWidth, dstHeight - warped + 1),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LipWarpPainter old) =>
      old.mouthOpen != mouthOpen || old.photo != photo;
}

class _BlinkPainter extends CustomPainter {
  final double eyeOpen;
  const _BlinkPainter({required this.eyeOpen});

  @override
  void paint(Canvas canvas, Size size) {
    final closed = (1 - eyeOpen).clamp(0.0, 1.0);
    if (closed <= 0) return;

    final eyes = [
      (_EyeGeometry.leftCentre, _EyeGeometry.leftLid),
      (_EyeGeometry.rightCentre, _EyeGeometry.rightLid),
    ];
    // Feathering the lid into her skin is what stops it reading as a censor
    // bar. Scaled off the photo's displayed size so it holds at any size.
    final feather = math.max(0.6, size.width * 0.0035);

    for (final (centre, lidColour) in eyes) {
      final cx = centre.dx * size.width;
      final halfW = _EyeGeometry.halfWidth * size.width;
      final halfH = _EyeGeometry.halfHeight * size.height;
      // The lid sweeps down from the top of the eye.
      final top = centre.dy * size.height - halfH;
      final lidHeight = 2 * halfH * closed;

      final lid = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - halfW, top, 2 * halfW, lidHeight),
        Radius.circular(halfW * 0.55),
      );
      canvas.drawRRect(
        lid,
        Paint()
          ..color = lidColour
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, feather),
      );

      // A lash line at the closing edge sells it as an eyelid, not a block.
      if (closed > 0.5) {
        canvas.drawLine(
          Offset(cx - halfW * 0.85, top + lidHeight),
          Offset(cx + halfW * 0.85, top + lidHeight),
          Paint()
            ..color = _EyeGeometry.lashColour
                .withValues(alpha: (closed - 0.5) / 0.5 * 0.85)
            ..strokeWidth = math.max(0.8, halfH * 0.26)
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, feather * 0.6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BlinkPainter old) => old.eyeOpen != eyeOpen;
}

class _OliviaPainter extends CustomPainter {
  final double mouthOpen;
  final double eyeOpen;
  final double breath;
  final bool listening;
  final bool thinking;
  final double thinkPhase;

  _OliviaPainter({
    required this.mouthOpen,
    required this.eyeOpen,
    required this.breath,
    required this.listening,
    required this.thinking,
    required this.thinkPhase,
  });

  static const _skin = Color(0xFFF2C9A8);
  static const _skinShade = Color(0xFFE0B08C);
  static const _hair = Color(0xFF4A3427);
  static const _hairLight = Color(0xFF5C4132);
  static const _polo = LhColors.navy;
  static const _poloLight = Color(0xFF16395C);
  static const _headset = Color(0xFF2B2B2E);
  static const _lip = Color(0xFFC96A6A);
  static const _mouthInner = Color(0xFF7E3B3B);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    // A gentle vertical drift so she is never perfectly still.
    final drift = (breath - 0.5) * h * 0.008;

    canvas.save();
    canvas.translate(0, drift);

    _paintHalo(canvas, cx, h * 0.46, w);
    _paintShoulders(canvas, cx, w, h);
    _paintHairBack(canvas, cx, w, h);
    _paintFace(canvas, cx, w, h);
    _paintHairFront(canvas, cx, w, h);
    _paintEyes(canvas, cx, w, h);
    _paintMouth(canvas, cx, w, h);
    _paintHeadset(canvas, cx, w, h);

    canvas.restore();
  }

  /// A soft ring behind her that brightens while she listens or thinks, so the
  /// customer can tell her state at a glance without reading anything.
  void _paintHalo(Canvas canvas, double cx, double cy, double w) {
    if (!listening && !thinking) return;
    final pulse = thinking
        ? (math.sin(thinkPhase * 2 * math.pi * 3) * 0.5 + 0.5)
        : (math.sin(thinkPhase * 2 * math.pi * 2) * 0.5 + 0.5);
    final colour = listening ? LhColors.green : LhColors.blue;
    canvas.drawCircle(
      Offset(cx, cy),
      w * (0.40 + 0.03 * pulse),
      Paint()
        ..color = colour.withValues(alpha: 0.10 + 0.10 * pulse)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      w * (0.40 + 0.03 * pulse),
      Paint()
        ..color = colour.withValues(alpha: 0.30 + 0.25 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.008,
    );
  }

  void _paintShoulders(Canvas canvas, double cx, double w, double h) {
    final shoulders = Path()
      ..moveTo(cx - w * 0.40, h)
      ..quadraticBezierTo(cx - w * 0.36, h * 0.78, cx - w * 0.17, h * 0.73)
      ..lineTo(cx + w * 0.17, h * 0.73)
      ..quadraticBezierTo(cx + w * 0.36, h * 0.78, cx + w * 0.40, h)
      ..close();
    canvas.drawPath(shoulders, Paint()..color = _polo);

    // Collar
    final collar = Path()
      ..moveTo(cx - w * 0.10, h * 0.735)
      ..lineTo(cx, h * 0.83)
      ..lineTo(cx + w * 0.10, h * 0.735)
      ..lineTo(cx + w * 0.055, h * 0.725)
      ..lineTo(cx, h * 0.78)
      ..lineTo(cx - w * 0.055, h * 0.725)
      ..close();
    canvas.drawPath(collar, Paint()..color = _poloLight);

    // Neck, drawn after the polo so it sits inside the collar opening.
    final neck = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - w * 0.075, h * 0.60, w * 0.15, h * 0.16),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(neck, Paint()..color = _skinShade);
  }

  void _paintHairBack(Canvas canvas, double cx, double w, double h) {
    // Ponytail behind the shoulder.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx + w * 0.235, h * 0.56),
          width: w * 0.14,
          height: h * 0.26),
      Paint()..color = _hair,
    );
    // Full head of hair, which the face is then drawn on top of.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, h * 0.44), width: w * 0.56, height: h * 0.60),
      Paint()..color = _hair,
    );
  }

  void _paintFace(Canvas canvas, double cx, double w, double h) {
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, h * 0.455), width: w * 0.44, height: h * 0.52),
      Paint()..color = _skin,
    );
    // Cheeks
    for (final dx in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + dx * w * 0.135, h * 0.545),
            width: w * 0.10,
            height: h * 0.055),
        Paint()..color = const Color(0xFFE8A48C).withValues(alpha: 0.45),
      );
    }
  }

  void _paintHairFront(Canvas canvas, double cx, double w, double h) {
    // Fringe sweeping across the forehead.
    final fringe = Path()
      ..moveTo(cx - w * 0.225, h * 0.40)
      ..quadraticBezierTo(cx - w * 0.20, h * 0.20, cx + w * 0.02, h * 0.205)
      ..quadraticBezierTo(cx + w * 0.21, h * 0.215, cx + w * 0.225, h * 0.42)
      ..quadraticBezierTo(cx + w * 0.16, h * 0.30, cx - w * 0.02, h * 0.325)
      ..quadraticBezierTo(cx - w * 0.16, h * 0.345, cx - w * 0.225, h * 0.40)
      ..close();
    canvas.drawPath(fringe, Paint()..color = _hairLight);
  }

  void _paintEyes(Canvas canvas, double cx, double w, double h) {
    final eyeY = h * 0.455;
    final open = eyeOpen.clamp(0.0, 1.0);
    for (final dx in [-1.0, 1.0]) {
      final ex = cx + dx * w * 0.095;

      // Brow
      final brow = Path()
        ..moveTo(ex - w * 0.045, eyeY - h * 0.070)
        ..quadraticBezierTo(
            ex, eyeY - h * 0.092, ex + w * 0.045, eyeY - h * 0.068);
      canvas.drawPath(
        brow,
        Paint()
          ..color = _hair
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.014
          ..strokeCap = StrokeCap.round,
      );

      if (open < 0.12) {
        // Closed: a single lash line reads better than a squashed oval.
        canvas.drawLine(
          Offset(ex - w * 0.038, eyeY),
          Offset(ex + w * 0.038, eyeY),
          Paint()
            ..color = _hair
            ..strokeWidth = w * 0.012
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }

      final eyeH = h * 0.052 * open;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(ex, eyeY), width: w * 0.076, height: eyeH),
        Paint()..color = Colors.white,
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(ex, eyeY),
            width: w * 0.040,
            height: math.min(eyeH, h * 0.040)),
        Paint()..color = const Color(0xFF3E2A20),
      );
      canvas.drawCircle(
        Offset(ex + w * 0.010, eyeY - h * 0.008),
        w * 0.008 * open,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }

    // Nose
    final nose = Path()
      ..moveTo(cx - w * 0.012, h * 0.520)
      ..quadraticBezierTo(cx, h * 0.535, cx + w * 0.016, h * 0.522);
    canvas.drawPath(
      nose,
      Paint()
        ..color = _skinShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.010
        ..strokeCap = StrokeCap.round,
    );
  }

  /// The part that actually sells it. The mouth interpolates from a closed
  /// smile through a small "o" to an open shape as [mouthOpen] rises.
  void _paintMouth(Canvas canvas, double cx, double w, double h) {
    final my = h * 0.595;
    final open = mouthOpen;

    if (open < 0.06) {
      final smile = Path()
        ..moveTo(cx - w * 0.052, my)
        ..quadraticBezierTo(cx, my + h * 0.020, cx + w * 0.052, my);
      canvas.drawPath(
        smile,
        Paint()
          ..color = _lip
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.016
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    // Wide when barely open, rounder as it opens — roughly how a mouth moves
    // between a flat "ee" and an open "ah".
    final mouthW = w * (0.105 - 0.030 * open);
    final mouthH = h * (0.012 + 0.075 * open);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, my), width: mouthW, height: mouthH),
      Paint()..color = _mouthInner,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, my), width: mouthW, height: mouthH),
      Paint()
        ..color = _lip
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012,
    );
    // A hint of teeth on the upper lip keeps it from reading as a hole.
    if (open > 0.25) {
      canvas.save();
      canvas.clipRect(Rect.fromCenter(
          center: Offset(cx, my), width: mouthW, height: mouthH));
      canvas.drawRect(
        Rect.fromLTWH(cx - mouthW / 2, my - mouthH / 2, mouthW, mouthH * 0.26),
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
      canvas.restore();
    }
  }

  void _paintHeadset(Canvas canvas, double cx, double w, double h) {
    final band = Path()
      ..moveTo(cx - w * 0.285, h * 0.44)
      ..quadraticBezierTo(cx, h * 0.115, cx + w * 0.285, h * 0.44);
    canvas.drawPath(
      band,
      Paint()
        ..color = _headset
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.032
        ..strokeCap = StrokeCap.round,
    );

    // Ear cups
    for (final dx in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx + dx * w * 0.285, h * 0.475),
              width: w * 0.075,
              height: h * 0.115),
          Radius.circular(w * 0.030),
        ),
        Paint()..color = _headset,
      );
    }

    // Mic boom down the left side, ending in front of her mouth.
    final boom = Path()
      ..moveTo(cx - w * 0.285, h * 0.525)
      ..quadraticBezierTo(cx - w * 0.265, h * 0.640, cx - w * 0.150, h * 0.625);
    canvas.drawPath(
      boom,
      Paint()
        ..color = _headset
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.016
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(cx - w * 0.140, h * 0.624),
      w * 0.026,
      Paint()..color = _headset,
    );
    // The mic tip lights up while she is listening.
    if (listening) {
      canvas.drawCircle(
        Offset(cx - w * 0.140, h * 0.624),
        w * 0.013,
        Paint()..color = LhColors.green,
      );
    }
  }

  @override
  bool shouldRepaint(_OliviaPainter old) =>
      old.mouthOpen != mouthOpen ||
      old.eyeOpen != eyeOpen ||
      old.breath != breath ||
      old.listening != listening ||
      old.thinking != thinking ||
      old.thinkPhase != thinkPhase;
}
