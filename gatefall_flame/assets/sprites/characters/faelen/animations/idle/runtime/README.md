# Faelen Idle Runtime

Approved runtime contract for Faelen's idle animation.

- Frame count: 8
- Frame cadence: 190 ms
- Naming: `faelen_idle_01.png` through `faelen_idle_08.png`
- Format: transparent PNG (RGBA)
- Runtime activates only when the complete approved frame set is present.
- Missing or incomplete frame sets must fall back to the base character sprite.

Art requirements:
- Preserve Faelen's canonical face, hair, outfit, sword, and warden shield.
- Keep a consistent body scale and baseline across all frames.
- Idle motion should be subtle: breathing, cloth/hair settling, shield/sword micro-movement.
- No attack wind-up or large pose changes in the idle loop.
