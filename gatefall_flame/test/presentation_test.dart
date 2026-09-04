// Version 3 ("Illumination") tests: the art, the animation and the sound.
//
// None of this is decoration that can be left untested. The art is
// *generated*, so a companion added to the roster with no look defined is a
// real bug; the sound is a set of committed WAVs, so a missing or silent
// file is a real bug; and the ambient animation is the one thing that can
// hang every widget test in the suite if it is ever left running under
// `flutter test`.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/art/character_art.dart';
import 'package:gatefall/art/effects.dart';
import 'package:gatefall/art/gate_art.dart';
import 'package:gatefall/art/motion.dart';
import 'package:gatefall/art/palette.dart';
import 'package:gatefall/audio/sfx.dart';
import 'package:gatefall/data/element.dart';
import 'package:gatefall/data/house.dart';
import 'package:gatefall/data/roster.dart';
import 'package:gatefall/state/game_controller.dart';
import 'package:gatefall/state/save_store.dart';
import 'package:gatefall/ui/shell.dart';
import 'package:gatefall/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(460, 2600);
    Audio.instance.resetLog();
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  // -------------------------------------------------------------------
  group('motion', () {
    test('ambient animation is off under flutter test', () {
      // If this ever flips to true, every `pumpAndSettle` in the suite
      // waits forever on a repeating controller. That is the whole reason
      // Motion exists.
      expect(Motion.ambient, isFalse);
    });

    test('one-shot transitions stay on, so a test can settle on them', () {
      expect(Motion.transitions, isTrue);
      expect(Motion.quick(const Duration(milliseconds: 300)),
          const Duration(milliseconds: 300));
    });
  });

  // -------------------------------------------------------------------
  group('character art', () {
    test('everyone in the roster and the house is actually drawn', () {
      for (final f in Roster.all) {
        expect(CharacterArt.looks.containsKey(f.id), isTrue,
            reason: '${f.id} fights but has no look defined');
      }
      for (final r in House.residents) {
        expect(CharacterArt.looks.containsKey(r.id), isTrue,
            reason: '${r.id} lives here but has no look defined');
      }
    });

    test("a look's element matches the fighter's, so art and combat agree",
        () {
      for (final f in Roster.all) {
        expect(CharacterArt.of(f.id).element, f.element,
            reason: '${f.id} is drawn in the wrong element');
      }
    });

    test('an unknown id still returns something drawable', () {
      final look = CharacterArt.of('nobody-by-that-name');
      expect(look.build, Build.awakened);
      expect(look.accent, isNotNull);
    });

    test('every build is used by somebody, and no two share a silhouette',
        () {
      final builds = CharacterArt.looks.values.map((l) => l.build).toList();
      expect(builds.toSet().length, builds.length,
          reason: 'two characters would be indistinguishable at chip size');
    });

    testWidgets('a portrait renders at every size it is used at',
        (tester) async {
      for (final size in [30.0, 46.0, 66.0, 130.0]) {
        await tester.pumpWidget(MaterialApp(
          home: Center(child: CharacterPortrait('faelen', size: size)),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(CharacterPortrait), findsOneWidget);
      }
    });
  });

  // -------------------------------------------------------------------
  group('world art', () {
    test('every element has its own colour', () {
      final colors =
          GateElement.values.map((e) => elementColor(e).toARGB32()).toList();
      expect(colors.toSet().length, colors.length);
    });

    test('the creature drawn is the creature the simulation spawned', () {
      // battle.dart cycles five wave enemies and then the guardian.
      for (var i = 0; i < 5; i++) {
        expect(beastformFor(waveIndex: i, boss: false),
            Beastform.values[i]);
      }
      expect(beastformFor(waveIndex: 0, boss: true), Beastform.guardian);
      expect(beastformFor(waveIndex: 12, boss: false),
          beastformFor(waveIndex: 2, boss: false));
    });

    testWidgets('a rift renders for every element', (tester) async {
      for (final e in GateElement.values) {
        await tester.pumpWidget(
            MaterialApp(home: Center(child: RiftView(element: e, size: 90))));
        await tester.pumpAndSettle();
        expect(find.byType(RiftView), findsOneWidget);
      }
    });
  });

  // -------------------------------------------------------------------
  group('sound files', () {
    /// Reads a mono 16-bit PCM WAV and returns (rate, samples).
    (int, Int16List) readWav(File file) {
      final bytes = file.readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF',
          reason: '${file.path} is not a RIFF file');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      final channels = data.getUint16(22, Endian.little);
      final rate = data.getUint32(24, Endian.little);
      final bits = data.getUint16(34, Endian.little);
      expect(channels, 1, reason: '${file.path} should be mono');
      expect(bits, 16, reason: '${file.path} should be 16-bit');
      // The generator writes a canonical 44-byte header.
      final samples = Int16List.sublistView(
          Uint8List.fromList(bytes.sublist(44)));
      return (rate, samples);
    }

    File assetFor(String asset) => File('assets/$asset');

    test('every sound the game can play exists on disk', () {
      for (final s in Sfx.values) {
        expect(assetFor(s.asset).existsSync(), isTrue,
            reason: '${s.asset} is missing — run tool/make_sounds.py');
      }
      for (final a in Ambience.values) {
        expect(assetFor(a.asset).existsSync(), isTrue,
            reason: '${a.asset} is missing — run tool/make_sounds.py');
      }
    });

    test('every sound is audible, in range, and not silence', () {
      for (final s in Sfx.values) {
        final (rate, samples) = readWav(assetFor(s.asset));
        expect(rate, 22050, reason: '${s.file} has an unexpected sample rate');
        expect(samples.length / rate, greaterThan(.02),
            reason: '${s.file} is too short to hear');
        expect(samples.length / rate, lessThan(4.0),
            reason: '${s.file} is too long for a sound effect');
        var peak = 0;
        for (final v in samples) {
          final a = v.abs();
          if (a > peak) peak = a;
        }
        // Loud enough to hear, quiet enough not to clip.
        expect(peak, greaterThan(3000), reason: '${s.file} is near silence');
        expect(peak, lessThan(32767), reason: '${s.file} clips');
      }
    });

    test('the ambient beds loop without a click at the seam', () {
      for (final a in Ambience.values) {
        final (rate, samples) = readWav(assetFor(a.asset));
        expect(rate, 16000);
        expect(samples.length / rate, greaterThan(8.0),
            reason: '${a.file} is too short to loop unnoticed');
        // The generator crossfades the tail over the head; if that ever
        // stops happening the join becomes an audible tick every few
        // seconds, which is worse than having no music at all.
        final step = (samples.first - samples.last).abs();
        expect(step, lessThan(1200),
            reason: '${a.file} jumps $step at the loop point');
      }
    });

    test('the pubspec ships the audio directory', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/audio/'));
    });
  });

  // -------------------------------------------------------------------
  group('the sound bus', () {
    test('is inert under test but still records what was asked for', () {
      Audio.instance.resetLog();
      Audio.instance.play(Sfx.ultimate);
      expect(Audio.instance.lastPlayed, Sfx.ultimate);
      expect(Audio.instance.log, contains(Sfx.ultimate));
    });

    test('settings survive a save and reload', () async {
      final store = MemorySaveStore();
      final a = GameController(store: store);
      await a.boot();
      a.setSfxOn(false);
      a.setMusicOn(false);
      await a.persist();

      final b = GameController(store: store);
      await b.boot();
      expect(b.sfxOn, isFalse);
      expect(b.musicOn, isFalse);
      expect(Audio.instance.sfxOn, isFalse);

      // Leave the bus how the rest of the suite expects to find it.
      b.setSfxOn(true);
      b.setMusicOn(true);
    });

    test('a save written before version 3 turns sound on', () async {
      final store = MemorySaveStore();
      final first = GameController(store: store);
      await first.boot();
      final old = first.toJson()
        ..remove('sfx_on')
        ..remove('music_on');
      await store.save(old);

      final g = GameController(store: store);
      await g.boot();
      expect(g.sfxOn, isTrue);
      expect(g.musicOn, isTrue);
    });
  });

  // -------------------------------------------------------------------
  group('ambient motion, actually running', () {
    // The suite runs with ambient animation off, which means nothing else
    // in it ever exercises a repeating controller — the state a real device
    // is always in. This turns it on for one test, pumps real frames (never
    // pumpAndSettle, which would wait forever by design), and puts it back.
    testWidgets('every screen animates without throwing', (tester) async {
      Motion.ambient = true;
      addTearDown(() => Motion.ambient = false);

      late final GameController game;
      await tester.runAsync(() async {
        game = GameController(store: MemorySaveStore());
        await game.boot();
      });
      await tester.pumpWidget(MaterialApp(
        theme: gatefallTheme(),
        home: GatefallShell(game: game),
      ));
      for (final icon in [
        Icons.blur_circular_outlined,
        Icons.groups_outlined,
        Icons.home_outlined,
      ]) {
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
        await tester.tap(find.byIcon(icon));
        await tester.pump();
      }
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------
  group('the fight, drawn and heard', () {
    Future<GameController> pumpGame(WidgetTester tester) async {
      late final GameController game;
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

    testWidgets('a raid draws the gate, the thing in it, and the party',
        (tester) async {
      await pumpGame(tester);
      await tester.tap(find.byIcon(Icons.blur_circular_outlined));
      await tester.pumpAndSettle();

      // The board already shows a turning rift per gate.
      expect(find.byType(RiftView), findsWidgets);

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      Audio.instance.resetLog();
      await tester.tap(find.text('Enter the gate'));
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(CreatureView), findsOneWidget);
      expect(find.byType(CharacterPortrait), findsWidgets);
      expect(find.byType(AnimatedBar), findsWidgets);
      // Opening a gate is the loudest thing in the game's first minute.
      expect(Audio.instance.log, contains(Sfx.gateOpen));
      // And three seconds of fighting has to have made some noise.
      expect(
        Audio.instance.log.any((s) =>
            s == Sfx.hit || s == Sfx.ability || s == Sfx.crit ||
            s == Sfx.ultimate),
        isTrue,
        reason: 'a fight in progress played no combat sound at all',
      );
    });

    testWidgets('the fight shows what it is doing in the log', (tester) async {
      await pumpGame(tester);
      await tester.tap(find.byIcon(Icons.blur_circular_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter the gate'));
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Whatever it says, it is saying something: before version 3 the
      // event log existed in the simulation and was never rendered
      // anywhere at all.
      final log = find.byKey(const ValueKey('battle-log'));
      expect(log, findsOneWidget);
      expect(find.descendant(of: log, matching: find.byType(Text)),
          findsWidgets);
    });
  });
}
