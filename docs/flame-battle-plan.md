# Rendered sprites on the battle screen — the two approaches

`combat/battle.dart` is a pure simulation with no rendering in it, so putting
rendered art on the raid screen is a presentation change only. There are two
ways to do it, and the project runs them as a **hybrid**: Approach A is wired
now; Approach B stays open as a deliberate follow-up. They do not conflict —
both read the same `assets/sprites/` files by the same names.

## Approach A — widget/sprite swap (shipped)

The raid screen keeps its `Timer.periodic` loop and its `CustomPainter`
effects (shake, floating damage numbers, draining HP bars, sound). A single
widget decides, per character or creature, whether to draw a rendered PNG or
the painted silhouette.

- **Code:** `lib/art/sprites.dart` — `SpriteBook` (loads the asset manifest
  once at boot so a widget can decide synchronously), `CharacterSprite` and
  `CreatureSprite` (draw the PNG when present, fall back to
  `CharacterPortrait` / `CreatureView` when absent or broken).
- **Wired at:** the three battle-screen call sites in `lib/ui/gate_screen.dart`
  (formation unit chip, fighter row, enemy).
- **Drop-in:** `assets/sprites/characters/<rosterId>.png` and
  `assets/sprites/enemies/<beastform>.png`. Directories are declared in
  `pubspec.yaml`, so adding art needs no pubspec or code edit. See the
  `README.md` in each directory.
- **Why this first:** everything a static or spritesheet sprite needs is a
  *widget*, and every screen already asks for one. It ships art one character
  at a time (start with Faelen, whose reference is locked), keeps every tested
  reaction effect, and changes nothing visually until a PNG is added.
- **Ceiling:** static/frame-cycled sprites plus the existing widget effects.
  Not free-moving sprites or heavy particle systems.

`CharacterSprite` is wired on every screen that shows a character as a
card/figure: the battle screen (formation, fighter rows, enemy), the house
(`home_screen.dart`), dialogue headers (`dialogue_screen.dart`), the roster
(`companions_screen.dart`), and the endings (`ending_screen.dart`). So a
dropped-in PNG shows everywhere at once, with the same painted fallback.

The one screen deliberately **left on painted art** is the opening comic
(`start_scene.dart`): it is a distinct inked / halftone style layer that draws
its figures with `plate: false` inside already-drawn panels, and a
semi-realistic hero-card render would clash with it. Swap it too only if you
generate comic-styled art for that sequence.

## Approach B — the FlameGame swap (open)

Replace the fight view's enemy+party rendering with a `GameWidget` hosting a
`FlameGame`. Move `battle.tick(dt)` from the `Timer` into Flame's `update(dt)`.
Fighters and enemies become `SpriteComponent` / `SpriteAnimationComponent`s on
a canvas; the shake, floating numbers, and HP bars are re-implemented as Flame
components (they are Flutter widgets today and do not live inside a
`GameWidget`); the ability row and battle log stay as a Flutter overlay via
Flame's overlay system.

- **Worth it when:** you want a live canvas — thousands of particles,
  free-moving/tweened sprites, spritesheet animation — not merely to show
  rendered portraits. HANDOFF step 6 brackets it the same way.
- **Cost:** re-implements the tested render path; the widget tests that drive
  the real screens need rework.
- **Not blocked by A, and does not block A:** a `SpriteComponent` loads the
  same `assets/sprites/...` PNGs by the same names this layer already uses.
  `flame` is already a dependency in `pubspec.yaml`.

## How to actually make one

Step-by-step (generate → crop → transparent → drop in → run), plus the
expression-variant and proof-sheet workflow: **`docs/making-sprites.md`**.

## Asset prep note

`docs/art-direction/faelen_*.png` are 832×1216 full-body **LoRA training**
images, not battle sprites. Battle sprites want a transparent background and a
roughly square, consistent crop — clean a hero-card render down before dropping
it into `assets/sprites/`. Checkpoint in use: **Aniverse Pony XL**
(see `docs/art-direction.md`).
