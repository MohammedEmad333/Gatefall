import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/ui/webtoon_panel_progress.dart';

void main() {
  test('binary-search progress identifies panels during rapid jumps', () {
    const ends = <double>[310, 690, 1030, 1510, 2050];
    int panel(double offset, {double viewport = 300}) =>
        webtoonVisiblePanelIndex(
          ends,
          offset: offset,
          viewportExtent: viewport,
        );

    expect(panel(0), 0);
    expect(panel(400), 1);
    expect(panel(700), 2);
    expect(panel(950), 3);
    expect(panel(1400), 3);
    expect(panel(1990), 4);
    expect(panel(100000), 4);
    expect(panel(-100), 0);
    expect(webtoonVisiblePanelIndex(const [], offset: 0,
        viewportExtent: 300), 0);
  });

  test('bookmark survives changed panel heights and preserves panel fraction', () {
    const before = <double>[310, 610, 940, 1210, 1590];
    const after = <double>[410, 890, 1350, 1800, 2420];
    final anchor = webtoonAnchorAt(before, 750);
    expect(anchor.panelIndex, 2);
    expect(anchor.fraction, closeTo(140 / 330, .001));
    final restored = webtoonOffsetForAnchor(after, anchor);
    expect(restored, closeTo(890 + (460 * 140 / 330), .01));
    expect(webtoonAnchorAt(after, restored).panelIndex, 2);
    expect(webtoonPanelStart(after, 0), 0);
    expect(webtoonPanelStart(after, 3), 1350);
    expect(webtoonPanelStart(after, 99), 1800);
    expect(webtoonOffsetForAnchor(const [], anchor), 0);
    expect(webtoonAnchorAt(const [], 100).panelIndex, 0);
  });

  testWidgets('accessible panel picker can jump directly to a reached panel',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    const ends = <double>[210, 410, 610, 810, 1010, 1210, 1410, 1610];
    int? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ListView.builder(
              controller: controller,
              itemExtent: 200,
              itemCount: ends.length,
              itemBuilder: (_, index) => Text('Panel $index'),
            ),
            WebtoonPanelProgress(
              controller: controller,
              panelEnds: ends,
              onJumpToPanel: (index) {
                selected = index;
                controller.jumpTo(
                  webtoonPanelStart(ends, index).clamp(
                    0.0,
                    controller.position.maxScrollExtent,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dialogue-panel-progress')));
    await tester.pumpAndSettle();
    expect(find.text('Panel 1 of 8'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dialogue-next-panel')));
    await tester.pumpAndSettle();
    expect(find.text('Panel 2 of 8'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dialogue-jump-to-panel')));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(controller.offset, closeTo(210, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('visual reader progress follows scrolling without rebuilding art',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    const ends = <double>[210, 410, 610, 810, 1010, 1210, 1410, 1610];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ListView.builder(
              controller: controller,
              itemExtent: 200,
              itemCount: ends.length,
              itemBuilder: (_, index) => Text('Panel $index'),
            ),
            WebtoonPanelProgress(
              controller: controller,
              panelEnds: ends,
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialogue-panel-progress')), findsOneWidget);
    expect(find.text('PANEL 1 / 8'), findsOneWidget);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('PANEL 6 / 8'), findsOneWidget);

    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('PANEL 1 / 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
