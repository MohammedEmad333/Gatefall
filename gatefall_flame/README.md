# Gatefall — raid prototype (step 2)

Party of 4 with front/back rows, fighting through waves to a boss.
No elements, no Bond, no gear yet. This stage answers one question:
**does the formation decision feel like it matters?**

## Run it

```
flutter pub get
flutter run
```

Balance tests (pure Dart, no Flutter needed):

```
dart test
```

## Structure

```
lib/
  combat/battle.dart        Pure simulation — no Flutter, no Flame, unit-testable
  data/combat_config.dart   All tuned constants, with the reasoning recorded
  data/roster.dart          5 characters, abilities, default formation
  main.dart                 Flutter UI: formation screen + battle
test/
  balance_test.dart         Regression tests encoding the tuning decisions
```

**The model is separate from the UI on purpose.** You can test balance changes
in milliseconds without rendering anything, and the same `Battle` class can
later drive offline-progress calculations. Keep it that way.

**Plain widgets, not FlameGame, also on purpose.** The open question here is
pacing and decision-feel, not presentation. Swap in `FlameGame` + sprite
components once that's proven — `battle.dart` won't change, you just call
`battle.tick(dt)` from Flame's `update()` instead of a `Timer`.

## The tuning is simulated, not guessed

Constants came out of a few thousand simulated raids. Result: every full
composition clears (96-100%), but they trade speed against safety.

| Composition | Win rate | Avg time |
|---|---|---|
| Kess front, no healer | 96% | 316s |
| Kess back, no healer | 98% | 343s |
| With Thora (healer) | 100% | 418s |
| No tank | 100% | 336s |

That spread is the design goal: fast-and-fragile actually beats safe-and-slow
on time, and nothing is mandatory.

## Four findings that are load-bearing

Each of these was discovered by simulation, not intuition, and each is a real
bug if reverted.

**1. Faelen's Guard must be a TAUNT, not a self-shield.** With row-weighted
targeting, damage spreads across the party — so a shield that only protects
Faelen sustains nobody. Every no-healer composition sat at a **0% win rate**
until Guard began pulling damage onto her. It's also exactly her character:
she stands in front of everyone. Her flaw is the mechanic.

**2. The boss enrage ramp is what makes difficulty tunable.** Without a damage
ramp, sustain-vs-incoming is a hard threshold: below it you cannot lose, above
it you cannot win. Boss damage 44 → 48 flipped the win rate from 100% to ~0%.
The ramp converts that cliff into a race.

**3. Between-wave recovery and revive prevent a death spiral.** Without them,
one early death drops party damage, which lengthens the fight, which causes
more deaths. They keep a poor formation *slower* rather than unwinnable —
which is what the no-fail-state design promises.

**4. A party of fewer than 4 loses ~100% of the time.** The missing damage
lets the enrage outrun you. That's fine as a visible player choice (the UI
warns), but it must never be the default — an early build shipped a 3-member
default formation that was literally unwinnable.

`test/balance_test.dart` encodes all four so a future stat tweak can't
silently undo them.

## 2× speed

Unlocked by clearing the gate once, then toggleable. Implemented as two
simulation steps per frame rather than a shorter tick, so the physics stay
identical at both speeds and balance can't drift between them.

## What to add next

Per the combat spec's build order, and only once the formation decision feels
good:

1. Elements and the matchup wheel
2. Mana rewards → companion leveling
3. Gear drops and upgrades
4. Bond buffs + `post_raid` story hooks
5. Offline accrual
