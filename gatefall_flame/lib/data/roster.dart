import '../combat/battle.dart';
import 'progression.dart';

enum BattleRow { front, back }

/// Step-2 roster. Five characters, choose 4.
///
/// Elements are locked per docs/combat-spec.md §3. The player is human, same
/// as Dana — both get Sever, the neutral element outside the wheel, which is
/// exactly what a reliable non-companion pick should be.
class Roster {
  static final all = <FighterDef>[
    FighterDef(
        id: 'player',
        name: 'You',
        role: 'Awakened',
        maxHp: 950,
        attack: 17,
        attackSpeed: 1.00,
        melee: true,
        locked: true,
        element: GateElement.sever),
    FighterDef(
        id: 'faelen',
        name: 'Faelen',
        role: 'Warden',
        maxHp: 1500,
        attack: 14,
        attackSpeed: 0.85,
        melee: true,
        element: GateElement.verdant),
    FighterDef(
        id: 'kess',
        name: 'Kess',
        role: 'Striker',
        maxHp: 780,
        attack: 22,
        attackSpeed: 1.30,
        melee: true,
        element: GateElement.ember),
    FighterDef(
        id: 'momo',
        name: 'Momo',
        role: 'Caster',
        maxHp: 700,
        attack: 16,
        attackSpeed: 0.80,
        melee: false,
        element: GateElement.gloam),
    FighterDef(
        id: 'thora',
        name: 'Thora',
        role: 'Mender',
        maxHp: 1700,
        attack: 10,
        attackSpeed: 0.70,
        melee: true,
        element: GateElement.stone),
  ];

  static FighterDef byId(String id) => all.firstWhere((f) => f.id == id);

  /// Default formation is a full party of 4 on purpose — a 3-member party
  /// loses ~100% of the time (see CombatConfig).
  static Map<String, BattleRow> defaultFormation() => {
        'player': BattleRow.front,
        'faelen': BattleRow.front,
        'kess': BattleRow.back,
        'momo': BattleRow.back,
      };

  static final abilities = <AbilityDef>[
    AbilityDef(
        id: 'strike',
        name: 'Sever',
        ownerId: 'player',
        kind: AbilityKind.damage,
        power: 46,
        cooldown: 4.5),
    // Guard is a TAUNT, not a self-shield. With row-weighted targeting a
    // self-only shield protects nobody; pulling damage onto Faelen is both
    // the mechanical fix and exactly her character — she stands in front.
    AbilityDef(
        id: 'guard',
        name: 'Guard',
        ownerId: 'faelen',
        kind: AbilityKind.taunt,
        power: 200,
        cooldown: 9.0,
        duration: 4.0),
    AbilityDef(
        id: 'oath',
        name: 'Oath',
        ownerId: 'faelen',
        kind: AbilityKind.ultimate,
        power: 190,
        cooldown: 22.0),
    AbilityDef(
        id: 'dash',
        name: 'Dash',
        ownerId: 'kess',
        kind: AbilityKind.damage,
        power: 70,
        cooldown: 6.0),
    AbilityDef(
        id: 'bolt',
        name: 'Bolt',
        ownerId: 'momo',
        kind: AbilityKind.damage,
        power: 85,
        cooldown: 7.0),
    AbilityDef(
        id: 'mend',
        name: 'Mend',
        ownerId: 'thora',
        kind: AbilityKind.heal,
        power: 150,
        cooldown: 7.0),
  ];

  /// Only abilities whose owner is actually deployed. [levels] scales each
  /// ability's power with its owner's companion level (step 4); [gear]
  /// stacks a further multiplier from their equipped item (step 5).
  static List<Ability> abilitiesFor(Iterable<String> deployedIds,
          {Map<String, int> levels = const {},
          Map<String, Gear?> gear = const {}}) =>
      abilities
          .where((a) => deployedIds.contains(a.ownerId))
          .map((d) => d.instantiate(
              level: levels[d.ownerId] ?? Progression.minLevel,
              gear: gear[d.ownerId]))
          .toList();

  static List<Fighter> partyFrom(Map<String, BattleRow> formation,
          {Map<String, int> levels = const {},
          Map<String, Gear?> gear = const {}}) =>
      formation.entries
          .map((e) => byId(e.key).instantiate(e.value,
              level: levels[e.key] ?? Progression.minLevel, gear: gear[e.key]))
          .toList();
}

class FighterDef {
  final String id, name, role;
  final double maxHp, attack, attackSpeed;
  final bool melee, locked;
  final GateElement element;

  FighterDef({
    required this.id,
    required this.name,
    required this.role,
    required this.maxHp,
    required this.attack,
    required this.attackSpeed,
    required this.melee,
    required this.element,
    this.locked = false,
  });

  Fighter instantiate(BattleRow row,
      {int level = Progression.minLevel, Gear? gear}) {
    final mult =
        Progression.statMultiplier(level) * (gear?.statMultiplier ?? 1.0);
    return Fighter(
      id: id,
      name: name,
      role: role,
      maxHp: maxHp * mult,
      attack: attack * mult,
      attackSpeed: attackSpeed,
      melee: melee,
      element: element,
      row: row,
      level: level,
    );
  }
}

class AbilityDef {
  final String id, name, ownerId;
  final AbilityKind kind;
  final double power, cooldown, duration;

  AbilityDef({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.kind,
    required this.power,
    required this.cooldown,
    this.duration = 0,
  });

  Ability instantiate({int level = Progression.minLevel, Gear? gear}) =>
      Ability(
        id: id,
        name: name,
        ownerId: ownerId,
        kind: kind,
        power: power *
            Progression.statMultiplier(level) *
            (gear?.statMultiplier ?? 1.0),
        cooldown: cooldown,
        duration: duration,
      );
}
