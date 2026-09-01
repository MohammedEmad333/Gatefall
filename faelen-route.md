# FAELEN — Full Character Route

*Elf, ex-Warden. Frontline anchor. The one who protects everyone by refusing to be protected.*
*This document doubles as the **reusable route template** — see the skeleton at the end.*

**Core arc:** Protecting people doesn't have to mean pushing them away.
**The lie she believes:** If she lets anyone close, she'll fail them the way she failed before.
**The truth she has to reach:** Standing *with* people is stronger than standing between them and the world.

---

## How the route is gated

Each beat unlocks at a **Bond tier** (raised via gifts, dates, dialogue, and fighting alongside her), sometimes also gated behind a **story act** or a **combat milestone**. Beats fire in order; the player controls the *pace* by how much they invest in her.

**Gift preferences** (so the player can learn her, which is itself characterization):
- **Loves:** whetstones and weapon-care kits, strong bitter tea, star maps *(the sky of a world she can't return to)*, plain home-cooked food.
- **Likes:** books on tactics and history, durable practical clothing.
- **Dislikes:** luxury and ornament, flattery, anything that reads as pity or pampering, fragile decorative things.

---

## Beat 0 — Recruitment: *"I won't be staying."*
**Gate:** Story (early Act 1).
You find her after a gate collapse — outnumbered, wounded, still standing over a fallen civilian she didn't know. She refuses shelter until she physically can't refuse, then accepts "for one night." One night becomes a room. She insists, coldly, that she'll leave the moment she's able.
- **Establishes:** her competence, her isolation, the sense she's *hunting* something.
- **Mechanical:** she joins the party as your first proper frontline. Tutorial for the guard role.

## Beat 1 — The Wall: *"Don't mistake this for kindness."*
**Gate:** Bond 1.
She trains before dawn, maintains everyone's gear without a word, and cooks for the house while denying she cares. You catch her leaving tea outside Momo's door after a nightmare. She deflects hard.
- **Choice:** **Press her** ("you don't have to hide that") **/ Let it go** (say nothing, just nod).
- **Flag set:** `FAELEN_APPROACH = press | patience`. Both are valid; they change *how* she opens up later, not whether. Pressing earns faster reveals but sharper early friction; patience earns slower, steadier trust.
- **Reveals:** the warmth under the ice is real, and it's the thing she's most afraid of.

## Beat 2 — The Warden's Discipline: *"Get behind me."*
**Gate:** Bond 2 + one gate cleared with her in the party.
A gate battle turns bad. She throws herself between the party and a killing blow, takes the hit, and refuses healing until everyone else is safe. Afterward she treats her own wound alone.
- **Choice:** **Order her to retreat next time** / **Trust her to make the call.**
- **Flag set:** `FAELEN_COMMAND_STYLE`.
- **Mechanical:** unlocks her signature **Guard / Taunt ultimate** — she pulls aggro and shields the party. Her kit literally *is* her flaw: she's built to stand in front of everyone and eat the damage.
- **Reveals:** her instinct to sacrifice herself first. Name the pattern; don't resolve it yet.

## Beat 3 — The First Truth: *"I was never a refugee."*
**Gate:** Bond 3 + a downtime/date scene.
A quiet night — rooftop, star map, bitter tea. She admits she didn't flee to Earth. She's a **Warden**, sworn to the gates of her own world, and she came through *chasing* something. She stops short of why. But the mask slips: she knows things about the gates no civilian should.
- **Choice:** **Ask what she's hunting** / **Tell her she doesn't owe you the story.**
- **Flag set:** `FAELEN_WARDEN_KNOWN = true` (this also unlocks a thread of the **main gate mystery** — Faelen is a lore key).
- **Reveals:** partial. The guilt is visible now; its shape isn't.

## Beat 4 — The Fracture: *"This is my war. Not the house's."*
**Gate:** Bond 4 + Act 2 (the danger escalates).
The thing she's been tracking surfaces near home. She packs in the dead of night to face it alone — to keep everyone else out of the blast radius. This is the **crux of the arc**: the exact moment her flaw becomes a decision.
- **Choice (the big one):**
  - **Stop her** — refuse to let her go alone.
  - **Go with her** — she doesn't get to carry it by herself.
  - **Let her go** — respect her wish, stand aside.
- **Flag set:** `FAELEN_FRACTURE = stop | join | release`. This flag weighs heaviest of all on her ending.
- **Reveals:** everything is about to hinge on whether she's ever been *chosen to stand beside* rather than left to stand alone.

## Beat 5 — The Full Truth: *"I gave the order. They followed it. They died."*
**Gate:** Bond 5 (reachable only if `FAELEN_FRACTURE = stop | join`).
In the aftermath, she finally breaks. Her old command fell because of a call she made; she's been running a private war of penance ever since, certain she forfeited the right to a home or a hand to hold. She confesses she let *you* close anyway — and it terrifies her.
- **Choice:** the confession beat. **Tell her the past doesn't disqualify her from being loved** / **Tell her you're not going anywhere, and prove it by staying, not speaking.**
- **Flag set:** `FAELEN_CONFESSED = true`. Romance locks in here for players pursuing her.
- **Reveals:** full. The lie is finally spoken aloud, which is the only way it can be beaten.

## Beat 6 — The Choice to Stay: *"Then I'll fight as one of you."*
**Gate:** Bond 6 + Act 3.
Her war and the house's fate collide. She must choose: finish it alone as the Warden she was (and likely fall), or fight it *with* the house as the person she's become. Your accumulated bond and choices decide whether she can accept that being protected isn't weakness.
- **Mechanical payoff:** if she stays, she unlocks her **true form / ascended ultimate** — one that **buffs the whole party** instead of only guarding it. The mechanics complete the theme: she stops being the wall in front of everyone and becomes the strength *within* everyone. Fighting together is, literally, her strongest state.

---

## Endings

Determined by two dials (per the bible): **her Bond + your choices**, crossed with the **world/gate outcome**.

- **True ending** — `FAELEN_FRACTURE = stop|join` + `FAELEN_CONFESSED` + high Bond: she lays down the penance and stays. Romantic union. She fights as family, strongest when protecting *and* protected. Her Warden knowledge helps resolve the gate mystery on the coexistence path.
- **Bittersweet ending** — moderate Bond, mixed choices: she survives and stays, but guarded; the war is quieted, not ended. A partial, hard-won peace.
- **Lost ending** — `FAELEN_FRACTURE = release` or low Bond: she leaves to finish her war alone. A short, quiet scene of the home she almost let herself have. The cost of never letting her in.

---

## Reusable Route Template

Strip Faelen out and this is the skeleton for every companion. Fill the blanks:

| Beat | Purpose | Bond gate | What it needs |
|------|---------|-----------|---------------|
| **0 — Recruitment** | How they arrive; first impression of their surface | Story | An entrance that shows their *mask* |
| **1 — The Wall** | The mask cracks once; deflection | Bond 1 | A small kindness they deny + a press/patience choice |
| **2 — Proving Ground** | Their flaw shown in action (often combat) | Bond 2 + combat | Unlock their signature ability = mechanical version of their flaw |
| **3 — The First Truth** | Partial secret revealed; a date beat | Bond 3 + downtime | Half the secret + a mystery/lore thread |
| **4 — The Fracture** | The flaw becomes a *decision*; the crux | Bond 4 + Act 2 | One heavy 3-way choice that drives the ending |
| **5 — The Full Truth** | The whole secret; confession; romance locks | Bond 5 (gated by Beat 4 choice) | The lie spoken aloud + a confession choice |
| **6 — The Choice** | Flaw resolved *or* not; mechanical payoff | Bond 6 + Act 3 | Ascended ability = mechanical version of the *cure* |
| **Endings** | True / Bittersweet / Lost | Bond + flags | Each tied to the crux flag from Beat 4 |

**The two design rules that make it work:**
1. **Every character has one lie and one truth.** The whole route is the distance between them. Faelen: *"closeness = failure"* → *"together = strength."*
2. **Their combat kit mirrors their flaw, and their final upgrade mirrors the cure.** This is what fuses your two genres — the romance arc and the power fantasy resolve in the same moment.

Give me any character's one-line arc and I can generate their full route on this frame.
