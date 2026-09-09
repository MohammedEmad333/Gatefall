# Making sprites for Gatefall

How to turn a Stable Diffusion render into a battle sprite the game shows.
The wiring is already done (see `docs/flame-battle-plan.md`): drop a correctly
named PNG into `gatefall_flame/assets/sprites/` and it appears in place of the
painted silhouette — on the battle screen and on the house, dialogue, roster,
and ending screens. Missing or broken art falls back to the painted look, so
you can do this one character at a time and the game always renders.

Checkpoint in use: **AniVerse (Pony XL)**. Prompts live in
`docs/art-direction.md`.

---

## The pipeline

**Generate → crop to a battle figure → remove the background → save as
`<name>.png` in the right folder → run the game.**

### 1. Generate the render (ComfyUI + AniVerse Pony XL)

- Install and launch ComfyUI — full setup in `docs/comfyui-tutorial.md`.
- Load **AniVerse (Pony XL)** as the checkpoint.
- Paste a prompt from `docs/art-direction.md`:
  - **Faelen** — her prompt is locked. You also already have 19 hero-card
    renders in `docs/art-direction/`; you can crop one instead of generating
    fresh (skip to step 2).
  - **Kess / Momo / Thora / Dana** — draft prompts are in the house style;
    run, pick a keeper, lock the design.
  - **Enemies** (`stalker`, `hound`, `shade`, `husk`, `thornbound`,
    `guardian`) — draft creature prompts are in the "Enemy creatures" section.
- Sane starting settings: 832×1216 for characters (1024×1024 for creatures),
  Euler a / DPM++ 2M, ~25–30 steps, CFG ~6–7. Check the checkpoint's Civitai
  page for its own recommendations.

**Staying on-model across a set** (multiple expressions/poses of one
character): train a per-character LoRA from a 15–20 image set —
`docs/colab/gatefall_lora_training.ipynb` handles captioning + training, and
`gatefall_lora_inference.ipynb` loads it back into ComfyUI. Not required for a
single sprite per character.

### 2. Crop to a battle figure

The 832×1216 output is a full-body **hero card** — too tall for a 34–54px
battle chip. Crop to a **roughly square** bust/waist-up figure, framed the same
way across the whole cast (and facing the same direction) so the party row and
dialogue header stay tidy. This is the step that turns "reference art" into a
"sprite".

### 3. Remove the background (make it transparent)

The battle screen draws the sprite on its own lit plate; an opaque rectangle
reads as a sticker. Get a transparent PNG by either:

- **In ComfyUI:** add a background-removal / segmentation node (e.g. `rembg`)
  and save PNG with alpha; or
- **After the fact:** `rembg i in.png out.png`, or Photoshop / GIMP / Krita, or
  any web background remover.

### 4. Drop it in — no code change

Save with the exact name. No `pubspec.yaml` or Dart edit is needed; the folders
are already declared.

| What | Path |
|---|---|
| Party member | `gatefall_flame/assets/sprites/characters/<id>.png` |
| — ids | `player`, `faelen`, `kess`, `momo`, `thora`, `dana` |
| Enemy | `gatefall_flame/assets/sprites/enemies/<beastform>.png` |
| — forms | `stalker`, `hound`, `shade`, `husk`, `thornbound`, `guardian` |

Each folder's `README.md` restates the naming and export guidance.

#### Optional: expression variants (dialogue)

The dialogue portrait can show a per-line expression. Add variants named
`<id>_<emotion>.png`, e.g. `faelen_happy.png`, `faelen_sad.png`. They are used
when a scene node carries an `emotion` (see below); a missing variant falls
back to the neutral `<id>.png`, then to painted art. Suggested set (matches the
training images): `neutral` (this is just the base `<id>.png`), `happy`, `sad`,
`angry`, `flustered`.

To drive them, add an `emotion` key to a dialogue node in the scene JSON (under
`gatefall_dialogue_engine/data/` — and mirror into `gatefall_flame/data/`, the
two must match):

```json
{
  "id": "n3",
  "speaker": "faelen",
  "emotion": "flustered",
  "text": "That is not what I meant.",
  "next": "n4"
}
```

`emotion` is optional and purely presentational — the engine ignores it, and a
scene without it behaves exactly as before.

### 5. See it

```
cd gatefall_flame
flutter pub get
flutter run -d chrome        # or a device / emulator
```

The character's PNG now shows everywhere at once. Start with **Faelen**
(her style is locked), check it reads at chip size, then do the rest.

---

## Checking your framing: the proof sheet

`test/_preview.dart` writes visual proof sheets to `build/art-preview/`. It is
not part of the test suite (the leading underscore keeps `flutter test` from
picking it up) — run it by hand:

```
cd gatefall_flame
flutter test test/_preview.dart
```

The `sprites` shot puts each **sprite next to its painted fallback**, so you
can eyeball whether a crop sits right against what it replaces. With no PNGs
present both sides are identical (the shipping state); once you drop art in,
the left of each pair becomes your sprite.

---

## Notes and gotchas

- **Sprites are not element-tinted.** The painted `CreatureView` lights a
  creature in the gate's element colour; a PNG is drawn as-is. In-game the
  element colour comes from the *rift behind* the creature, so generate enemies
  in a neutral dark palette that reads against any element (see the enemy
  prompt notes).
- **Reactions still work over a sprite.** Hit-flash, floating damage, screen
  shake, HP-bar drain and the death collapse are separate layers, so a static
  sprite still flinches, takes numbers, and drops when it dies.
- **The opening comic is deliberately left on painted art** (`start_scene.dart`
  — an inked/halftone style). A semi-realistic render would clash there; wire
  it in only if you make comic-styled art for that sequence.
- **Keep the dialogue-engine `data/` and the flame `data/` mirror in sync** if
  you add `emotion` keys — `game_test.dart` fails if they drift.
- **I (Claude) can't generate the images.** Steps 1–3 run on your machine;
  this repo carries the prompts, the wiring, and this guide.
