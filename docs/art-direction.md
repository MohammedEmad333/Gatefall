# Art Direction

Working doc for AI-generated character art. Not locked — this is the
starting reference to keep prompts consistent once generation begins.
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
- Locked reference: `docs/art-direction/faelen-locked-v1.png` —
  green-cloaked leather/steel corset armor over a high-ish neckline,
  long silver-white hair, city-balcony backdrop. Chosen over two other
  finalist renders as the most restrained/practical-reading of the
  three, closest fit to her "guarded, not decorative" character notes.
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
- LoRA training-set in progress, img2img off the locked reference
  (denoise 0.3): `docs/art-direction/faelen_01_neutral.png` through
  `faelen_05_flustered.png` (neutral, happy, sad, angry, flustered).
  **Not yet ready to train on as-is** — two open issues:
  1. Expression variance is subtle at denoise 0.3 (low denoise mostly
     preserves the source's facial geometry). Get real expression
     change via **inpainting the face region** at higher denoise
     (~0.6-0.75) instead of full-image img2img — see the workflow
     notes exchanged when this was hit, not yet written up as a
     doc section.
  2. The locked reference has a hand/finger rendering flaw (visible in
     the belt-buckle-hand crop) that's propagated into all 5 of these
     derivatives since they were generated before the fix. Inpaint the
     hand on the reference first (denoise ~0.5-0.6, positive tags
     `detailed hand, five fingers, natural fingers, clean fingernails`,
     matching negatives), then regenerate the expression set from the
     corrected reference before using any of it for LoRA training.
  Aim for ~15-20 total images (these 5 plus more pose variety) before
  moving to `docs/colab/gatefall_lora_training.ipynb`.

### Kess — Fox Beastkin, the hustler
- Role: fast DPS, fragile if caught. Row: front (wants it, but needs
  cover). Element: **Ember** (fast, bright, burns hot).
- Character notes: loud, quick, magnetic, adapted to Earth fastest —
  streaming/side-gigs, always broke, secretly saving to find her
  separated family.
- Visual starting point: fox ears + tail, streetwear/modern mixed with
  a scrappy improvised look, warm oranges/reds for Ember, dynamic/
  high-energy pose language.
- Model sheet prompt: `[fill in]`

### Momo — Gloamkin, the quiet one
- Role: ranged spellcaster/support, gate-sense utility. Row: back.
  Element: **Gloam** (shadow/void — the gate-sense element).
- Character notes: small, bookish, whisper-soft, can feel gates and the
  wrongness leaking from them; may be central to the endgame mystery.
- Visual starting point: gloamkin trait (open question — pick something
  visually distinct, e.g. faint shadow/void motif around her, dim
  glowing eyes, or void-dark hair/markings), oversized/protective
  layered clothing, dark desaturated palette with a Gloam accent color.
- Model sheet prompt: `[fill in]`

### Thora — Orc-kin, the heart
- Role: tank/healer, keeps the party standing. Row: back-leaning
  bulwark (confirm against combat-spec's natural-row table). Element:
  **Stone** (endurance, earth, the hearth).
- Character notes: tall, warm, former clan healer who lost her people;
  mothers everyone; doesn't believe she deserves a second home.
- Visual starting point: orc-kin build (tusks, tall/sturdy frame),
  warm earthy palette for Stone, soft/nurturing details (an apron over
  armor, a healer's satchel) contrasted with obvious physical strength.
- Model sheet prompt: `[fill in]`

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
- Model sheet prompt: `[fill in]`

## Open questions

- Momo's gloamkin trait isn't visually defined yet — needs a concrete
  choice before her model sheet.
- Confirm Thora's natural row against `docs/combat-spec.md`'s table
  before finalizing her battle-sprite pose.
- House style is locked (see "Global style" above); Faelen's full
  asset set (dialogue portraits, battle sprite) still needs to be
  generated from the locked prompt, then the same style applied to
  Kess, Momo, Thora, and Dana.
