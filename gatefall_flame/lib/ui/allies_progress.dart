import 'package:flutter/material.dart';
import 'package:gatefall_dialogue_engine/engine/evaluator.dart';

import '../art/sprites.dart';
import '../data/combat_config.dart';
import '../data/roster.dart';
import '../state/game_controller.dart';
import 'theme.dart';

/// The actual saved formation. All changes go through GameController's
/// existing front -> back -> bench cycle and its deployability/party limits.
class AlliesFormationOverview extends StatelessWidget {
  final GameController game;

  const AlliesFormationOverview({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final front = game.roster
        .where((def) => game.formation[def.id] == BattleRow.front)
        .toList();
    final back = game.roster
        .where((def) => game.formation[def.id] == BattleRow.back)
        .toList();
    final bench = game.roster
        .where((def) => !game.formation.containsKey(def.id))
        .toList();

    return Panel(
      key: const Key('allies-formation-overview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Your formation',
                    style: TextStyle(color: bone, fontSize: 16)),
              ),
              Text('${game.partyCount}/${CombatConfig.partyMax} deployed',
                  key: const Key('allies-party-count'),
                  style: const TextStyle(color: verdant, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 5),
          const Text('Tap an ally to cycle Front → Back → Bench. '
              'Your character always stays in the party.',
              style: TextStyle(color: boneDim, height: 1.4, fontSize: 11)),
          const SizedBox(height: 13),
          _formationRow('FRONT', front, isBench: false),
          const SizedBox(height: 11),
          _formationRow('BACK', back, isBench: false),
          if (bench.isNotEmpty) ...[
            const SizedBox(height: 11),
            _formationRow('BENCH', bench, isBench: true),
          ],
        ],
      ),
    );
  }

  Widget _formationRow(
    String title,
    List<FighterDef> fighters, {
    required bool isBench,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: boneDim, letterSpacing: 1.7, fontSize: 10)),
          const SizedBox(height: 7),
          if (fighters.isEmpty)
            const Text('No allies in this row',
                style: TextStyle(color: boneDim, fontSize: 11))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final fighter in fighters)
                  _fighterTile(fighter, isBench: isBench),
              ],
            ),
        ],
      );

  Widget _fighterTile(FighterDef fighter, {required bool isBench}) {
    final canAdd = !isBench || game.partyCount < CombatConfig.partyMax;
    final nextAction = isBench
        ? 'move to front'
        : game.formation[fighter.id] == BattleRow.front
            ? 'move to back'
            : fighter.locked
                ? 'move to front'
                : 'bench';
    final tier = game.bondTier(fighter.id);
    return Tooltip(
      message: canAdd ? '${fighter.name}: $nextAction' : 'Party is full',
      child: Semantics(
        button: true,
        enabled: canAdd,
        label: '${fighter.name}, '
            '${isBench ? "benched" : game.formation[fighter.id] == BattleRow.front ? "front" : "back"}, '
            '${canAdd ? nextAction : "party full"}',
        child: InkWell(
          key: Key('allies-formation-${fighter.id}'),
          onTap: canAdd ? () => game.cycleFormation(fighter.id) : null,
          child: Container(
            width: 104,
            padding: const EdgeInsets.fromLTRB(6, 7, 6, 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: isBench ? riftDim : verdant.withValues(alpha: .6),
              ),
              color: isBench
                  ? night.withValues(alpha: .55)
                  : rift.withValues(alpha: .12),
            ),
            child: Column(
              children: [
                CharacterSprite(
                  fighter.id,
                  size: 56,
                  glow: isBench ? .2 : .8,
                  dimmed: isBench,
                  calm: true,
                ),
                const SizedBox(height: 3),
                Text(fighter.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(color: bone, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  fighter.id == 'player' ? 'Awakened' : 'Bond $tier',
                  style: const TextStyle(color: boneDim, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Uses the same thresholds as the story evaluator, not an invented
/// percentage. The highest tier is represented as a completed bar.
class AlliesBondProgress extends StatelessWidget {
  final int points;
  final int tier;

  const AlliesBondProgress({
    super.key,
    required this.points,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    final thresholds = Evaluator.bondTierThresholds;
    final current = tier.clamp(0, thresholds.length - 1);
    final atMax = current == thresholds.length - 1;
    final lower = thresholds[current];
    final upper = atMax ? lower : thresholds[current + 1];
    final fraction = atMax
        ? 1.0
        : ((points - lower) / (upper - lower)).clamp(0.0, 1.0);
    return Column(
      key: const Key('allies-bond-progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Bond tier $current/${thresholds.length - 1}',
                  style: const TextStyle(color: rose, fontSize: 11)),
            ),
            Text(atMax ? 'Max tier' : '${(upper - points).clamp(0, upper)} to next tier',
                style: const TextStyle(color: boneDim, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 5),
        Bar(fraction, rose, height: 5),
        const SizedBox(height: 4),
        Text('$points Bond points',
            style: const TextStyle(color: boneDim, fontSize: 10)),
      ],
    );
  }
}

/// A purely read-only visual account of completed route beats.
class AlliesStoryProgress extends StatelessWidget {
  final int completed;
  final int total;

  const AlliesStoryProgress({
    super.key,
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) => Column(
        key: const Key('allies-story-progress'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$completed/$total stories remembered',
              style: const TextStyle(color: rose, fontSize: 11)),
          const SizedBox(height: 5),
          Bar(total == 0 ? 0 : completed / total, gold, height: 5),
        ],
      );
}
