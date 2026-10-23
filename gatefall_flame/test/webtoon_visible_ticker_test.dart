import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/ui/webtoon_visible_ticker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('latest panel ticks only when the panel intersects the viewport',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ListView.builder(
              controller: controller,
              itemExtent: 250,
              itemCount: 20,
              itemBuilder: (_, index) => Text('Chapter panel $index'),
            ),
            WebtoonVisibleTicker(
              controller: controller,
              // Measured item height and bottom padding.
              trailingExtent: 278,
              child: const SizedBox(
                key: Key('latest-motion-child'),
                width: 10,
                height: 10,
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    bool latestEnabled() => TickerMode.of(
          tester.element(find.byKey(const Key('latest-motion-child'))),
        );

    expect(latestEnabled(), isFalse,
        reason: 'unseen frames must not keep animating');
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(latestEnabled(), isTrue,
        reason: 'the current visible panel retains its animation');

    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(latestEnabled(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticker reacts to a replacement scroll controller',
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
                  itemExtent: 200,
                  itemCount: count,
                  itemBuilder: (_, index) => Text('Panel $index'),
                ),
                WebtoonVisibleTicker(
                  controller: controller,
                  trailingExtent: 228,
                  child: const SizedBox(key: Key('latest-motion-child')),
                ),
              ],
            ),
          ),
        );

    bool latestEnabled() => TickerMode.of(
          tester.element(find.byKey(const Key('latest-motion-child'))),
        );

    await tester.pumpWidget(reader(first, 18));
    await tester.pumpAndSettle();
    expect(latestEnabled(), isFalse);

    await tester.pumpWidget(reader(second, 1));
    await tester.pumpAndSettle();
    expect(latestEnabled(), isTrue);

    await tester.pumpWidget(reader(first, 18));
    await tester.pumpAndSettle();
    expect(latestEnabled(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
