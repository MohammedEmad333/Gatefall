# Kess art assets

Kess production art and animation references selected from the approved Gatefall art pass.

## Canonical set

| Asset | Repository path | Role |
| --- | --- | --- |
| Kess full-body master | `kess_master.png` | Canonical visual identity source |
| Twin Ember Blades | `weapons/kess_twin_ember_blades.png` | Isolated weapon reference |
| Twin Ember Blades design sheet | `weapons/kess_twin_ember_blades_design_sheet.png` | Multi-view weapon/detail reference |
| Kess idle sheet | `animations/idle/kess_idle_sprite_sheet_v1.png` | Approved idle animation source |
| Kess rig v5 | `rig/kess_rig_cutout_v5.png` | Current rig/cutout source |
| Kess rig v4 | `rig/archive/kess_rig_cutout_v4.png` | Previous verified rig revision |

## Source identity

The selected source files uploaded for this pass are:

- `Kess_Master_Transparent_v1.png`
- `file_00000000ba6482108a5206cf6efb40da.png` — isolated Twin Ember Blades
- `file_00000000a5948210b0dee833fdb8d7de.png` — Twin Ember Blades design sheet
- `kess_idle_sprite_sheet_final.png`
- `Kess_Rig_Cutout_Sheet_v5.png`
- `Kess_Rig_Cutout_Sheet_v4.png`

Their SHA-256 checksums are recorded in `asset_manifest.json`.

## Production rules

- Treat `kess_master.png` as the Kess identity source of truth.
- Rig v5 is the active rig. v4 is retained only as a development/archive reference.
- The weapon design sheet is reference art, not a runtime sprite.
- The approved idle sheet is kept; rejected run/contact-pose generations remain excluded because they changed Kess identity and/or produced inconsistent mechanics.
- Do not promote generated animation art merely because it has a newer filename/version; it must first pass visual identity and frame-spacing review.
- The uploaded master PNG is currently flattened RGB artwork (no alpha channel), despite the source filename containing “Transparent”. Do not treat it as transparency-ready runtime art until a verified alpha version exists.
- Presentation/hero-card artwork should live under `reference/` and must not replace the canonical full-body master.

## Transfer state

The selected set and exact hashes are locked by the manifest on this branch. Binary files should only be considered transferred after their repository blobs match the recorded SHA-256 values.
