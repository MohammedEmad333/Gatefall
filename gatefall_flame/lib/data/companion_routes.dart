import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:gatefall_dialogue_engine/models/route.dart';
import 'package:gatefall_dialogue_engine/models/scene.dart';

/// Loads each companion's [CharacterRoute] and, on demand, the [Scene] a
/// beat's `scene_ref` points at, from the JSON bundled under `data/`
/// (mirrored from gatefall_dialogue_engine/data — see its README for why:
/// it's a pure-Dart package, so Flutter can't bundle its assets directly,
/// only the models/evaluator code is shared via the path dependency).
///
/// All five routes load, Dana included. She has no fighter in the roster
/// until her own route awakens her (docs/companion-routes.md, Dana: "starts
/// entirely *outside* the fight"), but she lives in the house, takes gifts
/// and has a full seven-beat route, so the house needs her data.
class CompanionRoutes {
  static const ids = ['faelen', 'kess', 'momo', 'thora', 'dana'];

  static final Map<String, Scene> _sceneCache = {};

  static Future<Map<String, CharacterRoute>> loadAll() async {
    final routes = <String, CharacterRoute>{};
    for (final id in ids) {
      final raw = await rootBundle.loadString('data/${id}_route.json');
      routes[id] =
          CharacterRoute.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    return routes;
  }

  /// Loads (and caches) the scene graph a beat points at. [sceneRef] is the
  /// route JSON's own `scene_ref`, e.g. `data/scenes/faelen_b1_the_wall.json`
  /// — already an asset path, so it is used verbatim.
  static Future<Scene> loadScene(String sceneRef) async {
    final cached = _sceneCache[sceneRef];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(sceneRef);
    final scene = Scene.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _sceneCache[sceneRef] = scene;
    return scene;
  }

  /// Warms the cache for every scene the given routes can reach.
  ///
  /// All 35 scenes together are a few tens of kilobytes, so this costs
  /// nothing and buys two things: opening a scene never shows a loading
  /// state, and a `scene_ref` that points at a missing file fails at boot,
  /// where it is obvious, rather than at the moment a player taps a beat.
  static Future<void> preloadScenes(Map<String, CharacterRoute> routes) async {
    for (final route in routes.values) {
      for (final beat in route.beats) {
        try {
          await loadScene(beat.sceneRef);
        } catch (_) {
          // A missing scene must not stop the game from opening — the beat
          // that points at it will surface the error when it is played.
        }
      }
    }
  }

  /// True once [preloadScenes] has cached this scene, so callers can render
  /// it without awaiting anything.
  static Scene? cachedScene(String sceneRef) => _sceneCache[sceneRef];
}
