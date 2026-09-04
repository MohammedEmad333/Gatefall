# Gatefall — the playable build

Idle action-RPG × romance simulation. Two halves that feed each other: the
**House** (Gold — rooms, gifts, dates, the seven-beat routes) and the
**Gates** (Mana — the auto-battler, levels, gear). **Bond** is the hinge,
earned by fighting together *and* by everything that happens at home, and it
gates the story while buffing the party.

This is a complete loop, start to ending: take Faelen in, clear a gate, build
a room for the next arrival, read their scenes, raise bond, reach Act III,
answer the gates, and read the epilogue.

## Run it

```
flutter pub get
flutter run                      # device, emulator, or desktop
flutter run -d chrome            # in a browser
```

Everything:

```
flutter analyze
flutter test                     # 90 tests: balance, systems, and widgets
```

### Build a web version you can just open

```
flutter build web --release --no-web-resources-cdn
```

`--no-web-resources-cdn` bundles CanvasKit into the build instead of loading
it from Google's CDN, so `build/web/` runs off any static file server with no
outbound network at all. Serve it with `python3 -m http.server` from that
directory and open the page.

## Structure

```
lib/
  combat/battle.dart          Pure simulation — no Flutter, no Flame, unit-testable
  data/combat_config.dart     Tuned constants, with the reasoning recorded
  data/roster.dart            Fighters, abilities, formation
  data/element.dart           The six elements and the matchup wheel
  data/gate.dart              Gate tiers, the board, element rotation
  data/progression.dart       Companion levels (Mana sink)
  data/gear.dart              Drops, rarity, enhancement (Mana sink)
  data/bond.dart              Bond tier -> combat buff
  data/house.dart             Residents, rooms, rent, dates (Gold)
  data/gifts.dart             The gift shop (Gold -> Bond)
  data/barks.dart             One-line reactions and idle lines
  data/story.dart             Acts, the gates decision, written endings
  data/companion_routes.dart  Loads routes and scenes from bundled JSON
  state/game_controller.dart  All game state, in one ChangeNotifier
  state/save_store.dart       Persistence (works on web, mobile and desktop)
  ui/                         theme, shell, house, gates, party, dialogue, ending
data/                         Route and scene JSON, mirrored from the engine
test/
  balance_test.dart           Simulated-raid regression tests (90 across all files)
  game_test.dart              Systems: save/load, economy, acts, endings, scenes
  widget_test.dart            The real screens, driven the way a player does
```

**The model is separate from the UI on purpose.** Balance changes can be
tested in milliseconds without rendering anything, and the same `Battle` class
drives the offline-progress maths. Keep it that way.

**Plain widgets, not FlameGame, also on purpose.** The open question is still
pacing and decision-feel, not presentation. Swap in `FlameGame` + sprite
components when you need sprites and particles — `battle.dart` won't change,
you just call `battle.tick(dt)` from Flame's `update()` instead of a `Timer`.

**The dialogue engine is not reimplemented here.** `gatefall_dialogue_engine`
is a path dependency; the house and the scene renderer call its real
`Evaluator` and `DialogueEngine` against one shared `GameState`, so the UI and
the story data can never disagree about what is unlocked.

## Gate tiers

One fixed difficulty could not survive the acquisition ramp: the house fills
one person at a time, and a party under four loses ~100% at the old tuning
(finding #4 below). So the *gate* scales, not the party.

| Tier | Built for | Enemy HP | Incoming | Mana | Gold | Unlocks at |
|---|---|---|---|---|---|---|
| Fracture | 2 | ×0.34 | ×0.44 | ×0.55 | +40 | 0 clears |
| Breach | 3 | ×0.62 | ×0.70 | ×0.80 | +70 | 2 clears |
| Rift | 4 | ×1.0 | ×1.0 | ×1.0 | +110 | 6 clears |
| Maw | 4, geared | ×1.55 | ×1.14 | ×1.8 | +190 | 14 clears |

Rift is exactly the old fixed difficulty, so every balance test written before
tiers existed still passes unchanged. The bottom tier is always on the board:
there is never a state with nothing you can clear.

## The tuning is simulated, not guessed

Constants came out of tens of thousands of simulated raids. Every full
composition clears, trading speed against safety.

| Composition (Rift, level 1, no gear) | Win rate | Avg time |
|---|---|---|
| Kess front, no healer | 96% | 316s |
| Kess back, no healer | 98% | 343s |
| With Thora (healer) | 100% | 418s |
| No tank | 100% | 336s |

And across tiers, with the progression a player actually has when each opens:

| | Fracture | Breach | Rift | Maw |
|---|---|---|---|---|
| Party of 2, level 1 | 100% / 236s | — | — | — |
| Party of 4, level 1 | 100% / 111s | 100% / 202s | 100% / 340s | — |
| Party of 4, Lv8 + rare gear | 100% / 65s | 100% / 121s | 100% / 197s | 100% / 306s |

## Findings that are load-bearing

Each was discovered by simulation, not intuition, and each is a real bug if
reverted. `test/balance_test.dart` encodes all of them.

**1. Faelen's Guard must be a TAUNT, not a self-shield.** With row-weighted
targeting, damage spreads across the party — so a shield that only protects
Faelen sustains nobody. Every no-healer composition sat at a **0% win rate**
until Guard began pulling damage onto her. It is also exactly her character:
she stands in front of everyone. Her flaw is the mechanic.

**2. The boss enrage ramp is what makes difficulty tunable.** Without a damage
ramp, sustain-vs-incoming is a hard threshold: below it you cannot lose, above
it you cannot win. Boss damage 44 → 48 flipped the win rate from 100% to ~0%.
The ramp converts that cliff into a race.

**3. Between-wave recovery and revive prevent a death spiral.** Without them,
one early death drops party damage, which lengthens the fight, which causes
more deaths. They keep a poor formation *slower* rather than unwinnable —
which is what the no-fail-state design promises.

**4. A party of fewer than 4 loses ~100% of the time** *at the Rift tier*.
That is fine as a visible player choice (every gate card states the party size
it is built for) and it is why the lower tiers exist at all.

**5. Elements sit directly on the enrage cliff.** A single disadvantaged
character costs ~30% of one damage source, which at the old enrage rate
crashed a viable comp to ~15-23%. Enrage dropped 0.25 → 0.18 to buy the margin
back. Re-check this whenever ability power, HP or the ±30% multipliers change
— and now, whenever a tier's multipliers change.

**6. Every power track is a speed bonus, never a gate.** Levels, gear and bond
all multiply into the same stats, and a party with none of them still clears a
tier built for its size. Losing costs nothing: you keep the Mana and the gate
stays open.

**7. Ending priority runs specific before generic.** A bond-threshold
"bittersweet" fallback with no flag check will silently outrank a more
specific "lost" ending if it is checked first.

## Speed

2× unlocks on your first clear, 4× at ten. Both are extra simulation steps per
frame rather than a shorter tick, so the physics are identical at every speed
and balance cannot drift between them.

## Offline

Cleared gates keep paying while you are away — four clears an hour at half
value, capped at ten hours, scaled by your best clear so far. Deliberately
well under what active play earns per hour: coming back is a head start, never
a substitute for playing.
