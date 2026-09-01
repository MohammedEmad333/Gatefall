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
| `gatefall_dialogue_engine.zip` | Pure-Dart dialogue engine + **all 5 characters' routes as real JSON** (40 files) |
| `gatefall_prototype.html` | **Playable step-2 prototype** — open in any browser |
| `gatefall_flame.zip` | Flutter/Flame scaffold mirroring the prototype + balance tests |

---

## Build progress

- [x] **Step 1** — one character, auto-battle to a boss
- [x] **Step 2** — party of 4 + front/back rows, 2× speed unlock
- [ ] **Step 3** — elements and the matchup wheel
- [ ] Step 4 — Mana rewards → companion leveling
- [ ] Step 5 — gear drops and upgrades
- [ ] Step 6 — Bond buffs + `post_raid` story hooks
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

### Current tuning (all compositions viable, speed/safety tradeoff)
| Composition | Win | Avg |
|---|---|---|
| Kess front, no healer | 96% | 316s |
| Kess back, no healer | 98% | 343s |
| With Thora healer | 100% | 418s |
| No tank | 100% | 336s |

---

## Known caveats

- **No Dart SDK was available in the build environment**, so the Flutter code is carefully written and reviewed but **never compiled**. The balance math was verified by porting the logic to Python and simulating. Expect to fix small compile errors on first `flutter run`.
- The HTML prototype **has** passed a real JS syntax check and is fully playable.
- `Row` was renamed to **`BattleRow`** in the Dart code to avoid colliding with Flutter's `Row` widget.

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

1. **Play the prototype** and answer: does the formation choice feel meaningful?
2. **Step 3: elements** — 6 elements, ±30% matchups, gate element rotation. Watch the roster-pressure problem (5 characters, one element each: never let a bad matchup be unwinnable, just slower).
3. **Art direction** — see open question above.
4. **Write real dialogue** for a beat, using the existing JSON schema, to lock a character's voice.
