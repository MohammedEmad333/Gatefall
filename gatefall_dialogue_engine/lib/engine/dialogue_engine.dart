import '../models/dialogue_node.dart';
import '../models/game_state.dart';
import '../models/scene.dart';
import 'evaluator.dart';

/// Walks a single [Scene] for a given character, applying choice effects
/// to [state] as the player picks them. One instance per active scene.
class DialogueEngine {
  final Scene scene;
  final GameState state;
  final String characterId; // needed to apply bond deltas to the right character
  String currentNodeId;

  DialogueEngine({
    required this.scene,
    required this.state,
    required this.characterId,
  }) : currentNodeId = _resolveEntry(scene, scene.startNode, state, characterId);

  DialogueNode get currentNode => scene.nodes[currentNodeId]!;

  /// Follows `next` past any conditional-insert nodes whose condition isn't
  /// met, so the caller only ever lands on a node that should actually be
  /// shown. Linear conditional nodes are invisible plumbing when skipped;
  /// branch/end nodes are never skipped (conditions on choices are handled
  /// separately, in [visibleChoices]).
  static String _resolveEntry(Scene scene, String nodeId, GameState state, String characterId) {
    var id = nodeId;
    while (true) {
      final node = scene.nodes[id]!;
      final skippable = !node.isBranch && !node.endScene && node.condition != null;
      final conditionFails =
          skippable && !Evaluator.conditionsMet(node.condition, state, characterId: characterId);
      if (conditionFails && node.next != null) {
        id = node.next!;
        continue;
      }
      return id;
    }
  }

  bool get isEnd => currentNode.endScene;

  /// Choices at the current node, filtered to ones whose condition (if any)
  /// is currently satisfied — e.g. a callback line that only shows if an
  /// earlier beat set a particular flag.
  List<Choice> visibleChoices() {
    if (!currentNode.isBranch) return const [];
    return currentNode.choices
        .where((c) => Evaluator.conditionsMet(c.condition, state, characterId: characterId))
        .toList();
  }

  /// Advance past a linear (non-branching) node.
  void advance() {
    final next = currentNode.next;
    if (next == null) {
      throw StateError('Node ${currentNode.id} has no `next` — did you mean to call choose()?');
    }
    currentNodeId = _resolveEntry(scene, next, state, characterId);
  }

  /// Pick a choice by id: applies its effects to [state], then moves on.
  void choose(String choiceId) {
    final choice = currentNode.choices.firstWhere(
      (c) => c.choiceId == choiceId,
      orElse: () => throw ArgumentError('No choice "$choiceId" at node ${currentNode.id}'),
    );

    choice.effects.setFlags.forEach((flag, value) {
      state.flags[flag] = value;
    });

    if (choice.effects.bondDelta != 0) {
      state.addBond(characterId, choice.effects.bondDelta);
    }

    // unlockBeats is intentionally not auto-completed here — it only means
    // "make available now"; the evaluator already does that on its own the
    // next time nextAvailableBeat() runs, since flags/bond just changed.

    currentNodeId = _resolveEntry(scene, choice.next, state, characterId);
  }
}
