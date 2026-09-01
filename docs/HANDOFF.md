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
| `gatefall_flame/` | Flutter/Flame scaffold mirroring the prototype + balance tests; depends on `gatefall_dialogue_engine` (path dependency, step 6) for Bond/beat logic, with its own mirrored copy of the route JSON under `data/` since Flutter can't bundle assets from a pure-Dart path dependency |

---

## Build progress

- [x] **Step 1** — one character, auto-battle to a boss
- [x] **Step 2** — party of 4 + front/back rows, 2× speed unlock
- [x] **Step 3** — elements and the matchup wheel
- [x] **Step 4** — Mana rewards → companion leveling
- [x] **Step 5** — gear drops and upgrades
- [x] **Step 6** — Bond buffs + `post_raid` story hooks (buff and hook *detection* are real and tested; the raid screen still doesn't render a dialogue scene — see finding #10 and caveats)
- [ ] Step 7 — offline accrual

---

## Hard-won findings (do not revert)

Each of these was found by **simulating thousands of raids**, not by intuition.
Each is a real bug if undone. All are encoded in `test/balance_test.dart`.

1. **Faelen's Guard must be a TAUNT, not a self-shield.** With row-weighted targeting, damage spreads — a self-only shield sustains nobody. Every no-healer comp sat at **0% win rate** until Guard pulled aggro. Also perfectly on-theme: her flaw *is* the mechanic.

2. **The boss enrage ramp makes difficulty tunable at all.** Without it, sustain-vs-damage is a hard threshold — boss damage 44→48 flipped win rate from 100% to ~0%. The ramp turns a cliff into a race.

3. **Between-wave recovery + revive prevent a death spiral.** Otherwise one early death drops damage → longer fight → more deaths. They keep a bad formation *slower*, not unwinnable — which is what the no-fail-state promise requires.

4. **A party under 4 loses ~100%.** Fine as a visible choice (UI warns), never as a default. An early build shipped an unwinnable 3-member default.

5. **A multi-minute fight is impossible without sustain.** Fixed party HP + long fight = guaranteed death. First tuning pass was 0% for exactly this.

6. **Ending priority must run specific → generic.** A bond-threshold "bittersweet" fallback with no flag check will silently outrank a more specific "lost" ending if checked first. Fixed in all 5 route files.

7. **Elements (step 3) landed directly on the enrage cliff from finding #2.** A single disadvantaged character (−30% on one damage source) crashed a viable comp's win rate to ~15-23% at the old enrage rate — a wall, not "slower," which the elements spec explicitly forbids. Lowered `bossEnrage` 0.25 → 0.18: the same disadvantaged comp now clears ~97% of the time but still takes noticeably longer (~302s → ~342s), and every step-2 composition still clears 100% at full neutrality. Re-check this balance whenever ability power, HP, or the ±30% multipliers change.

8. **Companion leveling (step 4) had to stay a speed bonus, never a gate.** Combat spec §6 calls companion level "the main Mana sink" but the no-fail-state promise (finding #2/#7) means it must never become a required floor. `Progression.statMultiplier` is +4%/level, applied to attack, max HP, *and* ability power (a caster's damage is mostly her ability, so skipping abilities would make leveling near-invisible for Momo). At level 1 (the default) `_kessBack` still clears the same as before leveling existed; at level 10 the same comp's average clear drops from ~339s to ~240s. Cost curve is `40 * 1.18^(level-1)`, capped at level 20 (~4,937 cumulative Mana to max one character) — a real, long-running sink, not a same-session freebie.

9. **Gear (step 5) stacks *with* level rather than replacing it, and every win pays out.** Combat spec §2's resolve step says a win always drops gear (only losing withholds it) — so `_rollGearDrop()` isn't RNG-gated on top of the win, it always fires, only the *rarity* (common/rare/epic, weighted 65/28/7) is random. One slot per character, no inventory screen: a drop auto-equips only if it beats what's already worn (comparing `Gear.statMultiplier`, which folds in any enhance investment), otherwise it's salvaged into Mana on the spot — a "bad" drop is never a dead click. `Gear.statMultiplier` combines multiplicatively with `Progression.statMultiplier`, so a well-geared low-level character and a well-leveled ungeared one both feel the payoff. Same guardrail as leveling: a fully ungeared party still clears at the same rate as before gear existed.

10. **Bond (step 6) is real integration with the dialogue engine, not a reimplementation of its tier math.** `gatefall_flame` now depends on `gatefall_dialogue_engine` via a `path:` pubspec dependency and calls its actual `Evaluator.tierOf` / `Evaluator.nextAvailableBeat` — `BondBuff` only adds the combat-facing multiplier from combat-spec.md §5 (flat +5%/tier) on top of that one shared source of truth. Because the dialogue engine is a **pure-Dart package**, Flutter can't auto-bundle its `data/` assets from the path dependency; the route JSON is mirrored into `gatefall_flame/data/` (matching the asset paths the scaffold's `pubspec.yaml` had already declared, unused, since step 1) and loaded via `rootBundle`. That mirroring is a real duplication tradeoff — see caveats.
    - Bond is earned through play (a flat amount per raid clear, per companion deployed), never bought — the fourth, softest track per §6.
    - The `post_raid` story hook is *detection*, not playback: after a bond gain, `_awardBond()` calls the shared `nextAvailableBeat` and, if a newly-unlocked beat's `trigger_context` is `post_raid`, surfaces a one-line notification on the raid result screen. It does **not** render the beat's actual dialogue scene (no in-app scene renderer exists yet) or apply any of that scene's own choice-driven bond deltas/flags — see caveats for what that means for a companion's route staying stuck on an earlier `home_visit`/`gift`/`date` beat in this raid-only build.

### Current tuning (all compositions viable, speed/safety tradeoff)
| Composition | Win | Avg |
|---|---|---|
| Kess front, no healer | 96% | 316s |
| Kess back, no healer | 98% | 343s |
| With Thora healer | 100% | 418s |
| No tank | 100% | 336s |

---

## Known caveats

- A Dart + Flutter SDK is now available in the build environment (as of step 3). `gatefall_dialogue_engine` passes `dart analyze` clean; `gatefall_flame` passes `flutter analyze` clean and `flutter test` (33/33 as of step 6). Still never run on a device/emulator — expect to sanity-check the UI on first real `flutter run`.
- Gear (step 5) and Bond (step 6) are in-memory only, same as everything else — no save/load layer exists yet for any of Mana, levels, gear, or bond/completed-beats state. That's a pre-existing gap, not new to either step.
- `Row` was renamed to **`BattleRow`** in the Dart code to avoid colliding with Flutter's `Row` widget; the elements enum is likewise **`GateElement`**, not `Element`, to avoid colliding with Flutter's own `Element` (widget tree node) class.
- **Bond's `post_raid` hook realistically won't fire yet in a fresh playthrough.** Every companion's post_raid beat (e.g. `faelen_b2_proving_ground`) requires an earlier `home_visit` beat (e.g. `faelen_b1_the_wall`) to be completed first, and this raid-only screen has no way to trigger `home_visit`/`gift`/`date` beats — there's no house UI yet. So in practice a companion's `nextAvailableBeat` gets stuck on that earlier beat indefinitely here. The wiring is real and covered by a test that manually completes the prerequisite beats (see `balance_test.dart`'s bond group), but seeing it actually fire in the running app needs the house/dialogue UI this step didn't build. `gatefall_flame/data/` is a **manual mirror** of `gatefall_dialogue_engine/data/` — if a route JSON changes, copy it again; nothing keeps the two in sync automatically.

---

## Open question for the user

**Visual design / art direction has not started.** The user asked when to begin.
The recommendation given: **art direction exploration can start now in parallel**
(it has the longest lead time and character art is this genre's main selling
point), but **final asset production should wait until the loop is proven** —
roughly after step 3-4, when the systems that determine what art is *needed*
(how many characters, what poses, what UI states) are settled. Placeholder art
until then.

That conversation was left unfinished and is a good place to resume.

---

## Suggested next steps

1. **Play the prototype** and answer: does the formation choice feel meaningful, does an elemental disadvantage read as "slower" rather than "stuck," does spending Mana on a level-up or gear enhance feel like a real choice against the temptation to just re-raid, and does the single-slot auto-equip-or-salvage gear model feel satisfying without an inventory screen — or does it need one?
2. **A minimal house/dialogue screen.** This is the real gap left by step 6: Bond math and the `post_raid` hook are wired and tested, but there's nowhere in the app to trigger a `home_visit`/`gift`/`date` beat, so no companion's post_raid banter can actually fire in a live playthrough yet (see caveats). Even a bare-bones screen that walks a `DialogueEngine` through one beat's nodes would close the loop and let step 6 actually be felt, not just verified by test.
3. **Step 7: offline accrual.** Cleared gates yielding ~50% Mana while away, capped 8–12h (combat-spec.md §7).
4. **Art direction** — see open question above.
5. **Write real dialogue** for a beat, using the existing JSON schema, to lock a character's voice — now double as the first real content the house/dialogue screen above would render.
6. **Persistence** — Mana, companion levels, gear, and now bond/completed-beats are all in-memory only (see caveats). Worth a save/load layer before this goes much further, so playtesting progress survives a restart.
7. **De-duplicate `gatefall_flame/data/`** — it's a manual, one-time mirror of `gatefall_dialogue_engine/data/` (see caveats). Fine for now; worth a sync script or a real Flutter-package conversion of the dialogue engine before route JSON changes often.
