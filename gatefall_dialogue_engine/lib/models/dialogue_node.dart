import 'condition.dart';
import 'effects.dart';

/// One branch option at a choice node.
class Choice {
  final String choiceId;
  final String text;
  final Condition? condition; // null = always visible
  final String next; // node id to continue to
  final Effects effects;

  Choice({
    required this.choiceId,
    required this.text,
    this.condition,
    required this.next,
    this.effects = const Effects(),
  });

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      choiceId: json['choice_id'] as String,
      text: json['text'] as String,
      condition: json['condition'] == null
          ? null
          : Condition.fromJson(json['condition'] as Map<String, dynamic>),
      next: json['next'] as String,
      effects: Effects.fromJson(json['effects'] as Map<String, dynamic>?),
    );
  }
}

/// One line/block of dialogue. Either linear (`next`) or a branch (`choices`)
/// — never both. `endScene: true` marks a terminal node.
///
/// An optional [condition] marks a node as a *conditional insert* — a line
/// that only plays if the condition is met (e.g. a callback to an earlier
/// choice). Only valid on linear (non-branch) nodes: if the condition
/// fails, the engine skips straight to `next` without displaying it. See
/// [DialogueEngine] for the skip logic.
class DialogueNode {
  final String id;
  final String? speaker;
  final String? text;
  final String? next;
  final List<Choice> choices;
  final bool endScene;
  final Condition? condition;

  DialogueNode({
    required this.id,
    this.speaker,
    this.text,
    this.next,
    this.choices = const [],
    this.endScene = false,
    this.condition,
  });

  bool get isBranch => choices.isNotEmpty;

  factory DialogueNode.fromJson(String id, Map<String, dynamic> json) {
    return DialogueNode(
      id: id,
      speaker: json['speaker'] as String?,
      text: json['text'] as String?,
      next: json['next'] as String?,
      choices: (json['choices'] as List<dynamic>? ?? [])
          .map((e) => Choice.fromJson(e as Map<String, dynamic>))
          .toList(),
      endScene: json['end_scene'] as bool? ?? false,
      condition: json['condition'] == null
          ? null
          : Condition.fromJson(json['condition'] as Map<String, dynamic>),
    );
  }
}
