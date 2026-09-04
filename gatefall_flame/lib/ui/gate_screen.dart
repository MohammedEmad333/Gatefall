import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../art/character_art.dart';
import '../art/effects.dart';
import '../art/gate_art.dart';
import '../art/palette.dart';
import '../audio/sfx.dart';
import '../combat/battle.dart';
import '../data/combat_config.dart';
import '../data/gate.dart';
import '../data/house.dart';
import '../data/progression.dart';
import '../data/roster.dart';
import '../state/game_controller.dart';
import 'dialogue_screen.dart';
import 'theme.dart';

/// The Mana half: pick a gate off the board, set the formation, watch the
/// auto-battle, collect. Still plain Flutter widgets rather than a Flame
/// render loop — see the note in main.dart; battle.dart is the simulation
/// and does not care what draws it.
///
/// Version 3 is where that separation paid: the fight now has a turning
/// rift, a creature that flinches, numbers coming off it, a screen that
/// shakes and a sound per event — and battle.dart gained exactly one field
/// for it ([Battle.eventsEmitted]) plus an amount on each event. Everything
/// else here is this screen reading the simulation and reacting.
class GateScreen extends StatefulWidget {
  final GameController game;
  const GateScreen({super.key, required this.game});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

enum _Stage { board, formation, fighting, result }

class _GateScreenState extends State<GateScreen> {
  GameController get game => widget.game;

  _Stage stage = _Stage.board;
  Battle? battle;
  Gate? gate;
  Timer? _timer;

  /// The presentation layer's own state. None of this is the simulation —
  /// it is what the simulation looked like last frame, so this frame can
  /// tell what just happened.
  final GlobalKey<ShakeBoxState> _shake = GlobalKey<ShakeBoxState>();
  final GlobalKey<DamageLayerState> _numbers = GlobalKey<DamageLayerState>();

  /// How many events we have already reacted to. Monotonic, so trimming
  /// the event list cannot make us replay anything.
  int _eventCursor = 0;

  /// Enemy HP as of the last frame, for reading off chip damage that never
  /// emits an event of its own.
  double _enemyHp = 0;
  int _wave = 0;
  bool _onBoss = false;

  /// 0…1, how recently the thing on screen was hit. Decays every tick.
  double _hurt = 0;

  /// Auto-attack damage waiting to be shown as one number, so a five-per-
  /// second trickle does not become five numbers a second.
  double _chip = 0;
  double _chipAge = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _enter() {
    final g = gate;
    if (g == null) return;
    final b = game.startRaid(g);
    battle = b;
    stage = _Stage.fighting;
    _eventCursor = 0;
    _enemyHp = b.enemy.hp;
    _wave = b.waveIndex;
    _onBoss = b.onBoss;
    _hurt = 0;
    _chip = 0;
    _chipAge = 0;
    // The gate-opening sound comes from the button that called this (see
    // its `sound:`), so entering by any other route stays silent rather
    // than doubling up.
    _timer = Timer.periodic(
      Duration(milliseconds: (CombatConfig.tickSeconds * 1000).round()),
      (_) {
        // Higher speeds are extra simulation steps per frame, not a
        // different simulation.
        for (var i = 0; i < game.speed; i++) {
          if (b.status != BattleStatus.fighting) break;
          b.tick(CombatConfig.tickSeconds);
        }
        _react(b);
        if (b.status != BattleStatus.fighting) {
          _timer?.cancel();
          _timer = null;
          game.finishRaid(b, g);
          stage = _Stage.result;
          Audio.instance.play(
              b.status == BattleStatus.won ? Sfx.victory : Sfx.defeat);
        }
        if (mounted) setState(() {});
      },
    );
    setState(() {});
  }

  /// Turn one simulation frame into sound and motion.
  ///
  /// Two sources, deliberately: *events*, which are the things the fight
  /// says out loud (a cast, a crit, someone going down), and *chip damage*,
  /// which is the auto-attack trickle that emits nothing at all. Without
  /// the second, a fight with no abilities up would be silent and still
  /// even though the boss's health is visibly falling.
  void _react(Battle b) {
    // A new enemy: re-baseline, or the swap reads as one colossal hit.
    if (b.waveIndex != _wave || b.onBoss != _onBoss) {
      _wave = b.waveIndex;
      _onBoss = b.onBoss;
      _enemyHp = b.enemy.hp;
      _hurt = 0;
    }

    final dealt = _enemyHp - b.enemy.hp;
    _enemyHp = b.enemy.hp;
    if (dealt > 0) {
      _hurt = (_hurt + dealt / max(1.0, b.enemy.maxHp) * 7).clamp(0.0, 1.0);
      _chip += dealt;
      // The bus rate-limits this; at 4× speed the hits arrive far faster
      // than a human ear wants them.
      Audio.instance.play(Sfx.hit);
    }
    // ~0.6s of fade, at a 0.1s tick.
    _hurt = max(0, _hurt - .16);

    _chipAge += CombatConfig.tickSeconds * game.speed;
    if (_chip >= 1 && _chipAge >= .45) {
      _numbers.currentState
          ?.spawn('${_chip.round()}', bone.withValues(alpha: .8));
      _chip = 0;
      _chipAge = 0;
    }

    // Events since the last frame. [Battle.eventsEmitted] counts every one
    // ever emitted, so this stays correct after the list is trimmed.
    final fresh = (b.eventsEmitted - _eventCursor).clamp(0, b.events.length);
    if (fresh > 0) {
      for (final e in b.events.sublist(b.events.length - fresh)) {
        _onEvent(e, b);
      }
      _eventCursor = b.eventsEmitted;
    }
  }

  void _onEvent(BattleEvent e, Battle b) {
    final numbers = _numbers.currentState;
    final shake = _shake.currentState;
    switch (e.kind) {
      case 'ultimate':
        Audio.instance.play(Sfx.ultimate);
        shake?.shake(1.5);
        if (e.amount >= 1) {
          numbers?.spawn('${e.amount.round()}', rose, big: true);
        }
      case 'crit':
        Audio.instance.play(Sfx.crit);
        shake?.shake(.7);
        numbers?.spawn('${e.amount.round()}', gold, big: true);
      case 'damage':
        Audio.instance.play(Sfx.ability);
        numbers?.spawn('${e.amount.round()}', bone);
      case 'heal':
        Audio.instance.play(Sfx.heal);
        if (e.amount >= 1) numbers?.spawn('+${e.amount.round()}', verdant);
      case 'revive':
        Audio.instance.play(Sfx.heal);
      case 'boss':
        Audio.instance.play(Sfx.bossStir);
        shake?.shake(2.2);
      case 'down':
        Audio.instance.play(Sfx.partyDown);
        shake?.shake(1.1);
      case 'reward':
        // The last one of these is the clear itself, and the result screen
        // is about to play something much bigger over the top of it.
        if (b.status == BattleStatus.fighting) {
          Audio.instance.play(Sfx.enemyDown);
          numbers?.spawn('+${e.amount.round()} mana', verdant);
        }
    }
  }

  Future<void> _leaveResult() async {
    // The post_raid hook, actually played: banter after clearing a gate
    // together (docs/combat-spec.md §2), rendered rather than announced.
    final pending = game.postRaidBeat;
    if (pending != null) {
      await DialogueScreen.play(context,
          game: game,
          characterId: pending.characterId,
          beat: pending.beat);
    }
    if (!mounted) return;
    setState(() {
      battle = null;
      gate = null;
      stage = _Stage.board;
    });
    game.rerollBoard();
  }

  @override
  Widget build(BuildContext context) {
    final b = battle;
    return switch (stage) {
      _Stage.board => _boardView(),
      _Stage.formation => _formationView(),
      _Stage.fighting => _fightView(b!),
      _Stage.result => _resultView(b!),
    };
  }

  // ---------------- gate board ----------------

  Widget _boardView() => ScreenBody(
        children: [
          ScreenHeader('The board',
              trailing: CurrencyChip('${game.mana}', 'mana', verdant)),
          const SizedBox(height: 4),
          const Text(
            'Every tear in the city, graded. A bigger gate pays more and asks '
            'for more bodies. Losing costs nothing but time — the gate just '
            'stays open.',
            style: TextStyle(
                color: boneDim,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.5),
          ),
          const SizedBox(height: 14),
          for (final (i, g) in game.board.indexed) ...[
            Reveal(delay: Duration(milliseconds: 60 * i), child: _gateCard(g)),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Align(
            child: SlabButton('Look for other gates',
                tone: boneDim, onPressed: game.rerollBoard),
          ),
          if (GateTier.all.length > game.board.length) ...[
            const SizedBox(height: 14),
            Callout(
              'Harder gates open up as you clear more: '
              '${GateTier.all.where((t) => t.clearsToUnlock > game.clears).map((t) => "${t.name} at ${t.clearsToUnlock}").join(", ")}. '
              'You have ${game.clears}.',
              tone: boneDim,
            ),
          ],
        ],
      );

  Widget _gateCard(Gate g) {
    final party = game.formation.length;
    final short = party < g.tier.recommendedParty;
    final anyAdvantage = game.formation.keys.any((id) =>
        matchupOf(Roster.byId(id).element, g.element) == Matchup.advantage);

    return InkWell(
      onTap: () {
        Audio.instance.play(Sfx.uiSelect);
        setState(() {
          gate = g;
          stage = _Stage.formation;
        });
      },
      child: Panel(
        borderColor: short ? gold.withValues(alpha: .7) : riftDim,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Every gate on the board is turning. It is the same
                // painter the fight uses, held at half strength — a card is
                // a tear seen from across the city, not one you are
                // standing in.
                RiftView(element: g.element, size: 56, intensity: .55),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(g.fullName,
                                style:
                                    const TextStyle(color: bone, fontSize: 15)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: elementColor(g.element)
                                        .withValues(alpha: .55))),
                            child: Text(g.element.label,
                                style: TextStyle(
                                    color: elementColor(g.element),
                                    fontSize: 10.5)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(g.description,
                          style: const TextStyle(
                              color: boneDim,
                              fontSize: 12,
                              fontStyle: FontStyle.italic)),
                      const SizedBox(height: 6),
                      Text(g.tier.blurb,
                          style: const TextStyle(
                              color: boneDim, fontSize: 11.5, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                CurrencyChip('×${g.tier.manaMult}', 'mana', verdant),
                CurrencyChip('+${g.tier.goldReward}', 'gold', gold),
                CurrencyChip(
                    '+${CombatConfig.bondPerClearBase + CombatConfig.bondPerClearPerTier * g.tier.index}',
                    'bond',
                    rose),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'built for a party of ${g.tier.recommendedParty} · you have $party'
              '${anyAdvantage ? " · someone has the advantage" : ""}',
              style: TextStyle(
                  color: short ? gold : (anyAdvantage ? verdant : boneDim),
                  fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- formation ----------------

  Widget _formationView() {
    final g = gate!;
    final front = game.formation.entries
        .where((e) => e.value == BattleRow.front)
        .map((e) => e.key)
        .toList();
    final back = game.formation.entries
        .where((e) => e.value == BattleRow.back)
        .map((e) => e.key)
        .toList();
    final bench = game.roster
        .where((f) => !game.formation.containsKey(f.id))
        .map((f) => f.id)
        .toList();
    final party = game.formation.length;

    return ScreenBody(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => stage = _Stage.board),
              icon: const Icon(Icons.arrow_back, color: boneDim, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(g.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: bone, fontSize: 16)),
            ),
            const SizedBox(width: 8),
            CurrencyChip('${game.mana}', 'mana', verdant),
          ],
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PanelTitle('Set your formation',
                  subtitle:
                      'Front row draws most attacks and lands full melee '
                      'damage. Back row takes half damage, but melee hits from '
                      'there are weaker. Tap anyone to move them.'),
              if (game.formation.keys.every((id) =>
                  matchupOf(Roster.byId(id).element, g.element) !=
                  Matchup.advantage)) ...[
                const SizedBox(height: 9),
                Callout(
                  'No one deployed has the advantage against this '
                  '${g.element.label} gate — it will take longer, not fail. '
                  'Never a hard wall.',
                  tone: blood,
                ),
              ],
              _rowLabel('Front', '${front.length} — full damage, draws attacks'),
              _slotRow(front, g, 'No one up front — everyone will be exposed.'),
              _rowLabel('Back', '${back.length} — half damage taken'),
              _slotRow(back, g, 'Back row empty.'),
              _rowLabel('Available',
                  'tap to add — ${CombatConfig.partyMax} max'),
              _slotRow(bench, g, 'Everyone is deployed.'),
              if (party < g.tier.recommendedParty) ...[
                const SizedBox(height: 11),
                Callout(
                  'This gate is built for ${g.tier.recommendedParty}. You are '
                  'taking $party. Fewer fighters means less damage, and the '
                  'guardian grows stronger the longer it lives.',
                ),
              ],
              if (game.roster.length < CombatConfig.partyMax) ...[
                const SizedBox(height: 11),
                Callout(
                  'Only ${game.roster.length} of you can fight so far. Build '
                  'rooms at the house to bring more people home.',
                  tone: boneDim,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SlabButton('Enter the gate',
                  filled: true,
                  sound: Sfx.gateOpen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onPressed: _enter),
            ),
            const SizedBox(width: 7),
            _autoButton(),
            const SizedBox(width: 7),
            _speedButton(),
          ],
        ),
      ],
    );
  }

  Widget _rowLabel(String label, String detail) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: bone, fontSize: 11.5)),
            const SizedBox(width: 8),
            // The detail line is the flexible half: on a narrow phone it
            // gives ground before the label does.
            Flexible(
              child: Text(detail,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: boneDim, fontSize: 11.5)),
            ),
          ],
        ),
      );

  Widget _slotRow(List<String> ids, Gate g, String emptyText) => Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          border: Border.all(color: riftDim),
          color: Colors.black.withValues(alpha: .12),
        ),
        child: ids.isEmpty
            ? Center(
                child: Text(emptyText,
                    style: const TextStyle(
                        color: boneDim,
                        fontSize: 11,
                        fontStyle: FontStyle.italic)))
            : Row(
                children: [
                  for (final id in ids) ...[
                    Expanded(child: _unitChip(Roster.byId(id), g)),
                    if (id != ids.last) const SizedBox(width: 6),
                  ]
                ],
              ),
      );

  Widget _unitChip(FighterDef def, Gate g) {
    final matchup = matchupOf(def.element, g.element);
    final matchupColor = switch (matchup) {
      Matchup.advantage => verdant,
      Matchup.disadvantage => blood,
      Matchup.neutral => riftDim,
    };
    final tier = game.bondTier(def.id);
    return GestureDetector(
      onTap: () {
        Audio.instance.play(Sfx.uiTap);
        setState(() => game.cycleFormation(def.id));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: night2,
          border: Border.all(color: matchupColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CharacterPortrait(def.id,
                size: 34, glow: .35 + tier * .12, calm: true),
            const SizedBox(height: 4),
            Text(def.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: def.locked ? boneDim : bone, fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              '${def.role} · Lv.${game.levels[def.id] ?? Progression.minLevel}'
              '${tier > 0 ? " · ♥$tier" : ""}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: boneDim, fontSize: 9.5, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 2),
            Text(
              matchup == Matchup.advantage
                  ? '${def.element.label} · advantage'
                  : matchup == Matchup.disadvantage
                      ? '${def.element.label} · disadvantage'
                      : def.element.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: matchup == Matchup.neutral
                      ? elementColor(def.element).withValues(alpha: .8)
                      : matchupColor,
                  fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- the fight ----------------

  Widget _fightView(Battle b) => ShakeBox(
        key: _shake,
        child: ScreenBody(
          children: [
            ScreenHeader(gate!.fullName,
                trailing: CurrencyChip(
                    '${game.mana + b.manaEarned}', 'mana', verdant)),
            const SizedBox(height: 12),
            _enemyPanel(b),
            const SizedBox(height: 9),
            _waveTrack(b),
            const SizedBox(height: 12),
            ..._partyList(b),
            const SizedBox(height: 8),
            _abilityRow(b),
            const SizedBox(height: 10),
            _battleLog(b),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: SlabButton('In the gate…',
                      filled: true,
                      padding: EdgeInsets.symmetric(vertical: 14)),
                ),
                const SizedBox(width: 7),
                _autoButton(),
                const SizedBox(width: 7),
                _speedButton(),
              ],
            ),
          ],
        ),
      );

  /// The thing you are fighting, drawn: the tear it came out of behind it,
  /// the creature itself in front, and every number it takes coming off the
  /// top of the panel.
  Widget _enemyPanel(Battle b) {
    final e = b.enemy;
    final stacks = b.enrageStacks;
    final form =
        beastformFor(waveIndex: b.waveIndex, boss: e.isBoss);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 15),
      decoration: BoxDecoration(
        border: Border.all(
            color: e.isBoss ? blood.withValues(alpha: .55) : riftDim),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            elementColor(e.element).withValues(alpha: .16),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 148,
            child: Stack(
              alignment: Alignment.center,
              children: [
                RiftView(
                  element: e.element,
                  size: 148,
                  intensity: e.isBoss ? 1 : .8,
                  boss: e.isBoss,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: CreatureView(
                    form: form,
                    element: e.element,
                    size: e.isBoss ? 176 : 138,
                    hurt: _hurt,
                    falling: e.hp <= 0,
                  ),
                ),
                DamageLayer(key: _numbers),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(e.name,
              style: TextStyle(
                  color: e.isBoss ? blood : bone,
                  fontSize: e.isBoss ? 21 : 17)),
          const SizedBox(height: 3),
          Text(
            e.isBoss
                ? (stacks > 0
                    ? 'gate guardian — growing stronger ($stacks)'
                    : 'gate guardian')
                : 'wave ${b.waveIndex + 1} of ${CombatConfig.waves}',
            style:
                TextStyle(color: stacks > 2 ? blood : boneDim, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          AnimatedBar(e.hpFraction, e.isBoss ? blood : const Color(0xFFA33B52)),
          const SizedBox(height: 5),
          Text('${e.hp.ceil()} / ${e.maxHp.round()}',
              style: const TextStyle(
                  color: boneDim, fontSize: 11, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  /// The last few things the fight said. It was always emitting these —
  /// version 3 is the first build that shows them, and the reason a crit or
  /// an ascended cast now reads as an event rather than as a number that
  /// moved faster than usual.
  Widget _battleLog(Battle b) {
    final lines = b.events.length <= 3
        ? b.events
        : b.events.sublist(b.events.length - 3);
    return Container(
      // Keyed so a widget test can assert the fight is actually narrating
      // itself, without depending on which line happens to be last.
      key: const ValueKey('battle-log'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: riftDim.withValues(alpha: .55)),
        color: Colors.black.withValues(alpha: .22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, e) in lines.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Opacity(
                opacity: i == lines.length - 1 ? 1 : .45,
                child: Text(
                  e.message,
                  style: TextStyle(
                    color: switch (e.kind) {
                      'crit' => gold,
                      'ultimate' => rose,
                      'heal' || 'revive' => verdant,
                      'reward' => verdant,
                      'boss' || 'down' || 'hurt' => blood,
                      _ => boneDim,
                    },
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _waveTrack(Battle b) => Row(
        children: [
          for (var i = 0; i < CombatConfig.waves; i++)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(right: 3),
                color: i < b.waveIndex
                    ? verdant
                    : (i == b.waveIndex && !b.onBoss)
                        ? rift
                        : Colors.white.withValues(alpha: .1),
              ),
            ),
          Container(
              width: 22,
              height: 3,
              color: b.onBoss ? blood : blood.withValues(alpha: .3)),
        ],
      );

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
              color: boneDim, fontSize: 10.5, fontStyle: FontStyle.italic),
        ),
      ));
      widgets.addAll(members.map(_fighterRow));
    }
    return widgets;
  }

  Widget _fighterRow(Fighter f) {
    final frac = f.hpFraction;
    final color = frac < .25
        ? blood
        : frac < .55
            ? const Color(0xFFE8A04B)
            : verdant;
    final tag = !f.alive
        ? 'down'
        : f.isTaunting
            ? 'drawing fire'
            : f.isRallied
                ? 'oathbound'
                : f.role;
    final accent = !f.alive
        ? boneDim
        : f.isTaunting
            ? gold
            : f.isRallied
                ? rose
                : verdant;
    return AnimatedOpacity(
      opacity: f.alive ? 1 : .42,
      duration: const Duration(milliseconds: 350),
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
        decoration: BoxDecoration(
          color:
              f.isTaunting || f.isRallied ? const Color(0xFF1C1734) : night2,
          border: Border(left: BorderSide(color: accent, width: 2)),
        ),
        child: Row(
          children: [
            // The person, not the label. A row that is drawing fire or
            // oathbound lights up, so the buff reads without reading.
            CharacterPortrait(
              f.id,
              size: 38,
              glow: f.isTaunting || f.isRallied ? 1 : .45,
              dimmed: !f.alive,
              calm: true,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text('${f.name}  Lv.${f.level}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: bone, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      Text(tag,
                          style: TextStyle(
                              color: f.alive && (f.isTaunting || f.isRallied)
                                  ? accent
                                  : boneDim,
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  AnimatedBar(frac, color),
                  if (f.shield > 0) ...[
                    const SizedBox(height: 3),
                    Text('shield ${f.shield.round()}',
                        style: const TextStyle(color: gold, fontSize: 9.5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Version 2: an ascended ability is drawn apart from the base kit — it is
  /// the thing a finished route bought, so it should not look like one more
  /// button on the same shelf.
  static const _ascendedKinds = {
    AbilityKind.rally,
    AbilityKind.link,
    AbilityKind.foresight,
    AbilityKind.reciprocal,
    AbilityKind.wildcard,
  };

  Widget _abilityRow(Battle b) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: b.abilities.map((a) {
              final owner = b.party.where((p) => p.id == a.ownerId).firstOrNull;
              final ready = a.ready &&
                  b.status == BattleStatus.fighting &&
                  owner != null &&
                  owner.alive;
              final ascended = _ascendedKinds.contains(a.kind);
              return SizedBox(
                width: 104,
                child: _AbilityButton(
                  ability: a,
                  enabled: ready,
                  isUltimate: a.kind == AbilityKind.ultimate,
                  isAscended: ascended,
                  badge: ascended ? _ascendedBadge(b, a) : null,
                  // The cast itself makes the noise, through the event it
                  // emits — tapping only has to be allowed to happen.
                  onTap: () => setState(() => b.castAbility(a.id)),
                ),
              );
            }).toList(),
          ),
          if (b.warded) ...[
            const SizedBox(height: 7),
            Text(
              'Foresight is up — the party is taking '
              '${(Battle.foresightReduction * 100).round()}% less '
              '(${b.wardRemaining.toStringAsFixed(1)}s)',
              style: const TextStyle(color: rose, fontSize: 10.5),
            ),
          ],
        ],
      );

  /// The live number an ascended ability is worth right now, for the two
  /// that pay out off what the rest of the party has been doing.
  String? _ascendedBadge(Battle b, Ability a) {
    switch (a.kind) {
      case AbilityKind.link:
        return '×${(1 + Battle.linkPerStack * b.linkStacks).toStringAsFixed(1)}';
      case AbilityKind.reciprocal:
        final held = b.party
            .where((p) => p.id == a.ownerId)
            .fold<double>(0, (acc, p) => acc + p.careReceived);
        return held >= 1 ? '+${held.round()}' : null;
      default:
        return null;
    }
  }

  // ---------------- result ----------------

  Widget _resultView(Battle b) {
    final won = b.status == BattleStatus.won;
    final g = gate!;
    final post = game.postRaidBeat;
    var step = 0;
    // Each line arrives after the one above it, so the payout reads in
    // order instead of landing as a wall.
    Widget staged(Widget child) => Reveal(
          delay: Duration(milliseconds: 90 * step++),
          child: child,
        );

    return ScreenBody(
      children: [
        const SizedBox(height: 12),
        staged(Center(
          child: RiftView(
            element: g.element,
            size: 96,
            // A cleared gate is a closing one: the tear is still there, but
            // it has stopped pulling.
            intensity: won ? .35 : .8,
          ),
        )),
        const SizedBox(height: 14),
        staged(Text(won ? 'Gate cleared' : 'Party withdrawn',
            textAlign: TextAlign.center,
            style: TextStyle(color: won ? verdant : blood, fontSize: 25))),
        const SizedBox(height: 11),
        staged(Text(
          won
              ? 'The rift closes behind you. ${b.elapsed.round()}s in the gate.'
              : 'You pull back through the tear. The gate stays open, and '
                  'everything you earned in there is still yours.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: boneDim, fontSize: 14, height: 1.6),
        )),
        const SizedBox(height: 16),
        staged(Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CurrencyChip('+${b.manaEarned}', 'mana', verdant),
              if (won) ...[
                const SizedBox(width: 16),
                CurrencyChip('+${g.tier.goldReward}', 'gold', gold),
              ],
            ],
          ),
        )),
        if (won && game.lastDropMessage != null) ...[
          const SizedBox(height: 14),
          staged(Text(game.lastDropMessage!,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: verdant, fontSize: 12.5, height: 1.4))),
        ],
        if (won)
          for (final msg in game.lastBondMessages) ...[
            const SizedBox(height: 10),
            staged(Text(msg,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: gold, fontSize: 12.5, height: 1.4))),
          ],
        if (won && game.clears == CombatConfig.clearsToUnlockDoubleSpeed) ...[
          const SizedBox(height: 14),
          staged(const Callout(
              '2× speed unlocked — raid faster from now on.')),
        ],
        if (won && game.clears == CombatConfig.clearsToUnlockFastSpeed) ...[
          const SizedBox(height: 14),
          staged(const Callout('4× speed unlocked.')),
        ],
        const SizedBox(height: 26),
        staged(SlabButton(
          post != null
              ? '${House.byId(post.characterId).name} wants a word'
              : 'Back to the board',
          filled: true,
          tone: post != null ? gold : rift,
          sound: post != null ? Sfx.bond : Sfx.uiSelect,
          padding: const EdgeInsets.symmetric(vertical: 14),
          onPressed: _leaveResult,
        )),
      ],
    );
  }

  // ---------------- shared controls ----------------

  Widget _autoButton() => SlabButton(
        game.autoCast ? 'Auto' : 'Manual',
        tone: game.autoCast ? verdant : boneDim,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 13),
        onPressed: () => setState(() {
          game.setAutoCast(!game.autoCast);
          battle?.autoCast = game.autoCast;
        }),
      );

  Widget _speedButton() {
    final options = game.speedOptions;
    final enabled = options.length > 1;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: SlabButton(
        '${game.speed}×',
        tone: game.speed > 1 ? gold : boneDim,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 13),
        onPressed: enabled
            ? () {
                final i = options.indexOf(game.speed);
                setState(() =>
                    game.setSpeed(options[(i + 1) % options.length]));
              }
            : null,
      ),
    );
  }
}

class _AbilityButton extends StatelessWidget {
  final Ability ability;
  final bool enabled;
  final bool isUltimate;
  final bool isAscended;

  /// Live value for the abilities that scale off the party — the Chainbreak
  /// multiplier, the care Thora is holding. Null when there is nothing
  /// worth saying.
  final String? badge;
  final VoidCallback onTap;

  const _AbilityButton({
    required this.ability,
    required this.enabled,
    required this.isUltimate,
    required this.onTap,
    this.isAscended = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final pctLeft =
        ability.remaining > 0 ? ability.remaining / ability.cooldown : 0.0;
    final accent = isAscended ? rose : (isUltimate ? gold : verdant);
    final borderColor = enabled ? accent : riftDim;
    // A ready ability breathes. It is the only prompt the fight gives the
    // player, and before version 3 it was a border colour and nothing else.
    return Beacon(
      color: accent,
      active: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: night2,
            border: Border.all(
                color: borderColor, width: isAscended && enabled ? 1.6 : 1.0),
          ),
          child: Stack(
            children: [
              // The cooldown drains rather than stepping, even though the
              // simulation only moves ten times a second.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: pctLeft, end: pctLeft),
                duration: const Duration(milliseconds: 120),
                builder: (_, v, __) => FractionallySizedBox(
                  widthFactor: v.clamp(0, 1),
                  child: Container(color: rift.withValues(alpha: .22)),
                ),
              ),
              Center(
                child: Text(
                  ability.name,
                  style: TextStyle(
                    color: enabled
                        ? (isUltimate || isAscended ? accent : bone)
                        : boneDim,
                    fontSize: 12,
                  ),
                ),
              ),
              if (badge != null)
                Positioned(
                  right: 3,
                  top: 2,
                  child: Text(badge!,
                      style: TextStyle(
                          color: enabled ? accent : boneDim,
                          fontSize: 9,
                          fontFamily: 'monospace')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
