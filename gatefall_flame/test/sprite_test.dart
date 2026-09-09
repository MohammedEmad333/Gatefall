// The rendered-sprite layer (lib/art/sprites.dart), Approach A.
//
// The contract that must hold no matter what art exists: when a sprite PNG is
// absent, the battle widgets fall back to the painted art and nothing throws;
// when one is present, the widgets draw an Image instead. Neither the
// simulation nor the shipping (art-less) look may change.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/art/character_art.dart';
import 'package:gatefall/art/gate_art.dart';
import 'package:gatefall/art/sprites.dart';
import 'package:gatefall/data/element.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Each test declares the sprite set it wants; reset so order can't leak.
  tearDown(() => SpriteBook.instance.setAvailableForTest(const {}));

  test('asset paths follow the documented convention', () {
    expect(characterSpritePath('faelen'), 'assets/sprites/characters/faelen.png');
    expect(creatureSpritePath(Beastform.guardian),
        'assets/sprites/enemies/guardian.png');
  });

  testWidgets('with no sprite present, falls back to painted art', (t) async {
    SpriteBook.instance.setAvailableForTest(const {});

    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: CharacterSprite('faelen', size: 40),
    ));
    expect(find.byType(CharacterPortrait), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: CreatureSprite(form: Beastform.stalker, element: GateElement.gloam),
    ));
    expect(find.byType(CreatureView), findsOneWidget);
  });

  testWidgets('with a sprite present, draws an Image instead of the painter',
      (t) async {
    SpriteBook.instance.setAvailableForTest({
      characterSpritePath('faelen'),
      creatureSpritePath(Beastform.guardian),
    });

    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: CharacterSprite('faelen', size: 40),
    ));
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CharacterPortrait), findsNothing);

    // A character with no sprite still falls back, even when others have one.
    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: CharacterSprite('kess', size: 40),
    ));
    expect(find.byType(CharacterPortrait), findsOneWidget);

    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: CreatureSprite(
          form: Beastform.guardian, element: GateElement.verdant),
    ));
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CreatureView), findsNothing);
  });
}
