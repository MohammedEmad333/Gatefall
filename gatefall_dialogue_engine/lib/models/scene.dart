import 'dialogue_node.dart';

/// A full dialogue graph — what a Beat's `scene_ref` points to.
class Scene {
  final String sceneId;
  final String startNode;
  final Map<String, DialogueNode> nodes;

  Scene({required this.sceneId, required this.startNode, required this.nodes});

  factory Scene.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'] as Map<String, dynamic>;
    final nodes = <String, DialogueNode>{};
    rawNodes.forEach((id, value) {
      nodes[id] = DialogueNode.fromJson(id, value as Map<String, dynamic>);
    });
    return Scene(
      sceneId: json['scene_id'] as String,
      startNode: json['start_node'] as String,
      nodes: nodes,
    );
  }
}
