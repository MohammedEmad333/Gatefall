import '../combat/battle.dart';

enum BattleRow { front, back }

/// Step-2 roster. Five characters, choose 4.
class Roster {
  static final all = <FighterDef>[
    FighterDef(id: 'player', name: 'You', role: 'Awakened',
        maxHp: 950, attack: 17, attackSpeed: 1.00, melee: true, locked: true),
    FighterDef(id: 'faelen', name: 'Faelen', role: 'Warden',
        maxHp: 1500, attack: 14, attackSpeed: 0.85, melee: true),
    FighterDef(id: 'kess', name: 'Kess', role: 'Striker',
        maxHp: 780, attack: 22, attackSpeed: 1.30, melee: true),
    FighterDef(id: 'momo', name: 'Momo', role: 'Caster',
        maxHp: 700, attack: 16, attackSpeed: 0.80, melee: false),
    FighterDef(id: 'thora', name: 'Thora', role: 'Mender',
        maxHp: 1700, attack: 10, attackSpeed: 0.70, melee: true),
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
    AbilityDef(id: 'strike', name: 'Sever', ownerId: 'player',
        kind: AbilityKind.damage, power: 46, cooldown: 4.5),
    // Guard is a TAUNT, not a self-shield. With row-weighted targeting a
    // self-only shield protects nobody; pulling damage onto Faelen is both
    // the mechanical fix and exactly her character — she stands in front.
    AbilityDef(id: 'guard', name: 'Guard', ownerId: 'faelen',
        kind: AbilityKind.taunt, power: 200, cooldown: 9.0, duration: 4.0),
    AbilityDef(id: 'oath', name: 'Oath', ownerId: 'faelen',
        kind: AbilityKind.ultimate, power: 190, cooldown: 22.0),
    AbilityDef(id: 'dash', name: 'Dash', ownerId: 'kess',
        kind: AbilityKind.damage, power: 70, cooldown: 6.0),
    AbilityDef(id: 'bolt', name: 'Bolt', ownerId: 'momo',
        kind: AbilityKind.damage, power: 85, cooldown: 7.0),
    AbilityDef(id: 'mend', name: 'Mend', ownerId: 'thora',
        kind: AbilityKind.heal, power: 150, cooldown: 7.0),
  ];

  /// Only abilities whose owner is actually deployed.
  static List<Ability> abilitiesFor(Iterable<String> deployedIds) => abilities
      .where((a) => deployedIds.contains(a.ownerId))
      .map((d) => d.instantiate())
      .toList();

  static List<Fighter> partyFrom(Map<String, BattleRow> formation) => formation.entries
      .map((e) => byId(e.key).instantiate(e.value))
      .toList();
}

class FighterDef {
  final String id, name, role;
  final double maxHp, attack, attackSpeed;
  final bool melee, locked;

  FighterDef({
    required this.id,
    required this.name,
    required this.role,
    required this.maxHp,
    required this.attack,
    required this.attackSpeed,
    required this.melee,
    this.locked = false,
  });

  Fighter instantiate(BattleRow row) => Fighter(
        id: id, name: name, role: role, maxHp: maxHp,
        attack: attack, attackSpeed: attackSpeed, melee: melee, row: row,
      );
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

  Ability instantiate() => Ability(
        id: id, name: name, ownerId: ownerId, kind: kind,
        power: power, cooldown: cooldown, duration: duration,
      );
}
