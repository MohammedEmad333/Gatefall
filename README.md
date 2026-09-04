# Gatefall

Idle action-RPG × romance simulation. Gates tore open across the modern world.
Monsters came through, and so did refugees. You run a rundown building, take in
the people nobody else had room for, and clear gates for the mana to get strong
enough to keep them.

The house you are building and the power you are earning are the same fight
from two sides.

## Play it

```
cd gatefall_flame
flutter pub get
flutter run                      # device, emulator, or desktop
flutter run -d chrome            # in a browser
```

A first playthrough runs: take Faelen in, clear a Fracture, build a room for
whoever turns up next, read their scenes, raise bond by fighting and by gifts,
reach Act III, answer the question about the gates, and read the epilogue.
Progress saves automatically.

## Version 2 — "Ascension"

Finishing someone's route is now a combat power spike. Each companion's Beat 6
grants the transformed ability their story always promised — Faelen's oath
covers the whole party, Kess's strike loads off everything her allies did
while she waited, Momo reads the gate ahead and the party takes less for it,
Thora returns what the party put into her, and Dana — who moves in as a
non-combatant and cannot be deployed at all — awakens and joins the fight.

Ascension adds to a kit, it never replaces one, and nothing about it is
required: an un-ascended party still clears everything it could clear before.

## Android

`.github/workflows/build-apk.yml` builds a release APK on every push. Pushes
to `main` also publish it as a GitHub Release tagged with the `pubspec.yaml`
version; other branches leave it as a downloadable workflow artifact. The
Android platform files are generated in CI and are not committed.

See `docs/HANDOFF.md` for the full project handoff — premise, locked design
decisions, findings, and what to build next.

## Layout

- `docs/` — design docs (story bible, character routes, combat spec,
  dialogue data model, art direction, project handoff).
- `gatefall_dialogue_engine/` — pure-Dart branching dialogue engine, plus
  all five companion routes as JSON data. The canonical copy.
- `gatefall_flame/` — the game: Flutter app over a pure combat simulation,
  with the house, the gates, the party, the scene renderer and the endings.
