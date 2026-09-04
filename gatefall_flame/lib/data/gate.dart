import 'dart:math';

import 'element.dart';
import 'roster.dart';

/// Step-7 addition: gates come in **tiers**, not one fixed difficulty.
///
/// The reason is finding #4 in docs/HANDOFF.md — "a party under 4 loses
/// ~100%". That was true of a single fixed difficulty tuned for four
/// fighters, and it made the acquisition ramp (docs/story-bible.md:
/// Encounter -> Settle -> Unlock, companions arriving one at a time)
/// unshippable: a player who has only met Faelen would have had nothing
/// they could clear. Scaling the gate instead of the party keeps the
/// no-fail-state promise intact at every roster size.
///
/// Multipliers are simulation-tuned (see test/balance_test.dart, group
/// "gate tiers"), not guessed. The rule each tier must satisfy: a party of
/// its [recommendedParty] size clears it reliably at level 1 with no gear
/// and no bond, and a *larger* party clears it faster rather than trivially.
class GateTier {
  final int index;
  final String name;
  final String blurb;

  /// Scales enemy and boss max HP.
  final double hpMult;

  /// Scales incoming damage, including the boss enrage ramp.
  final double dpsMult;

  /// Scales Mana payout — harder gates are worth more per minute.
  final double manaMult;

  /// Gold paid out on a clear. Gold is the house economy (rent, gifts,
  /// rooms); a raid contributes some, but rent is the steady source.
  final int goldReward;

  /// Party size this tier is tuned around.
  final int recommendedParty;

  /// Total lifetime clears before this tier appears on the gate board.
  final int clearsToUnlock;

  const GateTier({
    required this.index,
    required this.name,
    required this.blurb,
    required this.hpMult,
    required this.dpsMult,
    required this.manaMult,
    required this.goldReward,
    required this.recommendedParty,
    required this.clearsToUnlock,
  });

  static const List<GateTier> all = [
    GateTier(
      index: 0,
      name: 'Fracture',
      blurb: 'A hairline tear. Thin enough for two.',
      hpMult: 0.34,
      dpsMult: 0.44,
      manaMult: 0.55,
      goldReward: 40,
      recommendedParty: 2,
      clearsToUnlock: 0,
    ),
    GateTier(
      index: 1,
      name: 'Breach',
      blurb: 'Wide enough to walk through. Something already did.',
      hpMult: 0.62,
      dpsMult: 0.70,
      manaMult: 0.80,
      goldReward: 70,
      recommendedParty: 3,
      clearsToUnlock: 2,
    ),
    GateTier(
      index: 2,
      name: 'Rift',
      blurb: 'Open, stable, and feeding. The standard job.',
      hpMult: 1.0,
      dpsMult: 1.0,
      manaMult: 1.0,
      goldReward: 110,
      recommendedParty: 4,
      clearsToUnlock: 6,
    ),
    GateTier(
      index: 3,
      name: 'Maw',
      blurb: 'It has been open long enough to grow a throat.',
      hpMult: 1.55,
      dpsMult: 1.14,
      manaMult: 1.8,
      goldReward: 190,
      recommendedParty: 4,
      clearsToUnlock: 14,
    ),
  ];

  static GateTier byIndex(int i) => all[i.clamp(0, all.length - 1)];

  /// Tiers visible on the gate board at [clears] lifetime clears. The first
  /// tier is always there — there is never a state with nothing to raid.
  static List<GateTier> unlockedAt(int clears) =>
      all.where((t) => clears >= t.clearsToUnlock).toList();
}

/// A gate the player can enter. One element and one tier for the whole raid.
class Gate {
  final String name;
  final String description;
  final GateElement element;
  final GateTier tier;

  const Gate({
    required this.name,
    required this.description,
    required this.element,
    this.tier = const GateTier(
      index: 2,
      name: 'Rift',
      blurb: 'Open, stable, and feeding. The standard job.',
      hpMult: 1.0,
      dpsMult: 1.0,
      manaMult: 1.0,
      goldReward: 110,
      recommendedParty: 4,
      clearsToUnlock: 6,
    ),
  });

  Gate withTier(GateTier t) => Gate(
      name: name, description: description, element: element, tier: t);

  /// "Verdant Rift", "Verdant Maw" — the tier is part of what you call it.
  String get fullName => '${element.label} ${tier.name}';
}

/// Flavor per element (see docs/combat-spec.md: Gloam gates tie to Momo's
/// arc, Verdant to Faelen's Warden past — gate flavor seeds the endgame
/// mystery later).
const Map<GateElement, Gate> _gatePool = {
  GateElement.verdant: Gate(
      name: 'Verdant Rift',
      description: 'A tear over the old rail yard',
      element: GateElement.verdant),
  GateElement.ember: Gate(
      name: 'Ember Scar',
      description: 'Heat shimmers off a cracked overpass',
      element: GateElement.ember),
  GateElement.gloam: Gate(
      name: 'Gloam Hollow',
      description: 'The streetlights nearby keep failing',
      element: GateElement.gloam),
  GateElement.stone: Gate(
      name: 'Stonefall Breach',
      description: 'A sinkhole that never stops settling',
      element: GateElement.stone),
  GateElement.tide: Gate(
      name: 'Tideglass Fissure',
      description: 'The air tastes like a shoreline that isn\'t there',
      element: GateElement.tide),
};

/// Picks gates for the player to raid.
///
/// Per docs/combat-spec.md §3 roster pressure mitigation #2: gate elements
/// should rotate fairly, weighted against repeating a disadvantage the
/// player just faced. Sever never generates a gate — it's the player/Dana's
/// own element, not something a gate can be made of.
class GateGenerator {
  final Random _rng;
  final List<GateElement> _history = [];

  GateGenerator({Random? rng}) : _rng = rng ?? Random();

  static const _gateElements = [
    GateElement.verdant,
    GateElement.ember,
    GateElement.gloam,
    GateElement.stone,
    GateElement.tide,
  ];

  /// Elements the roster the player actually has can hit with an advantage
  /// or is currently disadvantaged against, so rotation can react to what's
  /// deployable rather than the full cast.
  Gate next({Iterable<GateElement>? ownedElements, GateTier? tier}) {
    final owned = (ownedElements ?? Roster.all.map((f) => f.element)).toSet();

    final weights = <GateElement, double>{};
    for (final e in _gateElements) {
      var w = 1.0;
      // Down-weight repeating an element the party was just disadvantaged
      // against, so three walls in a row can't stack.
      final disadvantagedLastTime = _history.isNotEmpty &&
          _history.last == e &&
          owned.every((o) => matchupOf(o, e) != Matchup.advantage);
      if (disadvantagedLastTime) w *= 0.15;
      weights[e] = w;
    }

    final total = weights.values.fold<double>(0, (a, b) => a + b);
    var r = _rng.nextDouble() * total;
    GateElement chosen = _gateElements.first;
    for (final e in _gateElements) {
      r -= weights[e]!;
      if (r <= 0) {
        chosen = e;
        break;
      }
    }

    _history.add(chosen);
    if (_history.length > 8) _history.removeAt(0);
    final gate = _gatePool[chosen]!;
    return tier == null ? gate : gate.withTier(tier);
  }

  /// A whole board of gates — one per unlocked tier, each with its own
  /// element, so choosing a gate is a real decision (element matchup traded
  /// against payout) rather than a single "go" button.
  List<Gate> board(int clears, {Iterable<GateElement>? ownedElements}) => [
        for (final tier in GateTier.unlockedAt(clears))
          next(ownedElements: ownedElements, tier: tier),
      ];
}
