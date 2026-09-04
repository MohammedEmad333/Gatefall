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

See `docs/HANDOFF.md` for the full project handoff — premise, locked design
decisions, findings, and what to build next.

## Layout

- `docs/` — design docs (story bible, character routes, combat spec,
  dialogue data model, art direction, project handoff).
- `gatefall_dialogue_engine/` — pure-Dart branching dialogue engine, plus
  all five companion routes as JSON data. The canonical copy.
- `gatefall_flame/` — the game: Flutter app over a pure combat simulation,
  with the house, the gates, the party, the scene renderer and the endings.
