import 'dart:math';

import 'package:gatefall/combat/battle.dart';
import 'package:gatefall/data/roster.dart';
import 'package:test/test.dart';

void main() {
  test('routine auto-attack emits a hidden actor presentation event', () {
    final kess = Fighter(
      id: 'kess',
      name: 'Kess',
      role: 'Rogue',
      maxHp: 1000,
      attack: 100,
      attackSpeed: 100,
      melee: true,
      element: GateElement.ember,
      row: BattleRow.front,
    );

    final battle = Battle(
      party: [kess],
      abilities: const [],
      rng: Random(1),
    )..start();

    battle.tick(0.1);

    final attack = battle.events.lastWhere((e) => e.kind == 'attack');
    expect(attack.actorId, 'kess');
    expect(attack.loggable, isFalse);
    expect(attack.amount, greaterThan(0));
  });

  test('battle events remain loggable by default', () {
    final event = BattleEvent('visible', 'damage', actorId: 'kess');
    expect(event.loggable, isTrue);
  });
}
