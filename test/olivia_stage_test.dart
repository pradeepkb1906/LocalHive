import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/theme.dart';
import 'package:localhive/widgets/olivia/olivia_stage.dart';

/// Olivia's frame shows her WHOLE portrait — the bee, the LocalHive sign, her
/// face and her sweater — letterboxed when the box is a different shape.
/// Pradeep chose completeness over full-bleed after cropping kept eating
/// either her face or her sweater on one screen shape or another.
void main() {
  const source = OliviaStage.portrait;

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

  group('Olivia stage, whole portrait', () {
    // A small phone, a large phone, a tablet strip, a wide desktop strip.
    for (final box in [
      const Size(320, 200),
      const Size(390, 304),
      const Size(834, 260),
      const Size(2000, 650),
    ]) {
      testWidgets(
          'fits the whole frame inside ${box.width.toInt()}x${box.height.toInt()}',
          (t) async {
        await t.binding.setSurfaceSize(box);
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(harness(Center(
          child: SizedBox(width: box.width, height: box.height, child: stage()),
        )));
        await t.pumpAndSettle();

        expect(t.takeException(), isNull);
        expect(t.getSize(find.byType(OliviaStage)), box);

        // The frame keeps its own proportions and fits ENTIRELY inside the
        // box — nothing of her is ever cropped away.
        final painted = t.getSize(find.byType(ColoredBox).first);
        expect(painted.width / painted.height,
            closeTo(source.width / source.height, 0.01));
        expect(painted.width, lessThanOrEqualTo(box.width + 0.1));
        expect(painted.height, lessThanOrEqualTo(box.height + 0.1));
      });
    }

    test('the header asks for the height that fits the whole portrait', () {
      // On a phone the whole portrait at screen width is taller than the
      // window can spare, so the height is the spare space; the width then
      // letterboxes inside it.
      const phone = Size(390, 844);
      final h = OliviaStage.heightIn(phone);
      expect(h, lessThanOrEqualTo(phone.width * source.height / source.width));
      expect(h, greaterThanOrEqualTo(200));
    });

    testWidgets('keeps its own shape when not asked to fill', (t) async {
      await t.pumpWidget(harness(Center(
        child: SizedBox(width: 390, height: 304, child: stage(expand: false)),
      )));
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      final card = t.getSize(find.byType(AspectRatio));
      expect(card.width, lessThan(390));
    });
  });
}
