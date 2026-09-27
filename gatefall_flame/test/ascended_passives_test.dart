import 'dart:math';

import 'package:test/test.dart';

import 'package:gatefall/combat/battle.dart';
import 'package:gatefall/data/ascension.dart';
import 'package:gatefall/data/roster.dart';

void main() {
  group('ascended passives', () {
    test('every ascension documents an always-on passive', () {
      for (final ascension in Ascension.all) {
        expect(ascension.passive, isNotEmpty,
            reason: '${ascension.characterId} should explain its passive');
      }
    });

    test('Faelen shares Guard shield with living allies', () {
      final battle = Battle.fromFormation(
        {
          'player': BattleRow.front,
          'faelen': BattleRow.front,
        },
        ascended: {'faelen'},
        rng: Random(1),
      );
      battle.start();
      battle.autoCast = false;

      final player = battle.party.firstWhere((p) => p.id == 'player');
      final faelen = battle.party.firstWhere((p) => p.id == 'faelen');

      expect(battle.castAbility('guard'), isTrue);
      expect(faelen.shield, greaterThan(player.shield));
      expect(player.shield, closeTo(200 * Battle.faelenSharedGuard, 0.001));
      expect(
        battle.events.any((e) =>
            e.kind == 'passive' && e.message.contains('Oathbound passive')),
        isTrue,
      );
    });

    test('Kess begins each enemy with one team link banked', () {
      final battle = Battle.fromFormation(
        {
          'player': BattleRow.front,
          'kess': BattleRow.back,
        },
        ascended: {'kess'},
        rng: Random(2),
      );
      battle.start();
      battle.autoCast = false;

      expect(battle.linkStacks, Battle.kessOpeningLinks);
      expect(
        battle.events.any((e) =>
            e.kind == 'passive' && e.message.contains('Chainbreak passive')),
        isTrue,
      );
    });

    test('Momo sees the opening seconds of each enemy ahead', () {
      final battle = Battle.fromFormation(
        {
          'player': BattleRow.front,
          'momo': BattleRow.back,
        },
        ascended: {'momo'},
        rng: Random(3),
      );
      battle.start();
      battle.autoCast = false;

      expect(battle.warded, isTrue);
      expect(battle.wardRemaining, Battle.momoOpeningForesight);
      expect(
        battle.events.any((e) =>
            e.kind == 'passive' && e.message.contains('Foresight passive')),
        isTrue,
      );
    });

    test('Thora Mend leaves allies with a small reciprocal shield', () {
      final battle = Battle.fromFormation(
        {
          'player': BattleRow.front,
          'thora': BattleRow.front,
        },
        ascended: {'thora'},
        rng: Random(4),
      );
      battle.start();
      battle.autoCast = false;

      final player = battle.party.firstWhere((p) => p.id == 'player');
      expect(player.shield, 0);
      expect(battle.castAbility('mend'), isTrue);
      expect(player.shield, closeTo(150 * Battle.thoraMendShield, 0.001));
      expect(
        battle.events.any((e) =>
            e.kind == 'passive' && e.message.contains('Reciprocity passive')),
        isTrue,
      );
    });

    test('Dana prepares an opening shield for the whole party', () {
      final battle = Battle.fromFormation(
        {
          'player': BattleRow.front,
          'dana': BattleRow.back,
        },
        ascended: {'dana'},
        rng: Random(5),
      );
      battle.start();
      battle.autoCast = false;

      for (final fighter in battle.party) {
        expect(
          fighter.shield,
          closeTo(fighter.maxHp * Battle.danaOpeningShield, 0.001),
        );
      }
      expect(
        battle.events.any((e) =>
            e.kind == 'passive' && e.message.contains('Casework passive')),
        isTrue,
        reason: 'the opening passive event must survive battle.start()',
      );
    });
  });
}
