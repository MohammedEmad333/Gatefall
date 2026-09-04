// Widget smoke tests: the app boots, the three tabs render, and a scene can
// actually be played end to end through the real screens.
//
// The point of these is the class of bug unit tests can't reach — a screen
// that throws on first build, a tab that renders nothing, a dialogue node
// that has no way forward. `flutter analyze` will not catch any of those.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/data/gear.dart';
import 'package:gatefall/state/game_controller.dart';
import 'package:gatefall/state/save_store.dart';
import 'package:gatefall/ui/gate_screen.dart';
import 'package:gatefall/ui/shell.dart';
import 'package:gatefall/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every screen is a scrolling column, so the default 800x600 test surface
  // builds only the top of it and `find` misses anything below the fold.
  // A tall, narrow surface renders a whole screen at once — closer to the
  // phone this is actually for, and it makes the finders mean what they say.
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(460, 2600);
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<GameController> pumpGame(WidgetTester tester,
      {void Function(GameController)? setup}) async {
    // Booting reads route and scene JSON off disk. A widget test body runs
    // inside FakeAsync, where real I/O never completes — runAsync is the
    // documented escape hatch, and without it the second test in a file
    // hangs forever waiting on a Future the fake clock will never advance.
    late final GameController game;
    await tester.runAsync(() async {
      game = GameController(store: MemorySaveStore());
      await game.boot();
    });
    setup?.call(game);
    await tester.pumpWidget(MaterialApp(
      theme: gatefallTheme(),
      home: GatefallShell(game: game),
    ));
    await tester.pumpAndSettle();
    return game;
  }

  /// Tapping a bottom-nav destination. The label text appears once per
  /// destination, so target the destination itself rather than the string.
  Future<void> tapTab(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon));
    await tester.pumpAndSettle();
  }

  testWidgets('the app boots onto the house with Faelen already home',
      (tester) async {
    await pumpGame(tester);
    expect(find.text('Act I — The Door'), findsOneWidget);
    expect(find.text('Faelen'), findsWidgets);
    expect(find.text('House'), findsOneWidget);
    expect(find.text('Gates'), findsOneWidget);
    expect(find.text('Party'), findsOneWidget);
  });

  testWidgets('all three tabs render without throwing', (tester) async {
    await pumpGame(tester);

    await tapTab(tester, Icons.blur_circular_outlined);
    expect(find.text('The board'), findsOneWidget);

    await tapTab(tester, Icons.groups_outlined);
    expect(find.text('Who you take in there'), findsOneWidget);

    await tapTab(tester, Icons.home_outlined);
    expect(find.text('The books'), findsOneWidget);
  });

  testWidgets('the gate board offers a gate and a formation screen',
      (tester) async {
    await pumpGame(tester);
    await tapTab(tester, Icons.blur_circular_outlined);

    // The first tier is always on the board. Scope the finder to the gate
    // screen: the shell keeps every tab alive in an IndexedStack (so a raid
    // survives a tab switch), which means text on an off-screen tab is still
    // in the widget tree and an unscoped finder can match it.
    final card = find
        .descendant(
            of: find.byType(GateScreen),
            matching: find.textContaining('Fracture'))
        .first;
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('Set your formation'), findsOneWidget);
    expect(find.text('Enter the gate'), findsOneWidget);
  });

  testWidgets('Faelen\'s opening scene plays through to the end',
      (tester) async {
    // The whole reason the dialogue renderer exists: a beat you can tap,
    // read, and finish, with the completion landing back in game state.
    final game = await pumpGame(tester);
    expect(game.state.completedBeats, isEmpty);

    await tester.tap(find.text('Faelen — "I Won\'t Be Staying"'));
    await tester.pumpAndSettle();
    expect(find.text('I Won\'t Be Staying'), findsOneWidget);

    // Walk the linear scene to its terminal node.
    var guard = 0;
    while (find.text('Continue').evaluate().isNotEmpty && guard++ < 25) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    expect(find.text('End of scene'), findsOneWidget);
    expect(find.text('I don\'t need shelter.'), findsOneWidget);

    await tester.tap(find.text('End of scene'));
    await tester.pumpAndSettle();

    expect(game.state.completedBeats, contains('faelen_b0_recruitment'));
    expect(find.text('Act I — The Door'), findsOneWidget);
  });

  testWidgets('a branching scene shows its choices and applies the one picked',
      (tester) async {
    final game = await pumpGame(tester, setup: (g) {
      // Stand the player right in front of Faelen's Fracture.
      g.state.storyAct = 2;
      g.state.addBond('faelen', 500); // tier 4
      g.state.completedBeats.addAll([
        'faelen_b0_recruitment',
        'faelen_b1_the_wall',
        'faelen_b2_proving_ground',
        'faelen_b3_first_truth',
      ]);
    });
    await tester.pumpAndSettle();

    // The title also appears in the resident panel's "next up" line, so
    // target the story card itself.
    await tester.tap(find.text('Faelen — "This Is My War"'));
    await tester.pumpAndSettle();

    expect(find.text('What do you say?'), findsOneWidget);
    expect(find.text('"Then we go together."'), findsOneWidget);

    await tester.tap(find.text('"Then we go together."'));
    await tester.pumpAndSettle();

    expect(game.state.flags['FAELEN_FRACTURE'], 'join');

    await tester.tap(find.text('End of scene'));
    await tester.pumpAndSettle();
    expect(game.state.completedBeats, contains('faelen_b4_the_fracture'));
  });

  testWidgets('the gift shop spends gold and moves bond', (tester) async {
    final game = await pumpGame(tester, setup: (g) => g.gold = 500);
    await tester.pumpAndSettle();

    final before = game.bondPoints('faelen');
    await tester.tap(find.text('Gift').first);
    await tester.pumpAndSettle();

    expect(find.text('Something for Faelen'), findsOneWidget);
    await tester.tap(find.text('Whetstone and oil kit'));
    await tester.pumpAndSettle();

    expect(game.bondPoints('faelen'), greaterThan(before));
    expect(game.gold, lessThan(500));
  });

  testWidgets('every screen lays out on a small phone without overflowing',
      (tester) async {
    // A RenderFlex overflow throws in a test, so this is a real assertion:
    // 320 logical pixels is the narrowest phone anyone still ships, and it
    // is where a title next to a five-digit currency readout breaks first.
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(320, 2600);

    await pumpGame(tester, setup: (g) {
      // Worst case for width: big numbers, a full house, gear on everyone.
      g.mana = 987654;
      g.gold = 987654;
      g.clears = 40;
      g.settled.addAll(['kess', 'momo', 'thora', 'dana']);
      g.cycleFormation('kess');
      g.cycleFormation('momo');
      for (final f in g.roster) {
        g.levels[f.id] = 20;
        g.gear[f.id] = Gear(rarity: GearRarity.epic, enhanceLevel: 8);
        g.state.addBond(f.id, 950);
      }
      // The board is built at boot from the clear count, so it has to be
      // rebuilt after the setup raises it or the top tier is not on it.
      g.rerollBoard();
    });
    await tester.pumpAndSettle();

    await tapTab(tester, Icons.blur_circular_outlined);
    // And into the formation screen, where four unit chips share one row.
    await tester.tap(find
        .descendant(
            of: find.byType(GateScreen),
            matching: find.textContaining('Maw'))
        .first);
    await tester.pumpAndSettle();
    expect(find.text('Set your formation'), findsOneWidget);

    await tapTab(tester, Icons.groups_outlined);
    expect(find.text('Who you take in there'), findsOneWidget);

    await tapTab(tester, Icons.home_outlined);
    expect(find.text('The books'), findsOneWidget);
  });

  testWidgets('the party screen shows the Mana sinks', (tester) async {
    await pumpGame(tester, setup: (g) => g.mana = 5000);
    await tester.pumpAndSettle();
    await tapTab(tester, Icons.groups_outlined);

    expect(find.text('Level up'), findsWidgets);
    expect(find.textContaining('total stat multiplier'), findsWidgets);
  });
}
