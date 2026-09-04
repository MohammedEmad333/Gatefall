# GATEFALL — Project Handoff

*Everything decided so far, where the files are, and what to do next.
Written so a fresh conversation can pick up without re-deriving anything.*

---

## What this is

A mobile game: **idle action-RPG × romance simulation**, inspired structurally
by *Cozy Landlord Life* but with a real combat loop as its engine.

**Premise.** Gates tore open across the modern world, connecting Earth to a
multiverse. Monsters came through — so did refugees (elves, beastkin, and
stranger folk from many different worlds). A fraction of ordinary humans
"awakened" with mana and the power to fight. You're one of them: nobody
special. You run a rundown building, take in the refugees nobody has room for,
and clear gates for the mana to grow stronger.

**The hook:** the house you're building and the power you're earning are the
same fight from two sides — making a place worth protecting, and becoming
strong enough to protect it.

---

## Locked design decisions

Do not re-litigate these unless the user asks; they're settled.

### World
- Gates connect to a **multiverse** — different gates, different worlds, different monsters.
- Gates **can't be permanently destroyed**. An individual gate is **closed by clearing it** in a raid.
- An **uncleared gate destabilizes and surges**, flooding the area with more monsters. So clearing is both income and civic duty.
- Some humans **awakened** with mana when the gates came. The player is one.
- Deeper mystery (endgame): *why* did the gates start?

### Combat
- **Idle auto-battler.** Party of **you + 3 companions**.
- **One continuous raid to a boss, 5–10 minutes.**
- **Positioning: front/back rows, set before the raid**, locked during.
- **Abilities auto-cast by default**, manual override available (optimization, never required).
- **Elements matter more than roles** — 6 elements, one locked per character, ±30% on matchups.
- **No fail state.** Losing costs nothing; you keep earned mana and the gate stays open.
- **Offline:** cleared gates yield ~50% Mana, capped 8–12h. New gates/bosses require you present.
- **2× speed** unlocked by clearing a gate once.

### Economy
- **Mana** — from monsters. Powers companion levels, player abilities, gear upgrades. ("The world outside the door.")
- **Gold** — from rent, drops, odd jobs. Powers house/room upgrades, furniture, gifts, dates. ("The world inside the door.")
- **Bond** — a per-character *stat*, not a currency. Earned via gifts, dates, dialogue, and fighting together. Gates romance beats **and** buffs her in battle.
- **Keystone:** romance makes your party stronger. The two halves feed each other.

### Characters
Five core companions, each with one **lie** and one **truth** — the route is the
distance between them. **Their combat kit mirrors their flaw; their ascended
ability mirrors the cure.**

| Character | Element | Role | Lie → Truth |
|---|---|---|---|
| **Faelen** (elf, ex-Warden) | Verdant | Front anchor | "closeness = failure" → "together = strength" |
| **Kess** (fox beastkin) | Ember | Fast DPS | "I must earn my place" → "home is who's already beside you" |
| **Momo** (Gloamkin) | Gloam | Caster | "I'm a danger to everyone" → "my curse is my shield" |
| **Thora** (orc-kin) | Stone | Tank/healer | "I only give" → "being cared for is what home is" |
| **Dana** (human caseworker) | Sever | Late wildcard | "rules keep us safe" → "connection is the only thing that works" |

**Tide** is a reserved 6th element, unfilled — that's roster-depth pressure gacha can relieve later.
**Sever sits outside the elemental wheel** (no bonus, no penalty) — human mana is unrefined. Makes Dana a reliable neutral pick.

### Story structure
- 7 beats per character: Recruitment → Wall → Proving Ground → First Truth → **Fracture** → Full Truth → Choice.
- **Beat 4 (the Fracture) is the ending engine** — the same 3-way choice grammar (`stop` / `join` / `release`) across all characters.
- 3 acts. Endings turn on two dials: **who you bonded with** × **what you did about the gates**.

### Acquisition
Three layers: **Encounter** (meet, gated by level+act) → **Settle** (needs a Gold-built room + recruitment quest) → **Unlock** (route beats open as Bond rises).
The core five are **guaranteed via story** — no missable main characters.
Future gacha: a pull grants the character, then a **character-specific unlock quest** (their Beat 0) makes them playable.

---

## Files delivered

### Design docs
| File | Contents |
|---|---|
| `story-bible.md` | World, cast, structure, economy, acquisition, gacha plan |
| `faelen-route.md` | Faelen's full 7-beat route **+ the reusable route template** |
| `companion-routes.md` | Kess, Momo, Thora, Dana full routes |
| `combat-spec.md` | Raid loop, rows, elements, abilities, progression, build order |
| `dialogue-data-model.md` | JSON schema for beats/scenes/flags/endings |

### Code
| File | Contents |
|---|---|
| `gatefall_dialogue_engine/` | Pure-Dart dialogue engine + **all 5 characters' routes as real JSON** (40 files) — the canonical copy |
| `gatefall_flame/` | **The game.** House, gates, party, dialogue and ending screens over the pure combat sim; depends on `gatefall_dialogue_engine` (path dependency) for all route/beat/ending logic, with its own mirrored copy of the route JSON under `data/` since Flutter can't bundle assets from a pure-Dart path dependency. See its README for the tier table and the tuning. |

---

## Build progress

- [x] **Step 1** — one character, auto-battle to a boss
- [x] **Step 2** — party of 4 + front/back rows, 2× speed unlock
- [x] **Step 3** — elements and the matchup wheel
- [x] **Step 4** — Mana rewards → companion leveling
- [x] **Step 5** — gear drops and upgrades
- [x] **Step 6** — Bond buffs + `post_raid` story hooks
- [x] **Step 7** — offline accrual
- [x] **Step 8 — the playable first version.** The raid prototype became a
  game: a house, a working dialogue renderer, the Gold economy, gate tiers,
  acts, endings, and persistence. Details below.

### What step 8 added

| Piece | What it is |
|---|---|
| **The house** (`ui/home_screen.dart`, `data/house.dart`) | Rooms bought with Gold settle a resident and fire their Beat 0. Rent accrues per resident per hour (12h cap); odd jobs give Gold on a 2-minute cooldown. Talk / Gift / Date per resident. |
| **The dialogue renderer** (`ui/dialogue_screen.dart`) | The gap step 6 left. Drives the real `DialogueEngine` over one shared `GameState`: branches, conditional inserts, flags, bond deltas, and marking the beat complete. Scenes render as a transcript, not one line at a time. |
| **The gift shop** (`data/gifts.dart`, `data/barks.dart`) | 15 items priced in Gold. Reactions come from each route's own `gift_preferences` via `reactionTierFor`, and pay the exact bond deltas in the data model (loved +20, liked +10, neutral +2, disliked −5). Barks are new written content, one pool per character per tier. |
| **Gate tiers** (`data/gate.dart`) | Four difficulties on a board you choose from. This is what makes the acquisition ramp shippable — see finding #11. |
| **Acts and endings** (`data/story.dart`, `ui/ending_screen.dart`) | Acts advance on both halves of the game at once, gating Beats 4 and 6. Act III asks the second ending dial (what you do about the gates), then the epilogue resolves every route through the shared `Evaluator.resolveEnding` and prints written prose for all 15 route endings plus 3 gate answers. |
| **Persistence** (`state/save_store.dart`) | One JSON blob via `shared_preferences`, so it works unchanged on web, mobile and desktop. Mana, Gold, clears, levels, gear, formation, settled residents, bond, flags, completed beats and act all survive a restart. |
| **Offline accrual** (step 7) | Four clears an hour at 50% value, capped at 10h, scaled by best clear so far. |
| **One state object** (`state/game_controller.dart`) | Every screen reads from and calls into a single `ChangeNotifier` that holds the dialogue engine's own `GameState`. |
| **A web build that just opens** | `flutter build web --release --no-web-resources-cdn` produces a `build/web/` that runs off any static file server with no outbound network. |

### Verification

`flutter analyze` is clean and **90 tests pass** (`flutter test`; 135 as of
version 3) — the original 33 unchanged, plus gate tiers, save/load round trips, offline
accrual, the house economy, gifts, acts, endings, scene-graph integrity, and
widget tests that drive the real screens the way a player does. The web build
was then loaded in Chromium and played: opening scene to completion, a gate
cleared, mana spent, a gift given, and the save surviving a reload, with no
console errors.

---

## Hard-won findings (do not revert)

Each of these was found by **simulating thousands of raids**, not by intuition.
Each is a real bug if undone. All are encoded in `test/balance_test.dart`.

1. **Faelen's Guard must be a TAUNT, not a self-shield.** With row-weighted targeting, damage spreads — a self-only shield sustains nobody. Every no-healer comp sat at **0% win rate** until Guard pulled aggro. Also perfectly on-theme: her flaw *is* the mechanic.

2. **The boss enrage ramp makes difficulty tunable at all.** Without it, sustain-vs-damage is a hard threshold — boss damage 44→48 flipped win rate from 100% to ~0%. The ramp turns a cliff into a race.

3. **Between-wave recovery + revive prevent a death spiral.** Otherwise one early death drops damage → longer fight → more deaths. They keep a bad formation *slower*, not unwinnable — which is what the no-fail-state promise requires.

4. **A party under 4 loses ~100%** *at the Rift tier*. Fine as a visible choice (every gate card states the party size it is built for), never as a default. An early build shipped an unwinnable 3-member default. Step 8's gate tiers are the general answer — see finding #11.

5. **A multi-minute fight is impossible without sustain.** Fixed party HP + long fight = guaranteed death. First tuning pass was 0% for exactly this.

6. **Ending priority must run specific → generic.** A bond-threshold "bittersweet" fallback with no flag check will silently outrank a more specific "lost" ending if checked first. Fixed in all 5 route files.

7. **Elements (step 3) landed directly on the enrage cliff from finding #2.** A single disadvantaged character (−30% on one damage source) crashed a viable comp's win rate to ~15-23% at the old enrage rate — a wall, not "slower," which the elements spec explicitly forbids. Lowered `bossEnrage` 0.25 → 0.18: the same disadvantaged comp now clears ~97% of the time but still takes noticeably longer (~302s → ~342s), and every step-2 composition still clears 100% at full neutrality. Re-check this balance whenever ability power, HP, or the ±30% multipliers change.

8. **Companion leveling (step 4) had to stay a speed bonus, never a gate.** Combat spec §6 calls companion level "the main Mana sink" but the no-fail-state promise (finding #2/#7) means it must never become a required floor. `Progression.statMultiplier` is +4%/level, applied to attack, max HP, *and* ability power (a caster's damage is mostly her ability, so skipping abilities would make leveling near-invisible for Momo). At level 1 (the default) `_kessBack` still clears the same as before leveling existed; at level 10 the same comp's average clear drops from ~339s to ~240s. Cost curve is `40 * 1.18^(level-1)`, capped at level 20 (~4,937 cumulative Mana to max one character) — a real, long-running sink, not a same-session freebie.

9. **Gear (step 5) stacks *with* level rather than replacing it, and every win pays out.** Combat spec §2's resolve step says a win always drops gear (only losing withholds it) — so `_rollGearDrop()` isn't RNG-gated on top of the win, it always fires, only the *rarity* (common/rare/epic, weighted 65/28/7) is random. One slot per character, no inventory screen: a drop auto-equips only if it beats what's already worn (comparing `Gear.statMultiplier`, which folds in any enhance investment), otherwise it's salvaged into Mana on the spot — a "bad" drop is never a dead click. `Gear.statMultiplier` combines multiplicatively with `Progression.statMultiplier`, so a well-geared low-level character and a well-leveled ungeared one both feel the payoff. Same guardrail as leveling: a fully ungeared party still clears at the same rate as before gear existed.

10. **Bond (step 6) is real integration with the dialogue engine, not a reimplementation of its tier math.** `gatefall_flame` now depends on `gatefall_dialogue_engine` via a `path:` pubspec dependency and calls its actual `Evaluator.tierOf` / `Evaluator.nextAvailableBeat` — `BondBuff` only adds the combat-facing multiplier from combat-spec.md §5 (flat +5%/tier) on top of that one shared source of truth. Because the dialogue engine is a **pure-Dart package**, Flutter can't auto-bundle its `data/` assets from the path dependency; the route JSON is mirrored into `gatefall_flame/data/` (matching the asset paths the scaffold's `pubspec.yaml` had already declared, unused, since step 1) and loaded via `rootBundle`. That mirroring is a real duplication tradeoff — see caveats.
    - Bond is earned through play (per raid clear, per companion deployed), never bought — the fourth, softest track per §6. Step 8 scaled the per-clear amount by gate tier (`10 + 5 × tier`), so fighting something worse together is worth more than farming the easiest gate on the board.
    - The `post_raid` story hook was *detection* only in step 6. Step 8 made it playback: the raid result screen offers the beat and the scene renderer plays it.

11. **Gate tiers are what make the acquisition ramp shippable.** The house fills one person at a time (Encounter → Settle → Unlock), so a real playthrough starts with a party of two — and finding #4 says a party under four loses ~100% at the one fixed difficulty everything was tuned for. Scaling the *gate* rather than the party squares that with the no-fail-state promise. Four tiers, simulation-tuned per party size, with the standard "Rift" tier left at exactly ×1.0 across HP, damage and Mana so **every balance test written before tiers existed still passes unchanged**. Tier 0 is always on the board: there is never a state with nothing you can clear. Re-check finding #7's element margin per tier whenever a multiplier moves — `balance_test.dart` does this automatically now.

12. **Acts must gate on both halves of the game, not one.** Beat 4 needs Act 2 and Beat 6 needs Act 3, so the act is what controls the timing of the emotional peaks. Gating it on raid progress alone would walk a player into a Fracture for someone they have no relationship with; gating it on beats alone would let an empty house reach Act 3. It takes residents settled *and* scenes played (plus, for Act 3, someone actually at bond tier 4). The UI always states what the next act is waiting for.

13. **A save must never restore into an unwinnable or unopenable state.** Two failures worth guarding, both now tested: a save whose JSON parses but whose *fields* are the wrong types must start a new game rather than throw on every launch; and a save with nobody settled must repair itself to Faelen-on-the-doorstep rather than hand the player a party of one (finding #4 again, arriving through the save file instead of the UI).

### Current tuning (all compositions viable, speed/safety tradeoff)

At the Rift tier, level 1, no gear — i.e. exactly the pre-tier numbers:

| Composition | Win | Avg |
|---|---|---|
| Kess front, no healer | 96% | 316s |
| Kess back, no healer | 98% | 343s |
| With Thora healer | 100% | 418s |
| No tank | 100% | 336s |

Across tiers, against the progression a player actually has when each opens:

| | Fracture | Breach | Rift | Maw |
|---|---|---|---|---|
| Party of 2, level 1 | 100% / 236s | — | — | — |
| Party of 4, level 1 | 100% / 111s | 100% / 202s | 100% / 340s | — |
| Party of 4, Lv8 + rare gear + bond 2 | 100% / 65s | 100% / 121s | 100% / 197s | 100% / 306s |

---

## Known caveats

- Dart + Flutter (3.47.2 / Dart 3.13.2) are available in the build environment. `gatefall_dialogue_engine` passes `dart analyze` clean; `gatefall_flame` passes `flutter analyze` clean and `flutter test` (116/116 as of v2.0.0). The game has been played end to end in Chromium against a real `flutter build web` with no console errors, but **still never run on a phone or emulator** — expect to sanity-check touch targets and safe areas on a first real device run.
- **There is no art.** Every screen is type, rule lines and colour. That is a deliberate placeholder, not a style decision — see the open question below.
- **The scenes are stubs.** Every beat's dialogue exists and plays, but most scenes are 2-6 nodes: enough to prove the schema and the renderer, nowhere near enough to carry a route emotionally. Writing real scenes is now the highest-value content work, and it needs no code changes.
- `Row` was renamed to **`BattleRow`** in the Dart code to avoid colliding with Flutter's `Row` widget; the elements enum is likewise **`GateElement`**, not `Element`, to avoid colliding with Flutter's own `Element` (widget tree node) class.
- **`gatefall_flame/data/` is a manual mirror** of `gatefall_dialogue_engine/data/` — Flutter can't bundle assets from a pure-Dart path dependency. Nothing copies it automatically, but `game_test.dart` now **fails if the two ever drift**, so at least the mirror can't go stale silently.
- **4× speed is an addition, not a locked decision.** The locked list names 2× only. 4× unlocks at ten clears because a 5-10 minute raid loop needs a second speed step once a player has cleared the same gate a dozen times. It is a presentation rate — the simulation still steps at `tickSeconds` — so it cannot affect balance. Easy to remove if unwanted.
- **Dana is a non-combatant until her route awakens her** — that is now the mechanic rather than a gap. She moves in, takes gifts and dates and scenes like anyone else, but the bench refuses her and `GameController.roster` leaves her out until `dana_b6_the_choice` completes. Her bond still can't be raised by raiding *before* that, which is intended: the route is the only road to the party slot.
- **Ascension is derived, never stored.** `GameController.ascended` reads `state.completedBeats` every time it is asked. That is deliberate — an old save ascends the moment it is loaded, there is no second source of truth to migrate, and nothing can drift out of sync with the routes. The cost is that it recomputes a small set on every read; if that ever matters, cache it on `completeBeat`, not in the save file.
- **Widget tests must boot inside `tester.runAsync`.** Loading routes and scenes is real file I/O, which never completes inside the FakeAsync zone a widget test body runs in. Without it the second test in a file hangs forever on a Future the fake clock will never advance — a genuinely confusing failure, so the helper in `widget_test.dart` carries the explanation.

---

## Open question for the user

**Visual design / art direction is still the open question.** The
recommendation stands and is now overdue rather than early: the loop is
proven, so the systems that decide what art is *needed* — how many characters,
what poses, what UI states — are settled. Every screen currently runs on type
and rule lines, which reads as deliberate and austere but is not what this
genre sells on.

Concretely, what the game now asks for: a portrait per companion with the five
expression variants already generated for Faelen (`docs/art-direction/`), a
room illustration or background per resident for the house, and a gate
backdrop per element. Nothing else is blocking.

---

## Version 2 — "Ascension"

Shipped as `gatefall_flame` **2.0.0+2**. One idea: *finishing a route is a
combat power spike*. It was the keystone in every design doc and the one
thing the code had never paid out.

- **`lib/data/ascension.dart`** is the whole feature's table of contents —
  who ascends, which beat grants it, the lie the base kit was built around,
  and the cure the new ability is. Granted by completing that route's Beat 6
  ("The Choice"), which the evaluator already gates behind bond tier 6 and
  Act 3, so reaching it means the story was actually told.
- **Five new `AbilityKind`s**, written as new kinds rather than bigger
  numbers, because each one is the *shape* of a route resolving:
  `rally` (Faelen shields and empowers everyone, not only herself),
  `link` (Kess's Chainbreak loads off every ally action since her last cast),
  `foresight` (Momo cuts incoming damage party-wide for a window),
  `reciprocal` (Thora returns the healing and shielding the party put into
  her, with interest), and `wildcard` (Dana rolls one of three effects).
- **Ascension adds, it never replaces.** The base kit survives, so no
  pre-v2 balance number changed meaning and no player has to relearn a
  character they just finished a route with. `flutter test` still passes the
  entire step-2 through step-7 suite unchanged.
- **Dana fights.** She has a `FighterDef` (Sever, back-row generalist, 1050
  HP) and her Beat 6 is the only thing that puts her in the roster. The
  formation tap refuses her before that, and a save that somehow carries her
  in the party is repaired on load.

---

## Version 3 — "Illumination"

Shipped as `gatefall_flame` **3.0.0+3**. One idea: *the game should look and
sound like itself, without waiting for an illustrator or a sample library.*
Everything visible and audible is generated from code in this repo.

- **The cast is drawn** (`lib/art/character_art.dart`). Each companion is a
  flat dark silhouette with an element-lit outline — Faelen's ears and cloak
  clasp, Kess's ears and tail, Momo as two lights inside a hood, Thora's
  tusks and braid, Dana's bob and lanyard, and the player faceless with a
  gate where a face would be. One painter, six builds, readable from 30px
  (a formation chip) to 130px (a dialogue header). An id with no look
  defined still draws, and `presentation_test.dart` fails if anyone in the
  roster or the house is missing one.
- **The world is drawn** (`lib/art/gate_art.dart`). Rifts turn — three
  counter-rotating rings, a lit tear, motes falling inward — in the element's
  own colour, on the gate board and in the fight. The five wave enemies and
  the guardian each have their own silhouette, keyed off the same wave index
  the simulation uses, so what is on screen is what is being fought.
- **The fight reacts** (`lib/art/effects.dart`). Hits flash the creature and
  float numbers off it, ultimates shake the screen, bars drain with a slower
  ghost behind them, ready abilities breathe, and the event log — which the
  simulation had always emitted and nothing had ever rendered — is finally
  on screen.
- **Sound is synthesised** (`tool/make_sounds.py`, `lib/audio/sfx.dart`).
  Twenty effects and two ambient beds, about a megabyte of WAVs, built from
  sine partials, filtered noise and a cheap reverb, with an equal-power
  crossfade so the beds loop without a click. The bus is fire-and-forget,
  rate-limited, gesture-gated for browsers, and disables itself rather than
  throwing if a platform has no audio.
- **The simulation barely moved.** `battle.dart` gained one field
  (`eventsEmitted`, a monotonic counter so a renderer can react to *new*
  events after the list is trimmed), an `amount` on each event, and finer
  event kinds (`heal`, `revive`, `boss`, `down`). Every step-2 through
  version-2 balance test passes unchanged.
- **Animation and tests coexist.** `Motion.ambient` is false under
  `flutter test` (detected via `FLUTTER_TEST` behind a conditional import,
  so nothing test-only leaks into the app), because an endless animation
  makes `pumpAndSettle` wait forever. One-shot animations stay on, so tests
  still settle *on* them.

`flutter analyze` is clean, **135 tests pass**, and `flutter build web
--release` compiles with the audio bundled.

---

## Suggested next steps

In the order that adds the most to the game as it now stands.

1. **Play it, then tune the pacing.** The whole loop is playable, so the
   questions are finally answerable by playing rather than by simulating: does
   choosing a gate off the board feel like a decision or a chore? Does bond
   climb too slowly between scenes? Is the Gold economy too tight early (one
   resident, 20 gold/hour, a 260-gold room) or too loose later? Every one of
   those is a constant in `data/house.dart`, `data/gate.dart` or
   `data/combat_config.dart`.

2. **Write real scenes.** This is now the highest-value work in the project
   and it needs no code. The renderer, the schema, the flags, the branching
   and the endings all work; most scenes are 2-6 nodes of placeholder. Start
   with one complete route — Faelen's, since her art exists — and let it set
   the length and voice standard for the rest.

3. **Tune the ascended kits against real play.** *(Shipped in v2.0.0 — see
   "Version 2" below.)* All five exist and are simulation-tested, but the
   numbers that decide how big a spike a finished route is — `linkPerStack`,
   `foresightReduction`, `reciprocalReturn`, `rallyAttackBonus` in
   `combat/battle.dart` — were tuned for "clearly felt, never required".
   Whether that is the right size is a question for playing, not simulating.

4. **A second ascended ability, or an ascended *passive*.** Each companion
   gets exactly one new button today. The routes describe transformations
   broad enough to justify changing how their base kit behaves too — Momo's
   sense pre-empting an ambush before it lands, say, rather than only a
   cooldown she presses.

5. **Art direction** — see the open question above. *(Version 3 shipped a
   complete generated art style — painted silhouettes, animated rifts,
   drawn creatures — so the game is no longer blocked on this. The
   rendered-splash-art path in `docs/art-direction.md` is still open and
   still worth doing: a painted portrait can replace `CharacterPortrait`
   one character at a time, because every screen asks for a widget, not for
   an image.)*

6. **Sprites, once there is art.** `battle.dart` is a pure simulation with no
   rendering in it, so swapping the raid screen for a `FlameGame` is a
   presentation change only: call `battle.tick(dt)` from Flame's `update()`
   instead of the `Timer`. *(Version 3 did the whole presentation layer in
   `CustomPainter`s instead and did not need this; it is now only worth it
   if you want thousands of particles.)*

7. **De-duplicate `gatefall_flame/data/`.** Still a manual mirror of the
   canonical route JSON, though `game_test.dart` now fails loudly if the two
   drift. A sync script or converting the dialogue engine into a real Flutter
   package would close it properly.
