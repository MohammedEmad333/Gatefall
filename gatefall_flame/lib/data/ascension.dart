import '../combat/battle.dart';
import 'roster.dart';

/// Version 2: the ascended kits (docs/combat-spec.md §4, "Ability
/// progression ties to story").
///
/// The keystone the design has always promised and the code never paid out:
/// *finishing someone's romance arc is a combat power spike*. Every route's
/// Beat 6 — "The Choice" — is where a companion stops living by their lie.
/// The base kit mirrors the flaw; the ability granted here mirrors the cure,
/// so the two halves of the game resolve in the same moment.
///
/// Ascension is not bought and never expires. It is earned by playing a
/// route to its end, which the evaluator already gates behind bond tier 6
/// and Act 3 — so reaching here means the story has been told.
class Ascension {
  final String characterId;

  /// The beat whose completion grants it. Always that route's Beat 6.
  final String beatId;

  /// The name the house gives it afterwards.
  final String title;

  /// The lie the base kit was built around.
  final String lie;

  /// What the ascended ability does, in the player's terms.
  final String cure;

  const Ascension({
    required this.characterId,
    required this.beatId,
    required this.title,
    required this.lie,
    required this.cure,
  });

  static const List<Ascension> all = [
    Ascension(
      characterId: 'faelen',
      beatId: 'faelen_b6_the_choice',
      title: 'Oathbound',
      lie: 'Guard shields her alone, because closeness is how people get hurt.',
      cure: 'Her oath covers the whole party — everyone shielded, everyone '
          'hitting harder, because together is the stronger thing.',
    ),
    Ascension(
      characterId: 'kess',
      beatId: 'kess_b6_the_choice',
      title: 'Chainbreak',
      lie: 'Dash is one enormous hit she takes alone, over-extended.',
      cure: 'Every ally action since her last strike loads the next one. '
          'Strongest when she is not fighting alone.',
    ),
    Ascension(
      characterId: 'momo',
      beatId: 'momo_b6_the_choice',
      title: 'Foresight',
      lie: 'Her gate-sense drags danger to the party and she hides from it.',
      cure: 'She reads the gate a few seconds ahead and the whole party takes '
          'less for it. "She draws danger" becomes "she sees it first."',
    ),
    Ascension(
      characterId: 'thora',
      beatId: 'thora_b6_the_choice',
      title: 'Reciprocity',
      lie: 'Mend pours into everyone but herself, until she runs dry.',
      cure: 'What the party puts back into her is returned with interest — '
          'the more she is held up, the harder the house hits.',
    ),
    Ascension(
      characterId: 'dana',
      beatId: 'dana_b6_the_choice',
      title: 'Casework',
      lie: 'She is not a fighter. She files, and other people bleed.',
      cure: 'She awakens and enters the party — an off-role wildcard whose '
          'call is never quite the same fight twice.',
    ),
  ];

  static Ascension byId(String id) =>
      all.firstWhere((a) => a.characterId == id);

  static bool exists(String id) => all.any((a) => a.characterId == id);

  /// The beat that grants [id]'s ascension, or null if they have none (the
  /// player).
  static String? beatFor(String id) =>
      exists(id) ? byId(id).beatId : null;

  /// Everyone whose Beat 6 is in [completedBeats].
  static Set<String> from(Iterable<String> completedBeats) {
    final done = completedBeats.toSet();
    return {
      for (final a in all)
        if (done.contains(a.beatId)) a.characterId,
    };
  }

  /// Ascended abilities, keyed by owner. Kept beside the base kit in
  /// [Roster.abilities] rather than inside it, so the base kit is still the
  /// only thing an un-ascended party brings and no balance test written
  /// against step 3 changes meaning.
  ///
  /// Costs are deliberately long: an ascended ability is a moment in the
  /// fight, not a new auto-attack. Two of them (Chainbreak, Reciprocity)
  /// pay out based on what the *rest* of the party did, so their listed
  /// power is a floor, not a ceiling.
  static final Map<String, AbilityDef> abilities = {
    'faelen': AbilityDef(
      id: 'oathbound',
      name: 'Oathbound',
      ownerId: 'faelen',
      kind: AbilityKind.rally,
      power: 150,
      cooldown: 26.0,
      duration: 10.0,
    ),
    'kess': AbilityDef(
      id: 'chainbreak',
      name: 'Chainbreak',
      ownerId: 'kess',
      kind: AbilityKind.link,
      power: 62,
      cooldown: 11.0,
    ),
    'momo': AbilityDef(
      id: 'foresight',
      name: 'Foresight',
      ownerId: 'momo',
      kind: AbilityKind.foresight,
      power: 70,
      cooldown: 20.0,
      duration: 9.0,
    ),
    'thora': AbilityDef(
      id: 'reciprocity',
      name: 'Reciprocity',
      ownerId: 'thora',
      kind: AbilityKind.reciprocal,
      power: 120,
      cooldown: 15.0,
    ),
    'dana': AbilityDef(
      id: 'casework',
      name: 'Casework',
      ownerId: 'dana',
      kind: AbilityKind.wildcard,
      power: 110,
      cooldown: 13.0,
      duration: 6.0,
    ),
  };
}
