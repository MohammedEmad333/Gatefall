import 'dart:math';

import '../data/combat_config.dart';
import '../data/element.dart';
import '../data/gear.dart';
import '../data/roster.dart';

export '../data/bond.dart';
export '../data/element.dart';
export '../data/gear.dart';

/// Pure combat simulation — no Flame, no Flutter, no rendering.
/// Kept separate so balance can be unit-tested in milliseconds, and so the
/// same model can later drive offline-progress calculations.

/// Base kits use the first four. The last five are the **ascended** kinds
/// (version 2, see data/ascension.dart) — each one is the mechanical shape
/// of a companion's route resolving, so they are written as new kinds
/// rather than as bigger numbers on the old ones.
enum AbilityKind {
  damage,
  ultimate,
  taunt,
  heal,

  /// Faelen — shields and empowers the whole party instead of only herself.
  rally,

  /// Kess — damage scales off what the rest of the party did since her last
  /// cast.
  link,

  /// Momo — reads the gate ahead: party-wide damage reduction, plus a hit.
  foresight,

  /// Thora — returns, with interest, the healing and shielding the party
  /// put into her.
  reciprocal,

  /// Dana — an off-role wildcard that resolves differently every cast.
  wildcard,
}

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

  /// Attack multiplier granted by an ascended rally, and how long it lasts.
  /// Kept off [attack] itself so the base stat stays the tuned constant.
  double attackBuff = 1.0;
  double attackBuffRemaining = 0;

  /// Healing and shielding this fighter has *received* since it was last
  /// spent. Thora's Reciprocity is the only thing that reads it, and it is
  /// what turns "she is held up" into damage.
  double careReceived = 0;

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
  bool get isRallied => alive && attackBuffRemaining > 0;

  /// Attack after any active rally. Everything that deals damage reads this.
  double get effectiveAttack => attack * (isRallied ? attackBuff : 1.0);

  /// Take healing, capped at max HP, and remember it was given. Returns the
  /// amount that actually landed.
  double receiveHealing(double amount) {
    if (!alive || amount <= 0) return 0;
    final before = hp;
    hp = min(maxHp, hp + amount);
    final landed = hp - before;
    careReceived += landed;
    return landed;
  }

  void receiveShield(double amount) {
    if (!alive || amount <= 0) return;
    shield += amount;
    careReceived += amount;
  }
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

/// One line of what just happened, for whatever is drawing the fight.
///
/// [kind] is a presentation hint, not simulation state — version 3's combat
/// screen turns it into a sound, a colour and a floating number, and
/// version 1 ignored it entirely. [amount] is the number that line is
/// about (damage dealt, healing landed, mana paid), so the renderer never
/// has to parse it back out of the message.
class BattleEvent {
  final String message;

  /// damage | crit | ultimate | heal | revive | boss | down | hurt | reward
  final String kind;
  final double amount;

  BattleEvent(this.message, this.kind, {this.amount = 0});
}

class Battle {
  final Random _rng;
  final List<Fighter> party;
  final List<Ability> abilities;

  /// The gate's element for this whole raid — every wave and the boss share
  /// it (see docs/combat-spec.md §3: "each [gate] shows its element").
  final GateElement gateElement;

  /// Gate tier scaling (see GateTier in data/gate.dart). Defaults to 1.0
  /// across the board, which is exactly the step-3 tuning every existing
  /// balance test was written against — a tier-2 "Rift" is the old gate.
  final double hpMult;
  final double dpsMult;
  final double manaMult;

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

  /// Total events ever emitted this fight, including the ones already
  /// trimmed off the front of [events]. A renderer reacting to *new* events
  /// needs a count that only goes up — the list itself is capped and shifts
  /// under anyone holding an index into it.
  int eventsEmitted = 0;

  /// Ally actions — ability casts and critical hits — since the last
  /// [AbilityKind.link] cast. Kess's Chainbreak spends them; nothing else
  /// reads them, and they only accumulate while she is deployed.
  int linkStacks = 0;

  /// Seconds of Momo's Foresight left. While it is up the whole party takes
  /// [foresightReduction] less damage — the reason her ascension is a
  /// defensive cooldown and not just a bigger Bolt.
  double wardRemaining = 0;

  static const int maxLinkStacks = 10;
  static const double linkPerStack = 0.22;
  static const double foresightReduction = 0.42;
  static const double reciprocalReturn = 1.35;
  static const double rallyAttackBonus = 0.30;

  bool get warded => wardRemaining > 0;

  /// One ally action, for Chainbreak. Only counts while someone can spend
  /// them, so an un-ascended party pays nothing for the bookkeeping.
  void _noteAllyAction(String actorId) {
    if (!abilities.any((a) => a.kind == AbilityKind.link)) return;
    if (abilities.any((a) => a.kind == AbilityKind.link && a.ownerId == actorId)) {
      return;
    }
    if (linkStacks < maxLinkStacks) linkStacks++;
  }

  Battle({
    required this.party,
    required this.abilities,
    this.gateElement = GateElement.verdant,
    this.hpMult = 1.0,
    this.dpsMult = 1.0,
    this.manaMult = 1.0,
    this.autoCast = true,
    Random? rng,
  }) : _rng = rng ?? Random();

  factory Battle.fromFormation(Map<String, BattleRow> formation,
      {Map<String, int> levels = const {},
      Map<String, Gear?> gear = const {},
      Map<String, int> bondTiers = const {},
      Set<String> ascended = const {},
      GateElement gateElement = GateElement.verdant,
      double hpMult = 1.0,
      double dpsMult = 1.0,
      double manaMult = 1.0,
      Random? rng}) {
    return Battle(
      party: Roster.partyFrom(formation,
          levels: levels, gear: gear, bondTiers: bondTiers),
      abilities: Roster.abilitiesFor(formation.keys,
          levels: levels,
          gear: gear,
          bondTiers: bondTiers,
          ascended: ascended),
      gateElement: gateElement,
      hpMult: hpMult,
      dpsMult: dpsMult,
      manaMult: manaMult,
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
      f.attackBuff = 1.0;
      f.attackBuffRemaining = 0;
      f.careReceived = 0;
    }
    linkStacks = 0;
    wardRemaining = 0;
    for (final a in abilities) {
      a.remaining = 0;
    }
    events.clear();
    eventsEmitted = 0;
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
        maxHp: CombatConfig.bossHp * hpMult,
        baseDps: CombatConfig.bossDps * dpsMult,
        element: gateElement,
        isBoss: true,
      );
      _emit('The gate guardian stirs.', 'boss');
    } else {
      final hp = (CombatConfig.waveEnemyHp +
              CombatConfig.waveEnemyHpGrowth * waveIndex) *
          hpMult;
      enemy = Enemy(
        name: _waveNames[waveIndex % _waveNames.length],
        maxHp: hp,
        baseDps:
            (CombatConfig.enemyDps + CombatConfig.enemyDpsGrowth * waveIndex) *
                dpsMult,
        element: gateElement,
      );
    }
  }

  void _emit(String msg, String kind, {double amount = 0}) {
    events.add(BattleEvent(msg, kind, amount: amount));
    eventsEmitted++;
    if (events.length > 40) events.removeAt(0);
  }

  /// Current incoming damage per second, including the boss enrage ramp.
  double get incomingDps {
    final raw = onBoss
        ? enemy.baseDps + CombatConfig.bossEnrage * dpsMult * bossElapsed
        : enemy.baseDps;
    return warded ? raw * (1 - foresightReduction) : raw;
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

    _noteAllyAction(owner.id);

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
          amount: dmg,
        );
        break;

      case AbilityKind.taunt:
        owner.receiveShield(a.power);
        owner.taunt = a.duration;
        _emit(
            '${owner.name}: "Get behind me." '
                '(+${a.power.round()} shield, drawing fire)',
            'ultimate',
            amount: a.power);
        break;

      case AbilityKind.heal:
        var healed = 0.0;
        for (final p in party) {
          if (!p.alive) continue;
          healed += p.receiveHealing(a.power);
        }
        _emit('${owner.name} mends the party (${healed.round()} healed)',
            'heal',
            amount: healed);
        break;

      // ---- ascended kits (version 2, see data/ascension.dart) ----

      // Faelen's cure: the oath stops being a wall she stands behind alone.
      // Everyone is shielded and everyone hits harder, which is the whole
      // "together is the stronger thing" argument, stated as a cooldown.
      case AbilityKind.rally:
        const bonus = 1 + rallyAttackBonus;
        for (final p in party) {
          if (!p.alive) continue;
          p.receiveShield(a.power);
          p.attackBuff = bonus;
          p.attackBuffRemaining = a.duration;
        }
        _emit(
            '${owner.name}: "On me — all of you." '
            '(party +${a.power.round()} shield, '
            '+${(rallyAttackBonus * 100).round()}% attack for '
            '${a.duration.round()}s)',
            'ultimate');
        break;

      // Kess's cure: the hit is loaded by everything the party did while she
      // waited. Alone it is a weak Dash; in a working party it is the
      // biggest single number in the fight.
      case AbilityKind.link:
        final stacks = linkStacks;
        linkStacks = 0;
        final crit = _rng.nextDouble() < CombatConfig.abilityCritChance;
        final dmg = a.power *
            (1 + linkPerStack * stacks) *
            (crit ? CombatConfig.abilityCritMult : 1.0) *
            elementMultiplier(owner.element, enemy.element) *
            _jitter(0.9, 1.1);
        enemy.hp -= dmg;
        _emit(
            '${owner.name} — Chainbreak off $stacks link'
            '${stacks == 1 ? "" : "s"}: ${dmg.round()}'
            '${crit ? " (critical)" : ""}',
            'ultimate',
            amount: dmg);
        break;

      // Momo's cure: the sense that dragged danger to the party now reads it
      // early. A flat cut to incoming damage for the whole party, plus the
      // pre-empting hit itself.
      case AbilityKind.foresight:
        wardRemaining = max(wardRemaining, a.duration);
        final dmg = a.power *
            elementMultiplier(owner.element, enemy.element) *
            _jitter(0.9, 1.1);
        enemy.hp -= dmg;
        _emit(
            '${owner.name} reads it coming — party takes '
            '${(foresightReduction * 100).round()}% less for '
            '${a.duration.round()}s (${dmg.round()} damage)',
            'ultimate',
            amount: dmg);
        break;

      // Thora's cure: everything the party put back into her is returned
      // with interest. She still heals, but what she was *given* is what
      // arms the strike.
      case AbilityKind.reciprocal:
        final held = owner.careReceived;
        owner.careReceived = 0;
        var healed = 0.0;
        for (final p in party) {
          if (!p.alive || p.id == owner.id) continue;
          healed += p.receiveHealing(a.power);
        }
        final dmg = (a.power + held * reciprocalReturn) *
            elementMultiplier(owner.element, enemy.element) *
            _jitter(0.9, 1.1);
        enemy.hp -= dmg;
        _emit(
            '${owner.name} gives it back — ${dmg.round()} damage off '
            '${held.round()} taken care of, ${healed.round()} healed',
            'ultimate',
            amount: dmg);
        break;

      // Dana's cure: she was never supposed to be in the fight, so what she
      // does in it is never quite the same twice. One of three, rolled at
      // cast.
      case AbilityKind.wildcard:
        switch (_rng.nextInt(3)) {
          case 0:
            final dmg = a.power *
                2.1 *
                elementMultiplier(owner.element, enemy.element) *
                _jitter(0.9, 1.1);
            enemy.hp -= dmg;
            _emit(
                '${owner.name} files an emergency order: ${dmg.round()} damage',
                'ultimate',
                amount: dmg);
            break;
          case 1:
            var healed = 0.0;
            for (final p in party) {
              if (!p.alive) continue;
              healed += p.receiveHealing(a.power * 1.1);
            }
            _emit(
                '${owner.name} calls in a favour — ${healed.round()} healed '
                'across the party',
                'heal',
                amount: healed);
            break;
          default:
            for (final p in party) {
              if (!p.alive) continue;
              p.receiveShield(a.power * 0.9);
              p.attackBuff = 1 + rallyAttackBonus * 0.6;
              p.attackBuffRemaining = a.duration;
            }
            _emit(
                '${owner.name} reads the regulations aloud — party shielded '
                'and steadied for ${a.duration.round()}s',
                'ultimate',
                amount: a.power * 0.9);
            break;
        }
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
      if (p.attackBuffRemaining > 0) {
        p.attackBuffRemaining = max(0, p.attackBuffRemaining - dt);
        if (p.attackBuffRemaining == 0) p.attackBuff = 1.0;
      }
    }
    if (wardRemaining > 0) wardRemaining = max(0, wardRemaining - dt);
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
        final dmg = p.effectiveAttack *
            rowMult *
            (crit ? CombatConfig.allyCritMult : 1.0) *
            elementMultiplier(p.element, enemy.element) *
            _jitter(0.85, 1.15);
        enemy.hp -= dmg;
        if (crit) {
          // A critical is an ally action Chainbreak can load off, same as a
          // cast — "the party did something while she waited".
          _noteAllyAction(p.id);
          _emit('${p.name} strikes for ${dmg.round()} (critical)', 'crit',
              amount: dmg);
        }
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
        target.attackBuffRemaining = 0;
        target.attackBuff = 1.0;
        _emit('${target.name} goes down', 'down');
      }
    }

    if (enemy.hp <= 0) {
      enemy.hp = 0;
      final gain = ((enemy.isBoss
                  ? CombatConfig.bossMana
                  : CombatConfig.waveManaBase +
                      CombatConfig.waveManaGrowth * waveIndex) *
              manaMult)
          .round();
      manaEarned += gain;

      if (enemy.isBoss) {
        status = BattleStatus.won;
        _emit('The rift closes. +$gain mana', 'reward',
            amount: gain.toDouble());
        return;
      }

      _emit('${enemy.name} falls. +$gain mana', 'reward',
          amount: gain.toDouble());

      // Between-wave recovery + revive. This is what keeps a poor formation
      // slower rather than unwinnable — no death spiral.
      for (final p in party) {
        if (p.alive) {
          p.hp = min(p.maxHp, p.hp + p.maxHp * CombatConfig.waveRecovery);
        } else {
          p.alive = true;
          p.hp = p.maxHp * CombatConfig.reviveAtWave;
          _emit('${p.name} gets back up', 'revive');
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
