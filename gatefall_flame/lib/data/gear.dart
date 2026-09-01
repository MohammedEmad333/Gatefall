import 'dart:math';

/// Step 5: gear drops and upgrades (docs/combat-spec.md §6, track 3 —
/// "Gear — dropped in raids, upgraded/enchanted with Mana. Equipped per
/// character.") and §2's resolve step: "Win -> gate closes, full Mana +
/// gear drops." — a win always drops something; only losing withholds it.
///
/// One gear slot per character, kept deliberately simple: no weapon/armor
/// split, no inventory screen. A drop either replaces a character's gear
/// (if it's an upgrade) or is salvaged into Mana on the spot, so every win
/// pays off without needing inventory management UI.
enum GearRarity { common, rare, epic }

extension GearRarityX on GearRarity {
  /// Flat stat bonus at enhance level 0.
  double get baseBonus => switch (this) {
        GearRarity.common => 0.06,
        GearRarity.rare => 0.12,
        GearRarity.epic => 0.20,
      };

  /// Drop odds — common weapons are exactly that.
  double get dropWeight => switch (this) {
        GearRarity.common => 0.65,
        GearRarity.rare => 0.28,
        GearRarity.epic => 0.07,
      };

  /// Mana refunded when a drop of this rarity isn't worth equipping.
  int get salvageValue => switch (this) {
        GearRarity.common => 10,
        GearRarity.rare => 25,
        GearRarity.epic => 60,
      };

  /// Enhancing rarer gear costs proportionally more.
  double get enhanceCostMult => switch (this) {
        GearRarity.common => 1.0,
        GearRarity.rare => 1.5,
        GearRarity.epic => 2.2,
      };

  String get label => switch (this) {
        GearRarity.common => 'Common',
        GearRarity.rare => 'Rare',
        GearRarity.epic => 'Epic',
      };
}

class Gear {
  static const int maxEnhance = 8;
  static const double _enhanceBonusPerLevel = 0.03;

  final GearRarity rarity;
  int enhanceLevel;

  Gear({required this.rarity, this.enhanceLevel = 0});

  /// Multiplier this piece contributes to attack, max HP, and ability power
  /// — stacks multiplicatively with companion level (see Progression).
  double get statMultiplier =>
      1.0 + rarity.baseBonus + enhanceLevel * _enhanceBonusPerLevel;

  /// Mana cost to enhance once more, or -1 if already at [maxEnhance].
  int get enhanceCost {
    if (enhanceLevel >= maxEnhance) return -1;
    return (30 * pow(1.22, enhanceLevel) * rarity.enhanceCostMult).round();
  }
}

/// One roll of the drop table, used at the end of a won raid.
class GearDrop {
  final GearRarity rarity;
  const GearDrop(this.rarity);

  static GearDrop roll(Random rng) {
    final total = GearRarity.values.fold<double>(0, (a, r) => a + r.dropWeight);
    var roll = rng.nextDouble() * total;
    for (final r in GearRarity.values) {
      roll -= r.dropWeight;
      if (roll <= 0) return GearDrop(r);
    }
    return const GearDrop(GearRarity.common);
  }
}
