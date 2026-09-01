import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:gatefall_dialogue_engine/models/route.dart';

/// Loads each companion's [CharacterRoute] from the JSON bundled under
/// `data/` (mirrored from gatefall_dialogue_engine/data — see its README
/// for why: it's a pure-Dart package, so Flutter can't bundle its assets
/// directly, only the models/evaluator code is shared via the path
/// dependency). Only companions actually in [Roster] are loaded — there's
/// no Dana fighter yet, so her route stays unused for now.
class CompanionRoutes {
  static const _ids = ['faelen', 'kess', 'momo', 'thora'];

  static Future<Map<String, CharacterRoute>> loadAll() async {
    final routes = <String, CharacterRoute>{};
    for (final id in _ids) {
      final raw = await rootBundle.loadString('data/${id}_route.json');
      routes[id] =
          CharacterRoute.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    return routes;
  }
}
