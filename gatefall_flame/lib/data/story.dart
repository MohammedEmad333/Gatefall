/// Acts, the endgame decision, and the written endings.
///
/// docs/HANDOFF.md: "3 acts. Endings turn on two dials: **who you bonded
/// with** × **what you did about the gates**." The romance dial is already
/// in the route JSON (each route's `endings` block, resolved by the shared
/// [Evaluator.resolveEnding]). This file supplies the second dial — the
/// player's answer to the gates — and the prose both dials resolve into.
library gatefall.data.story;

/// Act progression. Beats 4 and 6 are gated on Act 2 and Act 3
/// (docs/story-bible.md: "the player controls the *pace* but the story
/// controls the *timing* of the emotional peaks"), so the act needs a real
/// trigger rather than a debug button.
///
/// Both dials of progress count: the house filling up (Gold side) and beats
/// actually played (Bond side). Neither alone advances the act, which stops
/// a player who only raids from walking into a Fracture they have no
/// relationship for.
class Acts {
  static const int maxAct = 3;

  static const int act2SettledMin = 3;
  static const int act2BeatsMin = 6;

  static const int act3SettledMin = 4;
  static const int act3BeatsMin = 12;
  static const int act3TopBondTierMin = 4;

  /// The act the current progress earns. Never goes down.
  static int actFor({
    required int settledCount,
    required int completedBeats,
    required int highestBondTier,
  }) {
    if (settledCount >= act3SettledMin &&
        completedBeats >= act3BeatsMin &&
        highestBondTier >= act3TopBondTierMin) {
      return 3;
    }
    if (settledCount >= act2SettledMin && completedBeats >= act2BeatsMin) {
      return 2;
    }
    return 1;
  }

  /// What the player still needs before the next act turns over — shown in
  /// the UI so "why can't I reach her Fracture" is never a mystery.
  static String? nextActRequirement({
    required int act,
    required int settledCount,
    required int completedBeats,
    required int highestBondTier,
  }) {
    if (act >= maxAct) return null;
    if (act == 1) {
      final needRooms = (act2SettledMin - settledCount).clamp(0, 99);
      final needBeats = (act2BeatsMin - completedBeats).clamp(0, 99);
      final parts = [
        if (needRooms > 0) '$needRooms more resident${needRooms == 1 ? "" : "s"}',
        if (needBeats > 0) '$needBeats more scene${needBeats == 1 ? "" : "s"}',
      ];
      return parts.isEmpty ? null : 'Act II needs ${parts.join(" and ")}.';
    }
    final needRooms = (act3SettledMin - settledCount).clamp(0, 99);
    final needBeats = (act3BeatsMin - completedBeats).clamp(0, 99);
    final needTier = (act3TopBondTierMin - highestBondTier).clamp(0, 99);
    final parts = [
      if (needRooms > 0) '$needRooms more resident${needRooms == 1 ? "" : "s"}',
      if (needBeats > 0) '$needBeats more scene${needBeats == 1 ? "" : "s"}',
      if (needTier > 0) 'someone at bond tier $act3TopBondTierMin',
    ];
    return parts.isEmpty ? null : 'Act III needs ${parts.join(", ")}.';
  }

  static const Map<int, String> title = {
    1: 'Act I — The Door',
    2: 'Act II — The Fracture',
    3: 'Act III — What The Gates Were For',
  };

  static const Map<int, String> blurb = {
    1: 'A rundown building, a handful of people nobody else had room for, '
        'and a city full of tears in the air.',
    2: 'Everyone you have taken in is about to try to leave for a reason '
        'they think is noble.',
    3: 'The gates were never an accident. What you do about that is the '
        'last thing the house asks of you.',
  };
}

/// The second dial: the player's answer to the gates, taken once, in Act 3.
///
/// The flag is stored on [GameState.flags] under [flagKey] so it reads
/// exactly like every route flag and could move into route JSON later
/// without changing the evaluator.
enum GateAnswer { seal, study, live }

extension GateAnswerX on GateAnswer {
  String get id => switch (this) {
        GateAnswer.seal => 'seal',
        GateAnswer.study => 'study',
        GateAnswer.live => 'live',
      };

  String get label => switch (this) {
        GateAnswer.seal => 'Close them all',
        GateAnswer.study => 'Learn why they opened',
        GateAnswer.live => 'Let both worlds stay open',
      };

  String get pitch => switch (this) {
        GateAnswer.seal =>
          'End the monsters and the refugees in the same stroke. The city '
              'gets safe. Everyone in this house becomes the last of their kind '
              'on the wrong side of a shut door.',
        GateAnswer.study =>
          'Momo\'s sense and Faelen\'s Warden records point the same '
              'direction. Follow it and you might learn what tore the sky. You '
              'will not be finished for a very long time.',
        GateAnswer.live =>
          'Stop treating it as a wound. Clear what surges, register who '
              'arrives, build more rooms. It never ends and it was never '
              'supposed to.',
      };

  String get epilogue => switch (this) {
        GateAnswer.seal =>
          'The gates go quiet one after another over eleven months. The '
              'monsters stop. So does everything else that was coming through. '
              'The house stays full, and no one in it can ever go home, and '
              'they knew that when they voted.',
        GateAnswer.study =>
          'You do not close the last gate. You map it. The answer, when it '
              'comes, is not the one anyone wanted, and it takes years, and '
              'the house is still standing when it arrives.',
        GateAnswer.live =>
          'Nothing ends. The surges get answered faster, the paperwork gets '
              'easier, the third floor gets finished. Somebody new is on the '
              'step most weeks. You keep the door open. That was the whole '
              'job.',
      };

  static const String flagKey = 'GATES_ANSWER';
}

/// The written payoff for each route ending id in the JSON. Ids match the
/// `endings` blocks in `data/*_route.json` exactly.
class Endings {
  static const Map<String, String> text = {
    // Faelen — "closeness = failure" -> "together = strength"
    'faelen_true':
        'She lays the penance down. Not all at once, and never out loud, but '
            'one morning she is sitting at the table instead of standing where '
            'she can watch both doors. She still goes in first. The difference '
            'is that she expects you behind her now, and is stronger for it.',
    'faelen_bittersweet':
        'She stays. She is kinder than she was and still sleeps closest to '
            'the stairs. Some of the war is over. She does not say which part.',
    'faelen_lost':
        'She finishes it alone, the way she always meant to. There is a room '
            'in the house with a squared-off bed in it that nobody reassigns, '
            'and a whetstone on the sill, and no note.',

    // Kess — "I must earn my place" -> "home is who's already beside you"
    'kess_true':
        'She stops running the numbers on what she owes. The search does not '
            'end so much as change hands — she is looking for family with '
            'family, which turns out to be a different activity entirely. The '
            'stream stays up. It is mostly the house now.',
    'kess_bittersweet':
        'She stays, loudly, with one bag packed under the bed where she '
            'thinks nobody has seen it. She always covers rent. She always '
            'covers rent early.',
    'kess_lost':
        'She spends everything on one more lead, and then another. The '
            'uploads get further apart. The last one is eleven seconds of a '
            'road at night, no commentary, and then the channel goes quiet.',

    // Momo — "I'm a danger to everyone" -> "my curse is my shield"
    'momo_true':
        'She stops apologising for the weather. The sense that made her a '
            'target becomes the reason nothing takes this house by surprise '
            'again — she calls the surge four hours out, every time, and sits '
            'in the front room to do it, where the light is.',
    'momo_bittersweet':
        'She uses it now, and flinches every time it works. Half-healed is '
            'still upright. She moves her chair a little closer to the window '
            'each season.',
    'momo_lost':
        'She leaves in the night to lead it away, and it works, and the '
            'house is safe. The books stay on the shelf in the order she left '
            'them. The gates near here stop opening. Nobody is glad about it.',

    // Thora — "I only give" -> "being cared for is what home is"
    'thora_true':
        'She lets somebody else cook. It takes an argument and most of a '
            'year. When the house finally stands between her and something, '
            'she does not step around them, and what she does next is the '
            'strongest thing anyone in that room has ever seen.',
    'thora_bittersweet':
        'Softer, slower to refuse help, still first up and last fed. The '
            'kitchen is warm. She takes the small room anyway.',
    'thora_lost':
        'She spends herself for people she had known for an hour, because '
            'that was always the arithmetic. The recipe book stays. The house '
            'is fed and warm and grieving, and does the work she left.',

    // Dana — "rules keep us safe" -> "connection is the only thing that works"
    'dana_true':
        'She resigns on a Tuesday and is back by Thursday on the other side '
            'of the desk. The mana comes late and strange and does not fit any '
            'role the party had. Neither does she. That turns out to be the '
            'point of her.',
    'dana_bittersweet':
        'She stays inside the system and bends it from there, quietly, for '
            'years. It helps. It is not the same as walking through the door, '
            'and she knows it.',
    'dana_lost':
        'She follows the order, or she resigns rather than give it — either '
            'way the file closes and she is not in the building any more. The '
            'house survives. The door to the human world shuts very politely.',
  };

  /// Everyone who never got far enough to resolve an ending at all.
  static const String unresolved =
      'Their route never reached its end. They are still here, still holding '
      'the line they arrived with.';

  static String forId(String? endingId) =>
      endingId == null ? unresolved : (text[endingId] ?? unresolved);

  /// "True" / "Bittersweet" / "Lost" from the id suffix, for the UI label.
  static String labelFor(String? endingId) {
    if (endingId == null) return 'Unresolved';
    if (endingId.endsWith('_true')) return 'True';
    if (endingId.endsWith('_bittersweet')) return 'Bittersweet';
    if (endingId.endsWith('_lost')) return 'Lost';
    return 'Ending';
  }
}
