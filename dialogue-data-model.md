# DIALOGUE & BRANCHING DATA MODEL

*How every route, beat, choice, and flag from the story docs becomes data the game reads — instead of hardcoded logic.*

---

## Design goals

1. **Content is data, not code.** Writers/you add dialogue by editing JSON, never touching Dart.
2. **One evaluator, many characters.** The same unlock logic checks Bond tier + story act + flags for every route.
3. **Beats already map cleanly.** The 7-beat frame (Recruitment → Wall → Proving Ground → First Truth → Fracture → Full Truth → Choice) becomes 7 data objects per character, each gated the same way.
4. **Flags are the memory.** Every meaningful choice writes a flag; every later beat can read one. This *is* how `FAELEN_FRACTURE` decides which Beat 5 variant plays, and later, which ending fires.

---

## 1. Global state (lives outside any single route)

```json
{
  "story_act": 2,
  "bond": {
    "faelen": 420,
    "momo": 180,
    "kess": 310,
    "thora": 90,
    "dana": 40
  },
  "flags": {
    "FAELEN_APPROACH": "press",
    "FAELEN_COMMAND_STYLE": "trust",
    "FAELEN_WARDEN_KNOWN": true,
    "FAELEN_FRACTURE": "join",
    "MOMO_APPROACH": null,
    "KESS_SEARCH_KNOWN": true
  },
  "gold": 12500,
  "mana": 3200
}
```

- `bond` is a raw point total per character. **Bond tier** is derived, not stored — a lookup table converts points to tier (see §5), so tuning thresholds later never touches saved flags.
- `flags` is one flat namespace, character-prefixed by convention (`FAELEN_...`) to avoid collisions. Values can be `true/false`, a string (for named branches like `"press" | "patience"`), or absent (`null`/unset = not yet reached).

---

## 2. Route & Beat schema

One JSON file per character. A **Route** is metadata + an ordered list of **Beats**.

```json
{
  "character_id": "faelen",
  "display_name": "Faelen",
  "gift_preferences": {
    "loved": ["whetstone", "bitter_tea", "star_map", "plain_meal"],
    "liked": ["tactics_book", "practical_clothing"],
    "disliked": ["luxury_item", "flattery_note", "fragile_decor"]
  },
  "beats": [ "...Beat objects, see below..." ],
  "endings": [ "...Ending objects, see §6..." ]
}
```

Each **Beat**:

```json
{
  "beat_id": "faelen_b1_the_wall",
  "order": 1,
  "title": "The Wall",
  "unlock_conditions": {
    "bond_tier_min": 1,
    "story_act_min": 1,
    "requires_flags": [],
    "requires_beats_complete": ["faelen_b0_recruitment"]
  },
  "trigger_context": "home_visit",
  "scene_ref": "scenes/faelen_b1_the_wall.json",
  "on_unlock_default_effects": {}
}
```

- `unlock_conditions` is the *only* thing the evaluator checks. Every field is optional — omit what you don't need (Beat 0 has no bond requirement, for instance).
- `requires_flags` supports both existence checks and exact-value checks, e.g. `{"flag": "FAELEN_FRACTURE", "equals": "join"}` — this is how Beat 5 depends on Beat 4's choice.
- `trigger_context` tells the game *where* this beat can surface: `"story"` (cutscene, plays automatically when unlocked), `"home_visit"` (player walks up to her in the house), `"gift"` (fires after a specific gift), `"date"` (a scheduled activity), `"post_raid"` (banter after clearing a gate together).
- `scene_ref` points to the actual dialogue graph — kept in a separate file so beat metadata (small, load-everywhere) is decoupled from dialogue text (large, load-on-demand).

---

## 3. Scene schema — the dialogue graph itself

A scene is a small state machine: **Nodes** (a line or block of dialogue) connected by **Choices** or straight `next` links.

```json
{
  "scene_id": "faelen_b1_the_wall",
  "start_node": "n1",
  "nodes": {
    "n1": {
      "speaker": "faelen",
      "text": "You're up early.",
      "next": "n2"
    },
    "n2": {
      "speaker": "player",
      "text": "(You find her leaving tea outside Momo's door after her nightmare.)",
      "next": "n3"
    },
    "n3": {
      "speaker": "faelen",
      "text": "Don't mistake this for kindness. Someone has to keep this house functioning.",
      "choices": [
        {
          "choice_id": "press",
          "text": "\"You don't have to hide that you care.\"",
          "next": "n4_press",
          "effects": { "set_flags": { "FAELEN_APPROACH": "press" }, "bond_delta": 15 }
        },
        {
          "choice_id": "patience",
          "text": "(Say nothing. Just nod.)",
          "next": "n4_patience",
          "effects": { "set_flags": { "FAELEN_APPROACH": "patience" }, "bond_delta": 10 }
        }
      ]
    },
    "n4_press": {
      "speaker": "faelen",
      "text": "...Tch. You see too much.",
      "next": "end"
    },
    "n4_patience": {
      "speaker": "faelen",
      "text": "...Thank you. For not asking.",
      "next": "end"
    },
    "end": { "end_scene": true }
  }
}
```

- A node either has `next` (linear) or `choices` (branch point) — never both.
- `effects` on a choice can carry `set_flags`, `bond_delta`, and (rarely) `unlock_beats` for a beat that should become available immediately rather than waiting for the next evaluator pass.
- Both branches converge back to `end`, but they don't have to — some beats (like Beat 4, the Fracture) should stay meaningfully different past the choice, including different follow-up nodes or even different `scene_ref` values for Beat 5.

**Conditional nodes/choices** (for callbacks to earlier choices) use the same `requires_flags` structure as beat unlocking:

```json
{
  "choice_id": "callback_press",
  "text": "\"Like you did with the tea.\"",
  "condition": { "requires_flags": [{ "flag": "FAELEN_APPROACH", "equals": "press" }] },
  "next": "n_callback"
}
```

This is how a Beat 3 conversation can quietly reference a Beat 1 choice without maintaining separate scene files per path.

---

## 4. Gifts — a lighter-weight hook into the same system

Gifts don't need the full graph — just a reaction lookup plus an optional bark:

```json
{
  "character_id": "faelen",
  "gift_reactions": {
    "loved":    { "bond_delta": 20, "bark_pool": ["faelen_gift_loved_01", "faelen_gift_loved_02"] },
    "liked":    { "bond_delta": 10, "bark_pool": ["faelen_gift_liked_01"] },
    "neutral":  { "bond_delta": 2,  "bark_pool": ["faelen_gift_neutral_01"] },
    "disliked": { "bond_delta": -5, "bark_pool": ["faelen_gift_disliked_01"] }
  }
}
```

`bark_pool` entries are single-node mini-scenes (one line, no branching) — cheap to write, reused across many gift-giving moments. Full **date** scenes (Beat 3's rooftop tea, Beat 3-equivalents for others) are just regular Beats with `trigger_context: "date"`.

---

## 5. Bond tier lookup

Keep this as one shared table, not per-character, so balancing is global:

```json
{
  "bond_tier_thresholds": [0, 60, 150, 280, 450, 650, 900]
}
```

`tier = index of highest threshold ≤ bond_points`. Tier 4 (`faelen_b4_the_fracture`, `bond_tier_min: 4`) needs 450+ points, for example. Designers only ever touch this one array to retune pacing across the entire cast at once.

---

## 6. Endings — the same flag/condition language, evaluated at Act 3

```json
{
  "endings": [
    {
      "ending_id": "faelen_true",
      "priority": 1,
      "conditions": {
        "requires_flags": [
          { "flag": "FAELEN_FRACTURE", "in": ["stop", "join"] },
          { "flag": "FAELEN_CONFESSED", "equals": true }
        ],
        "bond_tier_min": 6
      }
    },
    {
      "ending_id": "faelen_lost",
      "priority": 2,
      "conditions": {
        "requires_flags": [{ "flag": "FAELEN_FRACTURE", "equals": "release" }]
      }
    },
    {
      "ending_id": "faelen_bittersweet",
      "priority": 3,
      "conditions": { "bond_tier_min": 3 }
    }
  ]
}
```

Evaluate endings **in priority order**, first match wins — specific, flag-conditioned endings before the generic bond-threshold fallback. **Order matters here, not just labels:** "bittersweet" has no flag check at all, so if it were checked before "lost," a player who chose the release path but had built up bond some other way would incorrectly land on "bittersweet" instead — the fallback would silently outrank the more specific outcome. Put every ending with a `requires_flags` condition ahead of any purely bond-threshold fallback, regardless of what order they're drafted in.

---

## 7. The evaluator (pseudocode, engine-agnostic)

This single function drives beat availability, choice visibility, and endings alike:

```
function conditionsMet(conditions, state):
    if conditions.bond_tier_min and tierOf(state.bond[character]) < conditions.bond_tier_min:
        return false
    if conditions.story_act_min and state.story_act < conditions.story_act_min:
        return false
    for req in conditions.requires_flags:
        value = state.flags[req.flag]
        if req.equals and value != req.equals: return false
        if req.in and value not in req.in: return false
    for beat_id in conditions.requires_beats_complete:
        if beat_id not in state.completed_beats: return false
    return true

function nextAvailableBeat(character_route, state):
    for beat in character_route.beats (in order):
        if beat.beat_id not in state.completed_beats
           and conditionsMet(beat.unlock_conditions, state):
            return beat
    return null
```

Run `nextAvailableBeat` per character whenever bond/flags/act change (e.g., after a raid, a gift, an act transition) to decide what lights up as "available" in the house/quest UI.

---

## 8. Worked example, end to end

**Player gives Faelen a whetstone** → gift system looks up `"whetstone"` in her `loved` list → `bond_delta: +20`, a loved-gift bark plays.

**Bond crosses 60** → tier becomes 1 → evaluator re-checks Faelen's beats → `faelen_b1_the_wall` conditions (`bond_tier_min: 1`, `faelen_b0_recruitment` complete) are now met → it appears as available in the house.

**Player triggers it** (`trigger_context: "home_visit"`) → scene `faelen_b1_the_wall.json` plays → player picks **"press"** → `FAELEN_APPROACH = "press"` is written, `+15` bond.

**Much later, Bond hits tier 3 and Act 2 begins** → `faelen_b3_first_truth` unlocks → because `FAELEN_APPROACH == "press"`, a `condition`-gated callback line becomes available inside that scene, referencing the tea-and-Momo moment directly — a small continuity payoff built entirely from flags, no special-casing in code.

**Eventually Bond hits tier 4 in Act 2** → `faelen_b4_the_fracture` unlocks → player picks **"join"** → `FAELEN_FRACTURE = "join"` is written.

**At Act 3, with Bond tier 6 and `FAELEN_CONFESSED = true`** → the ending evaluator checks `faelen_true` first, conditions match, that ending fires.

Every step above is the *same* four building blocks — flags, bond tier, story act, and the one evaluator function — reused for every character with zero character-specific code.

---

## Engine integration notes (Flutter + Flame)

- Model this as plain Dart classes (`Beat`, `Scene`, `Node`, `Choice`) with `fromJson` constructors — straightforward, no special package needed.
- Keep `state` (flags/bond/act/gold/mana) in one `GameState` object, persisted via local save (and cloud sync later, given CLL's reviews about lost progress).
- Scene files can lazy-load on demand (`scene_ref`) so you're not holding every character's full dialogue tree in memory at once.
- The evaluator function translates 1:1 into a pure Dart function with no UI dependencies — easy to unit test beat-unlock logic independent of any rendering.
