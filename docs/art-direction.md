# Art Direction

Working doc for AI-generated character art. Not locked — this is the
starting reference to keep prompts consistent once generation begins.

## What actually ships today (version 3)

The game is **not** waiting on the art below. Version 3 shipped a complete
generated art style: every companion is a hand-written silhouette painted by
`gatefall_flame/lib/art/character_art.dart` — flat dark shapes, an
element-lit outline, a glow behind — and the world (rifts, wave creatures,
the guardian, the ambient dust) is painted by `lib/art/gate_art.dart`. It is
a deliberate style, not a placeholder: it reads at 30 pixels, it costs
nothing to ship, and it cannot drift out of step with the roster.

Version 3.1 added a second generated style beside it: the **comic layer**
(`lib/art/comic.dart`) the opening is told in — inked panels with a hard
shadow and halftone tone, caption boxes, speech balloons with tails, and
lettering that is a stroked copy of the text under a filled one. It borrows
no assets and no fonts, and the pictures inside its panels are the same
painters as everything else. If rendered art ever lands, the comic panels
take it the same way every other screen does: they ask for a *widget*.

Everything below is still the plan for **rendered** art, and nothing here
forecloses it. A painted portrait can replace `CharacterPortrait` one
character at a time, because every screen asks for a *widget*, not for an
image — start with Faelen, whose reference is already locked below. Run
`flutter test test/_preview.dart` in `gatefall_flame/` to write proof sheets
of the current generated art to `build/art-preview/` if you want to see what
you are replacing.
See `docs/HANDOFF.md` for sequencing: **Faelen's model sheet first, to
lock overall style; the rest wait until the combat loop is proven**
(roughly step 3-4). All five companions are female; Dana is a human foil
(non-combat at first, possible late wildcard).

## Tools

- **Midjourney (niji 6 mode)** for model sheets and portraits. Use
  `--cref` (character reference) against the locked model sheet image to
  keep face/outfit consistent across expressions and later art instead
  of re-describing the character every time. Paid.
- **Stable Diffusion via ComfyUI, free** — local install, anime-tuned
  checkpoint (Illustrious or Pony Diffusion XL), unlimited generation,
  and the same LoRA-per-character path for consistency. See
  `docs/comfyui-tutorial.md` for setup. Recommended default if you
  don't want a Midjourney subscription.
- **LoRA per character** — worth it once a design is locked (Faelen's
  is) and you need pose/crop/expression to stay consistent, since a
  bare fixed seed drifts once the prompt's composition tokens change.
  Free path: `docs/colab/gatefall_lora_training.ipynb`, a Colab
  notebook using kohya-ss/sd-scripts. Needs a 15-20 image training set
  first — generate those via img2img at low denoise (~0.3-0.5) off
  the locked reference in the ComfyUI notebook, not fresh txt2img
  rerolls, so the identity stays close enough across the set to train
  on. See that notebook for the full workflow, including captioning
  and how to load the trained LoRA back into ComfyUI.
- Keep every locked prompt (below) copy-pasteable so art generation is
  reproducible across sessions/tools. Note: Midjourney prompts are
  natural-language; SD/Illustrious/Pony prompts are comma-separated
  **tags** (danbooru-style) — the two are not interchangeable, keep a
  version of each locked prompt per tool you actually use.

## Global style — LOCKED

Decided from Faelen's exploration pass (Pony Diffusion V6 XL). Not a
flat cel-shaded anime look — a **semi-realistic, mobile-gacha "hero
card" render style**: polished skin/hair rendering, dramatic rim
lighting, glossy highlights, cinematic vignette backgrounds. Closer to
gacha splash art than to cel-shaded anime.

- Line/render style: semi-realistic/photoreal-leaning shading, glossy
  highlights, sharp focus, ultra detailed — not flat cel shading.
- Palette/lighting mood: dramatic rim lighting, cinematic lighting,
  dark vignette backgrounds (often a blurred fantasy-city backdrop).
- Outfit language: practical fantasy armor/gear per character's
  element and role; **moderate coverage, not skimpy** — Pony leans
  toward deep cutouts/cleavage-forward armor by default (seen across
  early test renders), so every prompt should nudge back toward
  practical gear with tags like `high collar, closed neckline, full
  coverage armor, modest clothing, covered torso` plus matching
  negatives (`cleavage, exposed midriff, bare stomach, underboob,
  cutout armor, low-cut`). The target isn't zero skin shown — Faelen's
  locked look (below) keeps a soft neckline — just armor that reads as
  battle-practical rather than decorative/fanservice-cut.
- Crop: full-body "hero card" framing (not a tight bust/portrait crop)
  — see Faelen's locked prompt below.
- Resolution: 832x1216 (SDXL portrait) worked well for this framing.

## Asset checklist (per character)

1. **Model sheet** — front view, neutral pose, full outfit, locks
   proportions and species markers. Generate once, reuse as `--cref`
   source for everything else.
2. **Dialogue portraits** — bust/waist-up, transparent or simple
   background, expression set: neutral, happy, concerned/sad, angry,
   flustered/blushing (romance scenes).
3. **Battle sprite/icon** — simplified, readable at small combat-UI
   size. Pose should read the character's row (frontline melee stance
   vs. backline caster/ranged stance).
4. **Ultimate splash art** *(later)* — bigger action pose for the
   tap-triggered ultimate moment.
5. **Bond-event CG** *(later, cozy-side content)* — one or two
   illustrated scenes per companion for relationship milestones.

## Characters

Combat role and element are locked in `docs/combat-spec.md`; front/back
row affects battle-sprite pose (front row = melee stance close to the
action; back row = ranged/support stance, more distance/guard).

### Faelen — Elf, ex-Warden — LOCKED
- Role: frontline melee anchor. Row: front. Element: **Verdant**
  (life/growth/binding — elven Warden magic).
- Character notes: stoic, watchful, fights like penance. Ex-Warden who
  failed to protect her world.
- Visual starting point: elf ears, weathered/practical Warden-style
  armor or gear (not ornate), guarded posture even at rest, muted
  greens/naturals reflecting Verdant. **First character rendered —
  locked the house style** (see "Global style" above).
- Locked reference: `docs/art-direction/faelen_01_neutral.png` —
  green-cloaked leather/steel corset armor over a high-ish neckline,
  long silver-white hair, city-balcony backdrop. Supersedes the
  original `faelen-locked-v1.png` (deleted from the repo in `d426ece`;
  this is its confirmed replacement, not an accidental loss).
- Model sheet prompt (Midjourney, draft, not yet run):
  `[fill in — SD/Pony is the primary tool in use, this can wait]`
- Locked prompt (SD / Pony Diffusion V6 XL, full-body "hero card"
  framing):
  ```
  score_9, score_8_up, score_7_up, masterpiece, best quality, ultra
  detailed, 1girl, solo, elf, pointed ears, full body, long
  silver-white hair, tied back, pale skin, detailed skin texture,
  tired eyes, stoic expression, weathered leather and steel armor,
  high collar, closed neckline, full coverage armor, modest clothing,
  practical armor, covered torso, worn cloak, cloak clasp shaped like
  a closing gate, green glowing seams, photorealistic shading, glossy
  highlights, dramatic rim lighting, cinematic lighting, dark vignette
  background, blurred cityscape background, game character splash art,
  sharp focus

  Negative: chibi, deformed, extra limbs, extra fingers, blurry, lowres,
  watermark, signature, text, bad anatomy, flat lighting, cartoon, cel
  shading, cleavage, exposed midriff, bare stomach, underboob, cutout
  armor, revealing clothing, low-cut, bare shoulders
  ```
  Resolution: 832x1216. Checkpoint: Pony Diffusion V6 XL.
  See `docs/comfyui-tutorial.md` for how to run this.
- LoRA training-set: **19 images in `docs/art-direction/`**,
  `faelen_01_neutral.png` through `faelen_19_windswept_b.png`.
  Expression set (`01`-`06`) generated via img2img off the locked
  reference at denoise 0.3; pose/angle variety (`07`-`19`) at denoise
  0.55 — 0.3 barely shifted expression at all (low denoise mostly
  preserves the source's facial geometry) and fresh generation
  (denoise 1.0) broke outfit consistency (produced a full silver-plate
  variant, discarded), so 0.55 is the working sweet spot: enough
  freedom to change pose/angle while staying recognizably on-model.
  Hand-fixing individual images (manual inpaint, then
  ComfyUI Impact Pack's `FaceDetailer` + `UltralyticsDetectorProvider`
  auto-detect route) was tried and abandoned — not worth it for
  training data, since the LoRA learns identity from the set as a
  whole and minor per-image hand flaws don't get baked in the way a
  *repeated* flaw would. This set is ready to move to
  `docs/colab/gatefall_lora_training.ipynb` for captioning + training.

### Kess — Fox Beastkin, the hustler
- Role: fast DPS, fragile if caught. Row: front (wants it, but needs
  cover). Element: **Ember** (fast, bright, burns hot).
- Character notes: loud, quick, magnetic, adapted to Earth fastest —
  streaming/side-gigs, always broke, secretly saving to find her
  separated family.
- Visual starting point: fox ears + tail, streetwear/modern mixed with
  a scrappy improvised look, warm oranges/reds for Ember, dynamic/
  high-energy pose language.
- Draft prompt (SD / Pony Diffusion V6 XL, full-body "hero card"
  framing) — style locked to the house look, design not yet locked:
  ```
  score_9, score_8_up, score_7_up, masterpiece, best quality, ultra
  detailed, 1girl, solo, fox girl, animal ears, fox ears, fox tail,
  full body, messy orange-red hair, amber eyes, tan skin, detailed
  skin texture, confident grin, cocky expression, dynamic pose,
  modern streetwear layered with scrappy improvised leather armor,
  hooded jacket, fingerless gloves, high collar, closed neckline,
  full coverage armor, modest clothing, practical armor, covered
  torso, orange glowing ember seams, glowing gate-shaped pendant,
  warm orange and red palette, photorealistic shading, glossy
  highlights, dramatic rim lighting, cinematic lighting, dark
  vignette background, blurred cityscape background, game character
  splash art, sharp focus

  Negative: chibi, deformed, extra limbs, extra fingers, extra tails,
  blurry, lowres, watermark, signature, text, bad anatomy, flat
  lighting, cartoon, cel shading, cleavage, exposed midriff, bare
  stomach, underboob, cutout armor, revealing clothing, low-cut, bare
  shoulders
  ```
  Resolution: 832x1216. Checkpoint: Pony Diffusion V6 XL.

### Momo — Gloamkin, the quiet one
- Role: ranged spellcaster/support, gate-sense utility. Row: back.
  Element: **Gloam** (shadow/void — the gate-sense element).
- Character notes: small, bookish, whisper-soft, can feel gates and the
  wrongness leaking from them; may be central to the endgame mystery.
- Visual starting point: gloamkin trait (open question — pick something
  visually distinct, e.g. faint shadow/void motif around her, dim
  glowing eyes, or void-dark hair/markings), oversized/protective
  layered clothing, dark desaturated palette with a Gloam accent color.
- Gloamkin trait — proposed lock for the prompt below: **void-dark hair,
  dim violet glowing eyes, and faint glowing void-purple markings on the
  skin, with a soft shadow haze clinging around her.** This is the
  concrete choice the open question was waiting on; treat it as a
  candidate until the design is locked the way Faelen's is.
- Draft prompt (SD / Pony Diffusion V6 XL, full-body "hero card"
  framing) — style locked to the house look, design not yet locked:
  ```
  score_9, score_8_up, score_7_up, masterpiece, best quality, ultra
  detailed, 1girl, solo, full body, small petite figure, short
  stature, long void-black hair, dim glowing violet eyes, pale skin,
  detailed skin texture, faint glowing violet void markings on skin,
  soft shadow haze around her, shy expression, downcast look,
  oversized layered hooded robe, protective layered clothing, high
  collar, closed neckline, full coverage, modest clothing, covered
  torso, holding a small worn book, indigo and violet gloam accents,
  dark desaturated palette, photorealistic shading, glossy
  highlights, dramatic rim lighting, cinematic lighting, dark
  vignette background, blurred cityscape background, game character
  splash art, sharp focus

  Negative: chibi, deformed, extra limbs, extra fingers, blurry,
  lowres, watermark, signature, text, bad anatomy, flat lighting,
  cartoon, cel shading, cleavage, exposed midriff, bare stomach,
  underboob, cutout armor, revealing clothing, low-cut, bare
  shoulders, oversexualized, mature body
  ```
  Resolution: 832x1216. Checkpoint: Pony Diffusion V6 XL.

### Thora — Orc-kin, the heart
- Role: tank/healer, keeps the party standing. Row: **front** —
  confirmed against `docs/combat-spec.md`'s natural-row table (bulwark +
  healer, needs to be where the damage is). Element: **Stone**
  (endurance, earth, the hearth).
- Character notes: tall, warm, former clan healer who lost her people;
  mothers everyone; doesn't believe she deserves a second home.
- Visual starting point: orc-kin build (tusks, tall/sturdy frame),
  warm earthy palette for Stone, soft/nurturing details (an apron over
  armor, a healer's satchel) contrasted with obvious physical strength.
- Draft prompt (SD / Pony Diffusion V6 XL, full-body "hero card"
  framing) — style locked to the house look, design not yet locked:
  ```
  score_9, score_8_up, score_7_up, masterpiece, best quality, ultra
  detailed, 1girl, solo, orc, orc girl, small tusks, full body, tall
  muscular sturdy build, green skin, detailed skin texture, dark hair
  tied back, warm gentle smile, kind eyes, heavy earth-toned plate
  and leather armor, cloth apron over armor, healer's satchel, high
  collar, closed neckline, full coverage armor, modest clothing,
  practical armor, covered torso, amber glowing stone seams, glowing
  gate-shaped clasp, warm earthy brown and ochre palette,
  photorealistic shading, glossy highlights, dramatic rim lighting,
  cinematic lighting, dark vignette background, blurred cityscape
  background, game character splash art, sharp focus

  Negative: chibi, deformed, extra limbs, extra fingers, blurry,
  lowres, watermark, signature, text, bad anatomy, flat lighting,
  cartoon, cel shading, cleavage, exposed midriff, bare stomach,
  underboob, cutout armor, revealing clothing, low-cut, bare
  shoulders, skinny, frail
  ```
  Resolution: 832x1216. Checkpoint: Pony Diffusion V6 XL.

### Dana — Human, the foil
- Role: non-combat caseworker, possible late wildcard combatant. Element
  (if/when she fights): **Sever** — sits outside the elemental wheel,
  never advantaged/disadvantaged.
- Character notes: government integration caseworker, by-the-book,
  tired, suspicious; voices the world's prejudice early, softens over
  time; grounded human romance option.
- Visual starting point: plain-clothes/office-casual rather than
  fantasy gear (she's the one grounded, non-Awakened presence for most
  of the story), neutral/muted palette to contrast the other four's
  elemental colors.
- Draft prompt (SD / Pony Diffusion V6 XL, full-body "hero card"
  framing) — deliberately **no elemental glow and no fantasy gear**: she
  is the grounded human foil, so the render leans photoreal and plain.
  Style locked to the house look, design not yet locked:
  ```
  score_9, score_8_up, score_7_up, masterpiece, best quality, ultra
  detailed, 1girl, solo, human, full body, shoulder-length brown
  hair, tired eyes, guarded skeptical expression, realistic skin
  texture, plain office-casual clothing, buttoned blouse, blazer,
  slacks, lanyard id badge, high collar, closed neckline, modest
  clothing, covered torso, holding a clipboard, muted neutral grey
  and beige palette, no magic, photorealistic shading, glossy
  highlights, dramatic rim lighting, cinematic lighting, dark
  vignette background, blurred cityscape background, game character
  splash art, sharp focus

  Negative: chibi, deformed, extra limbs, extra fingers, blurry,
  lowres, watermark, signature, text, bad anatomy, flat lighting,
  cartoon, cel shading, cleavage, exposed midriff, bare stomach,
  underboob, cutout armor, revealing clothing, low-cut, bare
  shoulders, fantasy armor, glowing magic, elf ears, animal ears,
  weapon
  ```
  Resolution: 832x1216. Checkpoint: Pony Diffusion V6 XL.

## Open questions

- Momo's gloamkin trait now has a **proposed** visual (void-dark hair,
  dim violet eyes, glowing void markings, shadow haze — see her prompt);
  lock it the way Faelen's is before generating her full asset set.
- Thora's natural row is **confirmed front** against
  `docs/combat-spec.md` — her battle-sprite pose should read as a
  frontline bulwark, not a backline healer.
- House style is locked (see "Global style" above); Faelen's full
  asset set (dialogue portraits, battle sprite) still needs to be
  generated from the locked prompt. Kess, Momo, Thora, and Dana now
  have **draft** Pony prompts in the house style — run them, pick a
  keeper per character, and lock each design (locked reference image +
  LoRA set) the same way Faelen's was before treating any as final.
