import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/data/ascension.dart';
import 'package:gatefall/ui/dialogue_screen.dart';
import 'package:gatefall/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ascension reveal shows active ability and passive payoff',
      (tester) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: gatefallTheme(),
        home: Scaffold(
          body: Center(
            child: AscensionReveal(
              characterId: 'faelen',
              ascension: Ascension.byId('faelen'),
              note: 'Faelen has ascended.',
              onContinue: () => continued = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ASCENSION'), findsOneWidget);
    expect(find.text('Faelen — Oathbound'), findsOneWidget);
    expect(find.text('NEW ABILITY'), findsOneWidget);
    expect(find.text('Oathbound'), findsOneWidget);
    expect(find.text('PASSIVE'), findsOneWidget);
    expect(
      find.text('Guard now shares part of its shield with every living ally.'),
      findsOneWidget,
    );
    expect(find.text('Take it to the gates'), findsOneWidget);

    await tester.tap(find.text('Take it to the gates'));
    await tester.pump();
    expect(continued, isTrue);
  });
}
