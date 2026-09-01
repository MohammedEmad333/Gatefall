import 'condition.dart';

/// Metadata for one beat — small and always-loaded. The actual dialogue
/// lives in the separate scene file pointed to by [sceneRef].
class Beat {
  final String beatId;
  final int order;
  final String title;
  final Condition unlockConditions;
  final String triggerContext; // "story" | "home_visit" | "gift" | "date" | "post_raid"
  final String sceneRef;

  Beat({
    required this.beatId,
    required this.order,
    required this.title,
    required this.unlockConditions,
    required this.triggerContext,
    required this.sceneRef,
  });

  factory Beat.fromJson(Map<String, dynamic> json) {
    return Beat(
      beatId: json['beat_id'] as String,
      order: json['order'] as int,
      title: json['title'] as String,
      unlockConditions: Condition.fromJson(json['unlock_conditions'] as Map<String, dynamic>?),
      triggerContext: json['trigger_context'] as String,
      sceneRef: json['scene_ref'] as String,
    );
  }
}

class Ending {
  final String endingId;
  final int priority; // lower = checked first
  final Condition conditions;

  Ending({required this.endingId, required this.priority, required this.conditions});

  factory Ending.fromJson(Map<String, dynamic> json) {
    return Ending(
      endingId: json['ending_id'] as String,
      priority: json['priority'] as int,
      conditions: Condition.fromJson(json['conditions'] as Map<String, dynamic>?),
    );
  }
}

/// A gift's bond payoff and which one-line barks can play when it's given.
class GiftReaction {
  final int bondDelta;
  final List<String> barkPool;

  GiftReaction({required this.bondDelta, required this.barkPool});

  factory GiftReaction.fromJson(Map<String, dynamic> json) {
    return GiftReaction(
      bondDelta: json['bond_delta'] as int,
      barkPool: (json['bark_pool'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
    );
  }
}

/// One character's full route: metadata, gift preferences, beats, endings.
class CharacterRoute {
  final String characterId;
  final String displayName;
  final Map<String, List<String>> giftPreferences; // "loved" | "liked" | "disliked" -> item ids
  final List<Beat> beats;
  final List<Ending> endings;

  CharacterRoute({
    required this.characterId,
    required this.displayName,
    required this.giftPreferences,
    required this.beats,
    required this.endings,
  });

  factory CharacterRoute.fromJson(Map<String, dynamic> json) {
    final rawPrefs = json['gift_preferences'] as Map<String, dynamic>? ?? {};
    final prefs = <String, List<String>>{};
    rawPrefs.forEach((tier, items) {
      prefs[tier] = (items as List<dynamic>).map((e) => e as String).toList();
    });

    return CharacterRoute(
      characterId: json['character_id'] as String,
      displayName: json['display_name'] as String,
      giftPreferences: prefs,
      beats: (json['beats'] as List<dynamic>? ?? [])
          .map((e) => Beat.fromJson(e as Map<String, dynamic>))
          .toList(),
      endings: (json['endings'] as List<dynamic>? ?? [])
          .map((e) => Ending.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// "loved" | "liked" | "neutral" | "disliked" — falls back to "neutral"
  /// for any item not explicitly listed.
  String reactionTierFor(String itemId) {
    for (final tier in ['loved', 'liked', 'disliked']) {
      if (giftPreferences[tier]?.contains(itemId) ?? false) return tier;
    }
    return 'neutral';
  }
}
