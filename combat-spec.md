# GATEFALL — Combat & Raid System Spec

*The other half of the game. Everything in the story docs feeds this or is fed by it.*

---

## Design summary

| Decision | Value |
|---|---|
| Combat style | Idle auto-battler |
| Raid shape | One continuous push to a boss, 5–10 min |
| Party size | Player + 3 companions (4 total) |
| Positioning | Front/back row, **set before the raid**, locked during |
| Abilities | Auto-cast by default, **manual override** available |
| Strategy layer | **Elemental matchups** (roles are flavor, not hard dependency) |
| Failure | No punishment — you stop earning, retry freely |
| Offline | Cleared gates yield reduced-rate Mana; new gates need you present |

**The core insight:** because positioning is locked and abilities can auto-cast, the real strategy happens **before the raid** — in team composition, elemental planning, and formation. The raid itself is the *test* of decisions already made. That's a strong fit for idle, and it makes Bond matter: who you've invested in determines what you can field.

---

## 1. The raid loop

1. **Select a gate.** Each shows its **element**, recommended power, boss preview, and time remaining before it destabilizes.
2. **Compose.** Pick 3 companions (+ you), assign each to **front or back row**, review the elemental matchup warning.
3. **Fight.** The party auto-attacks and advances through waves toward the boss. Abilities fire automatically off cooldown unless you take manual control.
4. **Boss.** A single sustained fight. This is the wall.
5. **Resolve.** Win → gate closes, full Mana + gear drops. Lose → keep Mana earned up to the point you fell, gate stays open, retry whenever.

**Why losing is safe:** with no death penalty, a boss you can't beat isn't a punishment — it's a **growth target**. You go level companions, upgrade gear, raise Bond, and come back. That's the idle-RPG dopamine loop working as intended.

---

## 2. Positioning — front/back rows

Two rows, four slots (typically 2 front / 2 back, but any split allowed).

**Front row:** takes the majority of incoming attacks, deals more damage with melee-type abilities, takes more damage from area attacks.
**Back row:** heavily reduced incoming single-target damage, full effectiveness for ranged/support abilities, reduced effectiveness for melee.

| Character | Natural row | Why |
|---|---|---|
| **Faelen** | Front | Guard/taunt anchor — she's built to absorb |
| **Thora** | Front | Bulwark + healer, needs to be where the damage is |
| **Kess** | Front | High-speed striker; fragile, but melee-dependent |
| **Momo** | Back | Ranged caster, must be protected |
| **Dana** (Act 3) | Back | Wildcard support; late arrival, off-role |
| **Player** | Either | Your build decides — this is a real choice |

**The tension this creates:** Kess *wants* front row for damage but is fragile there — so she needs Faelen or Thora up front with her to survive. That's your "romance makes the party stronger" theme expressed as a formation puzzle, without requiring hard aggro/threat mechanics.

**One rule to keep it honest:** an all-back-row party should be viable-but-weak (no one absorbing, so damage leaks through and the fight drags), and an all-front party should be viable-but-fragile. No formation is *forbidden*; some are just better.

---

## 3. Elements — the main strategy layer

**Six elements**, each locked to a character as identity (never changeable — it's who they are):

| Element | Character | Fiction |
|---|---|---|
| **Verdant** | Faelen | Elven Warden magic — life, growth, binding |
| **Ember** | Kess | Fast, bright, burns hot |
| **Gloam** | Momo | Shadow/void — the gate-sense element |
| **Stone** | Thora | Endurance, earth, the hearth |
| **Sever** | Dana | Human mana — raw, unrefined, breaks patterns |
| **Tide** | *(unfilled)* | Reserved — see roster pressure below |

### The matchup wheel

Keep it a simple cycle so players can hold it in their head:

```
Verdant → Stone → Ember → Gloam → Tide → Verdant
   (each beats the next)
```

**Sever (human mana) sits outside the wheel** — it never gets a bonus and never takes a penalty. Fictionally perfect: human mana is unrefined and doesn't fit the otherworldly system. Mechanically it makes Dana a reliable neutral pick, which is exactly what a late-arriving wildcard should be.

### Damage modifiers

- **Advantage** (your element beats the gate's): **+30% damage dealt**
- **Neutral:** no change
- **Disadvantage** (gate's element beats yours): **−30% damage dealt**

Applied per-character, so a mixed party naturally hedges: bring one advantaged and one neutral character and you're never fully walled.

### Roster pressure — the thing to watch

With five characters and one element each, a gate that disadvantages your only viable pick is a wall with *no counterplay* — the player can't swap to an answer they don't own. Three mitigations, in order of importance:

1. **Never let disadvantage make a gate unwinnable.** −30% damage should mean "this takes noticeably longer," not "impossible." Tune boss HP so a fully-disadvantaged party can still clear a level-appropriate gate with patience — that's the promise of the no-fail-state design.
2. **Gate elements should rotate fairly.** Don't let the rotation stack three consecutive gates against the same element. Weight the generator against repeating a disadvantage the player just faced.
3. **This is what gacha is for.** Roster depth is the genuine value proposition for bonus characters — filling **Tide**, or giving a second **Ember** so you're not dependent on Kess. That makes pulls feel valuable without ever being *required*, which is the ethical line worth holding.

---

## 4. Abilities — auto by default, manual to optimize

Every character has:

- **Basic attack** — always automatic, never manual.
- **2 skills** — moderate cooldowns. Auto-cast off cooldown by default.
- **1 ultimate** — long cooldown, high impact. This is the one worth timing.

**Auto mode** (default): everything fires off cooldown. Perfectly playable, clears content you're geared for.
**Manual mode** (toggle): you hold abilities and tap to fire them. Correct timing — an ultimate saved for the boss phase, a heal held until the party is actually hurt — should be worth roughly **15–25% effective power**.

That gap is deliberate: enough that engaged players feel rewarded, small enough that idle players never feel *punished*. Never make manual mandatory — that breaks the genre promise.

### Ability progression ties to story

From the routes doc, each companion's kit mirrors their flaw and their **ascended ability mirrors the cure** — unlocked at their Beat 6:

| Character | Base kit (the flaw) | Ascended (the cure) |
|---|---|---|
| **Faelen** | Guard/taunt — absorbs alone | Buffs the whole party instead of only shielding it |
| **Kess** | Solo burst, over-extends | Damage scales off ally actions — combo-linked |
| **Momo** | Backline caster, draws danger | Party-wide foreknowledge; pre-empts ambushes |
| **Thora** | Heals everyone but herself | Reciprocal — party can heal *her*, she powers up |
| **Dana** | *(non-combatant)* | Awakens; off-role wildcard that rewrites synergy |

**This is the keystone.** Finishing someone's romance arc is a *combat power spike*. The two halves of the game resolve in the same moment.

---

## 5. Bond → combat buff

Bond tier (from the dialogue system, 0–6) gives a flat scaling stat bonus:

| Bond tier | Combat bonus |
|---|---|
| 0 | — |
| 1–2 | +5% / +10% ATK & HP |
| 3–4 | +15% / +20% ATK & HP |
| 5 | +25%, plus a passive tied to her arc |
| 6 | +30%, **ascended ability unlocked** |

Keep it a *meaningful boost, not a hard gate* — a tier-2 companion should still be usable. Otherwise you punish players for spreading their attention, which fights the player-driven-romance design.

---

## 6. Progression & scaling

**Three power tracks**, all feeding the same combat:

1. **Player level** — earned from raids. Unlocks and upgrades your own mana abilities. Gates your gear tier.
2. **Companion combat level** — bought with **Mana**. The main Mana sink.
3. **Gear** — dropped in raids, upgraded/enchanted with Mana. Equipped per character.

Plus **Bond** (above), which is earned through play rather than bought — the fourth, softest track.

### Gate difficulty tiers

Each gate has a **power rating**. Compare against your party's total power:

- **Well above yours:** clearly signposted as too strong. Player can still try — no fail state, so let them.
- **At/near yours:** the intended experience. A real boss fight, 5–10 minutes, tight.
- **Below yours:** fast clear. This is what feeds offline/idle progress.

**Scaling rule of thumb:** boss HP should scale slightly *faster* than player power, so each new gate tier is a genuine wall that a few days of leveling opens up. That's the growth-from-weakness fantasy from the bible, expressed as a curve.

---

## 7. Offline progression

**Recommendation: reduced-rate Mana from cleared gates only.**

- **Cleared gates** keep yielding Mana passively at **~50% of active rate**, capped at **8–12 hours** of accumulation.
- **Uncleared gates and bosses always require you to be present.** Progress is earned live; income accrues while away.
- **Gold** accrues separately via rent on its own timer (see the bible's economy section).

**Why this split:** it gives you something to come back to (the habit loop the genre runs on) without letting the game play itself past content you've never beaten. The cap is what makes a daily check-in feel worthwhile rather than optional. And it keeps your two currencies on distinct rhythms — Mana from the world outside the door, Gold from the house.

---

## 8. What the raid feeds back into the story

The `post_raid` trigger context already in the dialogue data hooks here directly:

- **Beat 2 for every character is a `post_raid` scene** — Faelen taking the killing blow, Kess overextending, Momo trying to flee, Thora collapsing. The raid *is* where their flaws get demonstrated.
- **Fighting together raises Bond**, so raiding advances romance passively — a player who only likes combat still progresses relationships.
- **Gate elements and the mystery**: Gloam gates should behave strangely and tie to Momo's arc; Verdant gates to Faelen's Warden past. Use gate flavor to seed the endgame mystery.

---

## 9. Build order (what to prototype first)

Don't build all of this at once. In order:

1. **One character, one gate, auto-battle to a boss.** No elements, no rows, no Bond. Just: does the core loop feel good to watch?
2. **Add the party of four + front/back rows.** Now composition matters.
3. **Add elements and the matchup wheel.** Now composition matters *strategically*.
4. **Add Mana rewards + companion leveling.** Now there's a reason to repeat.
5. **Add gear drops and upgrades.** Now there's a reason to repeat *a lot*.
6. **Wire in Bond buffs and the `post_raid` story hooks.** Now the two halves of the game connect.
7. **Add offline accrual last** — it's a multiplier on a loop that has to be fun first.

**The honest test after step 1:** watching an auto-battle should be satisfying *before* any of the systems layer on. If the base loop is boring, elements and gear won't save it — they'll just be numbers on top of boredom. Get step 1 genuinely good before building step 2.
