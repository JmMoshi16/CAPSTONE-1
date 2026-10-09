import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoreward_bin/core/min_tap_area.dart';
import 'package:ecoreward_bin/core/tap.dart';

void main() {
  testWidgets('a small child gets a 48 dp target, centred', (tester) async {
    var taps = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Tap(label: 'x', onTap: () => taps++, child: const SizedBox(width: 20, height: 20))),
    ));
    expect(tester.getSize(find.byType(MinTapArea)), const Size(48, 48));
    // A tap at the edge of the 48 dp area, outside the 20 dp child, still counts.
    final box = tester.getRect(find.byType(MinTapArea));
    await tester.tapAt(box.topLeft + const Offset(2, 2));
    expect(taps, 1);
  });

  testWidgets('a card in a tight slot still fills it', (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 150, height: 120,
          child: Tap(label: 'card', onTap: () {}, child: Container(key: const Key('card'), color: const Color(0xFF00FF00))),
        ),
      ),
    ));
    expect(tester.getSize(find.byKey(const Key('card'))), const Size(150, 120));
  });
}
