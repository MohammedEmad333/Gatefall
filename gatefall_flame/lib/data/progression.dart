import 'dart:math';

/// Step 4: Mana rewards -> companion leveling (docs/combat-spec.md §6,
/// track 2 — "Companion combat level — bought with Mana. The main Mana
/// sink.").
///
/// Deliberately just this one track for now: player level and gear (the
/// other two tracks in §6) and Bond (the fourth, softest track in §5) are
/// later steps. This only spends the Mana a raid already earns to grow a
/// companion's own stats.
class Progression {
  static const int minLevel = 1;
  static const int maxLevel = 20;

  /// Mana cost to go from [currentLevel] to the next. Returns -1 once a
  /// companion is at [maxLevel] — there's nothing left to buy.
  static int costFor(int currentLevel) {
    if (currentLevel >= maxLevel) return -1;
    return (40 * pow(1.18, currentLevel - 1)).round();
  }

  /// Flat multiplier applied to attack and max HP. +4% per level above 1,
  /// so level 20 is a +76% character — noticeable, never a hard requirement
  /// (an unleveled companion still clears a level-appropriate gate; see
  /// balance_test.dart).
  static double statMultiplier(int level) => 1.0 + (level - 1) * 0.04;
}
