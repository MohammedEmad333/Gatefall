// Balance regression tests. These encode the step-2 tuning decisions so a
// future stat tweak can't silently break raid pacing or composition freedom.
//
// Run: dart test

import 'dart:math';

import 'package:test/test.dart';

import '../lib/combat/battle.dart';
import '../lib/data/roster.dart';

({bool won, double seconds}) _run(Map<String, BattleRow> formation, int seed,
    {double cap = 2400}) {
  final b = Battle.fromFormation(formation, rng: Random(seed));
  b.start();
  const dt = 0.1;
  while (b.status == BattleStatus.fighting && b.elapsed < cap) {
    b.tick(dt);
  }
  return (won: b.status == BattleStatus.won, seconds: b.elapsed);
}

double _winRate(Map<String, BattleRow> formation, {int trials = 60}) {
  var wins = 0;
  for (var i = 0; i < trials; i++) {
    if (_run(formation, i).won) wins++;
  }
  return wins / trials;
}

double _avgWinSeconds(Map<String, BattleRow> formation, {int trials = 40}) {
  final times = <double>[];
  for (var i = 0; i < trials; i++) {
    final r = _run(formation, 500 + i);
    if (r.won) times.add(r.seconds);
  }
  if (times.isEmpty) return 0;
  return times.reduce((a, b) => a + b) / times.length;
}

// Compositions used across the suite.
const _kessFront = {
  'player': BattleRow.front, 'faelen': BattleRow.front, 'kess': BattleRow.front, 'momo': BattleRow.back,
};
const _kessBack = {
  'player': BattleRow.front, 'faelen': BattleRow.front, 'kess': BattleRow.back, 'momo': BattleRow.back,
};
const _withHealer = {
  'player': BattleRow.front, 'faelen': BattleRow.front, 'thora': BattleRow.front, 'momo': BattleRow.back,
};
const _noTank = {
  'player': BattleRow.front, 'kess': BattleRow.front, 'momo': BattleRow.back, 'thora': BattleRow.front,
};
const _shortParty = {
  'player': BattleRow.front, 'faelen': BattleRow.front, 'momo': BattleRow.back,
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
            reason: '${entry.key} should be viable — no composition is mandatory');
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
}
