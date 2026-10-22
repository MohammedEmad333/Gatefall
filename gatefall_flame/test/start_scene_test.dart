// The opening comic: the flag that decides whether it plays, and the page
// turn that gets a reader from the first panel to the game.
//
// Two classes of bug this catches and nothing else does. One: a returning
// player, or a save written before the prologue existed, being made to sit
// through six pages on every launch — the flag defaults the wrong way and
// the game opens on a cutscene. Two: a page whose panels cannot be
// advanced, which strands a *new* player on panel one with no way into the
// game at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/art/comic.dart';
import 'package:gatefall/audio/sfx.dart';
import 'package:gatefall/state/game_controller.dart';
import 'package:gatefall/state/save_store.dart';
import 'package:gatefall/ui/start_scene.dart';
import 'package:gatefall/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(460, 900);
    Audio.instance.resetLog();
  });

  group('when the opening plays', () {
    test('a brand new game has not been introduced yet', () async {
      final game = GameController(store: MemorySaveStore());
      await game.boot();
      expect(game.prologueSeen, isFalse);
    });

    test('a save from before the opening existed is treated as read',
        () async {
      // The whole point: shipping this must not open a cutscene on someone
      // who is forty raids into a run.
      final game = GameController(
          store: MemorySaveStore({'mana': 400, 'settled': ['faelen']}));
      await game.boot();
      expect(game.prologueSeen, isTrue);
    });

    test('reading it once is saved, and survives a reload', () async {
      final store = MemorySaveStore();
      final first = GameController(store: store);
      await first.boot();
      await first.markPrologueSeen();
      expect((await store.load())!['prologue_seen'], isTrue);

      final second = GameController(store: store);
      await second.boot();
      expect(second.prologueSeen, isTrue);
    });

    test('starting over does not replay it', () async {
      final game = GameController(store: MemorySaveStore());
      await game.boot();
      await game.markPrologueSeen();
      await game.resetGame();
      expect(game.prologueSeen, isTrue);
    });
  });

  group('reading it', () {
    testWidgets('vertical mode shows the original scrollable comic',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: gatefallTheme(),
        home: StartScene(onDone: () {}),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('opening-reader-mode')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('opening-vertical-reader')), findsOneWidget);
      final vertical = tester.widget<ListView>(
        find.byKey(const Key('opening-vertical-reader')),
      );
      expect(vertical.cacheExtent, lessThanOrEqualTo(240));
      expect((vertical.childrenDelegate as SliverChildBuilderDelegate).addAutomaticKeepAlives, isFalse);
      expect(find.byKey(const Key('opening-panel-0')), findsOneWidget);
      expect(TickerMode.of(tester.element(
        find.byKey(const Key('opening-panel-0')),
      )), isTrue);
      final next = find.byKey(const Key('opening-panel-1'));
      if (next.evaluate().isNotEmpty) {
        expect(TickerMode.of(tester.element(next)), isFalse);
      }
      expect(find.text('Scroll to read · panel 1 / 11'), findsOneWidget);
      expect(find.text('skip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scroll focus updates indicators without rebuilding the header',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: gatefallTheme(),
        home: StartScene(onDone: () {}),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('opening-reader-mode')));
      await tester.pumpAndSettle();

      final headerModeBefore =
          tester.widget<TextButton>(find.byKey(const Key('opening-reader-mode')));
      await tester.drag(
        find.byKey(const Key('opening-vertical-reader')),
        const Offset(0, -650),
      );
      await tester.pumpAndSettle();

      final progress =
          tester.widget<Text>(find.byKey(const Key('opening-scroll-progress')));
      final panel = int.parse(
        RegExp(r'panel (\d+)').firstMatch(progress.data!)!.group(1)!,
      );
      expect(panel, greaterThan(1));
      // A changed scroll focus must not rebuild the title, controls, or art
      // owned by StartScene's Scaffold.
      expect(identical(
        headerModeBefore,
        tester.widget<TextButton>(
          find.byKey(const Key('opening-reader-mode')),
        ),
      ), isTrue);

      final focused = find.byKey(Key('opening-panel-${panel - 1}'));
      if (focused.evaluate().isNotEmpty) {
        expect(TickerMode.of(tester.element(focused)), isTrue);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('vertical mode finishes only at the final reader action',
        (tester) async {
      var done = false;
      await tester.pumpWidget(MaterialApp(
        theme: gatefallTheme(),
        home: StartScene(onDone: () => done = true),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('opening-reader-mode')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('opening-vertical-finish')),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(done, isFalse);
      await tester.tap(find.byKey(const Key('opening-vertical-finish')));
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });

    testWidgets('switching reader modes keeps the scroll position',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: gatefallTheme(),
        home: StartScene(onDone: () {}),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('opening-reader-mode')));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('opening-vertical-reader')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('opening-reader-mode')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('opening-pages-1')), findsNothing);
      expect(find.byType(ComicPanel), findsWidgets);
      expect(tester.takeException(), isNull);
    });


    testWidgets('opens on the first page, one panel at a time',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: gatefallTheme(),
        home: StartScene(onDone: () {}),
      ));
      await tester.pumpAndSettle();

      // The whole page is laid out from the first frame — panels are
      // revealed, not inserted, so nothing reflows under the reader.
      expect(find.byType(ComicPanel), findsNWidgets(2));
      expect(find.text('skip'), findsOneWidget);
      expect(find.text('BEGIN'), findsNothing);
    });

    testWidgets('opening header fits a very narrow phone', (tester) async {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(280, 620);

      await tester.pumpWidget(MaterialApp(
        theme: gatefallTheme(),
        home: StartScene(onDone: () {}),
      ));
      await tester.pumpAndSettle();

      expect(find.text('skip'), findsOneWidget);
      expect(find.byType(ComicPanel), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('taps reach the end and hand over to the game',
        (tester) async {
      var done = false;
      await tester.pumpWidget(MaterialApp(
        theme: gatefallTheme(),
        home: StartScene(onDone: () => done = true),
      ));
      await tester.pumpAndSettle();

      // Generously more taps than the script needs; the assertion is that
      // it *ends*, not how many taps it takes.
      for (var i = 0; i < 60 && find.text('BEGIN').evaluate().isEmpty; i++) {
        await tester.tapAt(tester.getCenter(find.byType(ComicPanel).first));
        await tester.pumpAndSettle();
      }

      expect(find.text('BEGIN'), findsOneWidget,
          reason: 'the last page must offer a way into the game');
      expect(done, isFalse);

      await tester.tap(find.text('BEGIN'));
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });

    testWidgets('skip hands over immediately', (tester) async {
      var done = false;
      await tester.pumpWidget(MaterialApp(
        theme: gatefallTheme(),
        home: StartScene(onDone: () => done = true),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('skip'));
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });

    testWidgets('a re-read from the house says so on the last page',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: gatefallTheme(),
        home: StartScene(onDone: () {}, finishLabel: 'BACK'),
      ));
      await tester.pumpAndSettle();

      for (var i = 0; i < 60 && find.text('BACK').evaluate().isEmpty; i++) {
        await tester.tapAt(tester.getCenter(find.byType(ComicPanel).first));
        await tester.pumpAndSettle();
      }
      expect(find.text('BACK'), findsOneWidget);
    });
  });
}
