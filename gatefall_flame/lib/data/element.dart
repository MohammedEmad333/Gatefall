/// Step 3: elements and the matchup wheel (see docs/combat-spec.md §3).
///
/// Six elements, each locked to a character as identity. Five of them sit on
/// a cycle where each beats the next; Sever (human mana) sits outside the
/// wheel entirely — it never gets a bonus and never takes a penalty, which
/// is what makes Dana (and the player, also human) reliable neutral picks.
enum GateElement { verdant, ember, gloam, stone, sever, tide }

/// `_wheel[i]` beats `_wheel[i + 1]`, wrapping around.
/// Verdant -> Stone -> Ember -> Gloam -> Tide -> Verdant
const List<GateElement> _wheel = [
  GateElement.verdant,
  GateElement.stone,
  GateElement.ember,
  GateElement.gloam,
  GateElement.tide,
];

const double advantageMult = 1.3;
const double disadvantageMult = 0.7;

/// The element [e] beats on the wheel, or null for Sever (outside the wheel).
GateElement? beats(GateElement e) {
  final i = _wheel.indexOf(e);
  if (i == -1) return null; // Sever
  return _wheel[(i + 1) % _wheel.length];
}

/// Damage multiplier for an attacker with [attacker]'s element hitting a
/// target with [defender]'s element. Sever on either side is always neutral.
double elementMultiplier(GateElement attacker, GateElement defender) {
  if (attacker == GateElement.sever || defender == GateElement.sever) {
    return 1.0;
  }
  if (beats(attacker) == defender) return advantageMult;
  if (beats(defender) == attacker) return disadvantageMult;
  return 1.0;
}

enum Matchup { advantage, neutral, disadvantage }

Matchup matchupOf(GateElement attacker, GateElement defender) {
  final m = elementMultiplier(attacker, defender);
  if (m > 1.0) return Matchup.advantage;
  if (m < 1.0) return Matchup.disadvantage;
  return Matchup.neutral;
}

extension ElementLabel on GateElement {
  String get label {
    switch (this) {
      case GateElement.verdant:
        return 'Verdant';
      case GateElement.ember:
        return 'Ember';
      case GateElement.gloam:
        return 'Gloam';
      case GateElement.stone:
        return 'Stone';
      case GateElement.sever:
        return 'Sever';
      case GateElement.tide:
        return 'Tide';
    }
  }
}
