# Kess art assets

Kess production art and animation references.

## Selected canonical set

The following source files were selected from the approved Gatefall art pass and define the intended repository layout:

| Source asset | Planned repository path | Use |
| --- | --- | --- |
| `Kess_Master_Transparent_v1.png` | `kess_master.png` | Canonical transparent full-body Kess identity source |
| `Twin Molten Ember Daggers.png` | `weapons/kess_twin_ember_blades.png` | Isolated Twin Ember Blades reference |
| `Fox-Eared Emberblade Warrior Reference Sheet.png` | `reference/kess_character_reference_v1.png` | Character/reference sheet |
| approved Gatefall Kess hero card | `reference/kess_hero_card.webp` | Presentation/concept reference only |
| `kess_idle_sprite_sheet_final.png` | `animations/idle/kess_idle_sprite_sheet_v1.png` | Approved idle animation source |
| `Kess_Rig_Cutout_Sheet_v4.png` | `rig/kess_rig_cutout_v4.png` | Current cutout/rig development reference |

## Production rules

- Treat `kess_master.png` as the visual identity source of truth.
- Keep transparent runtime/sprite assets separate from presentation artwork.
- The hero card is reference/presentation art and must not be used as a runtime sprite.
- Preserve original source files when deriving WebP previews or optimized runtime copies.
- Generated run-cycle/contact-pose attempts are intentionally excluded for now because character identity and/or run mechanics were not consistent enough for production use.
- Do not promote a newer rig sheet merely by version number; only replace v4 after a visually verified improvement.

## Transfer status

The catalog and destination structure are committed on this branch. The selected binary image files still need to be transferred into the paths above before this branch is ready to merge.
