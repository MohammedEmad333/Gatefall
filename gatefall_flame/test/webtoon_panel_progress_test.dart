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
