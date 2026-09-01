/// What happens to game state when a choice is picked.
library gatefall.models.effects;

class Effects {
  final Map<String, dynamic> setFlags;
  final int bondDelta;
  final List<String> unlockBeats; // rarely used — forces immediate availability

  const Effects({
    this.setFlags = const {},
    this.bondDelta = 0,
    this.unlockBeats = const [],
  });

  factory Effects.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Effects();
    return Effects(
      setFlags: Map<String, dynamic>.from(json['set_flags'] as Map? ?? {}),
      bondDelta: json['bond_delta'] as int? ?? 0,
      unlockBeats: (json['unlock_beats'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }
}
