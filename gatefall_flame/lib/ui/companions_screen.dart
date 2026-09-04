import 'package:flutter/material.dart';

import '../data/ascension.dart';
import '../data/bond.dart';
import '../data/element.dart';
import '../data/gear.dart';
import '../data/house.dart';
import '../data/progression.dart';
import '../data/roster.dart';
import '../state/game_controller.dart';
import 'theme.dart';

/// Where Mana is spent. Three of the four progression tracks in
/// docs/combat-spec.md §6 live here — companion level and gear, both bought
/// with Mana, and Bond, which is shown but never purchasable.
class CompanionsScreen extends StatefulWidget {
  final GameController game;
  const CompanionsScreen({super.key, required this.game});

  @override
  State<CompanionsScreen> createState() => _CompanionsScreenState();
}

class _CompanionsScreenState extends State<CompanionsScreen> {
  GameController get game => widget.game;

  @override
  Widget build(BuildContext context) {
    return ScreenBody(
      children: [
        ScreenHeader('Who you take in there',
            trailing: CurrencyChip('${game.mana}', 'mana', verdant)),
        const SizedBox(height: 4),
        const Text(
          'Mana buys levels and enhances gear. Bond is not for sale — it comes '
          'from fighting together and from everything that happens at home.',
          style: TextStyle(
              color: boneDim,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.5),
        ),
        const SizedBox(height: 14),
        for (final def in game.roster) ...[
          _fighterPanel(def),
          const SizedBox(height: 12),
        ],
        for (final id in Roster.all
            .map((f) => f.id)
            .where(game.awaitingAwakening))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Callout(
              '${Roster.byId(id).name} lives here but does not fight. '
              '${Ascension.byId(id).cure} Finish her route and she joins the '
              'party.',
              tone: rose,
            ),
          ),
        if (game.roster.length < Roster.all.length)
          const Callout(
            'Not everyone here fights yet. Build rooms at the house to bring '
            'the rest of them home.',
            tone: boneDim,
          ),
      ],
    );
  }

  Widget _fighterPanel(FighterDef def) {
    final level = game.levels[def.id] ?? Progression.minLevel;
    final levelCost = Progression.costFor(level);
    final levelMaxed = levelCost < 0;
    final canLevel = !levelMaxed && game.mana >= levelCost;

    final g = game.gear[def.id];
    final gearCost = g?.enhanceCost ?? -1;
    final gearMaxed = g != null && gearCost < 0;
    final canEnhance = g != null && !gearMaxed && game.mana >= gearCost;
    final gearPct = g == null ? 0 : ((g.statMultiplier - 1) * 100).round();

    final tier = game.bondTier(def.id);
    final bondPct = ((BondBuff.statMultiplier(tier) - 1) * 100).round();
    final hasRoute = game.routes.containsKey(def.id);
    final deployed = game.formation.containsKey(def.id);

    // "Nothing available right now" is not "route finished" — see
    // GameController.upcomingBeat.
    final upcoming = game.upcomingBeat(def.id);
    final available = game.nextBeat(def.id);
    final nextBeatSuffix = upcoming == null
        ? ''
        : available != null
            ? ' · ready: "${available.title}"'
            : ' · next: "${upcoming.title}"';

    final total = Progression.statMultiplier(level) *
        (g?.statMultiplier ?? 1.0) *
        BondBuff.statMultiplier(tier);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(def.name,
                        style: const TextStyle(color: bone, fontSize: 15)),
                    Text(
                      '${def.role} · ${def.element.label}'
                      '${deployed ? " · deployed" : " · benched"}',
                      style: TextStyle(
                          color: deployed ? verdant : boneDim, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text('×${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: gold, fontSize: 15, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 3),
          const Text('total stat multiplier',
              textAlign: TextAlign.right,
              style: TextStyle(color: boneDim, fontSize: 9.5)),
          const SizedBox(height: 12),

          // Level
          _trackRow(
            title: 'Level $level',
            detail: levelMaxed
                ? 'max level'
                : '+4% attack, HP and ability power each — next costs '
                    '$levelCost mana',
            buttonLabel: levelMaxed ? 'Max' : 'Level up',
            tone: canLevel ? gold : boneDim,
            onPressed: canLevel
                ? () => setState(() => game.levelUp(def.id))
                : null,
          ),

          // Gear
          _trackRow(
            title: g == null
                ? 'No gear yet'
                : '${g.rarity.label} +${g.enhanceLevel}',
            detail: g == null
                ? 'every gate you clear drops a piece — it equips itself if '
                    'it beats what they have, or salvages into mana if not'
                : gearMaxed
                    ? '+$gearPct% to everything — fully enhanced'
                    : '+$gearPct% to everything — enhance for $gearCost mana',
            buttonLabel: g == null ? '—' : (gearMaxed ? 'Max' : 'Enhance'),
            tone: canEnhance ? gold : boneDim,
            onPressed: canEnhance
                ? () => setState(() => game.enhanceGear(def.id))
                : null,
          ),

          // Bond
          _trackRow(
            title: hasRoute
                ? 'Bond tier $tier/${game.maxBondTier}'
                : 'No bond — that is you',
            detail: hasRoute
                ? '+$bondPct% attack and HP · ${game.bondPoints(def.id)} points'
                    '$nextBeatSuffix'
                : 'the awakened human at the middle of all this',
            buttonLabel: 'At home',
            tone: boneDim,
            onPressed: null,
          ),

          // Ascension — the fourth track, and the only one that cannot be
          // bought at all. It is what finishing a route pays out.
          if (Ascension.exists(def.id)) _ascensionRow(def.id),
        ],
      ),
    );
  }

  Widget _ascensionRow(String id) {
    final a = Ascension.byId(id);
    final done = game.isAscended(id);
    final ability = Ascension.abilities[id];
    return _trackRow(
      title: done ? '${a.title} — ascended' : 'Ascension locked',
      detail: done
          ? '${ability?.name ?? a.title}: ${a.cure}'
          : 'her route\'s last scene grants it — ${a.lie}',
      buttonLabel: done ? 'Earned' : 'Locked',
      tone: done ? rose : boneDim,
      onPressed: null,
    );
  }

  Widget _trackRow({
    required String title,
    required String detail,
    required String buttonLabel,
    required Color tone,
    VoidCallback? onPressed,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(color: bone, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(detail,
                      style: const TextStyle(
                          color: boneDim, fontSize: 10.5, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 86,
              child: SlabButton(buttonLabel,
                  tone: tone,
                  onPressed: onPressed,
                  padding: const EdgeInsets.symmetric(vertical: 9)),
            ),
          ],
        ),
      );
}

/// Small helper so the file above can name residents without importing the
/// house everywhere.
String residentName(String id) =>
    House.exists(id) ? House.byId(id).name : id;
