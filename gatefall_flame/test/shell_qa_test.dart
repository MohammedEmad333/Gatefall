import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/data/roster.dart';
import 'package:gatefall/state/game_controller.dart';
import 'package:gatefall/state/save_store.dart';
import 'package:gatefall/ui/allies_screen.dart';
import 'package:gatefall/ui/gate_screen.dart';
import 'package:gatefall/ui/home_screen.dart';
import 'package:gatefall/ui/shell.dart';
import 'package:gatefall/ui/story_screen.dart';
import 'package:gatefall/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Future<GameController> boot(WidgetTester tester) async {
    late GameController game;
    await tester.runAsync(() async {
      game = GameController(store: MemorySaveStore());
      await game.boot();
    });
    await tester.pumpWidget(MaterialApp(
      theme: gatefallTheme(),
      home: GatefallShell(game: game),
    ));
    await tester.pumpAndSettle();
    return game;
  }

  int activeTab(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  testWidgets('OS Back from each secondary tab returns to House',
      (tester) async {
    await boot(tester);
    expect(activeTab(tester), 0);

    for (final icon in [
      Icons.menu_book_outlined,
      Icons.blur_circular_outlined,
      Icons.groups_outlined,
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      expect(activeTab(tester), isNot(0));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(activeTab(tester), 0);
      expect(find.text('The books'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('OS Back closes dialogue before leaving the Story tab',
      (tester) async {
    final game = await boot(tester);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    final scene = find.byKey(const Key('story-route-faelen'));
    await tester.ensureVisible(scene);
    await tester.tap(scene);
    await tester.pumpAndSettle();
    expect(find.text("I Won't Be Staying"), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(activeTab(tester), 1);
    expect(find.text('Your story'), findsOneWidget);
    expect(game.state.completedBeats, isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(activeTab(tester), 0);
  });

  testWidgets('inactive tabs freeze their tickers but retain state',
      (tester) async {
    await boot(tester);
    final home = find.byType(HomeScreen, skipOffstage: false);
    final story = find.byType(StoryScreen, skipOffstage: false);
    final gates = find.byType(GateScreen, skipOffstage: false);
    final allies = find.byType(AlliesScreen, skipOffstage: false);

    expect(TickerMode.of(tester.element(home)), isTrue);
    expect(TickerMode.of(tester.element(story)), isFalse);
    expect(TickerMode.of(tester.element(gates)), isFalse);
    expect(TickerMode.of(tester.element(allies)), isFalse);

    await tester.tap(find.byIcon(Icons.groups_outlined));
    await tester.pumpAndSettle();
    expect(TickerMode.of(tester.element(home)), isFalse);
    expect(TickerMode.of(tester.element(allies)), isTrue);

    await tester.tap(find.byIcon(Icons.blur_circular_outlined));
    await tester.pumpAndSettle();
    expect(TickerMode.of(tester.element(allies)), isFalse);
    expect(TickerMode.of(tester.element(gates)), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated result exits are ignored after withdrawal',
      (tester) async {
    final game = await boot(tester);
    await tester.tap(find.byIcon(Icons.blur_circular_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text(game.board.first.fullName).first);
    await tester.pump();
    await tester.tap(find.text('Enter the gate'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('withdraw-raid')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();
    expect(find.text('Party withdrawn'), findsOneWidget);

    // Retain the previous frame's callback to simulate a rapid second tap
    // arriving before Flutter has rebuilt the result page.
    final leave = tester.widget<SlabButton>(
      find.byKey(const ValueKey('leave-failed-gate')),
    ).onPressed!;
    leave();
    leave();
    await tester.pumpAndSettle();
    expect(find.text('The board'), findsOneWidget);
    expect(game.clears, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('formation and paused raid survive tab navigation and Back',
      (tester) async {
    final game = await boot(tester);

    await tester.tap(find.byIcon(Icons.groups_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('allies-formation-faelen')));
    await tester.pumpAndSettle();
    expect(game.formation['faelen'], BattleRow.back);

    await tester.tap(find.byIcon(Icons.blur_circular_outlined));
    await tester.pumpAndSettle();
    final picked = game.board.first;
    await tester.tap(find.text(picked.fullName).first);
    await tester.pump();
    await tester.tap(find.text('Enter the gate'));
    await tester.pump();
    expect(find.byKey(const ValueKey('pause-raid')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(activeTab(tester), 0);

    await tester.tap(find.byIcon(Icons.blur_circular_outlined));
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    expect(game.formation['faelen'], BattleRow.back);
    expect(tester.takeException(), isNull);
  });
}
