# Gatefall Godot Battle Prototype

A standalone Godot 4 prototype for the side-view auto-battle loop. It lives beside the existing Flutter + Flame game and does not modify it.

## Run

1. Install Godot 4.3 or newer.
2. Import `gatefall_godot/project.godot` in the Godot Project Manager.
3. Press **F6** or **Run Project**.

No plugins or downloaded assets are required.

## Controls

- Tap/click **WARDEN'S OATH** (or press Space): party heal plus damage to all enemies.
- Tap/click **Ⅱ** (or press P): pause/resume.
- Tap/click **1× / 2×**: change battle speed.
- Tap/click **PLAY AGAIN** after victory or defeat.

## Included gameplay

- Four-character party led by Faelen
- Automatic target selection, movement, and attacks
- Melee and ranged attack distances
- Five increasingly difficult waves
- Rift Guardian boss in wave five
- HP bars, damage numbers, hit flashes, skill cooldown, pause, and speed controls
- Responsive 1280×720 canvas for desktop, web, and Android testing

The Faelen image is copied from the existing Flame asset as the same Git blob, so the file is not recompressed.

