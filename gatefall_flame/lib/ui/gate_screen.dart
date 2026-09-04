import 'dart:async';

import 'package:flutter/material.dart';

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
    _timer = Timer.periodic(
      Duration(milliseconds: (CombatConfig.tickSeconds * 1000).round()),
      (_) {
        // Higher speeds are extra simulation steps per frame, not a
        // different simulation.
        for (var i = 0; i < game.speed; i++) {
          if (b.status != BattleStatus.fighting) break;
          b.tick(CombatConfig.tickSeconds);
        }
        if (b.status != BattleStatus.fighting) {
          _timer?.cancel();
          _timer = null;
          game.finishRaid(b, g);
          stage = _Stage.result;
        }
        if (mounted) setState(() {});
      },
    );
    setState(() {});
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
          for (final g in game.board) ...[
            _gateCard(g),
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
      onTap: () => setState(() {
        gate = g;
        stage = _Stage.formation;
      }),
      child: Panel(
        borderColor: short ? gold.withValues(alpha: .7) : riftDim,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(g.fullName,
                      style: const TextStyle(color: bone, fontSize: 15)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: riftDim)),
                  child: Text(g.element.label,
                      style: const TextStyle(color: boneDim, fontSize: 10.5)),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(g.description,
                style: const TextStyle(
                    color: boneDim,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            Text(g.tier.blurb,
                style: const TextStyle(color: boneDim, fontSize: 11.5, height: 1.4)),
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
      onTap: () => setState(() => game.cycleFormation(def.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: night2,
          border: Border.all(color: matchupColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                  color: matchup == Matchup.neutral ? boneDim : matchupColor,
                  fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- the fight ----------------

  Widget _fightView(Battle b) => ScreenBody(
        children: [
          ScreenHeader(gate!.fullName,
              trailing:
                  CurrencyChip('${game.mana + b.manaEarned}', 'mana', verdant)),
          const SizedBox(height: 12),
          _enemyPanel(b),
          const SizedBox(height: 9),
          _waveTrack(b),
          const SizedBox(height: 12),
          ..._partyList(b),
          const SizedBox(height: 8),
          _abilityRow(b),
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
      );

  Widget _enemyPanel(Battle b) {
    final e = b.enemy;
    final stacks = b.enrageStacks;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 17, 14, 15),
      decoration: BoxDecoration(
        border: Border.all(color: riftDim),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [rift.withValues(alpha: .16), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
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
          Bar(e.hpFraction, e.isBoss ? blood : const Color(0xFFA33B52)),
          const SizedBox(height: 5),
          Text('${e.hp.ceil()} / ${e.maxHp.round()}',
              style: const TextStyle(
                  color: boneDim, fontSize: 11, fontFamily: 'monospace')),
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
    final tag = !f.alive ? 'down' : (f.isTaunting ? 'drawing fire' : f.role);
    return Opacity(
      opacity: f.alive ? 1 : .42,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: f.isTaunting ? const Color(0xFF1C1734) : night2,
          border: Border(
            left: BorderSide(
              color: !f.alive ? boneDim : (f.isTaunting ? gold : verdant),
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
                Flexible(
                  child: Text('${f.name}  Lv.${f.level}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: bone, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Text(tag,
                    style: TextStyle(
                        color: f.isTaunting ? gold : boneDim,
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic)),
              ],
            ),
            const SizedBox(height: 4),
            Bar(frac, color),
          ],
        ),
      ),
    );
  }

  Widget _abilityRow(Battle b) => Wrap(
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

  // ---------------- result ----------------

  Widget _resultView(Battle b) {
    final won = b.status == BattleStatus.won;
    final g = gate!;
    final post = game.postRaidBeat;
    return ScreenBody(
      children: [
        const SizedBox(height: 24),
        Text(won ? 'Gate cleared' : 'Party withdrawn',
            textAlign: TextAlign.center,
            style: TextStyle(color: won ? verdant : blood, fontSize: 25)),
        const SizedBox(height: 11),
        Text(
          won
              ? 'The rift closes behind you. ${b.elapsed.round()}s in the gate.'
              : 'You pull back through the tear. The gate stays open, and '
                  'everything you earned in there is still yours.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: boneDim, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 16),
        Center(
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
        ),
        if (won && game.lastDropMessage != null) ...[
          const SizedBox(height: 14),
          Text(game.lastDropMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: verdant, fontSize: 12.5, height: 1.4)),
        ],
        if (won)
          for (final msg in game.lastBondMessages) ...[
            const SizedBox(height: 10),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: gold, fontSize: 12.5, height: 1.4)),
          ],
        if (won && game.clears == CombatConfig.clearsToUnlockDoubleSpeed) ...[
          const SizedBox(height: 14),
          const Callout('2× speed unlocked — raid faster from now on.'),
        ],
        if (won && game.clears == CombatConfig.clearsToUnlockFastSpeed) ...[
          const SizedBox(height: 14),
          const Callout('4× speed unlocked.'),
        ],
        const SizedBox(height: 26),
        SlabButton(
          post != null
              ? '${House.byId(post.characterId).name} wants a word'
              : 'Back to the board',
          filled: true,
          tone: post != null ? gold : rift,
          padding: const EdgeInsets.symmetric(vertical: 14),
          onPressed: _leaveResult,
        ),
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
    final borderColor = enabled ? (isUltimate ? gold : verdant) : riftDim;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: night2,
          border: Border.all(color: borderColor),
        ),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: pctLeft.clamp(0, 1),
              child: Container(color: rift.withValues(alpha: .22)),
            ),
            Center(
              child: Text(
                ability.name,
                style: TextStyle(
                  color: enabled ? (isUltimate ? gold : bone) : boneDim,
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
