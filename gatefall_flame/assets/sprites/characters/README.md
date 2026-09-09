# Character battle sprites

Drop a party member's rendered sprite here and the battle screen shows it in
place of the painted silhouette — no code change. Missing or broken art falls
back to the painter, so the game always renders.

## Naming

`assets/sprites/characters/<rosterId>.png`

| id       | who                          |
|----------|------------------------------|
| `player` | you (faceless, gate-for-a-face) |
| `faelen` | Faelen — elf, Verdant        |
| `kess`   | Kess — fox beastkin, Ember   |
| `momo`   | Momo — Gloamkin, Gloam       |
| `thora`  | Thora — orc-kin, Stone       |
| `dana`   | Dana — human, Sever          |

Example: `assets/sprites/characters/faelen.png`.

## Export guidance

- **Transparent PNG** (background removed). The battle screen draws the sprite
  on its own lit plate; an opaque rectangle reads as a sticker.
- **Roughly square framing**, consistent across the set — sprites are scaled
  into fixed 34–38 px boxes on the battle screen, so a bust/waist-up crop that
  sits the same way in each file keeps the party row tidy.
- These are *battle* sprites, not the 832×1216 full-body hero cards in
  `docs/art-direction/` (those are LoRA training data). Crop/clean a hero-card
  render down to a battle-readable sprite before dropping it here.

The checkpoint the reference set was generated on is **Aniverse Pony XL** — see
`docs/art-direction.md` for the locked prompt and style.

No pubspec edit is needed: `assets/sprites/characters/` is already declared.
