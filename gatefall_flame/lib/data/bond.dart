import 'package:gatefall_dialogue_engine/engine/evaluator.dart';

/// Step 6: Bond -> combat buff (docs/combat-spec.md §5).
///
/// Bond tier (0-6) is computed by the shared dialogue engine's
/// [Evaluator.tierOf] from raw bond points — this file only adds the
/// combat-facing multiplier on top of that one source of truth, so a
/// future retune of `Evaluator.bondTierThresholds` doesn't need a matching
/// change here.
class BondBuff {
  /// Index = bond tier. "Meaningful boost, not a hard gate" per the spec —
  /// a tier-2 companion (+10%) is still clearly usable next to a tier-6 one
  /// (+30%), same intent as Progression and Gear not gating anything.
  static const List<double> _tierBonus = [0, .05, .10, .15, .20, .25, .30];

  static double statMultiplier(int tier) =>
      1.0 + _tierBonus[tier.clamp(0, _tierBonus.length - 1)];

  static double statMultiplierForPoints(int bondPoints) =>
      statMultiplier(Evaluator.tierOf(bondPoints));
}
