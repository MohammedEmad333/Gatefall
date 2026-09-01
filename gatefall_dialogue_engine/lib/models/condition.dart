/// The shared gating language used by Beats, Choices, and Endings alike.
/// Every field is optional — omit what you don't need.
library gatefall.models.condition;

class FlagRequirement {
  final String flag;
  final dynamic equals; // exact-value check, e.g. "join"
  final List<dynamic>? oneOf; // membership check, e.g. ["stop", "join"]

  FlagRequirement({required this.flag, this.equals, this.oneOf});

  factory FlagRequirement.fromJson(Map<String, dynamic> json) {
    return FlagRequirement(
      flag: json['flag'] as String,
      equals: json['equals'],
      oneOf: (json['in'] as List<dynamic>?)?.toList(),
    );
  }

  /// True if this requirement is satisfied by the current flag store.
  bool isSatisfiedBy(Map<String, dynamic> flags) {
    final value = flags[flag];
    if (equals != null) return value == equals;
    if (oneOf != null) return oneOf!.contains(value);
    // No equals/oneOf given: just check the flag has been set at all.
    return value != null;
  }
}

class Condition {
  final int? bondTierMin;
  final int? storyActMin;
  final List<FlagRequirement> requiresFlags;
  final List<String> requiresBeatsComplete;

  const Condition({
    this.bondTierMin,
    this.storyActMin,
    this.requiresFlags = const [],
    this.requiresBeatsComplete = const [],
  });

  factory Condition.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Condition();
    return Condition(
      bondTierMin: json['bond_tier_min'] as int?,
      storyActMin: json['story_act_min'] as int?,
      requiresFlags: (json['requires_flags'] as List<dynamic>? ?? [])
          .map((e) => FlagRequirement.fromJson(e as Map<String, dynamic>))
          .toList(),
      requiresBeatsComplete: (json['requires_beats_complete'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }
}
