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
