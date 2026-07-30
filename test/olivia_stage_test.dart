import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/theme.dart';
import 'package:localhive/widgets/olivia/olivia_stage.dart';

/// Olivia's frame crops a tall portrait into whatever box the screen gives it.
/// The failure mode to guard against is the opposite of the one that hid the
/// demo logins: instead of collapsing to nothing, a full-bleed crop can happily
/// overflow its parent and paint over the conversation below. These pump it at
/// real window sizes and check it stays exactly inside the box.
void main() {
  const source = OliviaStage.portrait; // her clip, and the frames cut from it

  Widget harness(Widget child) => MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: child),
      );

  Widget stage({bool expand = true}) => OliviaStage(
        expand: expand,
        naturalSize: source,
        speaking: true,
        child: const ColoredBox(color: Colors.teal),
      );

  group('Olivia stage, filling the space', () {
    // A small phone, a large phone, a tablet, and a short landscape window.
    for (final box in [
      const Size(320, 200),
      const Size(390, 304),
      const Size(430, 340),
      const Size(834, 260),
    ]) {
      testWidgets('fills a ${box.width.toInt()}x${box.height.toInt()} box',
          (t) async {
        // The default test window is 800x600, narrower than a tablet.
        await t.binding.setSurfaceSize(box);
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(harness(Center(
          child: SizedBox(
            width: box.width,
            height: box.height,
            child: stage(),
          ),
        )));
        await t.pumpAndSettle();

        expect(t.takeException(), isNull);
        // Exactly the box: no empty margin either side of her, and nothing
        // spilling out over what comes next.
        expect(t.getSize(find.byType(OliviaStage)), box);
      });
    }

    testWidgets('crops rather than squashing her', (t) async {
      await t.pumpWidget(harness(Center(
        child: SizedBox(width: 390, height: 304, child: stage()),
      )));
      await t.pumpAndSettle();

      // The child keeps the source's own proportions — it is scaled up and the
      // excess is clipped. Squashing a face to fit is worse than cropping one.
      final painted = t.getSize(find.byType(ColoredBox));
      expect(painted.width / painted.height,
          closeTo(source.width / source.height, 0.001));
      // Scaled to cover the width, so it is taller than the box it sits in.
      expect(painted.height, greaterThan(304));
    });

    // What the customer must always be able to see. Fractions down her clip:
    // her head starts around 0.37, her mouth is around 0.62, and her sweater
    // runs to the bottom edge.
    const head = 0.37, mouth = 0.62;

    /// Which slice of her clip ends up on screen, as (top, bottom) fractions
    /// down the frame, when a [visible]-tall box is filled at [width].
    (double, double) framing(double width, double visible) {
      final full = width * source.height / source.width;
      final crop = OliviaStage.cropFor(full, visible);
      // Alignment is a fraction of the overflow, not of the frame.
      final top = (1 + crop.y) / 2 * (full - visible) / full;
      return (top, top + visible / full);
    }

    testWidgets('frames her from head to sweater on a phone', (t) async {
      const phone = Size(390, 844);
      final (top, bottom) = framing(phone.width, OliviaStage.heightIn(phone));

      // Starts above her head, and runs to the bottom of the frame, so her
      // sweater is in shot.
      expect(top, lessThan(head));
      expect(bottom, closeTo(1.0, 0.01));
    });

    testWidgets('gives up her sweater before her face on a short window',
        (t) async {
      final (top, bottom) = framing(390, 220);

      // Cropped hard, but her eyes and mouth are still there — a face that has
      // lost its mouth cannot look like it is talking to you.
      expect(top, lessThan(head));
      expect(bottom, greaterThan(mouth + 0.02));
    });

    test('the raw element crop shows her face in a wide desktop strip', () {
      // 2000x650: cover scales her portrait to ~2965px tall. Bottom-pinned
      // would show only sweater; the position must slide up to her face.
      final pos = OliviaStage.objectPositionFor(const Size(2000, 650));
      final pct = double.parse(pos.split(' ')[1].replaceAll('%', ''));
      final scaledH = 2000 * source.height / source.width;
      final top = pct / 100 * (scaledH - 650) / scaledH;
      final bottom = top + 650 / scaledH;
      // The strip is only ~22% of her height — hair-top AND mouth cannot both
      // fit. Priority for someone who is talking: eyes and mouth.
      const eyes = 0.47;
      expect(top, lessThan(eyes - 0.02), reason: 'her eyes must be in view');
      expect(bottom, greaterThan(mouth + 0.01), reason: 'and her mouth');
    });

    test('the raw element crop pins her sweater on a phone-tall box', () {
      final pos = OliviaStage.objectPositionFor(const Size(390, 500));
      final pct = double.parse(pos.split(' ')[1].replaceAll('%', ''));
      final scaledH = 390 * source.height / source.width;
      final top = pct / 100 * (scaledH - 500) / scaledH;
      expect(top + 500 / scaledH, closeTo(1.0, 0.02),
          reason: 'bottom of the frame — her sweater — stays in shot');
    });

    testWidgets('keeps its own shape when not asked to fill', (t) async {
      await t.pumpWidget(harness(Center(
        child: SizedBox(
          width: 390,
          height: 304,
          child: stage(expand: false),
        ),
      )));
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      // Height-bound: the rounded card stays portrait inside the wide box.
      final card = t.getSize(find.byType(AspectRatio));
      expect(card.width, lessThan(390));
    });
  });
}
