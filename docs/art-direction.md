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
  of re-describing the character every time.
- **LoRA per character** (fal.ai, Civitai training, or local ComfyUI) —
  worth it once a design is locked and you need to mass-produce
  expression sets / battle sprites cheaply. Not needed for the
  exploration phase.
- Keep every locked prompt (below) copy-pasteable so art generation is
  reproducible across sessions/tools.

## Global style

*(Fill in once the first Faelen exploration pass lands. Suggested
starting point given the tone — modern-world urban fantasy, dating-sim
warmth colliding with rift-monster stakes — is a clean anime/semi-realistic
illustration style, not chibi, not painterly-realistic. Note the winner
here once decided.)*

- Line/render style:
- Palette/lighting mood:
- Outfit language (how "Earth" vs "otherworldly" reads in clothing):
- Resolution / aspect ratios needed: portrait bust (e.g. 1:1 or 3:4),
  battle sprite (small, square-ish, silhouette-readable)

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

### Faelen — Elf, ex-Warden
- Role: frontline melee anchor. Row: front. Element: **Verdant**
  (life/growth/binding — elven Warden magic).
- Character notes: stoic, watchful, fights like penance. Ex-Warden who
  failed to protect her world.
- Visual starting point: elf ears, weathered/practical Warden-style
  armor or gear (not ornate), guarded posture even at rest, muted
  greens/naturals reflecting Verdant. **This is the first character to
  fully render — locks the house style.**
- Model sheet prompt (draft, refine after first pass):
  `[fill in after style is chosen]`

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
- House style itself is undecided — resolve via Faelen's first pass,
  then backfill the "Global style" section above.
