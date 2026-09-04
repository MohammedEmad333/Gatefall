// A visual proof sheet for the generated art. Not part of the test suite
// (its name keeps `flutter test` from picking it up); run it by hand when
// you change a painter:
//
//     flutter test test/_preview.dart
//
// It writes PNGs to build/art-preview/ so you can look at what the code
// actually draws instead of imagining it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/art/character_art.dart';
import 'package:gatefall/state/game_controller.dart';
import 'package:gatefall/state/save_store.dart';
import 'package:gatefall/ui/companions_screen.dart';
import 'package:gatefall/ui/dialogue_screen.dart';
import 'package:gatefall/ui/gate_screen.dart';
import 'package:gatefall/ui/shell.dart';
import 'package:gatefall/art/gate_art.dart';
import 'package:gatefall/data/element.dart';
import 'package:gatefall/ui/theme.dart';

Future<void> shoot(WidgetTester tester, String name, Widget child,
    {Size size = const Size(600, 400)}) async {
  final key = GlobalKey();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: gatefallTheme(),
    home: RepaintBoundary(
      key: key,
      child: Container(color: night, child: child),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/art-preview')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(
        data!.buffer.asUint8List(), flush: true);
  });
}

void main() {
  screens();
  const ids = ['player', 'faelen', 'kess', 'momo', 'thora', 'dana'];

  testWidgets('portraits', (tester) async {
    await shoot(
      tester,
      'portraits',
      Center(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final id in ids)
              Column(mainAxisSize: MainAxisSize.min, children: [
                CharacterPortrait(id, size: 130, glow: .9),
                Text(id, style: const TextStyle(color: bone, fontSize: 11)),
              ]),
          ],
        ),
      ),
      size: const Size(880, 640),
    );
  });

  testWidgets('portrait sizes', (tester) async {
    await shoot(
      tester,
      'portrait-sizes',
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final size in [30.0, 44.0, 64.0])
              Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final id in ids)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: CharacterPortrait(id, size: size),
                      ),
                  ],
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final id in ids)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: CharacterPortrait(id, size: 44, dimmed: true),
                  ),
              ],
            ),
          ],
        ),
      ),
      size: const Size(560, 420),
    );
  });

  testWidgets('rifts and creatures', (tester) async {
    await shoot(
      tester,
      'world',
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in GateElement.values)
                  RiftView(element: e, size: 120),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in Beastform.values)
                  CreatureView(
                      form: f, element: GateElement.gloam, size: 140),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in Beastform.values)
                  CreatureView(
                      form: f,
                      element: GateElement.ember,
                      size: 140,
                      hurt: 1),
              ],
            ),
          ],
        ),
      ),
      size: const Size(900, 520),
    );
  });
}

// ---- whole screens, as the player sees them ---------------------------

Future<void> shootScreen(WidgetTester tester, String name,
    {required Widget Function(GameController) build,
    Future<void> Function(WidgetTester, GameController)? drive,
    void Function(GameController)? setup,
    Size size = const Size(430, 900)}) async {
  late final GameController game;
  await tester.runAsync(() async {
    game = GameController(store: MemorySaveStore());
    await game.boot();
  });
  setup?.call(game);
  final key = GlobalKey();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: gatefallTheme(),
    // These screens normally live inside the shell's Scaffold; an InkWell
    // needs the Material it provides.
    home: Scaffold(
        backgroundColor: night,
        body: SafeArea(
          child: RepaintBoundary(
            key: key,
            // Inside the boundary, or the shot comes out transparent.
            child: ColoredBox(color: night, child: build(game)),
          ),
        )),
  ));
  await tester.pumpAndSettle();
  if (drive != null) await drive(tester, game);
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/art-preview')..createSync(recursive: true);
    File('${dir.path}/$name.png')
        .writeAsBytesSync(data!.buffer.asUint8List(), flush: true);
  });
}

void screens() {
  testWidgets('house', (tester) async {
    await shootScreen(tester, 'screen-house',
        setup: (g) {
          g.gold = 4000;
          g.clears = 9;
          g.settled.addAll(['kess', 'momo']);
          g.state.addBond('faelen', 120);
          g.state.addBond('kess', 60);
        },
        build: (g) => GatefallShell(game: g));
  });

  testWidgets('gate board', (tester) async {
    await shootScreen(tester, 'screen-gates',
        setup: (g) => g.clears = 12,
        build: (g) => GateScreen(game: g));
  });

  testWidgets('party', (tester) async {
    await shootScreen(tester, 'screen-party',
        setup: (g) {
          g.mana = 5000;
          g.settled.addAll(['kess', 'momo', 'thora']);
        },
        build: (g) => CompanionsScreen(game: g));
  });

  testWidgets('dialogue', (tester) async {
    await shootScreen(
      tester,
      'screen-dialogue',
      build: (g) => DialogueScreen(
          game: g,
          characterId: 'faelen',
          beat: g.upcomingBeat('faelen')!),
      drive: (tester, g) async {
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
        }
        await tester.pump(const Duration(milliseconds: 120));
      },
    );
  });

  testWidgets('fight', (tester) async {
    await shootScreen(
      tester,
      'screen-fight',
      setup: (g) => g.settled.addAll(['kess', 'momo']),
      build: (g) => GateScreen(game: g),
      drive: (tester, g) async {
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enter the gate'));
        await tester.pump();
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
    );
  });
}
