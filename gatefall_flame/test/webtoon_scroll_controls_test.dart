import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/ui/webtoon_scroll_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('latest panel control follows scroll position without rebuilding pages',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var panelBuilds = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ListView.builder(
              controller: controller,
              itemExtent: 210,
              itemCount: 20,
              itemBuilder: (context, index) {
                panelBuilds++;
                return ColoredBox(
                  color: Colors.black,
                  child: Text('Panel $index'),
                );
              },
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: WebtoonLatestButton(
                controller: controller,
                onPressed: () => controller.jumpTo(
                  controller.position.maxScrollExtent,
                ),
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialogue-back-to-latest')), findsOneWidget);
    final before = panelBuilds;
    // Updating the overlay has no reason to rebuild every historical panel.
    controller.jumpTo(450);
    await tester.pump();
    expect(find.byKey(const Key('dialogue-back-to-latest')), findsOneWidget);
    expect(panelBuilds - before, lessThan(20));

    await tester.tap(find.byKey(const Key('dialogue-back-to-latest')));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(controller.position.maxScrollExtent, 1));
    expect(find.byKey(const Key('dialogue-back-to-latest')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacement scroll controller refreshes latest shortcut',
      (tester) async {
    final first = ScrollController();
    final second = ScrollController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    Widget reader(ScrollController controller, int count) => MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ListView.builder(
                  controller: controller,
                  itemExtent: 210,
                  itemCount: count,
                  itemBuilder: (_, index) => Text('Panel $index'),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: WebtoonLatestButton(
                    controller: controller,
                    onPressed: () => controller.jumpTo(
                      controller.position.maxScrollExtent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    await tester.pumpWidget(reader(first, 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialogue-back-to-latest')), findsNothing);

    await tester.pumpWidget(reader(second, 20));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialogue-back-to-latest')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dialogue-back-to-latest')));
    await tester.pumpAndSettle();
    expect(second.offset, closeTo(second.position.maxScrollExtent, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('latest panel control is absent when history fits in one view',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ListView(
              controller: controller,
              children: const [SizedBox(height: 120, child: Text('Panel 1'))],
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: WebtoonLatestButton(
                controller: controller,
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialogue-back-to-latest')), findsNothing);
  });
}
