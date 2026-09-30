# Faelen Attack Runtime

Approved runtime contract for Faelen's primary attack animation.

- Frame count: 8
- Frame cadence: 95 ms
- Naming: `faelen_attack_01.png` through `faelen_attack_08.png`
- Format: transparent PNG (RGBA)
- Runtime activates only when the complete approved frame set is present.
- Missing or incomplete frame sets must fall back to the base character sprite.

Motion requirements:
- Preserve Faelen's canonical face, white hair, green cloak, armor, sword, and warden shield.
- One-handed sword attack with the shield actively guarded, not discarded or swapped.
- Clear sequence: guard-ready → wind-up → forward step → primary slash → follow-through → guarded recovery.
- Keep body scale and baseline consistent across all frames.
- Keep sword, shield, hair, and cloak fully inside each frame with safe gutters.
