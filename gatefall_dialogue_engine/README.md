# Gatefall Dialogue Engine — scaffold

A working implementation of the data model from `dialogue-data-model.md`:
Beats, Scenes, Choices, Conditions, and the one shared evaluator, plus
Faelen's complete route (all 7 beats) as real data to prove it out.

## Structure

```
lib/
  models/
    condition.dart       Condition + FlagRequirement — the shared gating language
    effects.dart          What a choice writes to state when picked
    dialogue_node.dart     DialogueNode + Choice — the scene graph pieces
    scene.dart            Scene — a full dialogue graph
    route.dart             Beat, Ending, GiftReaction, CharacterRoute
    game_state.dart         GameState — the one save-able object
  engine/
    evaluator.dart         Bond tier lookup, condition checks, next-beat/ending resolution
    dialogue_engine.dart    Walks a Scene node by node, applies effects

data/
  faelen_route.json         All 7 beats + endings
  kess_route.json           All 7 beats + endings
  momo_route.json           All 7 beats + endings
  thora_route.json          All 7 beats + endings
  dana_route.json           All 7 beats + endings
  scenes/
    faelen_b0_recruitment.json   through faelen_b6_the_choice.json
    kess_b0_recruitment.json     through kess_b6_the_choice.json
    momo_b0_recruitment.json     through momo_b6_the_choice.json
    thora_b0_recruitment.json    through thora_b6_the_choice.json
    dana_b0_recruitment.json     through dana_b6_the_choice.json
    (35 scene files total — one per beat, per character)

bin/
  demo.dart                Command-line walkthrough of the entire route
```

All five core companions — Faelen, Kess, Momo, Thora, and Dana — have
complete route data now: every beat, every choice, every ending, matching
`companion-routes.md` beat for beat. Dana's route deliberately bends the
pattern (her Beat 2 is bureaucratic, not combat) exactly as the routes doc
describes — nothing engine-side had to change to support that.

## Running the demo

This needs the Dart SDK (ships with Flutter — `flutter` on your PATH means
`dart` is too):

```
cd gatefall_dialogue_engine
dart run bin/demo.dart
```

It plays Faelen's full arc end to end: gives her gifts to cross each Bond
tier, runs each beat's dialogue (auto-picking a choice at every branch),
shows a conditional callback line firing because of an earlier choice, and
prints the resolved ending at the end. This is the same walkthrough as
Section 8 of the data model doc, just actually running.

## Using this in the real Flutter+Flame project

- Copy `lib/models/` and `lib/engine/` straight in — they have **zero
  Flutter dependency**, so nothing here needs to change.
- Swap `File.readAsStringSync()` (used in `bin/demo.dart` for a quick CLI
  demo) for `rootBundle.loadString('assets/data/...')` when loading from a
  real Flutter asset bundle. The JSON parsing and model code is identical.
- Wire `GameState` into your save system — it's already a plain
  `toJson()`/`fromJson()` object, so persisting it (locally first, cloud
  sync later) is a direct serialize/deserialize.
- Drive your house/quest UI off `Evaluator.nextAvailableBeat(route, state)`
  (or `allAvailableBeats` if you want to surface more than one at a time)
  — call it after anything that changes bond, flags, or story act.

## Writing a new character's route

1. Copy any existing `data/<character>_route.json` as a template — swap
   `character_id`, `gift_preferences`, and rewrite `unlock_conditions` per
   beat if the pacing should differ.
2. Write one scene JSON per beat under `data/scenes/`.
3. That's it — no engine code changes. The evaluator and dialogue engine
   are character-agnostic by design.

## A real bug this scaffold caught

Building all five routes surfaced an actual logic error in the original
ending-priority design (now fixed here and in the data model doc): a
generic bond-threshold "bittersweet" fallback with no flag check will
silently outrank a more specific "lost" ending if it's checked first,
because "first match wins" doesn't care how specific a match is — only
where it sits in the list. **Order endings from most specific
(flag-conditioned) to most generic (bond-only fallback).** Validated
across all five characters in `bin/demo.dart`'s logic (ported to Python
during scaffolding to check without a Dart runtime): a "cooperative" path
resolves to `<character>_true`, a "release" path resolves to
`<character>_lost`, for all five.

## Known simplifications (fine for a scaffold, worth knowing about)

- `bin/demo.dart` reads files with `dart:io` for simplicity — a real
  Flutter app should use asset loading instead (see above).
- Gift-giving in the demo is a bare bond-delta; a real game would also
  play a one-line "bark" from `bark_pool` (see the data model doc §4) —
  that's data you'll write per character, not an engine change.
- Bond tier thresholds (`Evaluator.bondTierThresholds`) are placeholder
  numbers — retune freely, it's one array.
