/// The single persisted object: everything the evaluator reads and every
/// choice writes to. This is what you save to disk / cloud.
class GameState {
  int storyAct;
  Map<String, int> bond; // characterId -> raw points
  Map<String, dynamic> flags; // flat, character-prefixed keys
  Set<String> completedBeats;
  int gold;
  int mana;

  GameState({
    this.storyAct = 1,
    Map<String, int>? bond,
    Map<String, dynamic>? flags,
    Set<String>? completedBeats,
    this.gold = 0,
    this.mana = 0,
  })  : bond = bond ?? {},
        flags = flags ?? {},
        completedBeats = completedBeats ?? {};

  int bondPointsFor(String characterId) => bond[characterId] ?? 0;

  void addBond(String characterId, int delta) {
    bond[characterId] = bondPointsFor(characterId) + delta;
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      storyAct: json['story_act'] as int? ?? 1,
      bond: Map<String, int>.from(json['bond'] as Map? ?? {}),
      flags: Map<String, dynamic>.from(json['flags'] as Map? ?? {}),
      completedBeats: Set<String>.from(json['completed_beats'] as List? ?? []),
      gold: json['gold'] as int? ?? 0,
      mana: json['mana'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'story_act': storyAct,
        'bond': bond,
        'flags': flags,
        'completed_beats': completedBeats.toList(),
        'gold': gold,
        'mana': mana,
      };
}
