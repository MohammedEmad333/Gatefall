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

## Version 3.1 — "Cold Open"

The game now opens by saying what it is. A new player used to land on a rent
panel with an elf already asleep upstairs and no idea why; they now get a
**six-page comic** first — the sky tearing, what came through it, what woke
up in a few ordinary people, the building you inherited, and the elf who
reaches your door still on her feet.

- **It is drawn the same way as everything else** (`lib/art/comic.dart`).
  Inked panels with a hard shadow, halftone screen tone, caption boxes,
  speech balloons with tails, and onomatopoeia on a burst — all painters and
  widgets, no imported art. The pictures inside the panels are the game's
  own: the same rift, the same cast, the same creatures.
- **It reads like a page, not a slideshow** (`lib/ui/start_scene.dart`). The
  whole page is laid out at once and revealed a panel at a time, so nothing
  reflows under you, and a tap while a line is still lettering finishes that
  line first.
- **It plays once.** `prologue_seen` is saved with everything else, and a
  save written before this existed defaults to *read* — an update never
  opens on a cutscene. `skip` is on every page, and `read the opening` at
  the bottom of the house plays it again without touching the save.

---

## Version 3 — "Illumination"

The game now looks and sounds like itself. Everything you see and hear is
**generated from code in this repo** — there is no art pack and no sample
library anywhere in it.

- **Art.** Every companion is a hand-written silhouette in a stained-glass
  style, drawn by a `CustomPainter` and lit in their own element: you know
  Faelen by her ears, Kess by hers, Momo by the two lights inside a hood.
  Gates are animated tears that turn, each element its own colour, and the
  five wave enemies and the guardian each have their own shape.
- **Animation.** The fight reacts: the creature flinches and flashes when
  it takes a hit, damage floats off it, the screen shakes for an ultimate,
  health bars drain instead of jumping, a ready ability breathes, and
  dialogue arrives a character at a time. Screens stage themselves in
  reading order rather than appearing all at once.
- **Sound.** Twenty effects and two ambient beds, all **synthesised** by
  `gatefall_flame/tool/make_sounds.py` — arithmetic in, WAVs out, about a
  megabyte in total. Every combat event has a voice; the house and the
  gates each have their own bed. Both switches (effects, ambience) live at
  the bottom of the house screen and are saved with everything else.

The simulation gained exactly one field for all of this
(`Battle.eventsEmitted`) plus an amount on each combat event. `battle.dart`
still knows nothing about how it is drawn.

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

### Signing — why it matters for saves

The APK is signed with a fixed upload key held in repository secrets. This is
not ceremony: Android refuses to install an update whose signature differs
from the installed app, and uninstalling to get around that deletes the app's
storage — which is where your save lives. Without a stable key, every CI run
generates a throwaway debug key, so no build could ever update another and
every update would cost the player their progress.

| Secret | What it is |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the keystore file, base64-encoded (`base64 -w0 upload.jks`) |
| `ANDROID_KEYSTORE_PASSWORD` | its store/key password |
| `ANDROID_KEY_ALIAS` | optional; defaults to `gatefall` |

The build signs with `apksigner` after Gradle rather than wiring a
`signingConfig` into Gradle, because `android/` is generated by
`flutter create` in CI and a Gradle edit would be a patch against a template
that moves between Flutter versions. The signing step verifies its own output
and fails if the APK is still debug-signed, and a push to `main` with no key
configured publishes nothing and says so on the run page.

To generate a keystore:

```
keytool -genkeypair -keystore upload.jks -storetype PKCS12 \
  -alias gatefall -keyalg RSA -keysize 4096 -validity 10950 \
  -dname "CN=Gatefall, O=Gatefall, C=US"
```

Keep it somewhere safe and backed up. Losing it means never being able to
ship an update that installs over an existing one.

See `docs/HANDOFF.md` for the full project handoff — premise, locked design
decisions, findings, and what to build next.

## Layout

- `docs/` — design docs (story bible, character routes, combat spec,
  dialogue data model, art direction, project handoff).
- `gatefall_dialogue_engine/` — pure-Dart branching dialogue engine, plus
  all five companion routes as JSON data. The canonical copy.
- `gatefall_flame/` — the game: Flutter app over a pure combat simulation,
  with the house, the gates, the party, the scene renderer and the endings.
  Its `lib/art/` draws the whole cast and world (including `comic.dart`, the
  panels and balloons the opening is told in), `lib/audio/` plays it, and
  `tool/make_sounds.py` regenerates every sound in `assets/audio/`.
