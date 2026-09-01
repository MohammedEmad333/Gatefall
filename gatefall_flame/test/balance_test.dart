// Balance regression tests. These encode the step-2 tuning decisions so a
// future stat tweak can't silently break raid pacing or composition freedom.
//
// Run: dart test

import 'dart:math';

import 'package:test/test.dart';

import '../lib/combat/battle.dart';
import '../lib/data/progression.dart';
import '../lib/data/roster.dart';

({bool won, double seconds}) _run(Map<String, BattleRow> formation, int seed,
    {double cap = 2400,
    GateElement gateElement = GateElement.verdant,
    Map<String, int> levels = const {}}) {
  final b = Battle.fromFormation(formation,
      gateElement: gateElement, levels: levels, rng: Random(seed));
  b.start();
  const dt = 0.1;
  while (b.status == BattleStatus.fighting && b.elapsed < cap) {
    b.tick(dt);
  }
  return (won: b.status == BattleStatus.won, seconds: b.elapsed);
}

double _winRate(Map<String, BattleRow> formation,
    {int trials = 60,
    GateElement gateElement = GateElement.verdant,
    Map<String, int> levels = const {}}) {
  var wins = 0;
  for (var i = 0; i < trials; i++) {
    if (_run(formation, i, gateElement: gateElement, levels: levels).won) {
      wins++;
    }
  }
  return wins / trials;
}

double _avgWinSeconds(Map<String, BattleRow> formation,
    {int trials = 40,
    GateElement gateElement = GateElement.verdant,
    Map<String, int> levels = const {}}) {
  final times = <double>[];
  for (var i = 0; i < trials; i++) {
    final r =
        _run(formation, 500 + i, gateElement: gateElement, levels: levels);
    if (r.won) times.add(r.seconds);
  }
  if (times.isEmpty) return 0;
  return times.reduce((a, b) => a + b) / times.length;
}

// Compositions used across the suite.
const _kessFront = {
  'player': BattleRow.front,
  'faelen': BattleRow.front,
  'kess': BattleRow.front,
  'momo': BattleRow.back,
};
const _kessBack = {
  'player': BattleRow.front,
  'faelen': BattleRow.front,
  'kess': BattleRow.back,
  'momo': BattleRow.back,
};
const _withHealer = {
  'player': BattleRow.front,
  'faelen': BattleRow.front,
  'thora': BattleRow.front,
  'momo': BattleRow.back,
};
const _noTank = {
  'player': BattleRow.front,
  'kess': BattleRow.front,
  'momo': BattleRow.back,
  'thora': BattleRow.front,
};
const _shortParty = {
  'player': BattleRow.front,
  'faelen': BattleRow.front,
  'momo': BattleRow.back,
};

void main() {
  group('composition freedom', () {
    test('every full 4-party composition can clear the gate', () {
      for (final entry in {
        'kess front': _kessFront,
        'kess back': _kessBack,
        'with healer': _withHealer,
        'no tank': _noTank,
      }.entries) {
        expect(_winRate(entry.value), greaterThan(0.85),
            reason:
                '${entry.key} should be viable — no composition is mandatory');
      }
    });

    test('the default formation is one of the viable ones', () {
      expect(_winRate(Roster.defaultFormation()), greaterThan(0.85));
    });

    test('compositions trade speed against safety', () {
      // Fast-and-fragile should finish meaningfully sooner than
      // slow-and-safe. If this collapses, formation stops being a decision.
      final fast = _avgWinSeconds(_kessFront);
      final safe = _avgWinSeconds(_withHealer);
      expect(fast, greaterThan(0));
      expect(safe, greaterThan(0));
      expect(fast, lessThan(safe),
          reason: 'the risk/speed tradeoff is the point of the row system');
    });
  });

  group('raid pacing', () {
    test('winning raids land inside the 5-10 minute design target', () {
      final avg = _avgWinSeconds(_kessBack);
      expect(avg, greaterThan(240));
      expect(avg, lessThan(600));
    });
  });

  group('design invariants', () {
    test('an understrength party is a real penalty, not the default', () {
      // 3 members loses ~always. That's intended — but it must never be
      // what a new player starts with.
      expect(_winRate(_shortParty), lessThan(0.25));
      expect(Roster.defaultFormation().length, equals(4));
    });

    test('losing still banks the mana earned (no failure penalty)', () {
      final b = Battle.fromFormation(_shortParty, rng: Random(3));
      b.start();
      while (b.status == BattleStatus.fighting && b.elapsed < 2400) {
        b.tick(0.1);
      }
      if (b.status == BattleStatus.lost) {
        expect(b.manaEarned, greaterThan(0),
            reason: 'a failed raid must still keep what was earned');
      }
    });

    test('boss enrage actually ramps incoming damage', () {
      final b = Battle.fromFormation(_withHealer, rng: Random(9));
      b.start();
      while (b.status == BattleStatus.fighting && !b.onBoss) {
        b.tick(0.1);
      }
      expect(b.onBoss, isTrue);
      final early = b.incomingDps;
      for (var i = 0; i < 400; i++) {
        if (b.status != BattleStatus.fighting) break;
        b.tick(0.1);
      }
      if (b.onBoss && b.status == BattleStatus.fighting) {
        expect(b.incomingDps, greaterThan(early),
            reason: 'the ramp is what makes the boss tunable at all');
      }
    });

    test('Guard taunt redirects damage onto Faelen', () {
      final b = Battle.fromFormation(_kessBack, rng: Random(4));
      b.start();
      b.autoCast = false;
      final faelen = b.party.firstWhere((p) => p.id == 'faelen');
      expect(b.castAbility('guard'), isTrue);
      expect(faelen.isTaunting, isTrue,
          reason: 'Guard must pull aggro — a self-only shield sustains nobody '
              'once damage spreads across rows');
    });

    test('auto mode is viable alone — manual is optimization, not a gate', () {
      expect(_winRate(_kessBack), greaterThan(0.85),
          reason: 'idle players must never be forced into manual play');
    });
  });

  group('elements (step 3)', () {
    test('the matchup wheel cycles Verdant -> Stone -> Ember -> Gloam -> Tide',
        () {
      expect(elementMultiplier(GateElement.verdant, GateElement.stone),
          equals(advantageMult));
      expect(elementMultiplier(GateElement.stone, GateElement.ember),
          equals(advantageMult));
      expect(elementMultiplier(GateElement.ember, GateElement.gloam),
          equals(advantageMult));
      expect(elementMultiplier(GateElement.gloam, GateElement.tide),
          equals(advantageMult));
      expect(elementMultiplier(GateElement.tide, GateElement.verdant),
          equals(advantageMult));
    });

    test('the disadvantaged side of each matchup takes -30%, not +30%', () {
      expect(elementMultiplier(GateElement.stone, GateElement.verdant),
          equals(disadvantageMult));
      expect(elementMultiplier(GateElement.ember, GateElement.stone),
          equals(disadvantageMult));
    });

    test('Sever never gets a bonus or a penalty on either side', () {
      for (final e in GateElement.values) {
        expect(elementMultiplier(GateElement.sever, e), equals(1.0),
            reason: 'human mana is unrefined — Sever sits outside the wheel');
        expect(elementMultiplier(e, GateElement.sever), equals(1.0));
      }
    });

    test('same element on both sides is neutral, not a mirror match bonus', () {
      for (final e in GateElement.values) {
        expect(elementMultiplier(e, e), equals(1.0));
      }
    });

    test(
        'with 4 of 5 wheel elements represented, no single gate can '
        'disadvantage the whole deployed roster at once', () {
      // Structural property of a 5-element cycle: each element only beats
      // one other, so a party missing just one element (here: Tide, which
      // has no character yet) can never be fully walled. This is what makes
      // "bring one advantaged and one neutral character" a real hedge
      // rather than a coin flip.
      final deployed = [
        GateElement.verdant,
        GateElement.ember,
        GateElement.gloam,
        GateElement.stone
      ];
      for (final gateEl in GateElement.values) {
        final allDisadvantaged = deployed.every(
            (attacker) => matchupOf(attacker, gateEl) == Matchup.disadvantage);
        expect(allDisadvantaged, isFalse,
            reason:
                '$gateEl must never wall out every deployed element at once');
      }
    });

    test('a single disadvantaged character slows a raid, never walls it', () {
      // Momo (Gloam) is disadvantaged against an Ember gate — the worst
      // single-character hit available to this roster. It must still be
      // clearly winnable, just slower than the neutral fight.
      final disadvantaged =
          _winRate(_kessFront, gateElement: GateElement.ember, trials: 120);
      expect(disadvantaged, greaterThan(0.85),
          reason: 'docs/combat-spec.md §3: disadvantage should mean "takes '
              'noticeably longer," never "impossible"');

      final neutralTime =
          _avgWinSeconds(_kessFront, gateElement: GateElement.verdant);
      final disadvantagedTime = _avgWinSeconds(_kessFront,
          gateElement: GateElement.ember, trials: 80);
      expect(disadvantagedTime, greaterThan(neutralTime),
          reason:
              'the elemental penalty should be felt as pace, not as a coin flip');
    });

    test('an advantaged character does not trivially break pacing', () {
      // Thora (Stone) is advantaged against an Ember gate.
      final advantaged = _winRate(_withHealer, gateElement: GateElement.ember);
      expect(advantaged, greaterThan(0.85));
    });

    test('every step-2 composition still clears at full element neutrality',
        () {
      // Elements must not have regressed the pre-step-3 tuning for a gate
      // that advantages nobody and disadvantages nobody in these comps.
      for (final entry in {
        'kess front': _kessFront,
        'kess back': _kessBack,
        'with healer': _withHealer,
        'no tank': _noTank,
      }.entries) {
        expect(_winRate(entry.value, gateElement: GateElement.verdant),
            greaterThan(0.85),
            reason: '${entry.key} regressed under the default gate element');
      }
    });
  });

  group('progression (step 4)', () {
    test('level 1 has no bonus — the multiplier is neutral at the floor', () {
      expect(Progression.statMultiplier(Progression.minLevel), equals(1.0));
    });

    test('leveling is a real Mana sink with rising cost, and eventually caps',
        () {
      var prevCost = Progression.costFor(Progression.minLevel);
      expect(prevCost, greaterThan(0));
      for (var lvl = Progression.minLevel + 1;
          lvl < Progression.maxLevel;
          lvl++) {
        final cost = Progression.costFor(lvl);
        expect(cost, greaterThan(prevCost),
            reason: 'each level should cost more than the last');
        prevCost = cost;
      }
      expect(Progression.costFor(Progression.maxLevel), equals(-1),
          reason: 'a maxed companion has nothing left to buy');
    });

    test(
        'a leveled party clears faster than an unleveled one, not just '
        'more reliably', () {
      final maxLevels = {
        for (final f in ['player', 'faelen', 'kess', 'momo', 'thora']) f: 10,
      };
      final baseline = _avgWinSeconds(_kessBack);
      final leveled = _avgWinSeconds(_kessBack, levels: maxLevels);
      expect(leveled, lessThan(baseline),
          reason:
              'docs/combat-spec.md §6: companion level is "the main Mana sink" '
              '— it should visibly pay off in pace');
    });

    test(
        'an unleveled party is still fully viable — leveling is a speed '
        'bonus, never a gate requirement', () {
      expect(_winRate(Roster.defaultFormation()), greaterThan(0.85),
          reason: 'the default formation at level 1 must clear on its own, '
              'same as before companion leveling existed');
    });
  });
}
