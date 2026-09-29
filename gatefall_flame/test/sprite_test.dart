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
    expect(characterSpritePath('faelen', expression: 'happy'),
        'assets/sprites/characters/faelen_happy.png');
    expect(characterSpritePath('faelen', expression: ''),
        'assets/sprites/characters/faelen.png');
    expect(characterHeroPath('faelen'),
        'assets/sprites/characters/faelen.png');
    expect(characterHeroPath('kess'),
        'assets/sprites/characters/kess/kess_master.jpg');
    expect(characterAnimationFramePaths('kess', CharacterAnimationState.idle).length, 8);
    expect(characterAnimationFramePaths('kess', CharacterAnimationState.idle).first,
        'assets/sprites/characters/kess/animations/idle/runtime/kess_idle_01.png');
    expect(characterAnimationFramePaths('kess', CharacterAnimationState.idle).last,
        'assets/sprites/characters/kess/animations/idle/runtime/kess_idle_08.png');
    expect(characterAnimationFramePaths('faelen', CharacterAnimationState.idle), isEmpty);
    expect(creatureSpritePath(Beastform.guardian),
        'assets/sprites/enemies/guardian.png');
  });


  test('combat animation states are ready to accept approved frame sets', () {
    expect(characterAnimationFrameDuration(CharacterAnimationState.attack),
        const Duration(milliseconds: 95));
    expect(characterAnimationFrameDuration(CharacterAnimationState.hurt),
        const Duration(milliseconds: 110));
    expect(characterAnimationFrameDuration(CharacterAnimationState.death),
        const Duration(milliseconds: 130));
    expect(
      characterAnimationTotalDuration('kess', CharacterAnimationState.attack),
      const Duration(milliseconds: 760),
    );
    expect(
      characterAnimationTotalDuration('kess', CharacterAnimationState.hurt),
      const Duration(milliseconds: 660),
    );
    expect(
      characterAnimationTotalDuration('kess', CharacterAnimationState.death),
      const Duration(milliseconds: 1040),
    );
    final attack =
        characterAnimationFramePaths('kess', CharacterAnimationState.attack);
    final hurt =
        characterAnimationFramePaths('kess', CharacterAnimationState.hurt);
    final death =
        characterAnimationFramePaths('kess', CharacterAnimationState.death);

    expect(attack, hasLength(8));
    expect(attack.first,
        'assets/sprites/characters/kess/animations/attack/runtime/kess_attack_01.png');
    expect(attack.last,
        'assets/sprites/characters/kess/animations/attack/runtime/kess_attack_08.png');

    expect(hurt, hasLength(6));
    expect(hurt.first,
        'assets/sprites/characters/kess/animations/hurt/runtime/kess_hurt_01.png');
    expect(hurt.last,
        'assets/sprites/characters/kess/animations/hurt/runtime/kess_hurt_06.png');

    expect(death, hasLength(8));
    expect(death.first,
        'assets/sprites/characters/kess/animations/death/runtime/kess_death_01.png');
    expect(death.last,
        'assets/sprites/characters/kess/animations/death/runtime/kess_death_08.png');
  });

  testWidgets('combat animation waits for a complete approved frame set',
      (t) async {
    final attack =
        characterAnimationFramePaths('kess', CharacterAnimationState.attack);
    SpriteBook.instance.setAvailableForTest({
      characterSpritePath('kess'),
      ...attack.take(7),
    });

    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: CharacterSprite(
        'kess',
        size: 80,
        animation: CharacterAnimationState.attack,
      ),
    ));

    final image = t.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, characterSpritePath('kess'));
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

  testWidgets('character hero uses full-body sprite and keeps fallback safe',
      (t) async {
    SpriteBook.instance.setAvailableForTest({characterSpritePath('faelen')});

    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 320,
        child: CharacterHero('faelen', height: 260),
      ),
    ));

    expect(find.byType(Image), findsOneWidget);
    final image = t.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, characterSpritePath('faelen'));

    SpriteBook.instance.setAvailableForTest({characterHeroPath('kess')});
    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 320,
        child: CharacterHero('kess', height: 260),
      ),
    ));
    expect(find.byType(Image), findsOneWidget);
    final kessImage = t.widget<Image>(find.byType(Image));
    expect((kessImage.image as AssetImage).assetName, characterHeroPath('kess'));

    // Hero art alone does not imply the runtime sprite is available; the
    // fallback remains safe when a test bundle only exposes the hero source.
    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: CharacterSprite('kess', size: 40),
    ));
    expect(find.byType(CharacterPortrait), findsOneWidget);

    SpriteBook.instance.setAvailableForTest(const {});
    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 320,
        child: CharacterHero('kess', height: 260),
      ),
    ));
    expect(find.byType(CharacterPortrait), findsOneWidget);
  });

  testWidgets('Kess calm portrait loops approved idle frames', (t) async {
    final frames = characterAnimationFramePaths('kess', CharacterAnimationState.idle);
    SpriteBook.instance.setAvailableForTest({
      characterSpritePath('kess'),
      ...frames,
    });

    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: CharacterSprite('kess', size: 80, calm: true),
    ));

    Image imageOf() => t.widget<Image>(find.byType(Image));
    expect((imageOf().image as AssetImage).assetName, frames[0]);

    await t.pump(const Duration(milliseconds: 200));
    expect((imageOf().image as AssetImage).assetName, frames[1]);

    // Active/combat presentation stays on the neutral runtime sprite.
    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: CharacterSprite('kess', size: 80),
    ));
    expect((imageOf().image as AssetImage).assetName, characterSpritePath('kess'));
  });


  testWidgets('re-keying repeated Kess attack restarts at frame one', (t) async {
    final frames =
        characterAnimationFramePaths('kess', CharacterAnimationState.attack);
    SpriteBook.instance.setAvailableForTest({
      characterSpritePath('kess'),
      ...frames,
    });

    Widget build(int revision) => Directionality(
          textDirection: TextDirection.ltr,
          child: CharacterSprite(
            'kess',
            key: ValueKey('kess-attack-$revision'),
            size: 80,
            animation: CharacterAnimationState.attack,
          ),
        );

    Image imageOf() => t.widget<Image>(find.byType(Image));

    await t.pumpWidget(build(1));
    expect((imageOf().image as AssetImage).assetName, frames.first);

    await t.pump(const Duration(milliseconds: 200));
    expect((imageOf().image as AssetImage).assetName, frames[2]);

    await t.pumpWidget(build(2));
    expect((imageOf().image as AssetImage).assetName, frames.first);
  });

  testWidgets('expression variant is used when present, else neutral base',
      (t) async {
    // Both a neutral base and a happy variant exist.
    SpriteBook.instance.setAvailableForTest({
      characterSpritePath('faelen'),
      characterSpritePath('faelen', expression: 'happy'),
    });

    Image imageOf(Finder f) => t.widget<Image>(f);

    // A requested variant that exists resolves to the variant file.
    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: CharacterSprite('faelen', size: 40, expression: 'happy'),
    ));
    expect((imageOf(find.byType(Image)).image as AssetImage).assetName,
        characterSpritePath('faelen', expression: 'happy'));

    // A requested variant that is missing falls back to the neutral base.
    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: CharacterSprite('faelen', size: 40, expression: 'furious'),
    ));
    expect((imageOf(find.byType(Image)).image as AssetImage).assetName,
        characterSpritePath('faelen'));

    // Only a variant exists, no neutral base: still falls back to painted art
    // rather than showing an expression the neutral portrait can't match.
    SpriteBook.instance.setAvailableForTest(
        {characterSpritePath('kess', expression: 'happy')});
    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: CharacterSprite('kess', size: 40),
    ));
    expect(find.byType(CharacterPortrait), findsOneWidget);
  });
}
