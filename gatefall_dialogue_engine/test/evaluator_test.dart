import 'package:test/test.dart';
import 'package:gatefall_dialogue_engine/engine/evaluator.dart';
import 'package:gatefall_dialogue_engine/models/condition.dart';
import 'package:gatefall_dialogue_engine/models/game_state.dart';

void main() {
  group('bond thresholds', () {
    test('tiers change only at thresholds', () {
      expect(Evaluator.tierOf(0), 0);
      expect(Evaluator.tierOf(59), 0);
      expect(Evaluator.tierOf(60), 1);
      expect(Evaluator.tierOf(899), 5);
      expect(Evaluator.tierOf(900), 6);
    });
  });

  group('conditions', () {
    test('all requirements must pass', () {
      final state = GameState(
        storyAct: 2,
        bond: {'faelen': 150},
        flags: {'faelen_choice': 'join'},
        completedBeats: {'faelen_b0'},
      );
      final condition = Condition(
        bondTierMin: 2,
        storyActMin: 2,
        requiresFlags: [
          FlagRequirement(flag: 'faelen_choice', equals: 'join'),
        ],
        requiresBeatsComplete: ['faelen_b0'],
      );
      expect(Evaluator.conditionsMet(condition, state, characterId: 'faelen'), isTrue);
      expect(Evaluator.conditionsMet(condition, state, characterId: 'kess'), isFalse);
      state.completedBeats.clear();
      expect(Evaluator.conditionsMet(condition, state, characterId: 'faelen'), isFalse);
    });

    test('flag membership checks exact accepted choices', () {
      final requirement = FlagRequirement(flag: 'choice', oneOf: ['stop', 'join']);
      expect(requirement.isSatisfiedBy({'choice': 'join'}), isTrue);
      expect(requirement.isSatisfiedBy({'choice': 'release'}), isFalse);
    });
  });

  test('game state JSON round trip retains progress', () {
    final original = GameState(
      storyAct: 3,
      bond: {'momo': 450},
      flags: {'momo_choice': 'join'},
      completedBeats: {'momo_b0', 'momo_b1'},
      gold: 42,
      mana: 99,
    );
    final restored = GameState.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());
  });
}
