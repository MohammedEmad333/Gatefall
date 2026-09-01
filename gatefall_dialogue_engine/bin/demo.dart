// Command-line demo: walks Faelen's entire route end to end using nothing
// but the shared engine — gifts, bond-tier crossings, all seven beats
// (including a conditional-callback line and a flag-gated later beat),
// and final ending resolution. Run with: dart run bin/demo.dart
//
// In the real Flutter app, swap File.readAsStringSync() for
// rootBundle.loadString() and this same model/engine code is unchanged.

import 'dart:convert';
import 'dart:io';

import '../lib/engine/dialogue_engine.dart';
import '../lib/engine/evaluator.dart';
import '../lib/models/game_state.dart';
import '../lib/models/route.dart';
import '../lib/models/scene.dart';

CharacterRoute loadRoute(String path) {
  final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return CharacterRoute.fromJson(json);
}

Scene loadScene(String path) {
  final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return Scene.fromJson(json);
}

void printState(GameState state, String characterId) {
  final points = state.bondPointsFor(characterId);
  final tier = Evaluator.tierOf(points);
  print('  [bond=$points tier=$tier act=${state.storyAct}]');
}

/// Runs a scene fully automatically, printing each line, and picking the
/// given choiceId whenever a branch is reached. Returns after end_scene.
void runScene(Scene scene, GameState state, String characterId, {Map<String, String> choicesToMake = const {}}) {
  final engine = DialogueEngine(scene: scene, state: state, characterId: characterId);
  print('--- scene: ${scene.sceneId} ---');
  while (!engine.isEnd) {
    final node = engine.currentNode;
    if (node.text != null) {
      final speaker = node.speaker ?? '';
      print('  $speaker: ${node.text}');
    }
    if (node.isBranch) {
      final options = engine.visibleChoices();
      final pick = choicesToMake[node.id] ?? options.first.choiceId;
      final chosen = options.firstWhere((c) => c.choiceId == pick);
      print('    -> choosing: "${chosen.text}"');
      engine.choose(pick);
    } else {
      engine.advance();
    }
  }
  print('--- end scene ---\n');
}

/// Silent bulk gift-giving, to move bond across a tier boundary without
/// printing every single gift (a real game would show a bark line each time).
void giveGifts(CharacterRoute route, GameState state, String itemId, int times) {
  final tier = route.reactionTierFor(itemId);
  final deltas = {'loved': 20, 'liked': 10, 'neutral': 2, 'disliked': -5};
  final delta = deltas[tier] ?? 0;
  for (var i = 0; i < times; i++) {
    state.addBond(route.characterId, delta);
  }
  print('Gave $itemId x$times ($tier, ${delta >= 0 ? '+' : ''}$delta each).');
  printState(state, route.characterId);
}

/// Fetches, runs, and marks-complete the beat the evaluator currently says
/// is next — this is the realistic flow: the evaluator decides *what's*
/// available, `beat.sceneRef` says *where its dialogue lives*.
void playNextBeat(CharacterRoute route, GameState state, {Map<String, String> choicesToMake = const {}}) {
  final beat = Evaluator.nextAvailableBeat(route, state);
  if (beat == null) {
    print('Next available beat: (none — route complete)');
    return;
  }
  print('Next available beat: ${beat.beatId} ("${beat.title}")');
  final scene = loadScene('${Directory.current.path}/${beat.sceneRef}');
  runScene(scene, state, route.characterId, choicesToMake: choicesToMake);
  state.completedBeats.add(beat.beatId);
}

void main() {
  final route = loadRoute('${Directory.current.path}/data/faelen_route.json');
  final state = GameState();

  print('=== GATEFALL — Faelen route walkthrough ===\n');

  // Beat 0 — recruitment (unlocked immediately at Act 1, no bond needed).
  playNextBeat(route, state);

  // Cross into Bond Tier 1 (threshold 60) with a loved gift.
  giveGifts(route, state, 'whetstone', 3); // 3 x 20 = 60
  playNextBeat(route, state, choicesToMake: {'n3': 'press'}); // deliberately choose "press"

  // Push toward Tier 2 (threshold 150).
  giveGifts(route, state, 'bitter_tea', 4); // +80 -> 155
  playNextBeat(route, state, choicesToMake: {'n2': 'trust_her'});

  // Push toward Tier 3 (threshold 280).
  giveGifts(route, state, 'whetstone', 6); // +120 -> 290
  giveGifts(route, state, 'tactics_book', 1); // liked, +10 -> 300
  // Beat 3 contains a conditional callback line (n1b) that only shows
  // because FAELEN_APPROACH == "press" was set back in Beat 1.
  playNextBeat(route, state, choicesToMake: {'n2': 'ask_hunting'});

  // Push toward Tier 4 (threshold 450) AND advance the story to Act 2.
  giveGifts(route, state, 'star_map', 8); // +160 -> 470
  giveGifts(route, state, 'plain_meal', 1); // +20 -> 490
  state.storyAct = 2;
  print('Story advances to Act 2.\n');
  playNextBeat(route, state, choicesToMake: {'n1': 'join'}); // the crux choice — sets FAELEN_FRACTURE

  // Push toward Tier 5 (threshold 650).
  giveGifts(route, state, 'whetstone', 9); // +180 -> 690
  playNextBeat(route, state, choicesToMake: {'n1': 'not_disqualified'});

  // Push toward Tier 6 (threshold 900) AND advance the story to Act 3.
  giveGifts(route, state, 'bitter_tea', 11); // +220 -> 930
  state.storyAct = 3;
  print('Story advances to Act 3.\n');
  playNextBeat(route, state);

  // No more beats left.
  playNextBeat(route, state);

  // Resolve the ending.
  final ending = Evaluator.resolveEnding(route, state);
  print('\n=== Resolved ending: ${ending?.endingId ?? "(no ending matched)"} ===');
  print('Final flags: ${state.flags}');
  printState(state, route.characterId);
}
