import '../models/condition.dart';
import '../models/game_state.dart';
import '../models/route.dart';

/// The one evaluator shared by every character. Retuning pacing means
/// editing [bondTierThresholds] — nothing character-specific lives here.
class Evaluator {
  // Index = tier. Tier N requires at least bondTierThresholds[N] points.
  static const List<int> bondTierThresholds = [0, 60, 150, 280, 450, 650, 900];

  static int tierOf(int bondPoints) {
    var tier = 0;
    for (var i = 0; i < bondTierThresholds.length; i++) {
      if (bondPoints >= bondTierThresholds[i]) tier = i;
    }
    return tier;
  }

  /// True if [condition] is satisfied by the current [state], for the given
  /// [characterId] (used to look up bond points).
  static bool conditionsMet(
    Condition? condition,
    GameState state, {
    required String characterId,
  }) {
    if (condition == null) return true;

    if (condition.bondTierMin != null) {
      if (tierOf(state.bondPointsFor(characterId)) < condition.bondTierMin!) {
        return false;
      }
    }

    if (condition.storyActMin != null) {
      if (state.storyAct < condition.storyActMin!) return false;
    }

    for (final req in condition.requiresFlags) {
      if (!req.isSatisfiedBy(state.flags)) return false;
    }

    for (final beatId in condition.requiresBeatsComplete) {
      if (!state.completedBeats.contains(beatId)) return false;
    }

    return true;
  }

  /// The first beat (in order) that isn't complete yet and whose conditions
  /// are currently met. Call this after any change to bond/flags/act to
  /// decide what should light up as "available" in the UI.
  static Beat? nextAvailableBeat(CharacterRoute route, GameState state) {
    final sorted = [...route.beats]..sort((a, b) => a.order.compareTo(b.order));
    for (final beat in sorted) {
      if (!state.completedBeats.contains(beat.beatId) &&
          conditionsMet(beat.unlockConditions, state, characterId: route.characterId)) {
        return beat;
      }
    }
    return null;
  }

  /// All currently-unlocked-but-incomplete beats, not just the next one —
  /// useful if you ever want to show several available threads at once
  /// rather than strictly one-at-a-time.
  static List<Beat> allAvailableBeats(CharacterRoute route, GameState state) {
    return route.beats
        .where((beat) =>
            !state.completedBeats.contains(beat.beatId) &&
            conditionsMet(beat.unlockConditions, state, characterId: route.characterId))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Run at Act 3 (or whenever you're ready to lock in a character's
  /// ending). Checked in priority order, first match wins.
  static Ending? resolveEnding(CharacterRoute route, GameState state) {
    final sorted = [...route.endings]..sort((a, b) => a.priority.compareTo(b.priority));
    for (final ending in sorted) {
      if (conditionsMet(ending.conditions, state, characterId: route.characterId)) {
        return ending;
      }
    }
    return null;
  }
}
