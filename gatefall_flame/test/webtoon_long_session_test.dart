import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/ui/dialogue_webtoon_panel.dart';
import 'package:gatefall/ui/theme.dart';

/// Stress a long, illustrated companion chapter without fabricating save
/// state or altering any canonical story branches. It uses the same lazy
/// measured-extent list and painted panels as the real reader.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rapid travel across 80 illustrated panels stays lazy and stable',
      (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(320, 720);
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final lines = List<String>.generate(
      80,
      (index) => List<String>.filled(
        index % 13 == 0 ? 20 : (index % 5) + 1,
        'The gate is still open, but we move forward together. ',
      ).join(),
    );
    const scaler = TextScaler.linear(1.6);
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: gatefallTheme(),
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(textScaler: scaler),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth - 28;
              return ListView.builder(
                key: const Key('stress-chapter-reader'),
                controller: controller,
                cacheExtent: 220,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                itemCount: lines.length,
                itemExtentBuilder: (index, _) => chapterPanelHeight(
                  text: lines[index],
                  width: width,
                  textScaler: scaler,
                  textDirection: TextDirection.ltr,
                  isNarration: false,
                ) + 18,
                itemBuilder: (_, index) => DialogueWebtoonPanel(
                  key: Key('stress-panel-$index'),
                  index: index,
                  characterId: 'faelen',
                  speakerId: 'faelen',
                  speakerName: 'Faelen',
                  text: lines[index],
                  isLatest: index == lines.length - 1,
                ),
              );
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    int livePanels() => find.byType(DialogueWebtoonPanel).evaluate().length;
    expect(livePanels(), lessThan(12));
    expect(controller.position.maxScrollExtent, greaterThan(10000));

    // Back-and-forth jumps should not inflate all artwork or leak old panels.
    for (final fraction in <double>[.9, .25, .72, 0, 1]) {
      controller.jumpTo(controller.position.maxScrollExtent * fraction);
      await tester.pumpAndSettle();
      expect(livePanels(), lessThan(12),
          reason: 'only viewport-adjacent panels should remain mounted');
      expect(tester.takeException(), isNull);
    }

    expect(find.byKey(const Key('stress-panel-79')), findsOneWidget);
  });
}
