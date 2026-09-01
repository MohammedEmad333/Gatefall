import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gatefall_dialogue_engine/engine/evaluator.dart';
import 'package:gatefall_dialogue_engine/models/game_state.dart';
import 'package:gatefall_dialogue_engine/models/route.dart';

import 'combat/battle.dart';
import 'data/combat_config.dart';
import 'data/companion_routes.dart';
import 'data/gate.dart';
import 'data/progression.dart';
import 'data/roster.dart';

/// Step-2 raid screen: formation, then the auto-battle.
///
/// Note this is plain Flutter widgets, not a Flame render loop. That's
/// deliberate at this stage: the open question is whether the *loop* and the
/// formation decision feel good, and widgets get you there far faster. Swap in
/// FlameGame + sprite components once the pacing is proven and you actually
/// need sprites, particles, and animation — battle.dart won't change, you just
/// call battle.tick(dt) from Flame's update() instead of a Timer.
void main() => runApp(const GatefallApp());

const _night = Color(0xFF0D0B1A);
const _night2 = Color(0xFF151129);
const _rift = Color(0xFF6B4BD6);
const _riftDim = Color(0xFF3A2B73);
const _verdant = Color(0xFF5FD39A);
const _bone = Color(0xFFE8E4F0);
const _boneDim = Color(0xFF9B93B5);
const _blood = Color(0xFFD4536B);
const _gold = Color(0xFFE0B95F);

class GatefallApp extends StatelessWidget {
  const GatefallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gatefall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: _night,
        colorScheme: const ColorScheme.dark(primary: _rift, surface: _night2),
        fontFamily: 'Georgia',
      ),
      home: const RaidScreen(),
    );
  }
}

class RaidScreen extends StatefulWidget {
  const RaidScreen({super.key});

  @override
  State<RaidScreen> createState() => _RaidScreenState();
}

class _RaidScreenState extends State<RaidScreen> {
  Battle? battle;
  Timer? _timer;
  int totalMana = 0;
  int clears = 0;
  int speed = 1;
  bool autoCast = true;
  bool showFormation = true;

  Map<String, BattleRow> formation = Map.of(Roster.defaultFormation());

  final GateGenerator _gates = GateGenerator();
  late Gate gate = _gates.next();

  // Companion combat levels (step 4) — bought with Mana between raids.
  final Map<String, int> levels = {
    for (final f in Roster.all) f.id: Progression.minLevel,
  };

  // Gear (step 5) — one slot per character. A win always drops something;
  // it's either equipped (if it's an upgrade) or salvaged into Mana.
  final Map<String, Gear?> gear = {for (final f in Roster.all) f.id: null};
  final Random _dropRng = Random();
  String? lastDropMessage;

  // Bond (step 6) — earned through play (raid clears), not bought; feeds a
  // flat combat buff and unlocks post_raid story beats. docs/combat-spec.md
  // §5 and the "fourth, softest track" note in §6.
  static const int _bondPerClear = 12;
  final GameState gameState = GameState();
  Map<String, CharacterRoute> routes = {};
  final Map<String, Beat?> _nextBeat = {};
  List<String> lastBondMessages = [];

  Map<String, int> get bondTiers => {
        for (final id in routes.keys)
          id: Evaluator.tierOf(gameState.bondPointsFor(id)),
      };

  bool get speedUnlocked => clears >= CombatConfig.clearsToUnlockDoubleSpeed;
  int get partyCount => formation.length;

  @override
  void initState() {
    super.initState();
    CompanionRoutes.loadAll().then((r) {
      if (!mounted) return;
      setState(() {
        routes = r;
        for (final id in routes.keys) {
          _nextBeat[id] = Evaluator.nextAvailableBeat(routes[id]!, gameState);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Tap cycles a unit: bench -> front -> back -> bench.
  /// The player can change rows but can never be benched.
  void _cycle(String id) {
    setState(() {
      final def = Roster.byId(id);
      if (!formation.containsKey(id)) {
        if (partyCount >= CombatConfig.partyMax) return;
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
    });
  }

  void _levelUp(String id) {
    final cost = Progression.costFor(levels[id] ?? Progression.minLevel);
    if (cost < 0 || totalMana < cost) return;
    setState(() {
      totalMana -= cost;
      levels[id] = (levels[id] ?? Progression.minLevel) + 1;
    });
  }

  void _enhanceGear(String id) {
    final current = gear[id];
    if (current == null) return;
    final cost = current.enhanceCost;
    if (cost < 0 || totalMana < cost) return;
    setState(() {
      totalMana -= cost;
      current.enhanceLevel++;
    });
  }

  /// A win always drops gear (docs/combat-spec.md §2, resolve step). It goes
  /// to a random deployed character; if it isn't an upgrade over what
  /// they're already wearing, it's salvaged into Mana instead so the drop
  /// is never wasted.
  void _rollGearDrop() {
    final ownerId =
        formation.keys.elementAt(_dropRng.nextInt(formation.length));
    final drop = Gear(rarity: GearDrop.roll(_dropRng).rarity);
    final current = gear[ownerId];
    final name = Roster.byId(ownerId).name;
    if (current == null || drop.statMultiplier > current.statMultiplier) {
      gear[ownerId] = drop;
      lastDropMessage =
          '${drop.rarity.label} gear dropped — equipped on $name.';
    } else {
      totalMana += drop.rarity.salvageValue;
      lastDropMessage =
          '${drop.rarity.label} gear dropped for $name — salvaged for '
          '+${drop.rarity.salvageValue} mana (their current gear is better).';
    }
  }

  /// Bond is earned through play, not bought — every deployed companion
  /// with route data gains a flat amount per clear. If that bond crosses a
  /// tier threshold and unlocks a new beat, surface it: this is the
  /// `post_raid` story hook (docs/combat-spec.md §2, "banter after clearing
  /// a gate together") firing off the win, without this raid screen
  /// rendering the actual scene — see docs/HANDOFF.md for that limitation.
  void _awardBond() {
    lastBondMessages = [];
    for (final id in formation.keys) {
      final route = routes[id];
      if (route == null) continue;
      gameState.addBond(id, _bondPerClear);
      final before = _nextBeat[id];
      final after = Evaluator.nextAvailableBeat(route, gameState);
      _nextBeat[id] = after;
      if (after != null && after.beatId != before?.beatId) {
        final name = Roster.byId(id).name;
        lastBondMessages.add(after.triggerContext == 'post_raid'
            ? '$name has something to say after this raid — new scene: '
                '"${after.title}".'
            : '$name\'s bond deepens — "${after.title}" is now available '
                '(${after.triggerContext}).');
      }
    }
  }

  void _startRaid() {
    lastDropMessage = null;
    final b = Battle.fromFormation(formation,
        levels: levels,
        gear: gear,
        bondTiers: bondTiers,
        gateElement: gate.element)
      ..start();
    b.autoCast = autoCast;
    battle = b;
    showFormation = false;
    _timer = Timer.periodic(
      Duration(milliseconds: (CombatConfig.tickSeconds * 1000).round()),
      (_) {
        // 2x speed = two simulation steps per frame.
        for (var i = 0; i < speed; i++) {
          if (b.status != BattleStatus.fighting) break;
          b.tick(CombatConfig.tickSeconds);
        }
        if (b.status != BattleStatus.fighting) {
          _timer?.cancel();
          _timer = null;
          totalMana += b.manaEarned;
          if (b.status == BattleStatus.won) {
            clears++;
            _rollGearDrop();
            _awardBond();
          }
        }
        setState(() {});
      },
    );
    setState(() {});
  }

  void _backToFormation() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      battle = null;
      showFormation = true;
      // Next gate rolls now — rotation reacts to the elements the player
      // just faced, so the same disadvantage can't stack three raids deep.
      gate = _gates.next();
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = battle;
    final fighting = b != null && b.status == BattleStatus.fighting;
    final finished = b != null &&
        (b.status == BattleStatus.won || b.status == BattleStatus.lost);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(b),
                  const SizedBox(height: 14),
                  if (finished)
                    _resultPanel(b)
                  else if (showFormation || b == null) ...[
                    _formationPanel(),
                    const SizedBox(height: 12),
                    _levelsPanel(),
                    const SizedBox(height: 12),
                    _gearPanel(),
                    const SizedBox(height: 12),
                    _bondPanel(),
                  ] else ...[
                    _enemyPanel(b),
                    const SizedBox(height: 9),
                    _waveTrack(b),
                    const SizedBox(height: 12),
                    ..._partyList(b),
                    const SizedBox(height: 8),
                    _abilityRow(b),
                  ],
                  const SizedBox(height: 16),
                  _controls(fighting, finished),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(Battle? b) {
    final mana = totalMana + (b?.manaEarned ?? 0);
    final g = gate;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(g.name,
                      style: const TextStyle(color: _bone, fontSize: 19)),
                  const SizedBox(width: 7),
                  _elementChip(g.element),
                ],
              ),
              const SizedBox(height: 2),
              Text(g.description,
                  style: const TextStyle(
                      color: _boneDim,
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        Text('$mana mana',
            style: const TextStyle(
                color: _verdant, fontSize: 13, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _elementChip(GateElement e) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(border: Border.all(color: _riftDim)),
        child: Text(e.label,
            style: const TextStyle(color: _boneDim, fontSize: 10.5)),
      );

  // ---------------- formation ----------------

  Widget _formationPanel() {
    final front =
        formation.entries.where((e) => e.value == BattleRow.front).toList();
    final back =
        formation.entries.where((e) => e.value == BattleRow.back).toList();
    final bench =
        Roster.all.where((f) => !formation.containsKey(f.id)).toList();

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: _riftDim),
        color: Colors.black.withValues(alpha: .2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Set your formation',
              style: TextStyle(color: _bone, fontSize: 14)),
          const SizedBox(height: 3),
          const Text(
            'Front row draws most attacks and lands full melee damage. '
            'Back row takes half damage, but melee hits from there are weaker. '
            'Tap anyone to move them.',
            style: TextStyle(
                color: _boneDim,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.5),
          ),
          if (formation.keys.every((id) =>
              matchupOf(Roster.byId(id).element, gate.element) !=
              Matchup.advantage))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  border:
                      const Border(left: BorderSide(color: _blood, width: 2)),
                  color: _blood.withValues(alpha: .07),
                ),
                child: Text(
                  'No one deployed has the advantage against this ${gate.element.label} '
                  'gate — it will take longer, not fail. Never a hard wall.',
                  style: const TextStyle(
                      color: _blood, fontSize: 11.5, height: 1.5),
                ),
              ),
            ),
          _rowLabel('Front', '${front.length} — full damage, draws attacks'),
          _slotRow(front.map((e) => e.key).toList(),
              'No one up front — everyone will be exposed.'),
          _rowLabel('Back', '${back.length} — half damage taken'),
          _slotRow(back.map((e) => e.key).toList(), 'Back row empty.'),
          _rowLabel('Available', 'tap to add — ${CombatConfig.partyMax} max'),
          _slotRow(bench.map((f) => f.id).toList(), 'Everyone is deployed.'),
          if (partyCount < CombatConfig.partyMax) ...[
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: const Border(left: BorderSide(color: _gold, width: 2)),
                color: _gold.withValues(alpha: .07),
              ),
              child: Text(
                'Only $partyCount of ${CombatConfig.partyMax} deployed. Fewer '
                'fighters means less damage, and the guardian grows stronger '
                'the longer it lives.',
                style:
                    const TextStyle(color: _gold, fontSize: 11.5, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rowLabel(String label, String detail) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: _bone, fontSize: 11.5)),
            Text(detail,
                style: const TextStyle(color: _boneDim, fontSize: 11.5)),
          ],
        ),
      );

  Widget _slotRow(List<String> ids, String emptyText) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        border: Border.all(color: _riftDim, style: BorderStyle.solid),
        color: Colors.black.withValues(alpha: .12),
      ),
      child: ids.isEmpty
          ? Center(
              child: Text(emptyText,
                  style: const TextStyle(
                      color: _boneDim,
                      fontSize: 11,
                      fontStyle: FontStyle.italic)))
          : Row(
              children: [
                for (final id in ids) ...[
                  Expanded(child: _unitChip(Roster.byId(id))),
                  if (id != ids.last) const SizedBox(width: 6),
                ]
              ],
            ),
    );
  }

  Widget _unitChip(FighterDef def) {
    final matchup = matchupOf(def.element, gate.element);
    final matchupColor = switch (matchup) {
      Matchup.advantage => _verdant,
      Matchup.disadvantage => _blood,
      Matchup.neutral => _riftDim,
    };
    return GestureDetector(
      onTap: () => _cycle(def.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: _night2,
          border: Border.all(color: matchupColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(def.name,
                style: TextStyle(
                    color: def.locked ? _boneDim : _bone, fontSize: 12)),
            const SizedBox(height: 2),
            Text('${def.role} · Lv.${levels[def.id] ?? Progression.minLevel}',
                style: const TextStyle(
                    color: _boneDim,
                    fontSize: 9.5,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 2),
            Text(
              matchup == Matchup.advantage
                  ? '${def.element.label} · advantage'
                  : matchup == Matchup.disadvantage
                      ? '${def.element.label} · disadvantage'
                      : def.element.label,
              style: TextStyle(
                  color: matchup == Matchup.neutral ? _boneDim : matchupColor,
                  fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- levels ----------------

  Widget _levelsPanel() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: _riftDim),
        color: Colors.black.withValues(alpha: .2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Companion levels',
                  style: TextStyle(color: _bone, fontSize: 14)),
              Text('$totalMana mana banked',
                  style: const TextStyle(
                      color: _verdant, fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Mana spent between raids grows a companion\'s attack and max HP '
            'permanently. Never required to clear a gate — just faster.',
            style: TextStyle(
                color: _boneDim,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.5),
          ),
          const SizedBox(height: 8),
          for (final def in Roster.all) _levelRow(def),
        ],
      ),
    );
  }

  Widget _levelRow(FighterDef def) {
    final level = levels[def.id] ?? Progression.minLevel;
    final cost = Progression.costFor(level);
    final maxed = cost < 0;
    final affordable = !maxed && totalMana >= cost;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${def.name}  ·  Lv.$level',
                    style: const TextStyle(color: _bone, fontSize: 12.5)),
                Text(
                  maxed
                      ? 'max level'
                      : '+4% ATK & HP per level — next: $cost mana',
                  style: const TextStyle(color: _boneDim, fontSize: 10.5),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 84,
            child: OutlinedButton(
              onPressed: (!maxed && affordable) ? () => _levelUp(def.id) : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: affordable ? _gold : _boneDim,
                side: BorderSide(color: affordable ? _gold : _riftDim),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: const RoundedRectangleBorder(),
              ),
              child: Text(maxed ? 'Max' : 'Level up',
                  style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- gear ----------------

  Widget _gearPanel() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: _riftDim),
        color: Colors.black.withValues(alpha: .2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Gear', style: TextStyle(color: _bone, fontSize: 14)),
          const SizedBox(height: 3),
          const Text(
            'A win always drops one piece of gear. It\'s equipped '
            'automatically if it beats what that character has, otherwise '
            'it\'s salvaged into Mana on the spot — nothing is ever wasted.',
            style: TextStyle(
                color: _boneDim,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.5),
          ),
          const SizedBox(height: 8),
          for (final def in Roster.all) _gearRow(def),
        ],
      ),
    );
  }

  Widget _gearRow(FighterDef def) {
    final g = gear[def.id];
    final bonusPct = g == null ? 0 : ((g.statMultiplier - 1) * 100).round();
    final cost = g?.enhanceCost ?? -1;
    final maxed = g != null && cost < 0;
    final affordable = g != null && !maxed && totalMana >= cost;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g == null
                      ? '${def.name}  ·  no gear yet'
                      : '${def.name}  ·  ${g.rarity.label} +${g.enhanceLevel}',
                  style: const TextStyle(color: _bone, fontSize: 12.5),
                ),
                Text(
                  g == null
                      ? 'clear a gate to find a first piece'
                      : maxed
                          ? '+$bonusPct% ATK, HP & ability power — max enhance'
                          : '+$bonusPct% ATK, HP & ability power — enhance: $cost mana',
                  style: const TextStyle(color: _boneDim, fontSize: 10.5),
                ),
              ],
            ),
          ),
          if (g != null)
            SizedBox(
              width: 84,
              child: OutlinedButton(
                onPressed:
                    (!maxed && affordable) ? () => _enhanceGear(def.id) : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: affordable ? _gold : _boneDim,
                  side: BorderSide(color: affordable ? _gold : _riftDim),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: const RoundedRectangleBorder(),
                ),
                child: Text(maxed ? 'Max' : 'Enhance',
                    style: const TextStyle(fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- bond ----------------

  Widget _bondPanel() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: _riftDim),
        color: Colors.black.withValues(alpha: .2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Bond', style: TextStyle(color: _bone, fontSize: 14)),
          const SizedBox(height: 3),
          const Text(
            'Earned by fighting together, not bought — every clear raises '
            'bond with whoever you brought. Higher tiers buff them in '
            'battle and unlock new story beats.',
            style: TextStyle(
                color: _boneDim,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.5),
          ),
          const SizedBox(height: 8),
          if (routes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Loading companion routes…',
                  style: TextStyle(color: _boneDim, fontSize: 11)),
            )
          else
            for (final id in routes.keys) _bondRow(id),
        ],
      ),
    );
  }

  Widget _bondRow(String id) {
    final def = Roster.byId(id);
    final points = gameState.bondPointsFor(id);
    final tier = Evaluator.tierOf(points);
    final maxTier = Evaluator.bondTierThresholds.length - 1;
    final bonusPct = ((BondBuff.statMultiplier(tier) - 1) * 100).round();
    final next = _nextBeat[id];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${def.name}  ·  Bond tier $tier/$maxTier  ·  +$bonusPct% ATK & HP',
              style: const TextStyle(color: _bone, fontSize: 12.5)),
          Text(
            next == null
                ? '$points bond points — route complete'
                : '$points bond points — next: "${next.title}" (${next.triggerContext})',
            style: const TextStyle(color: _boneDim, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  // ---------------- battle ----------------

  Widget _enemyPanel(Battle b) {
    final e = b.enemy;
    final stacks = b.enrageStacks;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 17, 14, 15),
      decoration: BoxDecoration(
        border: Border.all(color: _riftDim),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_rift.withValues(alpha: .16), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          Text(e.name,
              style: TextStyle(
                  color: e.isBoss ? _blood : _bone,
                  fontSize: e.isBoss ? 21 : 17)),
          const SizedBox(height: 3),
          Text(
            e.isBoss
                ? (stacks > 0
                    ? 'gate guardian — growing stronger ($stacks)'
                    : 'gate guardian')
                : 'wave ${b.waveIndex + 1} of ${CombatConfig.waves}',
            style: TextStyle(
                color: stacks > 2 ? _blood : _boneDim, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          _bar(e.hpFraction, e.isBoss ? _blood : const Color(0xFFA33B52)),
          const SizedBox(height: 5),
          Text('${e.hp.ceil()} / ${e.maxHp.round()}',
              style: const TextStyle(
                  color: _boneDim, fontSize: 11, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _waveTrack(Battle b) {
    return Row(
      children: [
        for (var i = 0; i < CombatConfig.waves; i++)
          Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.only(right: 3),
              color: i < b.waveIndex
                  ? _verdant
                  : (i == b.waveIndex && !b.onBoss)
                      ? _rift
                      : Colors.white.withValues(alpha: .1),
            ),
          ),
        Container(
          width: 22,
          height: 3,
          color: b.onBoss ? _blood : _blood.withValues(alpha: .3),
        ),
      ],
    );
  }

  List<Widget> _partyList(Battle b) {
    final widgets = <Widget>[];
    for (final row in [BattleRow.front, BattleRow.back]) {
      final members = b.party.where((p) => p.row == row).toList();
      if (members.isEmpty) continue;
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(0, 7, 0, 4),
        child: Text(
          row == BattleRow.front ? 'front row' : 'back row — half damage taken',
          style: const TextStyle(
              color: _boneDim, fontSize: 10.5, fontStyle: FontStyle.italic),
        ),
      ));
      widgets.addAll(members.map(_fighterRow));
    }
    return widgets;
  }

  Widget _fighterRow(Fighter f) {
    final frac = f.hpFraction;
    final color = frac < .25
        ? _blood
        : frac < .55
            ? const Color(0xFFE8A04B)
            : _verdant;
    final tag = !f.alive ? 'down' : (f.isTaunting ? 'drawing fire' : f.role);
    return Opacity(
      opacity: f.alive ? 1 : .42,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: f.isTaunting ? const Color(0xFF1C1734) : _night2,
          border: Border(
            left: BorderSide(
              color: !f.alive ? _boneDim : (f.isTaunting ? _gold : _verdant),
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${f.name}  Lv.${f.level}',
                    style: const TextStyle(color: _bone, fontSize: 13)),
                Text(tag,
                    style: TextStyle(
                        color: f.isTaunting ? _gold : _boneDim,
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic)),
              ],
            ),
            const SizedBox(height: 4),
            _bar(frac, color),
          ],
        ),
      ),
    );
  }

  Widget _bar(double frac, Color color) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: frac.clamp(0, 1),
          minHeight: 7,
          backgroundColor: Colors.white.withValues(alpha: .07),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );

  Widget _abilityRow(Battle b) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: b.abilities.map((a) {
        final owner = b.party.where((p) => p.id == a.ownerId).firstOrNull;
        final ready = a.ready &&
            b.status == BattleStatus.fighting &&
            owner != null &&
            owner.alive;
        return SizedBox(
          width: 104,
          child: _AbilityButton(
            ability: a,
            enabled: ready,
            isUltimate: a.kind == AbilityKind.ultimate,
            onTap: () => setState(() => b.castAbility(a.id)),
          ),
        );
      }).toList(),
    );
  }

  Widget _resultPanel(Battle b) {
    final won = b.status == BattleStatus.won;
    final justUnlocked =
        won && clears == CombatConfig.clearsToUnlockDoubleSpeed;
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(won ? 'Gate cleared' : 'Party withdrawn',
            style: TextStyle(color: won ? _verdant : _blood, fontSize: 25)),
        const SizedBox(height: 11),
        Text(
          won
              ? 'The rift closes behind you. ${b.elapsed.round()}s in the gate.'
              : 'You pull back through the tear. The gate stays open.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _boneDim, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 14),
        Text('+${b.manaEarned} mana earned',
            style: const TextStyle(
                color: _gold, fontSize: 15, fontFamily: 'monospace')),
        if (won && lastDropMessage != null) ...[
          const SizedBox(height: 10),
          Text(lastDropMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _verdant, fontSize: 12.5, height: 1.4)),
        ],
        if (won)
          for (final msg in lastBondMessages) ...[
            const SizedBox(height: 10),
            Text(msg,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: _gold, fontSize: 12.5, height: 1.4)),
          ],
        if (justUnlocked) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border.all(color: _gold)),
            child: const Text('2× speed unlocked — raid faster from now on.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _gold, fontSize: 13)),
          ),
        ],
      ],
    );
  }

  Widget _controls(bool fighting, bool finished) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: fighting
                ? null
                : () {
                    if (finished) {
                      _backToFormation();
                    } else {
                      _startRaid();
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: _rift,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(),
            ),
            child: Text(fighting
                ? 'In the gate…'
                : finished
                    ? 'Back to formation'
                    : 'Enter the gate'),
          ),
        ),
        const SizedBox(width: 7),
        OutlinedButton(
          onPressed: () => setState(() {
            autoCast = !autoCast;
            battle?.autoCast = autoCast;
          }),
          style: OutlinedButton.styleFrom(
            foregroundColor: autoCast ? _verdant : _boneDim,
            side: BorderSide(color: autoCast ? _verdant : _riftDim),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 13),
            shape: const RoundedRectangleBorder(),
          ),
          child: Text(autoCast ? 'Auto' : 'Manual'),
        ),
        const SizedBox(width: 7),
        Opacity(
          opacity: speedUnlocked ? 1 : .45,
          child: OutlinedButton(
            // 2x is a reward for clearing the gate once, not a default.
            onPressed: speedUnlocked
                ? () => setState(() => speed = speed == 1 ? 2 : 1)
                : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: speed == 2 ? _gold : _boneDim,
              side: BorderSide(color: speed == 2 ? _gold : _riftDim),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 13),
              shape: const RoundedRectangleBorder(),
            ),
            child: Text('${speed}×'),
          ),
        ),
      ],
    );
  }
}

class _AbilityButton extends StatelessWidget {
  final Ability ability;
  final bool enabled;
  final bool isUltimate;
  final VoidCallback onTap;

  const _AbilityButton({
    required this.ability,
    required this.enabled,
    required this.isUltimate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pctLeft =
        ability.remaining > 0 ? ability.remaining / ability.cooldown : 0.0;
    final borderColor = enabled ? (isUltimate ? _gold : _verdant) : _riftDim;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: _night2,
          border: Border.all(color: borderColor),
        ),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: pctLeft.clamp(0, 1),
              child: Container(color: _rift.withValues(alpha: .22)),
            ),
            Center(
              child: Text(
                ability.name,
                style: TextStyle(
                  color: enabled ? (isUltimate ? _gold : _bone) : _boneDim,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
