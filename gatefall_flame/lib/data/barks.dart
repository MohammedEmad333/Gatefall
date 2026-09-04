import 'dart:math';

/// One-line reactions — the cheap connective tissue between full scenes.
///
/// docs/dialogue-data-model.md calls these `bark_pool` entries: "single-node
/// mini-scenes (one line, no branching) — cheap to write, reused across many
/// gift-giving moments." The route JSON references pools by id; the lines
/// themselves live here so writing more is a one-line change and never a
/// schema change.
///
/// Every line is written to the character's lie, not their truth — they are
/// still defending it at the moment a gift lands.
class Barks {
  static final Random _rng = Random();

  static const Map<String, Map<String, List<String>>> _gift = {
    'faelen': {
      'loved': [
        'She turns it over twice before she says anything. "This is… the good grit." A pause. "Thank you."',
        '"You remembered." She says it like an accusation she has no defence against.',
      ],
      'liked': [
        '"Practical." From her that is not a small word.',
      ],
      'neutral': [
        'She accepts it with a soldier\'s nod and sets it down squared to the table edge.',
      ],
      'disliked': [
        '"I don\'t need decorating." She sets it aside, gently, which is somehow worse.',
      ],
    },
    'kess': {
      'loved': [
        'She shrieks. Actually shrieks. "Okay, okay — this is going in a video, you know that, right?"',
        'She goes very quiet, which for Kess is alarming. "…Where did you even find this."',
      ],
      'liked': [
        '"Ooh. Useful." She pockets it before you can change your mind.',
      ],
      'neutral': [
        '"Cute!" She is already looking at something else.',
      ],
      'disliked': [
        'Her grin stays exactly where it is and stops meaning anything. "Yeah. Thanks."',
      ],
    },
    'momo': {
      'loved': [
        'She holds it against her chest with both hands and does not look up for a while.',
        '"You didn\'t have to." Then, smaller: "I\'m glad you did."',
      ],
      'liked': [
        '"Oh — that\'s. That\'s nice." She hides behind the object.',
      ],
      'neutral': [
        'She thanks you twice, which means she isn\'t sure once was enough.',
      ],
      'disliked': [
        'She smiles and says it\'s lovely and puts it somewhere she won\'t have to look at it.',
      ],
    },
    'thora': {
      'loved': [
        'She weighs it in one hand. "Hah! Someone finally bought a real one." She is not talking about the object.',
        'She goes still. "For me." Not a question. She needed to say it out loud.',
      ],
      'liked': [
        '"That\'ll last." Highest praise available.',
      ],
      'neutral': [
        'She thanks you and immediately finds a use for it that benefits somebody else.',
      ],
      'disliked': [
        '"I don\'t need waiting on." She takes it anyway, because refusing would be rude.',
      ],
    },
    'dana': {
      'loved': [
        'She reads the label properly before she reacts. "This is the good one. …Noted."',
        '"You paid attention." She writes something in the margin of a form that has no margin note field.',
      ],
      'liked': [
        '"Functional. I approve." She means it.',
      ],
      'neutral': [
        '"Thank you." Filed, in every sense.',
      ],
      'disliked': [
        'She sets it down between you like evidence. "I\'m going to pretend this was a misunderstanding."',
      ],
    },
  };

  static const Map<String, List<String>> _idle = {
    'faelen': [
      'She is running the whetstone down the same blade she sharpened this morning.',
      '"The east stair is weak. I fixed it. Don\'t thank me for it."',
      'She stands where she can see both doors. She always does.',
    ],
    'kess': [
      '"Chat says the rail-yard gate has better lighting. Chat is wrong but I love them."',
      'She is editing something at speed and eating something at greater speed.',
      '"Rent\'s covered this month. I said I\'d cover it. I covered it."',
    ],
    'momo': [
      'She is in the corner with a book she has already finished twice.',
      '"There\'s one about four streets over. Small. It won\'t open tonight." She says it apologetically.',
      'She moves her chair a little further from the window when you come in.',
    ],
    'thora': [
      'Something is simmering. Something is always simmering.',
      '"You ate? Don\'t answer that, I can tell. Sit."',
      'She has fixed the thing you didn\'t mention was broken.',
    ],
    'dana': [
      'She is here for an inspection that nobody scheduled.',
      '"Your paperwork is late. I\'ve back-dated it. Don\'t make that face."',
      'She stays for the second cup of coffee, and does not explain why.',
    ],
  };

  static const Map<String, String> _dateLine = {
    'faelen':
        'You walk the perimeter together and she talks about the wall — the real one, the one she was posted to — for eleven whole minutes before she notices she is talking.',
    'kess':
        'She takes you somewhere with three tables and no sign, orders for both of you, and does not film any of it.',
    'momo':
        'A library after hours. She reads a passage aloud, stops, and reads it again slower because you asked her to.',
    'thora':
        'She makes you cook. She corrects your grip twice and lets you burn the second batch without saying anything.',
    'dana':
        'Off the clock, in a place with bad lighting, she takes the lanyard off and puts it in her pocket.',
  };

  static String gift(String characterId, String tier) {
    final pool = _gift[characterId]?[tier];
    if (pool == null || pool.isEmpty) return 'They take it without a word.';
    return pool[_rng.nextInt(pool.length)];
  }

  static String idle(String characterId) {
    final pool = _idle[characterId];
    if (pool == null || pool.isEmpty) return 'They are somewhere in the house.';
    return pool[_rng.nextInt(pool.length)];
  }

  static String date(String characterId) =>
      _dateLine[characterId] ?? 'You spend the evening together.';
}
