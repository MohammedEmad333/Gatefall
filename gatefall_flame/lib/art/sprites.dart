import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

import '../data/element.dart';
import '../ui/theme.dart';
import 'character_art.dart';
import 'gate_art.dart';

/// The rendered-sprite layer — **Approach A** of the two the art plan lays
/// out (`docs/art-direction.md`, `docs/HANDOFF.md` step 6).
///
/// A painted silhouette ([CharacterPortrait] / [CreatureView]) is what ships.
/// The moment a real rendered PNG is dropped into `assets/sprites/` under the
/// right name, the battle screen shows it instead — one character or creature
/// at a time, with no other change and no code edit. If the art is missing,
/// or fails to decode, the painted art draws exactly as before. Nothing here
/// touches `combat/battle.dart`: this is presentation only.
///
/// This is deliberately **not** the FlameGame swap (Approach B). Everything a
/// static or sheet-based sprite needs is a *widget*, and every screen already
/// asks for one. The Flame path stays open for a live particle/animation
/// canvas — see the note in `main.dart` and `docs/flame-battle-plan.md` — and
/// this layer does not block it: a `SpriteComponent` would read the same
/// `assets/sprites/` files by the same names.
///
/// ## Drop-in convention
///
/// - Character (party) sprite: `assets/sprites/characters/<rosterId>.png`
///   e.g. `assets/sprites/characters/faelen.png`. Ids are the roster ids
///   (`faelen`, `kess`, `momo`, `thora`, `dana`, `player`).
/// - Optional expression variant: `<rosterId>_<emotion>.png`, e.g.
///   `faelen_happy.png`. The dialogue portrait uses it when a scene node
///   carries an `emotion`; a missing variant falls back to the neutral
///   `<rosterId>.png`, then to painted art. Base sprite alone is enough.
/// - Enemy sprite: `assets/sprites/enemies/<beastform>.png`
///   e.g. `assets/sprites/enemies/guardian.png`. Names are the [Beastform]
///   enum values (`stalker`, `hound`, `shade`, `husk`, `thornbound`,
///   `guardian`).
///
/// Export transparent (background-removed), roughly square PNGs — the battle
/// screen scales them into fixed boxes, so a consistent framing across a set
/// keeps the row tidy. See `assets/sprites/README.md`.
class SpriteBook {
  SpriteBook._();
  static final SpriteBook instance = SpriteBook._();

  Set<String> _available = const {};
  bool _loaded = false;

  bool get loaded => _loaded;

  /// Which sprite asset paths actually exist in the bundle. Loaded once at
  /// boot from the asset manifest, so a widget can decide *synchronously*
  /// whether to draw a PNG or fall back — rather than calling a throwing
  /// `rootBundle.load` on every frame for art that isn't there yet.
  Future<void> load() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _available = manifest
          .listAssets()
          .where((p) => p.startsWith('assets/sprites/'))
          .toSet();
    } catch (_) {
      // No manifest, or none of these assets declared: everyone falls back to
      // the painted art. This is the shipping state until sprites are added.
      _available = const {};
    }
    _loaded = true;
  }

  /// Test seam: pretend these exact asset paths exist, without a bundle.
  @visibleForTesting
  void setAvailableForTest(Set<String> paths) {
    _available = paths;
    _loaded = true;
  }

  bool has(String assetPath) => _available.contains(assetPath);
}

String characterSpritePath(String id, {String? expression}) =>
    expression == null || expression.isEmpty
        ? 'assets/sprites/characters/$id.png'
        : 'assets/sprites/characters/${id}_$expression.png';

/// Full-body profile art can live separately from combat sprites. Kess is the
/// first character to use the canonical nested source set; everyone else keeps
/// the original drop-in convention until their final hero art arrives.
String characterHeroPath(String id) => switch (id) {
      'kess' => 'assets/sprites/characters/kess/kess_master.jpg',
      _ => characterSpritePath(id),
    };

enum CharacterAnimationState { neutral, idle, attack, hurt, death }

List<String> characterAnimationFramePaths(
  String id,
  CharacterAnimationState state,
) =>
    switch ((id, state)) {
      ('kess', CharacterAnimationState.idle) => List<String>.generate(
          8,
          (i) =>
              'assets/sprites/characters/kess/animations/idle/runtime/kess_idle_${(i + 1).toString().padLeft(2, '0')}.png',
        ),
      ('kess', CharacterAnimationState.attack) => List<String>.generate(
          8,
          (i) =>
              'assets/sprites/characters/kess/animations/attack/runtime/kess_attack_${(i + 1).toString().padLeft(2, '0')}.png',
        ),
      ('kess', CharacterAnimationState.hurt) => List<String>.generate(
          6,
          (i) =>
              'assets/sprites/characters/kess/animations/hurt/runtime/kess_hurt_${(i + 1).toString().padLeft(2, '0')}.png',
        ),
      ('kess', CharacterAnimationState.death) => List<String>.generate(
          8,
          (i) =>
              'assets/sprites/characters/kess/animations/death/runtime/kess_death_${(i + 1).toString().padLeft(2, '0')}.png',
        ),
      _ => const <String>[],
    };

Duration characterAnimationFrameDuration(CharacterAnimationState state) =>
    switch (state) {
      CharacterAnimationState.idle => const Duration(milliseconds: 190),
      CharacterAnimationState.attack => const Duration(milliseconds: 95),
      CharacterAnimationState.hurt => const Duration(milliseconds: 110),
      CharacterAnimationState.death => const Duration(milliseconds: 130),
      CharacterAnimationState.neutral => Duration.zero,
    };

String creatureSpritePath(Beastform form) =>
    'assets/sprites/enemies/${form.name}.png';

/// A party member on the battle screen: their rendered sprite if one exists,
/// otherwise the painted [CharacterPortrait]. Same constructor shape as the
/// portrait, so a call site swaps one word.
class CharacterSprite extends StatelessWidget {
  final String id;
  final double size;
  final double glow;
  final bool dimmed;
  final bool calm;
  final bool plate;
  final CharacterAnimationState animation;

  /// Optional expression variant, e.g. `happy` → `<id>_happy.png`. Falls back
  /// to the neutral `<id>.png` when the variant is missing, then to painted
  /// art. Drives the dialogue portrait off a scene node's `emotion` (see
  /// DialogueNode.emotion); harmless everywhere else.
  final String? expression;

  const CharacterSprite(
    this.id, {
    super.key,
    this.size = 46,
    this.glow = .6,
    this.dimmed = false,
    this.calm = false,
    this.plate = true,
    this.expression,
    this.animation = CharacterAnimationState.neutral,
  });

  Widget _painted() => CharacterPortrait(id,
      size: size, glow: glow, dimmed: dimmed, calm: calm, plate: plate);

  @override
  Widget build(BuildContext context) {
    // Prefer the expression variant; fall back to the neutral sprite; then to
    // painted art. So a character can have a base PNG and no variants, or a
    // full expression set, and both just work.
    final variant = characterSpritePath(id, expression: expression);
    final base = characterSpritePath(id);
    final path = SpriteBook.instance.has(variant)
        ? variant
        : (SpriteBook.instance.has(base) ? base : null);
    if (path == null) return _painted();

    final requestedAnimation =
        animation == CharacterAnimationState.neutral && calm
            ? CharacterAnimationState.idle
            : animation;
    final animationFrames =
        characterAnimationFramePaths(id, requestedAnimation);
    final useAnimation = expression == null &&
        requestedAnimation != CharacterAnimationState.neutral &&
        animationFrames.isNotEmpty &&
        animationFrames.every(SpriteBook.instance.has);

    Widget sprite = useAnimation
        ? _CharacterAnimationFrames(
            paths: animationFrames,
            size: size,
            fallback: _painted,
            frameDuration: characterAnimationFrameDuration(requestedAnimation),
            loop: requestedAnimation == CharacterAnimationState.idle,
          )
        : Image.asset(
            path,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            // A declared-but-broken asset must never crash the fight; fall back.
            errorBuilder: (_, __, ___) => _painted(),
          );
    if (dimmed) {
      // Down/benched: drain the colour, matching the painted portrait's dim.
      sprite = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.33, 0.33, 0.33, 0, 0, //
          0.33, 0.33, 0.33, 0, 0, //
          0.33, 0.33, 0.33, 0, 0, //
          0, 0, 0, 1, 0, //
        ]),
        child: Opacity(opacity: .6, child: sprite),
      );
    }
    if (!plate) return SizedBox(width: size, height: size, child: sprite);

    // A transparent sprite would otherwise float on nothing. Give it the
    // same kind of lit plate the portrait draws — a dark rounded card with a
    // soft backlight scaled by [glow]. Tune freely; it is pure decoration.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: night2,
        borderRadius: BorderRadius.circular(size * .16),
        boxShadow: glow <= 0
            ? null
            : [
                BoxShadow(
                  color: verdant.withValues(alpha: .18 * glow.clamp(0, 1)),
                  blurRadius: size * .5 * glow.clamp(0, 1),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: sprite,
    );
  }
}


class _CharacterAnimationFrames extends StatefulWidget {
  final List<String> paths;
  final double size;
  final Widget Function() fallback;
  final Duration frameDuration;
  final bool loop;

  const _CharacterAnimationFrames({
    required this.paths,
    required this.size,
    required this.fallback,
    required this.frameDuration,
    required this.loop,
  });

  @override
  State<_CharacterAnimationFrames> createState() =>
      _CharacterAnimationFramesState();
}

class _CharacterAnimationFramesState extends State<_CharacterAnimationFrames> {
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.paths.length < 2 || widget.frameDuration == Duration.zero) return;
    _timer = Timer.periodic(widget.frameDuration, (_) {
      if (!mounted || widget.paths.isEmpty) return;
      if (_frame >= widget.paths.length - 1) {
        if (!widget.loop) {
          _timer?.cancel();
          return;
        }
        setState(() => _frame = 0);
        return;
      }
      setState(() => _frame++);
    });
  }

  @override
  void didUpdateWidget(covariant _CharacterAnimationFrames oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paths != widget.paths ||
        oldWidget.frameDuration != widget.frameDuration ||
        oldWidget.loop != widget.loop) {
      _frame = 0;
      _startTimer();
    } else if (_frame >= widget.paths.length) {
      _frame = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Image.asset(
        widget.paths[_frame],
        key: ValueKey(widget.paths[_frame]),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => widget.fallback(),
      );
}


/// A taller, profile-oriented presentation of a character.
///
/// Uses a profile-specific source when one is registered by [characterHeroPath],
/// otherwise the same drop-in convention as [CharacterSprite]. This lets a
/// character ship approved full-body profile art before a transparent combat
/// sprite exists. Missing or broken art still falls back to the painted
/// portrait, so the cast can migrate incrementally.
class CharacterHero extends StatelessWidget {
  final String id;
  final double height;
  final double glow;
  final bool dimmed;

  const CharacterHero(
    this.id, {
    super.key,
    this.height = 260,
    this.glow = 1,
    this.dimmed = false,
  });

  Widget _fallback() => Center(
        child: CharacterPortrait(
          id,
          size: height * .56,
          glow: glow,
          dimmed: dimmed,
          calm: true,
          plate: false,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final path = characterHeroPath(id);
    final hasSprite = SpriteBook.instance.has(path);

    Widget figure = hasSprite
        ? Image.asset(
            path,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => _fallback(),
          )
        : _fallback();

    if (dimmed) {
      figure = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: Opacity(opacity: .62, child: figure),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              verdant.withValues(alpha: .10 * glow.clamp(0, 1)),
              rift.withValues(alpha: .04 * glow.clamp(0, 1)),
              Colors.transparent,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: .72,
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    boxShadow: glow <= 0
                        ? null
                        : [
                            BoxShadow(
                              color: verdant.withValues(
                                  alpha: .35 * glow.clamp(0, 1)),
                              blurRadius: 26,
                              spreadRadius: 5,
                            ),
                          ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: figure,
            ),
          ],
        ),
      ),
    );
  }
}

/// The thing you are fighting: its rendered sprite if one exists, otherwise
/// the painted [CreatureView]. Approximates the painter's hit-flash and
/// death-collapse so a sprite still reacts to the sim.
class CreatureSprite extends StatelessWidget {
  final Beastform form;
  final GateElement element;
  final double size;
  final double hurt;
  final bool falling;

  const CreatureSprite({
    super.key,
    required this.form,
    required this.element,
    this.size = 120,
    this.hurt = 0,
    this.falling = false,
  });

  Widget _painted() => CreatureView(
      form: form, element: element, size: size, hurt: hurt, falling: falling);

  @override
  Widget build(BuildContext context) {
    final path = creatureSpritePath(form);
    if (!SpriteBook.instance.has(path)) return _painted();

    Widget sprite = Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _painted(),
    );

    // A hit whitens/reddens only the sprite's own pixels (srcATop), not its
    // transparent bounding box — the same read as the painter's flash.
    final h = hurt.clamp(0.0, 1.0);
    if (h > 0) {
      sprite = ColorFiltered(
        colorFilter: ColorFilter.mode(
            blood.withValues(alpha: h * .6), BlendMode.srcATop),
        child: sprite,
      );
    }

    // Dead: collapse and fade rather than vanishing between frames.
    return AnimatedSlide(
      offset: falling ? const Offset(0, .18) : Offset.zero,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeIn,
      child: AnimatedOpacity(
        opacity: falling ? 0 : 1,
        duration: const Duration(milliseconds: 320),
        child: sprite,
      ),
    );
  }
}
