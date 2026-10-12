import 'package:test/test.dart';
import 'package:gatefall_dialogue_engine/engine/dialogue_engine.dart';
import 'package:gatefall_dialogue_engine/models/condition.dart';
import 'package:gatefall_dialogue_engine/models/dialogue_node.dart';
import 'package:gatefall_dialogue_engine/models/effects.dart';
import 'package:gatefall_dialogue_engine/models/game_state.dart';
import 'package:gatefall_dialogue_engine/models/scene.dart';

void main() {
  test('conditional choice cannot be selected by directly calling choose', () {
    final scene = Scene(
      sceneId: 'test',
      startNode: 'start',
      nodes: {
        'start': DialogueNode(id: 'start', choices: [
          Choice(
            choiceId: 'locked',
            text: 'Locked',
            next: 'end',
            condition: Condition(requiresFlags: [
              FlagRequirement(flag: 'unlock', equals: true),
            ]),
            effects: Effects(setFlags: {'reward': true}, bondDelta: 10),
          ),
        ]),
        'end': DialogueNode(id: 'end', endScene: true),
      },
    );
    final state = GameState();
    final engine = DialogueEngine(scene: scene, state: state, characterId: 'faelen');
    expect(engine.visibleChoices(), isEmpty);
    expect(() => engine.choose('locked'), throwsArgumentError);
    expect(state.flags.containsKey('reward'), isFalse);
    expect(state.bondPointsFor('faelen'), 0);
    expect(engine.currentNodeId, 'start');
    state.flags['unlock'] = true;
    expect(engine.visibleChoices(), hasLength(1));
    engine.choose('locked');
    expect(engine.currentNodeId, 'end');
    expect(state.flags['reward'], true);
    expect(state.bondPointsFor('faelen'), 10);
  });
}
