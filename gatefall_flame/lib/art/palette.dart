import 'package:flutter/material.dart';

import '../data/element.dart';
import '../ui/theme.dart';

/// Version 3 gave every element a colour, because the art has to say what
/// the text used to. These sit beside the palette in ui/theme.dart rather
/// than inside it: theme.dart is the *interface* palette (night, bone,
/// currencies), this is the *world's*.
const Color ember = Color(0xFFE07B45);
const Color gloam = Color(0xFF9A6BD9);
const Color stone = Color(0xFFC0A882);
const Color sever = Color(0xFF7FA9CC);
const Color tide = Color(0xFF4FB6C9);

/// The one place an element becomes a colour. Verdant reuses the currency
/// green on purpose — verdant mana *is* the green in this game.
Color elementColor(GateElement e) => switch (e) {
      GateElement.verdant => verdant,
      GateElement.ember => ember,
      GateElement.gloam => gloam,
      GateElement.stone => stone,
      GateElement.sever => sever,
      GateElement.tide => tide,
    };

/// A darker companion to [elementColor], for fills that must stay behind
/// text rather than compete with it.
Color elementDeep(GateElement e) =>
    Color.lerp(elementColor(e), night, 0.62)!;
