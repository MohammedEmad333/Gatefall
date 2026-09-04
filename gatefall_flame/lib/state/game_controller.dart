import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:gatefall_dialogue_engine/engine/evaluator.dart';
import 'package:gatefall_dialogue_engine/models/game_state.dart';
import 'package:gatefall_dialogue_engine/models/route.dart';

import '../audio/sfx.dart';
import '../combat/battle.dart';
import '../data/ascension.dart';
import '../data/barks.dart';
import '../data/combat_config.dart';
import '../data/companion_routes.dart';
import '../data/gate.dart';
import '../data/gifts.dart';
import '../data/house.dart';
import '../data/progression.dart';
import '../data/roster.dart';
import '../data/story.dart';
import 'save_store.dart';

/// Everything the game is, in one listenable object.
///
/// The screens are all thin: they read from here and call methods on here.
/// [GameState] (the dialogue engine's own persisted object) is held rather
/// than reimplemented — bond, flags, completed beats and the story act all
/// live there, so the evaluator and the UI can never disagree about what is
/// unlocked.
class GameController extends ChangeNotifier {
  GameController({SaveStore? store, Random? rng, DateTime Function()? clock})
      : _store = store ?? PrefsSaveStore(),
        _rng = rng ?? Random(),
        _now = clock ?? DateTime.now;

  final SaveStore _store;
  final Random _rng;
  final DateTime Function() _now;

  // ---------------- economy ----------------

  int mana = 0;
  int gold = 0;
  int clears = 0;

  /// The best single-raid Mana payout so far. Offline accrual is derived
  /// from it, so raiding a harder tier improves what you earn while away —
  /// the idle rate follows the player's actual power.
  int bestClearMana = 0;

  // ---------------- roster & loadout ----------------

  Map<String, BattleRow> formation = {'player': BattleRow.front};
  final Map<String, int> levels = {
    for (final f in Roster.all) f.id: Progression.minLevel
  };
  final Map<String, Gear?> gear = {for (final f in Roster.all) f.id: null};

  /// Residents who have moved in. Faelen is here from the first frame — she
  /// arrives on the doorstep, she is not a purchase.
  final Set<String> settled = {};

  // ---------------- story ----------------

  final GameState state = GameState();
  Map<String, CharacterRoute> routes = {};
  bool routesLoaded = false;

  /// Set once, in Act 3. The second ending dial.
  GateAnswer? get gateAnswer {
    final raw = state.flags[GateAnswerX.flagKey];
    return GateAnswer.values.where((a) => a.id == raw).firstOrNull;
  }

  // ---------------- session ----------------

  int speed = 1;
  bool autoCast = true;

  /// Whether the opening comic has been read. Saved, because the opening
  /// is an *introduction* — a returning player must never be made to sit
  /// through it again, and a save from before it existed has already been
  /// introduced by simply having been played.
  ///
  /// It starts false and only [_restore] and [markPrologueSeen] ever set
  /// it, which is why "start over" does not replay it: the flag is about
  /// this *player* having been introduced, not about this run. Re-reading
  /// it is a button on the house.
  bool prologueSeen = false;

  /// Version 3's two sound switches. They live here rather than in the
  /// audio bus because they are player state — they belong in the save
  /// beside auto-cast and speed, not in a singleton that forgets.
  bool sfxOn = true;
  bool musicOn = true;
  DateTime? _lastSeen;
  DateTime? _lastOddJob;
  DateTime? _rentSince;

  /// Set when a route's Beat 6 lands and the ascended ability is granted.
  /// Read and cleared by the UI so the power spike is announced where the
  /// scene ends, not buried in a stat panel.
  String? ascensionMessage;

  /// Set when returning to the app with something waiting. Cleared by the UI
  /// once shown.
  String? welcomeBackMessage;

  /// One-line results of the last raid, shown on the result screen.
  String? lastDropMessage;
  List<String> lastBondMessages = [];

  late final GateGenerator _gates = GateGenerator(rng: _rng);
  List<Gate> _board = const [];

  List<Gate> get board => _board;

  // ---------------- derived ----------------

  int get act => state.storyAct;

  /// Everyone who has finished their route's Beat 6 — "The Choice" — and so
  /// carries their ascended ability into a raid (version 2, see
  /// data/ascension.dart). Derived from completed beats rather than stored,
  /// so an old save ascends the moment it is loaded and nothing can drift.
  Set<String> get ascended => Ascension.from(state.completedBeats);

  bool isAscended(String id) => ascended.contains(id);

  /// True for a resident who lives here but cannot fight *yet* — Dana
  /// before her Beat 6. Her room is buyable long before that; what her
  /// route unlocks is the party slot.
  bool awaitingAwakening(String id) =>
      settled.contains(id) &&
      House.exists(id) &&
      !House.byId(id).deployable &&
      Ascension.exists(id) &&
      !isAscended(id);

  /// Deployable roster: the player plus every settled resident who fights.
  ///
  /// Version 2: "who fights" is no longer fixed at arrival. Dana ships
  /// `deployable: false` because she is not a fighter when she moves in;
  /// completing her route awakens her, and that is the only thing that puts
  /// her in the party.
  List<FighterDef> get roster => Roster.all
      .where((f) =>
          f.id == 'player' ||
          (settled.contains(f.id) &&
              House.exists(f.id) &&
              (House.byId(f.id).deployable || isAscended(f.id))))
      .toList();

  bool canDeploy(String id) => roster.any((f) => f.id == id);

  int get partyCount => formation.length;

  bool get speedUnlocked => clears >= CombatConfig.clearsToUnlockDoubleSpeed;
  bool get fastSpeedUnlocked => clears >= CombatConfig.clearsToUnlockFastSpeed;

  List<int> get speedOptions =>
      fastSpeedUnlocked ? const [1, 2, 4] : (speedUnlocked ? const [1, 2] : const [1]);

  int bondPoints(String id) => state.bondPointsFor(id);
  int bondTier(String id) => Evaluator.tierOf(bondPoints(id));
  int get maxBondTier => Evaluator.bondTierThresholds.length - 1;

  Map<String, int> get bondTiers =>
      {for (final id in CompanionRoutes.ids) id: bondTier(id)};

  int get completedBeatCount => state.completedBeats.length;

  int get highestBondTier => settled.isEmpty
      ? 0
      : settled.map(bondTier).fold<int>(0, (a, b) => a > b ? a : b);

  /// Residents who have turned up but not yet moved in.
  List<Resident> get encounteredNotSettled => House.residents
      .where((r) =>
          !settled.contains(r.id) && clears >= r.clearsToEncounter)
      .toList();

  /// Gold owed by residents since the last collection, capped.
  int get rentDue {
    final since = _rentSince;
    if (since == null || settled.isEmpty) return 0;
    final hours = _now().difference(since).inSeconds / 3600.0;
    final capped = min(hours, House.rentCapHours.toDouble());
    final perHour = settled
        .where(House.exists)
        .fold<int>(0, (a, id) => a + House.byId(id).rentPerHour);
    return (perHour * capped).floor();
  }

  bool get oddJobReady {
    final last = _lastOddJob;
    return last == null ||
        _now().difference(last) >= House.oddJobCooldown;
  }

  Duration get oddJobRemaining {
    final last = _lastOddJob;
    if (last == null) return Duration.zero;
    final left = House.oddJobCooldown - _now().difference(last);
    return left.isNegative ? Duration.zero : left;
  }

  // ---------------- beats ----------------

  /// The next beat this character can play, whatever its trigger context.
  Beat? nextBeat(String id) {
    final route = routes[id];
    if (route == null) return null;
    return Evaluator.nextAvailableBeat(route, state);
  }

  /// The next beat, but only if it fires in [context] — the question every
  /// screen actually asks ("is there a home_visit waiting for me here?").
  Beat? beatFor(String id, String context) {
    final beat = nextBeat(id);
    return beat != null && beat.triggerContext == context ? beat : null;
  }

  /// The first beat of a route that hasn't been played yet, whether or not
  /// it is currently unlocked.
  ///
  /// [nextBeat] returns null both when a route is genuinely finished and when
  /// the next beat is merely locked — very different things to a player, and
  /// conflating them told a companion's panel to read "her route is
  /// finished" one scene into a seven-beat route.
  Beat? upcomingBeat(String id) {
    final route = routes[id];
    if (route == null) return null;
    final sorted = [...route.beats]..sort((a, b) => a.order.compareTo(b.order));
    for (final beat in sorted) {
      if (!state.completedBeats.contains(beat.beatId)) return beat;
    }
    return null;
  }

  /// True only when every beat of the route has actually been played.
  bool routeComplete(String id) =>
      routes.containsKey(id) && upcomingBeat(id) == null;

  /// Why [upcomingBeat] is not playable yet, in the player's terms. Null when
  /// it is available now, or when there is nothing left to play.
  String? lockReason(String id) {
    final beat = upcomingBeat(id);
    if (beat == null) return null;
    if (nextBeat(id)?.beatId == beat.beatId) return null;

    final c = beat.unlockConditions;
    final needs = <String>[];
    if (c.bondTierMin != null && bondTier(id) < c.bondTierMin!) {
      final want = Evaluator.bondTierThresholds[
          c.bondTierMin!.clamp(0, Evaluator.bondTierThresholds.length - 1)];
      needs.add('bond tier ${c.bondTierMin}, ${want - bondPoints(id)} more');
    }
    if (c.storyActMin != null && act < c.storyActMin!) {
      needs.add('Act ${c.storyActMin}');
    }
    for (final b in c.requiresBeatsComplete) {
      if (!state.completedBeats.contains(b)) needs.add('an earlier scene');
    }
    for (final f in c.requiresFlags) {
      if (!f.isSatisfiedBy(state.flags)) {
        needs.add('a choice you have not made yet');
      }
    }
    if (needs.isEmpty) return 'not yet';
    return 'needs ${needs.toSet().join(", ")}';
  }

  /// Story beats across the whole cast that are ready to play now. These
  /// surface on their own rather than waiting behind a gift or a raid.
  List<({String characterId, Beat beat})> get pendingStoryBeats => [
        for (final id in settled)
          if (beatFor(id, 'story') case final b?) (characterId: id, beat: b),
      ];

  // ---------------- lifecycle ----------------

  Future<void> boot() async {
    routes = await CompanionRoutes.loadAll();
    await CompanionRoutes.preloadScenes(routes);
    routesLoaded = true;
    final saved = await _store.load();
    var restored = false;
    if (saved != null) {
      // A save written by an older build, hand-edited, or truncated mid-write
      // must not brick the app on every launch — losing a save is bad, being
      // unable to open the game at all is worse.
      try {
        _restore(saved);
        restored = true;
      } catch (e) {
        debugPrint('Gatefall: unreadable save discarded ($e)');
      }
    }
    if (restored) {
      _applyOfflineProgress();
    } else {
      _newGame();
    }
    _refreshBoard();
    _syncAct();
    applySoundSettings();
    notifyListeners();
    await persist();
  }

  /// Called by the UI when the opening has been read or skipped. Persists
  /// immediately: closing the app on the last panel must not cost the
  /// player the same six pages again.
  Future<void> markPrologueSeen() async {
    if (prologueSeen) return;
    prologueSeen = true;
    notifyListeners();
    await persist();
  }

  void _newGame() {
    // Faelen is the opening, not a purchase — she collapses on the step in
    // Act 1 and her Beat 0 plays the moment the player looks at the house.
    settled.add('faelen');
    formation = {'player': BattleRow.front, 'faelen': BattleRow.front};
    _rentSince = _now();
    _lastSeen = _now();
  }

  /// Restart from nothing. Used by the "start over" control on the house.
  Future<void> resetGame() async {
    mana = 0;
    gold = 0;
    clears = 0;
    bestClearMana = 0;
    settled.clear();
    for (final f in Roster.all) {
      levels[f.id] = Progression.minLevel;
      gear[f.id] = null;
    }
    state
      ..storyAct = 1
      ..bond.clear()
      ..flags.clear()
      ..completedBeats.clear()
      ..gold = 0
      ..mana = 0;
    _lastOddJob = null;
    welcomeBackMessage = null;
    ascensionMessage = null;
    lastDropMessage = null;
    lastBondMessages = [];
    speed = 1;
    _newGame();
    _refreshBoard();
    notifyListeners();
    await persist();
  }

  // ---------------- offline (combat-spec.md §7) ----------------

  /// "Cleared gates yield ~50% Mana, capped 8–12h. New gates/bosses require
  /// you present." Modelled as: while away, the gates you already know how
  /// to clear keep paying, at [CombatConfig.offlineClearsPerHour] clears an
  /// hour and [CombatConfig.offlineManaRate] of their value. Deliberately
  /// well under what active play earns per hour — coming back should feel
  /// like a head start, never like a reason not to play.
  void _applyOfflineProgress() {
    final since = _lastSeen;
    _lastSeen = _now();
    if (since == null || bestClearMana <= 0) return;

    final hours = _now().difference(since).inSeconds / 3600.0;
    if (hours <= 0.01) return;
    final capped = min(hours, CombatConfig.offlineCapHours.toDouble());
    final earned = (bestClearMana *
            CombatConfig.offlineClearsPerHour *
            CombatConfig.offlineManaRate *
            capped)
        .floor();
    if (earned <= 0) return;

    mana += earned;
    final h = capped.floor();
    final m = ((capped - h) * 60).round();
    final away = h > 0 ? '${h}h ${m}m' : '${m}m';
    welcomeBackMessage =
        'The gates you have already closed kept paying while you were away '
        '($away). +$earned mana.'
        '${hours > CombatConfig.offlineCapHours ? " Accrual caps at ${CombatConfig.offlineCapHours}h." : ""}';
  }

  // ---------------- house actions ----------------

  bool canAfford(int goldCost) => gold >= goldCost;

  /// Move a resident in. Returns their Beat 0 if it is ready to play, so the
  /// caller can push the scene straight away.
  Beat? settleResident(String id) {
    if (settled.contains(id)) return null;
    final r = House.byId(id);
    if (clears < r.clearsToEncounter) return null;
    if (gold < r.roomCost) return null;

    gold -= r.roomCost;
    settled.add(id);
    _rentSince ??= _now();
    if (r.deployable &&
        formation.length < CombatConfig.partyMax &&
        !formation.containsKey(id)) {
      formation[id] = BattleRow.back;
    }
    _syncAct();
    notifyListeners();
    persist();
    return beatFor(id, 'story');
  }

  int collectRent() {
    final due = rentDue;
    if (due <= 0) return 0;
    gold += due;
    _rentSince = _now();
    notifyListeners();
    persist();
    return due;
  }

  int workOddJob() {
    if (!oddJobReady) return 0;
    _lastOddJob = _now();
    gold += House.oddJobGold;
    notifyListeners();
    persist();
    return House.oddJobGold;
  }

  /// Buy a gift and give it immediately. Returns the bark to show, or null
  /// if it could not be afforded. Any `gift`-context beat that this unlocks
  /// is surfaced by the caller through [beatFor].
  String? giveGift(String characterId, GiftItem item) {
    if (gold < item.goldCost) return null;
    final route = routes[characterId];
    if (route == null) return null;

    gold -= item.goldCost;
    final tier = route.reactionTierFor(item.id);
    final delta = giftBondDelta[tier] ?? 0;
    state.addBond(characterId, delta);
    _syncAct();
    notifyListeners();
    persist();

    final sign = delta >= 0 ? '+$delta' : '$delta';
    return '${Barks.gift(characterId, tier)}\n\n($tier — $sign bond)';
  }

  /// Take someone out. Costs Gold, pays Bond, and is the natural place for a
  /// `date`-context beat to fire.
  String? goOnDate(String characterId) {
    if (gold < House.dateGoldCost) return null;
    gold -= House.dateGoldCost;
    state.addBond(characterId, House.dateBondReward);
    _syncAct();
    notifyListeners();
    persist();
    return '${Barks.date(characterId)}\n\n(+${House.dateBondReward} bond)';
  }

  // ---------------- progression ----------------

  void levelUp(String id) {
    final cost = Progression.costFor(levels[id] ?? Progression.minLevel);
    if (cost < 0 || mana < cost) return;
    mana -= cost;
    levels[id] = (levels[id] ?? Progression.minLevel) + 1;
    notifyListeners();
    persist();
  }

  void enhanceGear(String id) {
    final current = gear[id];
    if (current == null) return;
    final cost = current.enhanceCost;
    if (cost < 0 || mana < cost) return;
    mana -= cost;
    current.enhanceLevel++;
    notifyListeners();
    persist();
  }

  // ---------------- formation ----------------

  /// Tap cycles a unit: bench -> front -> back -> bench.
  /// The player can change rows but can never be benched.
  void cycleFormation(String id) {
    final def = Roster.byId(id);
    if (!formation.containsKey(id)) {
      if (partyCount >= CombatConfig.partyMax) return;
      // Version 2: a resident who has not been awakened yet cannot be
      // deployed at all, so the tap does nothing rather than smuggling a
      // non-combatant into the party.
      if (!canDeploy(id)) return;
      formation[id] = BattleRow.front;
    } else if (formation[id] == BattleRow.front) {
      formation[id] = BattleRow.back;
    } else {
      if (def.locked) {
        formation[id] = BattleRow.front;
      } else {
        formation.remove(id);
      }
    }
    notifyListeners();
    persist();
  }

  void setSpeed(int s) {
    speed = s;
    notifyListeners();
  }

  void setAutoCast(bool v) {
    autoCast = v;
    notifyListeners();
  }

  void setSfxOn(bool v) {
    sfxOn = v;
    Audio.instance.setSfxOn(v);
    notifyListeners();
    persist();
  }

  void setMusicOn(bool v) {
    musicOn = v;
    Audio.instance.setMusicOn(v);
    notifyListeners();
    persist();
  }

  /// Push the saved settings into the bus. Called once, at the end of boot.
  void applySoundSettings() {
    Audio.instance.sfxOn = sfxOn;
    Audio.instance.setMusicOn(musicOn);
  }

  // ---------------- raiding ----------------

  void _refreshBoard() {
    _board = _gates.board(clears,
        ownedElements: roster.map((f) => f.element).toList());
  }

  void rerollBoard() {
    _refreshBoard();
    notifyListeners();
  }

  Battle startRaid(Gate gate) {
    lastDropMessage = null;
    lastBondMessages = [];
    final b = Battle.fromFormation(
      formation,
      levels: levels,
      gear: gear,
      bondTiers: bondTiers,
      ascended: ascended,
      gateElement: gate.element,
      hpMult: gate.tier.hpMult,
      dpsMult: gate.tier.dpsMult,
      manaMult: gate.tier.manaMult,
      rng: _rng,
    )..start();
    b.autoCast = autoCast;
    return b;
  }

  /// Settle up after a raid. Mana is always kept (no fail state); gold, a
  /// gear drop and bond only land on a clear.
  void finishRaid(Battle b, Gate gate) {
    mana += b.manaEarned;
    if (b.status == BattleStatus.won) {
      clears++;
      gold += gate.tier.goldReward;
      bestClearMana = max(bestClearMana, b.manaEarned);
      _rollGearDrop();
      _awardBond(gate.tier);
      _refreshBoard();
    }
    _syncAct();
    _lastSeen = _now();
    notifyListeners();
    persist();
  }

  /// A win always drops gear (docs/combat-spec.md §2, resolve step). It goes
  /// to a random deployed character; if it isn't an upgrade over what
  /// they're already wearing, it's salvaged into Mana instead so the drop
  /// is never wasted.
  void _rollGearDrop() {
    if (formation.isEmpty) return;
    final ownerId = formation.keys.elementAt(_rng.nextInt(formation.length));
    final drop = Gear(rarity: GearDrop.roll(_rng).rarity);
    final current = gear[ownerId];
    final name = Roster.byId(ownerId).name;
    if (current == null || drop.statMultiplier > current.statMultiplier) {
      gear[ownerId] = drop;
      lastDropMessage = '${drop.rarity.label} gear dropped — equipped on $name.';
    } else {
      mana += drop.rarity.salvageValue;
      lastDropMessage =
          '${drop.rarity.label} gear dropped for $name — salvaged for '
          '+${drop.rarity.salvageValue} mana (their current gear is better).';
    }
  }

  /// Bond is earned through play, not bought — every deployed companion
  /// with route data gains per clear, scaled by how hard the gate was.
  /// Crossing a tier can unlock a beat; the raid result screen says so, and
  /// a `post_raid` beat is played right there.
  void _awardBond(GateTier tier) {
    lastBondMessages = [];
    final perClear = CombatConfig.bondPerClearBase +
        CombatConfig.bondPerClearPerTier * tier.index;
    for (final id in formation.keys) {
      final route = routes[id];
      if (route == null) continue;
      final before = nextBeat(id);
      state.addBond(id, perClear);
      final after = nextBeat(id);
      if (after != null && after.beatId != before?.beatId) {
        final name = Roster.byId(id).name;
        lastBondMessages.add(after.triggerContext == 'post_raid'
            ? '$name has something to say after this raid — "${after.title}".'
            : '$name\'s bond deepens — "${after.title}" is now available '
                '(${after.triggerContext}).');
      }
    }
  }

  /// The `post_raid` hook, now actual playback rather than detection: if a
  /// companion who fought has a post_raid beat ready, the result screen
  /// offers it and the scene renderer plays it.
  ({String characterId, Beat beat})? get postRaidBeat {
    for (final id in formation.keys) {
      final b = beatFor(id, 'post_raid');
      if (b != null) return (characterId: id, beat: b);
    }
    return null;
  }

  // ---------------- story ----------------

  /// Called by the dialogue screen once a scene reaches its end node. The
  /// scene's own effects (flags, bond deltas) were already applied by
  /// [DialogueEngine] against this same [state] as the player chose them.
  void completeBeat(String beatId) {
    final before = ascended;
    state.completedBeats.add(beatId);
    _onAscended(ascended.difference(before));
    _syncAct();
    notifyListeners();
    persist();
  }

  /// The moment the two halves of the game resolve together: a route ends
  /// and the party gets stronger for it. Anyone newly awakened is put into
  /// the formation if there is room, because a player who just finished
  /// Dana's route should not have to go and find the bench to see what
  /// changed.
  void _onAscended(Set<String> newly) {
    if (newly.isEmpty) return;
    final lines = <String>[];
    for (final id in newly) {
      final a = Ascension.byId(id);
      final name = Roster.byId(id).name;
      lines.add('$name — ${a.title}. ${a.cure}');
      final wasDeployable = House.exists(id) && House.byId(id).deployable;
      if (!wasDeployable &&
          !formation.containsKey(id) &&
          formation.length < CombatConfig.partyMax) {
        formation[id] = BattleRow.back;
        lines.add('$name is in the party now.');
      }
    }
    ascensionMessage = lines.join('\n\n');
  }

  void _syncAct() {
    final earned = Acts.actFor(
      settledCount: settled.length,
      completedBeats: completedBeatCount,
      highestBondTier: highestBondTier,
    );
    if (earned > state.storyAct) state.storyAct = earned;
  }

  String? get nextActRequirement => Acts.nextActRequirement(
        act: act,
        settledCount: settled.length,
        completedBeats: completedBeatCount,
        highestBondTier: highestBondTier,
      );

  void answerTheGates(GateAnswer answer) {
    state.flags[GateAnswerX.flagKey] = answer.id;
    notifyListeners();
    persist();
  }

  /// The finale is available once the gates have an answer — that is the
  /// last thing the house asks. Each route then resolves through the shared
  /// evaluator, priority order, specific before generic.
  bool get finaleAvailable => act >= Acts.maxAct && gateAnswer != null;

  Map<String, Ending?> resolveEndings() => {
        for (final id in settled)
          if (routes[id] case final r?) id: Evaluator.resolveEnding(r, state),
      };

  // ---------------- persistence ----------------

  Map<String, dynamic> toJson() => {
        'mana': mana,
        'gold': gold,
        'clears': clears,
        'best_clear_mana': bestClearMana,
        'settled': settled.toList(),
        'levels': levels,
        'gear': {
          for (final e in gear.entries)
            if (e.value != null)
              e.key: {
                'rarity': e.value!.rarity.index,
                'enhance': e.value!.enhanceLevel,
              }
        },
        'formation': {
          for (final e in formation.entries) e.key: e.value.name,
        },
        'state': state.toJson(),
        'last_seen': _now().toIso8601String(),
        'rent_since': _rentSince?.toIso8601String(),
        'last_odd_job': _lastOddJob?.toIso8601String(),
        'auto_cast': autoCast,
        'sfx_on': sfxOn,
        'music_on': musicOn,
        'prologue_seen': prologueSeen,
      };

  void _restore(Map<String, dynamic> json) {
    mana = json['mana'] as int? ?? 0;
    gold = json['gold'] as int? ?? 0;
    clears = json['clears'] as int? ?? 0;
    bestClearMana = json['best_clear_mana'] as int? ?? 0;
    autoCast = json['auto_cast'] as bool? ?? true;
    // A save from before version 3 has no sound settings, and the answer
    // for it is the same as for a new player: everything on.
    sfxOn = json['sfx_on'] as bool? ?? true;
    musicOn = json['music_on'] as bool? ?? true;
    // A save written before the opening existed belongs to someone who has
    // already met these characters. Default it to read, so an update never
    // opens on a prologue.
    prologueSeen = json['prologue_seen'] as bool? ?? true;

    settled
      ..clear()
      ..addAll((json['settled'] as List? ?? const []).cast<String>());

    final savedLevels = json['levels'] as Map? ?? const {};
    for (final f in Roster.all) {
      levels[f.id] = (savedLevels[f.id] as int?) ?? Progression.minLevel;
    }

    final savedGear = json['gear'] as Map? ?? const {};
    for (final f in Roster.all) {
      final g = savedGear[f.id] as Map?;
      gear[f.id] = g == null
          ? null
          : Gear(
              rarity: GearRarity
                  .values[(g['rarity'] as int? ?? 0).clamp(0, GearRarity.values.length - 1)],
              enhanceLevel: (g['enhance'] as int? ?? 0).clamp(0, Gear.maxEnhance),
            );
    }

    final savedFormation = json['formation'] as Map? ?? const {};
    formation = {
      for (final e in savedFormation.entries)
        if (Roster.all.any((f) => f.id == e.key))
          e.key as String: BattleRow.values
              .firstWhere((r) => r.name == e.value, orElse: () => BattleRow.front)
    };
    if (formation.isEmpty) formation = {'player': BattleRow.front};

    final savedState = json['state'] as Map<String, dynamic>?;
    if (savedState != null) {
      final s = GameState.fromJson(savedState);
      state
        ..storyAct = s.storyAct
        ..bond = s.bond
        ..flags = s.flags
        ..completedBeats = s.completedBeats
        ..gold = s.gold
        ..mana = s.mana;
    }

    _lastSeen = DateTime.tryParse(json['last_seen'] as String? ?? '');
    _rentSince = DateTime.tryParse(json['rent_since'] as String? ?? '') ?? _now();
    _lastOddJob = DateTime.tryParse(json['last_odd_job'] as String? ?? '');

    // A save written before Faelen was guaranteed, or one hand-edited into a
    // state with nobody home, would leave a party of one. Never ship that.
    if (settled.isEmpty) {
      settled.add('faelen');
      formation['faelen'] = BattleRow.front;
    }

    // Version 2 added a resident who is only deployable once her route
    // awakens her. A save that somehow carries her in the formation without
    // that — hand-edited, or written by a build where the rule differed —
    // must not field a non-combatant.
    formation.removeWhere((id, _) => id != 'player' && !canDeploy(id));
    if (formation.isEmpty) formation = {'player': BattleRow.front};
  }

  Future<void> persist() => _store.save(toJson());
}
