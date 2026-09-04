// Tests for the systems that turned the raid prototype into a game: the
// house economy, acts, save/load, offline accrual, the endings table, and
// the dialogue engine actually being driven the way the scene renderer
// drives it.
//
// These need `flutter test` rather than `dart test` because the route and
// scene JSON is loaded through rootBundle, exactly as the app loads it —
// which also means a broken asset declaration fails here instead of at
// runtime on a device.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/data/companion_routes.dart';
import 'package:gatefall/data/gear.dart';
import 'package:gatefall/data/gifts.dart';
import 'package:gatefall/data/house.dart';
import 'package:gatefall/data/story.dart';
import 'package:gatefall/state/game_controller.dart';
import 'package:gatefall/state/save_store.dart';
import 'package:gatefall_dialogue_engine/engine/dialogue_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameController> booted({
    MemorySaveStore? store,
    DateTime Function()? clock,
  }) async {
    final g = GameController(
        store: store ?? MemorySaveStore(), clock: clock);
    await g.boot();
    return g;
  }

  // -------------------------------------------------------------------
  group('assets', () {
    test('every route in the shipped data loads through the app bundle', () async {
      final routes = await CompanionRoutes.loadAll();
      expect(routes.keys.toSet(), CompanionRoutes.ids.toSet());
      for (final r in routes.values) {
        expect(r.beats, hasLength(7),
            reason: '${r.characterId} should have the full seven-beat frame');
        expect(r.endings, isNotEmpty);
      }
    });

    test('every beat in every route points at a scene that actually loads',
        () async {
      // The one failure mode a house/dialogue UI can hit that a raid screen
      // never could: a beat whose scene_ref is wrong is invisible until a
      // player taps it.
      final routes = await CompanionRoutes.loadAll();
      for (final route in routes.values) {
        for (final beat in route.beats) {
          final scene = await CompanionRoutes.loadScene(beat.sceneRef);
          expect(scene.nodes, isNotEmpty,
              reason: '${beat.beatId} loaded an empty scene');
          expect(scene.nodes.containsKey(scene.startNode), isTrue,
              reason: '${beat.beatId} start_node "${scene.startNode}" is not '
                  'a node in its own scene');
        }
      }
    });

    test('every node any scene can reach exists, and every path can end',
        () async {
      final routes = await CompanionRoutes.loadAll();
      for (final route in routes.values) {
        for (final beat in route.beats) {
          final scene = await CompanionRoutes.loadScene(beat.sceneRef);
          var sawEnd = false;
          for (final node in scene.nodes.values) {
            if (node.endScene) sawEnd = true;
            if (node.next != null) {
              expect(scene.nodes.containsKey(node.next), isTrue,
                  reason: '${beat.beatId}: node "${node.id}" points at '
                      'missing node "${node.next}"');
            }
            for (final c in node.choices) {
              expect(scene.nodes.containsKey(c.next), isTrue,
                  reason: '${beat.beatId}: choice "${c.choiceId}" points at '
                      'missing node "${c.next}"');
            }
            if (!node.endScene && !node.isBranch) {
              expect(node.next, isNotNull,
                  reason: '${beat.beatId}: node "${node.id}" is a dead end '
                      'that is not marked end_scene');
            }
          }
          expect(sawEnd, isTrue,
              reason: '${beat.beatId} has no terminal node — a player would '
                  'be stuck in it');
        }
      }
    });
  });

  // -------------------------------------------------------------------
  group('new game', () {
    test('the house is never empty and the party is never one', () async {
      // Finding #4 restated as a save-state invariant: Faelen arrives on the
      // step, so there is never a first frame where the player is alone.
      final g = await booted();
      expect(g.settled, contains('faelen'));
      expect(g.formation.length, greaterThanOrEqualTo(2));
      expect(g.roster.map((f) => f.id), contains('player'));
    });

    test('Faelen\'s recruitment beat is waiting to be played immediately',
        () async {
      final g = await booted();
      final pending = g.pendingStoryBeats;
      expect(pending, isNotEmpty);
      expect(pending.first.beat.beatId, 'faelen_b0_recruitment');
      expect(pending.first.beat.triggerContext, 'story');
    });

    test('the gate board always offers at least one gate', () async {
      final g = await booted();
      expect(g.board, isNotEmpty);
      expect(g.board.first.tier.index, 0);
    });
  });

  // -------------------------------------------------------------------
  group('save / load', () {
    test('a full round trip preserves everything a player earned', () async {
      final store = MemorySaveStore();
      final a = await booted(store: store);

      a.mana = 4321;
      a.gold = 999;
      a.clears = 7;
      a.bestClearMana = 460;
      a.levels['faelen'] = 9;
      a.settled.add('kess');
      a.state.addBond('faelen', 300);
      a.state.flags['FAELEN_FRACTURE'] = 'join';
      a.state.completedBeats.add('faelen_b0_recruitment');
      a.cycleFormation('kess');
      await a.persist();

      final b = await booted(store: store);
      expect(b.mana, 4321);
      expect(b.gold, 999);
      expect(b.clears, 7);
      expect(b.bestClearMana, 460);
      expect(b.levels['faelen'], 9);
      expect(b.settled, containsAll(['faelen', 'kess']));
      expect(b.bondPoints('faelen'), 300);
      expect(b.state.flags['FAELEN_FRACTURE'], 'join');
      expect(b.state.completedBeats, contains('faelen_b0_recruitment'));
      expect(b.formation.containsKey('kess'), isTrue);
    });

    test('gear survives a round trip with its rarity and enhance level',
        () async {
      final store = MemorySaveStore();
      final a = await booted(store: store);
      a.mana = 100000;
      a.gear['kess'] = Gear(rarity: GearRarity.rare, enhanceLevel: 3);
      await a.persist();

      final b = await booted(store: store);
      final g = b.gear['kess'];
      expect(g, isNotNull);
      expect(g!.rarity.label, 'Rare');
      expect(g.enhanceLevel, 3);
    });

    test('a corrupt save starts a new game instead of wedging the app',
        () async {
      final store = MemorySaveStore({'mana': 'not a number'});
      final g = GameController(store: store);
      await g.boot();
      expect(g.mana, 0);
      expect(g.settled, contains('faelen'));
    });

    test('a save with nobody home is repaired rather than shipped', () async {
      final store = MemorySaveStore({
        'mana': 10,
        'settled': <String>[],
        'formation': {'player': 'front'},
      });
      final g = await booted(store: store);
      expect(g.settled, contains('faelen'),
          reason: 'a party of one loses ~100% — never restore into it');
      expect(g.formation.length, greaterThanOrEqualTo(2));
    });
  });

  // -------------------------------------------------------------------
  group('offline accrual (combat-spec §7)', () {
    test('nothing accrues before the player has ever cleared a gate',
        () async {
      final store = MemorySaveStore();
      var now = DateTime(2026, 1, 1, 12);
      final a = await booted(store: store, clock: () => now);
      await a.persist();

      now = now.add(const Duration(hours: 6));
      final b = await booted(store: store, clock: () => now);
      expect(b.mana, 0);
      expect(b.welcomeBackMessage, isNull);
    });

    test('mana accrues while away, proportional to time', () async {
      final store = MemorySaveStore();
      var now = DateTime(2026, 1, 1, 12);
      final a = await booted(store: store, clock: () => now);
      a.bestClearMana = 400;
      await a.persist();

      now = now.add(const Duration(hours: 2));
      final b = await booted(store: store, clock: () => now);
      expect(b.mana, greaterThan(0));
      expect(b.welcomeBackMessage, isNotNull);
      // 400 * 4 clears/hr * 0.5 * 2h
      expect(b.mana, 1600);
    });

    test('accrual is capped, so leaving for a week is not a strategy',
        () async {
      final store = MemorySaveStore();
      var now = DateTime(2026, 1, 1, 12);
      final a = await booted(store: store, clock: () => now);
      a.bestClearMana = 400;
      await a.persist();

      now = now.add(const Duration(days: 7));
      final b = await booted(store: store, clock: () => now);
      expect(b.mana, 400 * 4 ~/ 2 * 10);
      expect(b.welcomeBackMessage, contains('caps at'));
    });

    test('offline is worth clearly less than playing', () async {
      // An hour away pays 800 on a 400-mana clear. An hour of active play at
      // 2x on a ~200s clear is roughly 18 clears, or 7,200. Idle is a head
      // start, never a substitute — the whole point of §7.
      final store = MemorySaveStore();
      var now = DateTime(2026, 1, 1, 12);
      final a = await booted(store: store, clock: () => now);
      a.bestClearMana = 400;
      await a.persist();

      now = now.add(const Duration(hours: 1));
      final b = await booted(store: store, clock: () => now);
      expect(b.mana, lessThan(400 * 5));
    });
  });

  // -------------------------------------------------------------------
  group('the house economy', () {
    test('rent accrues per resident per hour and is capped', () async {
      var now = DateTime(2026, 1, 1, 12);
      final g = await booted(clock: () => now);
      expect(g.rentDue, 0);

      now = now.add(const Duration(hours: 3));
      expect(g.rentDue, House.byId('faelen').rentPerHour * 3);

      now = now.add(const Duration(days: 2));
      expect(g.rentDue,
          House.byId('faelen').rentPerHour * House.rentCapHours);
    });

    test('collecting rent pays out and resets the clock', () async {
      var now = DateTime(2026, 1, 1, 12);
      final g = await booted(clock: () => now);
      now = now.add(const Duration(hours: 4));
      final got = g.collectRent();
      expect(got, House.byId('faelen').rentPerHour * 4);
      expect(g.gold, got);
      expect(g.rentDue, 0);
    });

    test('an odd job pays once, then holds until its cooldown expires',
        () async {
      var now = DateTime(2026, 1, 1, 12);
      final g = await booted(clock: () => now);
      expect(g.oddJobReady, isTrue);
      expect(g.workOddJob(), House.oddJobGold);
      expect(g.oddJobReady, isFalse);
      expect(g.workOddJob(), 0);

      now = now.add(House.oddJobCooldown);
      expect(g.oddJobReady, isTrue);
      expect(g.workOddJob(), House.oddJobGold);
    });

    test('a resident cannot move in before they have turned up', () async {
      final g = await booted();
      g.gold = 100000;
      // Dana needs 8 clears before she is even encountered.
      expect(g.settleResident('dana'), isNull);
      expect(g.settled.contains('dana'), isFalse);
    });

    test('a resident cannot move in without the gold for a room', () async {
      final g = await booted();
      g.clears = 20;
      g.gold = 10;
      g.settleResident('kess');
      expect(g.settled.contains('kess'), isFalse);
    });

    test('building a room costs the gold, settles them, and opens their route',
        () async {
      final g = await booted();
      g.clears = 20;
      g.gold = 5000;
      final beat = g.settleResident('kess');
      expect(g.settled, contains('kess'));
      expect(g.gold, 5000 - House.byId('kess').roomCost);
      expect(beat?.beatId, 'kess_b0_recruitment');
    });

    test('Dana moves in but never joins the fighting roster', () async {
      // docs/companion-routes.md: she "starts entirely outside the fight".
      final g = await booted();
      g.clears = 20;
      g.gold = 5000;
      g.settleResident('dana');
      expect(g.settled, contains('dana'));
      expect(g.roster.map((f) => f.id), isNot(contains('dana')));
    });
  });

  // -------------------------------------------------------------------
  group('gifts', () {
    test('reactions come from the route JSON, not a second copy of the table',
        () async {
      final g = await booted();
      final faelen = g.routes['faelen']!;
      expect(faelen.reactionTierFor('whetstone'), 'loved');
      expect(faelen.reactionTierFor('tactics_book'), 'liked');
      expect(faelen.reactionTierFor('luxury_item'), 'disliked');
      expect(faelen.reactionTierFor('street_food'), 'neutral');
    });

    test('a loved gift pays the bond the data model specifies', () async {
      final g = await booted();
      g.gold = 1000;
      final before = g.bondPoints('faelen');
      final bark = g.giveGift('faelen', Gifts.byId('whetstone'));
      expect(bark, isNotNull);
      expect(g.bondPoints('faelen') - before, giftBondDelta['loved']);
      expect(g.gold, 1000 - Gifts.byId('whetstone').goldCost);
    });

    test('a disliked gift costs gold and loses bond', () async {
      final g = await booted();
      g.gold = 1000;
      g.state.addBond('faelen', 100);
      final before = g.bondPoints('faelen');
      g.giveGift('faelen', Gifts.byId('luxury_item'));
      expect(g.bondPoints('faelen') - before, giftBondDelta['disliked']);
      expect(g.bondPoints('faelen'), lessThan(before));
    });

    test('a gift you cannot afford changes nothing at all', () async {
      final g = await booted();
      g.gold = 1;
      final before = g.bondPoints('faelen');
      expect(g.giveGift('faelen', Gifts.byId('star_map')), isNull);
      expect(g.gold, 1);
      expect(g.bondPoints('faelen'), before);
    });

    test('every shop item is somebody\'s loved, liked or disliked item',
        () async {
      // A shop full of items nobody has an opinion about would make gifting
      // a flat +2 tax rather than a read of the character.
      final g = await booted();
      for (final item in Gifts.shop) {
        final opinions = g.routes.values
            .map((r) => r.reactionTierFor(item.id))
            .where((t) => t != 'neutral');
        expect(opinions, isNotEmpty,
            reason: 'nobody in the cast has any opinion about "${item.id}"');
      }
    });

    test('a date costs gold and pays bond', () async {
      final g = await booted();
      g.gold = 1000;
      final before = g.bondPoints('faelen');
      expect(g.goOnDate('faelen'), isNotNull);
      expect(g.gold, 1000 - House.dateGoldCost);
      expect(g.bondPoints('faelen') - before, House.dateBondReward);
    });
  });

  // -------------------------------------------------------------------
  group('acts', () {
    test('Act 1 is where everyone starts', () async {
      final g = await booted();
      expect(g.act, 1);
      expect(g.nextActRequirement, isNotNull);
    });

    test('Act 2 needs both halves of the game, not just one', () {
      // Only raiding, no relationships:
      expect(
          Acts.actFor(settledCount: 5, completedBeats: 0, highestBondTier: 6),
          1);
      // Only relationships, an empty house:
      expect(
          Acts.actFor(settledCount: 1, completedBeats: 20, highestBondTier: 6),
          1);
      // Both:
      expect(
          Acts.actFor(settledCount: 3, completedBeats: 6, highestBondTier: 2),
          2);
    });

    test('Act 3 additionally needs a real relationship, not just volume', () {
      expect(
          Acts.actFor(settledCount: 4, completedBeats: 12, highestBondTier: 0),
          2);
      expect(
          Acts.actFor(settledCount: 4, completedBeats: 12, highestBondTier: 4),
          3);
    });

    test('the act never goes backwards once earned', () async {
      final g = await booted();
      g.settled.addAll(['kess', 'momo', 'thora']);
      for (var i = 0; i < 12; i++) {
        g.completeBeat('fake_beat_$i');
      }
      expect(g.act, greaterThanOrEqualTo(2));
      final reached = g.act;
      g.settled.removeAll(['kess', 'momo', 'thora']);
      g.completeBeat('one_more');
      expect(g.act, reached);
    });

    test('the UI can always say what the next act is waiting for', () {
      for (var settled = 1; settled <= 5; settled++) {
        for (final beats in [0, 5, 11, 30]) {
          final act = Acts.actFor(
              settledCount: settled,
              completedBeats: beats,
              highestBondTier: 3);
          final req = Acts.nextActRequirement(
              act: act,
              settledCount: settled,
              completedBeats: beats,
              highestBondTier: 3);
          if (act < Acts.maxAct) {
            expect(req, isNotNull,
                reason: 'act $act with $settled settled and $beats beats gave '
                    'the player no reason why they are stuck');
          }
        }
      }
    });
  });

  // -------------------------------------------------------------------
  group('a locked beat is not a finished route', () {
    test('a fresh companion has six beats ahead of her, not zero', () async {
      // The bug this guards: `nextAvailableBeat` returns null both when a
      // route is genuinely done and when the next beat is merely locked, so
      // a panel reading it directly told the player "her route is finished"
      // one scene into a seven-beat route.
      final g = await booted();
      g.completeBeat('faelen_b0_recruitment');

      expect(g.nextBeat('faelen'), isNull,
          reason: 'beat 1 needs bond tier 1, which a new game has not reached');
      expect(g.routeComplete('faelen'), isFalse);
      expect(g.upcomingBeat('faelen')?.beatId, 'faelen_b1_the_wall');
    });

    test('the lock reason names what is actually missing', () async {
      final g = await booted();
      g.completeBeat('faelen_b0_recruitment');
      final reason = g.lockReason('faelen');
      expect(reason, isNotNull);
      expect(reason, contains('bond tier 1'));
      expect(reason, contains('60 more'),
          reason: 'tier 1 starts at 60 points and she has none');
    });

    test('there is no lock reason once the beat is actually playable',
        () async {
      final g = await booted();
      g.completeBeat('faelen_b0_recruitment');
      g.state.addBond('faelen', 60);
      expect(g.nextBeat('faelen')?.beatId, 'faelen_b1_the_wall');
      expect(g.lockReason('faelen'), isNull);
    });

    test('a route only reads as finished when every beat is played', () async {
      final g = await booted();
      final route = g.routes['faelen']!;
      for (final beat in route.beats) {
        expect(g.routeComplete('faelen'), isFalse);
        g.completeBeat(beat.beatId);
      }
      expect(g.routeComplete('faelen'), isTrue);
      expect(g.upcomingBeat('faelen'), isNull);
    });
  });

  // -------------------------------------------------------------------
  group('endings', () {
    test('every ending id in every route has written prose', () async {
      // A route that resolves to an id with no text would print the
      // "unresolved" fallback at the emotional climax of a playthrough.
      final routes = await CompanionRoutes.loadAll();
      for (final route in routes.values) {
        for (final ending in route.endings) {
          expect(Endings.text.containsKey(ending.endingId), isTrue,
              reason: 'no epilogue written for "${ending.endingId}"');
          expect(Endings.text[ending.endingId]!.length, greaterThan(60));
        }
      }
    });

    test('ending priority still runs specific before generic', () async {
      // Finding #6 in docs/HANDOFF.md, re-asserted now that a screen
      // actually prints the result: a bond-threshold "bittersweet" fallback
      // must never outrank a flag-specific "lost".
      final routes = await CompanionRoutes.loadAll();
      for (final route in routes.values) {
        final byId = {for (final e in route.endings) e.endingId: e};
        final lost = byId['${route.characterId}_lost'];
        final bitter = byId['${route.characterId}_bittersweet'];
        if (lost != null && bitter != null) {
          expect(lost.priority, lessThan(bitter.priority),
              reason: '${route.characterId}: the generic bittersweet fallback '
                  'would swallow the specific lost ending');
        }
      }
    });

    test('the gates answer is recorded as a flag and gates the finale',
        () async {
      final g = await booted();
      expect(g.gateAnswer, isNull);
      expect(g.finaleAvailable, isFalse);

      g.answerTheGates(GateAnswer.live);
      expect(g.state.flags[GateAnswerX.flagKey], 'live');
      expect(g.gateAnswer, GateAnswer.live);
      // Still not available: the finale needs Act 3 too.
      expect(g.finaleAvailable, isFalse);

      g.state.storyAct = 3;
      expect(g.finaleAvailable, isTrue);
    });

    test('every gates answer has both a pitch and an epilogue', () {
      for (final a in GateAnswer.values) {
        expect(a.label, isNotEmpty);
        expect(a.pitch.length, greaterThan(60));
        expect(a.epilogue.length, greaterThan(60));
      }
    });

    test('a played-out route resolves to the ending its flags earned',
        () async {
      final g = await booted();
      g.state.addBond('faelen', 1000); // tier 6
      g.state.flags['FAELEN_FRACTURE'] = 'join';
      g.state.flags['FAELEN_CONFESSED'] = true;
      final endings = g.resolveEndings();
      expect(endings['faelen']?.endingId, 'faelen_true');

      g.state.flags['FAELEN_FRACTURE'] = 'release';
      g.state.flags.remove('FAELEN_CONFESSED');
      expect(g.resolveEndings()['faelen']?.endingId, 'faelen_lost');
    });
  });

  // -------------------------------------------------------------------
  group('playing a scene', () {
    test('a linear scene walks to its end and can be completed', () async {
      final g = await booted();
      final beat = g.routes['faelen']!.beats.first;
      final scene = await CompanionRoutes.loadScene(beat.sceneRef);
      final engine = DialogueEngine(
          scene: scene, state: g.state, characterId: 'faelen');

      var guard = 0;
      while (!engine.isEnd && guard++ < 50) {
        expect(engine.currentNode.isBranch, isFalse);
        engine.advance();
      }
      expect(engine.isEnd, isTrue);

      g.completeBeat(beat.beatId);
      expect(g.state.completedBeats, contains(beat.beatId));
      // The next beat is now a different one — the route moved.
      expect(g.nextBeat('faelen')?.beatId, isNot(beat.beatId));
    });

    test('a choice applies its flags and bond to the same state the UI reads',
        () async {
      // The Fracture is the ending engine; this is the exact path the
      // dialogue screen drives when a player picks one of its three options.
      final g = await booted();
      final beat = g.routes['faelen']!.beats
          .firstWhere((b) => b.beatId == 'faelen_b4_the_fracture');
      final scene = await CompanionRoutes.loadScene(beat.sceneRef);
      final engine = DialogueEngine(
          scene: scene, state: g.state, characterId: 'faelen');

      expect(engine.currentNode.isBranch, isTrue);
      final choices = engine.visibleChoices();
      expect(choices.map((c) => c.choiceId),
          containsAll(['stop', 'join', 'release']));

      final before = g.bondPoints('faelen');
      engine.choose('release');
      expect(g.state.flags['FAELEN_FRACTURE'], 'release');
      expect(g.bondPoints('faelen'), lessThan(before));
      expect(engine.isEnd, isTrue);
    });

    test('every route\'s Fracture offers the same three-way grammar',
        () async {
      // docs/companion-routes.md: "Beat 4 is always the ending engine […]
      // Keep that consistent — players learn the grammar and feel the
      // weight." The shape is what a player learns: two ways to hold on and
      // one to let go. The middle id is allowed to be character-specific —
      // Dana's is "stand" ("stand with her against the order"), because her
      // route is the deliberate foil — so this asserts the shape and the
      // wiring rather than three literal strings.
      final g = await booted();
      for (final route in g.routes.values) {
        final id = route.characterId;
        final beat = route.beats.firstWhere((b) => b.order == 4);
        final scene = await CompanionRoutes.loadScene(beat.sceneRef);
        final start = scene.nodes[scene.startNode]!;

        final ids = start.choices.map((c) => c.choiceId).toList();
        expect(ids, hasLength(3), reason: '$id: the Fracture is a 3-way');
        expect(ids, containsAll(['stop', 'release']),
            reason: '$id: every Fracture keeps "stop" and "release"');

        final flagKey = '${id.toUpperCase()}_FRACTURE';
        for (final c in start.choices) {
          expect(c.effects.setFlags[flagKey], c.choiceId,
              reason: '$id: choice "${c.choiceId}" must write $flagKey');
        }
        expect(
            start.choices
                .firstWhere((c) => c.choiceId == 'release')
                .effects
                .bondDelta,
            lessThan(0),
            reason: '$id: letting them go should cost bond');

        // The third, committed option must be what the true ending reads.
        final committed = ids.firstWhere((c) => c != 'stop' && c != 'release');
        final trueEnding =
            route.endings.firstWhere((e) => e.endingId == '${id}_true');
        final req = trueEnding.conditions.requiresFlags
            .firstWhere((f) => f.flag == flagKey);
        expect(req.oneOf, containsAll(['stop', committed]),
            reason: '$id: the true ending ignores its own Fracture options');
      }
    });
  });

  // -------------------------------------------------------------------
  group('the mirrored route data', () {
    test('gatefall_flame/data matches the dialogue engine\'s canonical copy',
        () {
      // docs/HANDOFF.md caveat: "gatefall_flame/data/ is a manual mirror […]
      // nothing keeps the two in sync automatically." This test is the
      // something. It fails loudly the first time the two drift.
      final canonical = Directory('../gatefall_dialogue_engine/data');
      if (!canonical.existsSync()) return; // engine not checked out alongside

      final files = canonical
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'));
      expect(files, isNotEmpty);

      for (final source in files) {
        final relative =
            source.path.split('gatefall_dialogue_engine/data/').last;
        final mirror = File('data/$relative');
        expect(mirror.existsSync(), isTrue,
            reason: 'data/$relative is missing from the Flutter mirror');
        expect(
          jsonDecode(mirror.readAsStringSync()),
          jsonDecode(source.readAsStringSync()),
          reason: 'data/$relative has drifted from the canonical copy in '
              'gatefall_dialogue_engine — re-copy it',
        );
      }
    });
  });
}
