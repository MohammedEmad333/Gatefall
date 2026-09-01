import 'dart:math';

import 'element.dart';
import 'roster.dart';

/// A gate the player can enter. One element for the whole raid.
class Gate {
  final String name;
  final String description;
  final GateElement element;

  const Gate(
      {required this.name, required this.description, required this.element});
}

/// Flavor per element (see docs/combat-spec.md: Gloam gates tie to Momo's
/// arc, Verdant to Faelen's Warden past — gate flavor seeds the endgame
/// mystery later).
const Map<GateElement, List<Gate>> _gatePool = {
  GateElement.verdant: [
    Gate(
        name: 'Verdant Rift',
        description: 'A tear over the old rail yard',
        element: GateElement.verdant),
  ],
  GateElement.ember: [
    Gate(
        name: 'Ember Scar',
        description: 'Heat shimmers off a cracked overpass',
        element: GateElement.ember),
  ],
  GateElement.gloam: [
    Gate(
        name: 'Gloam Hollow',
        description: 'The streetlights nearby keep failing',
        element: GateElement.gloam),
  ],
  GateElement.stone: [
    Gate(
        name: 'Stonefall Breach',
        description: 'A sinkhole that never stops settling',
        element: GateElement.stone),
  ],
  GateElement.tide: [
    Gate(
        name: 'Tideglass Fissure',
        description: 'The air tastes like a shoreline that isn\'t there',
        element: GateElement.tide),
  ],
};

/// Picks gates for the player to raid, one at a time.
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
  Gate next({Iterable<GateElement>? ownedElements}) {
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
    return _gatePool[chosen]!.first;
  }
}
