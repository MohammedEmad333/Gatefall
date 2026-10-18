import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/data/roster.dart';
import 'package:gatefall/state/game_controller.dart';
import 'package:gatefall/state/save_store.dart';
import 'package:gatefall/ui/allies_progress.dart';
import 'package:gatefall/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Party overview cycles an actual fighter through both rows',
      (tester) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(360, 1600);
    addTearDown(() {
      view.resetDevicePixelRatio();
      view.resetPhysicalSize();
    });

    late GameController game;
    await tester.runAsync(() async {
      game = GameController(store: MemorySaveStore());
      await game.boot();
    });
    await tester.pumpWidget(MaterialApp(
      theme: gatefallTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AnimatedBuilder(
            animation: game,
            builder: (context, _) => AlliesFormationOverview(game: game),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2/4 deployed'), findsOneWidget);
    expect(game.formation['faelen'], BattleRow.front);
    await tester.tap(find.byKey(const Key('allies-formation-faelen')));
    await tester.pumpAndSettle();
    expect(game.formation['faelen'], BattleRow.back);
    await tester.tap(find.byKey(const Key('allies-formation-faelen')));
    await tester.pumpAndSettle();
    expect(game.formation.containsKey('faelen'), isFalse);
    expect(find.text('1/4 deployed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('allies-formation-faelen')));
    await tester.pumpAndSettle();
    expect(game.formation['faelen'], BattleRow.front);
  });

  testWidgets('player cannot be benched and undeployable residents stay out',
      (tester) async {
    late GameController game;
    await tester.runAsync(() async {
      game = GameController(store: MemorySaveStore());
      await game.boot();
    });
    // Cycling player between front and back never removes the player.
    game.cycleFormation('player');
    expect(game.formation['player'], BattleRow.back);
    game.cycleFormation('player');
    expect(game.formation['player'], BattleRow.front);
    game.settled.add('dana');
    game.cycleFormation('dana');
    expect(game.formation.containsKey('dana'), isFalse);
  });

  testWidgets('Bond progress follows evaluator thresholds and max tier',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: gatefallTheme(),
      home: const Scaffold(
        body: Column(
          children: [
            AlliesBondProgress(points: 100, tier: 1),
            AlliesBondProgress(points: 950, tier: 6),
            AlliesStoryProgress(completed: 2, total: 7),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('50 to next tier'), findsOneWidget);
    expect(find.text('Max tier'), findsOneWidget);
    expect(find.text('2/7 stories remembered'), findsOneWidget);
    expect(find.byKey(const Key('allies-bond-progress')), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
