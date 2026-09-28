# Kess art assets

Kess production art and animation references selected from the approved Gatefall art pass.

## Canonical set

| Asset | Repository path | Role |
| --- | --- | --- |
| Kess runtime sprite | `../kess.png` | Transparent combat/dialogue sprite |
| Kess full-body master | `kess_master.jpg` | Canonical visual identity source |
| Twin Ember Blades | `weapons/kess_twin_ember_blades.jpg` | Isolated weapon reference |
| Twin Ember Blades design sheet | `weapons/kess_twin_ember_blades_design_sheet.jpg` | Multi-view weapon/detail reference |
| Kess idle sheet | `animations/idle/kess_idle_sprite_sheet_v1.jpg` | Approved idle animation source |
| Kess rig v5 | `rig/kess_rig_cutout_v5.jpg` | Current rig/cutout source |
| Kess rig v4 | `rig/archive/kess_rig_cutout_v4.jpg` | Previous verified rig revision |

## Runtime sprite

`assets/sprites/characters/kess.png` is the runtime-ready transparent sprite used by the existing `CharacterSprite` convention.

It is derived from the canonical Kess master by preserving the original RGB artwork and adding an alpha mask for the black background. The character itself is not redrawn or restyled. This keeps the approved identity intact while making the asset usable in combat and dialogue.

- Dimensions: 1024×1536
- Encoding: PNG / RGBA
- SHA-256: `d6111cdcab0e5e12408d1ad5ec42ae19a504f8febac2515ea609728f3f8967f5`
- Git blob: `370bab54512837131e6d00695a487c0b264d8213`

## Source identity

The six original uploaded sources were supplied with `.png` filenames, but byte inspection shows they are JPEG-encoded images. They are therefore stored in the repository with truthful `.jpg` extensions.

Source files:
- `Kess_Master_Transparent_v1.png`
- `file_00000000ba6482108a5206cf6efb40da.png` — isolated Twin Ember Blades
- `file_00000000a5948210b0dee833fdb8d7de.png` — Twin Ember Blades design sheet
- `kess_idle_sprite_sheet_final.png`
- `Kess_Rig_Cutout_Sheet_v5.png`
- `Kess_Rig_Cutout_Sheet_v4.png`

Their SHA-256 checksums are recorded in `asset_manifest.json`.

## Production rules

- Treat `kess_master.jpg` as the Kess visual identity source of truth.
- Use `../kess.png` as Kess's current runtime sprite.
- Rig v5 is the active rig. v4 is retained only as a development/archive reference.
- The weapon design sheet is reference art, not a runtime sprite.
- The approved idle sheet is preserved as an animation source, but is not yet runtime-ready because the supplied image is flattened JPEG artwork.
- Rejected run/contact-pose generations remain excluded because they changed Kess identity and/or produced inconsistent mechanics.
- Do not promote generated animation art merely because it has a newer filename/version; it must first pass visual identity and frame-spacing review.
- Presentation/hero-card artwork should live under `reference/` and must not replace the canonical full-body master.

## Transfer state

The six approved source assets plus the derived transparent runtime sprite are stored on this branch. The manifest locks both source hashes and runtime derivation metadata for traceability.
