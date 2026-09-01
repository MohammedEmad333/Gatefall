import 'dart:math';

import '../data/combat_config.dart';
import '../data/element.dart';
import '../data/gear.dart';
import '../data/roster.dart';

export '../data/element.dart';
export '../data/gear.dart';

/// Pure combat simulation — no Flame, no Flutter, no rendering.
/// Kept separate so balance can be unit-tested in milliseconds, and so the
/// same model can later drive offline-progress calculations.

enum AbilityKind { damage, ultimate, taunt, heal }

class Ability {
  final String id;
  final String name;
  final String ownerId;
  final AbilityKind kind;
  final double power;
  final double cooldown; // seconds
  final double duration; // taunt only

  double remaining = 0;

  Ability({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.kind,
    required this.power,
    required this.cooldown,
    this.duration = 0,
  });

  bool get ready => remaining <= 0;
}

class Fighter {
  final String id;
  final String name;
  final String role;
  final double maxHp;
  final double attack;
  final double attackSpeed; // attacks per second
  final bool melee;
  final GateElement element;
  final BattleRow row;
  final int level;

  double hp;
  double shield = 0;
  double taunt = 0; // seconds remaining of drawing fire
  bool alive = true;

  Fighter({
    required this.id,
    required this.name,
    required this.role,
    required this.maxHp,
    required this.attack,
    required this.attackSpeed,
    required this.melee,
    required this.element,
    required this.row,
    this.level = 1,
  }) : hp = maxHp;

  double get hpFraction => (hp / maxHp).clamp(0, 1);
  bool get isTaunting => alive && taunt > 0;
}

class Enemy {
  final String name;
  final double maxHp;
  final double baseDps;
  final bool isBoss;
  final GateElement element;
  double hp;

  Enemy({
    required this.name,
    required this.maxHp,
    required this.baseDps,
    required this.element,
    this.isBoss = false,
  }) : hp = maxHp;

  double get hpFraction => (hp / maxHp).clamp(0, 1);
}

enum BattleStatus { idle, fighting, won, lost }

class BattleEvent {
  final String message;
  final String kind; // damage | crit | ultimate | hurt | reward
  BattleEvent(this.message, this.kind);
}

class Battle {
  final Random _rng;
  final List<Fighter> party;
  final List<Ability> abilities;

  /// The gate's element for this whole raid — every wave and the boss share
  /// it (see docs/combat-spec.md §3: "each [gate] shows its element").
  final GateElement gateElement;

  /// When true, abilities fire off cooldown automatically. Auto must stay
  /// fully viable — manual is an optimization, never a requirement.
  bool autoCast;

  BattleStatus status = BattleStatus.idle;
  int waveIndex = 0;
  bool onBoss = false;
  double elapsed = 0;
  double bossElapsed = 0;
  int manaEarned = 0;

  late Enemy enemy;
  final List<BattleEvent> events = [];

  Battle({
    required this.party,
    required this.abilities,
    this.gateElement = GateElement.verdant,
    this.autoCast = true,
    Random? rng,
  }) : _rng = rng ?? Random();

  factory Battle.fromFormation(Map<String, BattleRow> formation,
      {Map<String, int> levels = const {},
      Map<String, Gear?> gear = const {},
      GateElement gateElement = GateElement.verdant,
      Random? rng}) {
    return Battle(
      party: Roster.partyFrom(formation, levels: levels, gear: gear),
      abilities:
          Roster.abilitiesFor(formation.keys, levels: levels, gear: gear),
      gateElement: gateElement,
      rng: rng,
    );
  }

  void start() {
    status = BattleStatus.fighting;
    elapsed = 0;
    bossElapsed = 0;
    manaEarned = 0;
    waveIndex = 0;
    onBoss = false;
    for (final f in party) {
      f.hp = f.maxHp;
      f.shield = 0;
      f.taunt = 0;
      f.alive = true;
    }
    for (final a in abilities) {
      a.remaining = 0;
    }
    events.clear();
    _spawn();
  }

  static const _waveNames = [
    'Rift Stalker',
    'Gloam Hound',
    'Bramble Shade',
    'Verdant Husk',
    'Thornbound',
  ];

  void _spawn() {
    if (waveIndex >= CombatConfig.waves) {
      onBoss = true;
      bossElapsed = 0;
      enemy = Enemy(
        name: 'The Root That Walks',
        maxHp: CombatConfig.bossHp,
        baseDps: CombatConfig.bossDps,
        element: gateElement,
        isBoss: true,
      );
      _emit('The gate guardian stirs.', 'hurt');
    } else {
      final hp =
          CombatConfig.waveEnemyHp + CombatConfig.waveEnemyHpGrowth * waveIndex;
      enemy = Enemy(
        name: _waveNames[waveIndex % _waveNames.length],
        maxHp: hp,
        baseDps:
            CombatConfig.enemyDps + CombatConfig.enemyDpsGrowth * waveIndex,
        element: gateElement,
      );
    }
  }

  void _emit(String msg, String kind) {
    events.add(BattleEvent(msg, kind));
    if (events.length > 40) events.removeAt(0);
  }

  /// Current incoming damage per second, including the boss enrage ramp.
  double get incomingDps {
    if (!onBoss) return enemy.baseDps;
    return enemy.baseDps + CombatConfig.bossEnrage * bossElapsed;
  }

  /// Enrage shown to the player, so escalating danger reads as a mechanic
  /// rather than mysterious bad luck.
  int get enrageStacks => onBoss ? (bossElapsed / 20).floor() : 0;

  double _jitter(double lo, double hi) => lo + _rng.nextDouble() * (hi - lo);

  bool castAbility(String abilityId) {
    final a = abilities.firstWhere((x) => x.id == abilityId,
        orElse: () => throw ArgumentError('No ability "$abilityId"'));
    if (!a.ready || status != BattleStatus.fighting) return false;
    final owner = party.where((p) => p.id == a.ownerId).firstOrNull;
    if (owner == null || !owner.alive) return false;

    a.remaining = a.cooldown;

    switch (a.kind) {
      case AbilityKind.damage:
      case AbilityKind.ultimate:
        final crit = _rng.nextDouble() < CombatConfig.abilityCritChance;
        final dmg = a.power *
            (crit ? CombatConfig.abilityCritMult : 1.0) *
            elementMultiplier(owner.element, enemy.element) *
            _jitter(0.9, 1.1);
        enemy.hp -= dmg;
        _emit(
          a.kind == AbilityKind.ultimate
              ? '${owner.name} — ${a.name}! ${dmg.round()} damage'
              : '${owner.name} uses ${a.name}: ${dmg.round()}${crit ? " (critical)" : ""}',
          a.kind == AbilityKind.ultimate
              ? 'ultimate'
              : (crit ? 'crit' : 'damage'),
        );
        break;

      case AbilityKind.taunt:
        owner.shield += a.power;
        owner.taunt = a.duration;
        _emit(
            '${owner.name}: "Get behind me." '
                '(+${a.power.round()} shield, drawing fire)',
            'ultimate');
        break;

      case AbilityKind.heal:
        var healed = 0.0;
        for (final p in party) {
          if (!p.alive) continue;
          final before = p.hp;
          p.hp = min(p.maxHp, p.hp + a.power);
          healed += p.hp - before;
        }
        _emit('${owner.name} mends the party (${healed.round()} healed)',
            'ultimate');
        break;
    }
    return true;
  }

  /// A taunting ally soaks everything — this is what makes fragile front-row
  /// picks survivable at all. Otherwise targeting is weighted by row.
  Fighter _pickTarget(List<Fighter> living) {
    final taunter = living.where((p) => p.isTaunting).firstOrNull;
    if (taunter != null) return taunter;

    final weights = living
        .map((p) =>
            p.row == BattleRow.front ? CombatConfig.frontAggroWeight : 1.0)
        .toList();
    final total = weights.fold<double>(0, (a, b) => a + b);
    var r = _rng.nextDouble() * total;
    var acc = 0.0;
    for (var i = 0; i < living.length; i++) {
      acc += weights[i];
      if (r <= acc) return living[i];
    }
    return living.last;
  }

  /// Advance the simulation by [dt] seconds. Call from the Flame update loop
  /// (or twice per frame for 2x speed).
  void tick(double dt) {
    if (status != BattleStatus.fighting) return;
    elapsed += dt;
    if (onBoss) bossElapsed += dt;

    for (final p in party) {
      if (p.taunt > 0) p.taunt = max(0, p.taunt - dt);
    }
    for (final a in abilities) {
      if (a.remaining > 0) a.remaining = max(0, a.remaining - dt);
    }

    if (autoCast) {
      for (final a in abilities) {
        if (a.ready) {
          final owner = party.where((p) => p.id == a.ownerId).firstOrNull;
          if (owner != null && owner.alive) castAbility(a.id);
        }
      }
    }

    // Party auto-attacks.
    for (final p in party) {
      if (!p.alive) continue;
      if (_rng.nextDouble() < p.attackSpeed * dt) {
        final crit = _rng.nextDouble() < CombatConfig.allyCritChance;
        final rowMult = (p.melee && p.row == BattleRow.back)
            ? CombatConfig.backMeleePenalty
            : 1.0;
        final dmg = p.attack *
            rowMult *
            (crit ? CombatConfig.allyCritMult : 1.0) *
            elementMultiplier(p.element, enemy.element) *
            _jitter(0.85, 1.15);
        enemy.hp -= dmg;
        if (crit)
          _emit('${p.name} strikes for ${dmg.round()} (critical)', 'crit');
      }
    }

    // Enemy attacks.
    final living = party.where((p) => p.alive).toList();
    if (living.isNotEmpty) {
      final target = _pickTarget(living);
      var dmg = incomingDps * dt;
      if (target.row == BattleRow.back) dmg *= CombatConfig.backDamageTaken;
      if (target.shield > 0) {
        final absorbed = min(target.shield, dmg);
        target.shield -= absorbed;
        dmg -= absorbed;
      }
      target.hp -= dmg;
      if (target.hp <= 0) {
        target.hp = 0;
        target.alive = false;
        target.taunt = 0;
        _emit('${target.name} goes down', 'hurt');
      }
    }

    if (enemy.hp <= 0) {
      enemy.hp = 0;
      final gain = enemy.isBoss
          ? CombatConfig.bossMana
          : CombatConfig.waveManaBase + CombatConfig.waveManaGrowth * waveIndex;
      manaEarned += gain;

      if (enemy.isBoss) {
        status = BattleStatus.won;
        _emit('The rift closes. +$gain mana', 'reward');
        return;
      }

      _emit('${enemy.name} falls. +$gain mana', 'reward');

      // Between-wave recovery + revive. This is what keeps a poor formation
      // slower rather than unwinnable — no death spiral.
      for (final p in party) {
        if (p.alive) {
          p.hp = min(p.maxHp, p.hp + p.maxHp * CombatConfig.waveRecovery);
        } else {
          p.alive = true;
          p.hp = p.maxHp * CombatConfig.reviveAtWave;
          _emit('${p.name} gets back up', 'ultimate');
        }
      }

      waveIndex++;
      _spawn();
    }

    if (party.every((p) => !p.alive)) {
      status = BattleStatus.lost;
      // No penalty by design: mana earned is kept, the gate stays open.
      _emit('You withdraw through the tear. Mana kept: $manaEarned', 'hurt');
    }
  }
}

extension FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
