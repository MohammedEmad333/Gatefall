import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/ui/dialogue_webtoon_panel.dart';
import 'package:gatefall/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('long captions grow beyond the former 1250px cap',
      (tester) async {
    final longLine = List.filled(
      18,
      'Beyond the rift, we stand together. ',
    ).join();
    const width = 280.0;
    const large = TextScaler.linear(2.0);
    const normal = TextScaler.linear(1.0);

    final normalHeight = chapterPanelHeight(
      text: longLine,
      width: width,
      textScaler: normal,
      textDirection: TextDirection.ltr,
      isNarration: false,
    );
    final largeHeight = chapterPanelHeight(
      text: longLine,
      width: width,
      textScaler: large,
      textDirection: TextDirection.ltr,
      isNarration: false,
    );
    expect(largeHeight, greaterThan(normalHeight));
    expect(largeHeight, greaterThan(1250));

    final view = TestWidgetsFlutterBinding
        .instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(280, 700);
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      theme: gatefallTheme(),
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(textScaler: large),
          child: SingleChildScrollView(
            child: DialogueWebtoonPanel(
              index: 0,
              characterId: 'faelen',
              speakerId: 'faelen',
              speakerName: 'Faelen',
              text: longLine,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(DialogueWebtoonPanel), findsOneWidget);
    expect(find.text(longLine), findsOneWidget);
    expect(tester.getSize(find.byType(DialogueWebtoonPanel)).height,
        closeTo(largeHeight + 18, 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('panel measurements respect forced line breaks and narration',
      (tester) async {
    const short = 'We hold the gate.';
    const broken = 'We\nhold\nthe\ngate.';
    const scaler = TextScaler.linear(1.5);
    double height(String text, {bool narration = false}) =>
        chapterPanelHeight(
          text: text,
          width: 260,
          textScaler: scaler,
          textDirection: TextDirection.ltr,
          isNarration: narration,
        );

    expect(height(broken), greaterThanOrEqualTo(height(short)));
    expect(height(List.filled(24, broken).join('\n')),
        greaterThan(height(broken)));
    expect(height(broken, narration: true), greaterThanOrEqualTo(298));

    final rtl = chapterPanelHeight(
      text: 'مرحبا بكم في جيت فول',
      width: 260,
      textScaler: scaler,
      textDirection: TextDirection.rtl,
      isNarration: false,
    );
    expect(rtl, greaterThanOrEqualTo(298));
    expect(tester.takeException(), isNull);
  });
}
