import 'package:flutter/material.dart';

import '../art/gate_art.dart';
import '../art/sprites.dart';
import '../data/element.dart';
import 'theme.dart';

/// Pure presentation for the already-running encounter; combat simulation
/// remains the only source of truth for waves and guardian status.
class RaidEncounterBanner extends StatelessWidget {
  final GateElement element;
  final int waveIndex;
  final int waveCount;
  final bool onBoss;

  const RaidEncounterBanner({
    super.key,
    required this.element,
    required this.waveIndex,
    required this.waveCount,
    required this.onBoss,
  });

  @override
  Widget build(BuildContext context) {
    final title = onBoss
        ? 'THE GATE GUARDIAN'
        : 'WAVE ${waveIndex + 1} / $waveCount';
    return Container(
      key: const Key('raid-encounter-banner'),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: onBoss ? blood : rift, width: 3)),
        gradient: LinearGradient(colors: [
          (onBoss ? blood : rift).withValues(alpha: .22),
          night2,
        ]),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Icon(onBoss ? Icons.warning_amber_rounded : Icons.blur_on_outlined,
              size: 20, color: onBoss ? blood : boneDim),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: TextStyle(
                  color: onBoss ? blood : bone,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1.3,
                )),
          ),
          Text(element.label,
              style: const TextStyle(color: boneDim, fontSize: 11)),
        ],
      ),
    );
  }
}

/// The raid's cinematic resolution is a visual account of the *real* outcome.
/// Values, rewards and unlocks are rendered separately by GateScreen.
class RaidOutcomeHero extends StatelessWidget {
  final bool won;
  final GateElement element;
  final String gateName;
  final int elapsedSeconds;
  final List<String> partyIds;

  const RaidOutcomeHero({
    super.key,
    required this.won,
    required this.element,
    required this.gateName,
    required this.elapsedSeconds,
    required this.partyIds,
  });

  @override
  Widget build(BuildContext context) {
    final accent = won ? verdant : blood;
    final companion = partyIds.where((id) => id != 'player').firstOrNull;
    return Semantics(
      label: won ? 'Gate cleared. $gateName.' : 'Party withdrawn. $gateName.',
      child: Container(
        key: const Key('raid-outcome-hero'),
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: accent.withValues(alpha: .5)),
          color: night2,
        ),
        child: Column(
          children: [
            SizedBox(
              height: 153,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            night,
                            accent.withValues(alpha: .20),
                            night2,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: RiftView(
                      element: element,
                      size: 145,
                      intensity: won ? .3 : .85,
                    ),
                  ),
                  Positioned(
                    bottom: -13,
                    left: 12,
                    child: CharacterSprite('player',
                        size: 115, plate: false, glow: won ? .8 : .28),
                  ),
                  if (companion != null)
                    Positioned(
                      bottom: -11,
                      right: 12,
                      child: CharacterSprite(companion,
                          size: 118, plate: false, glow: won ? .72 : .30),
                    ),
                  Positioned(
                    top: 8,
                    left: 12,
                    child: Text(
                      won ? 'GATE CLOSED' : 'RETREAT',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        letterSpacing: 1.9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                children: [
                  Text(
                    won ? 'Gate cleared' : 'Party withdrawn',
                    style: TextStyle(color: accent, fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    won
                        ? 'The rift closes behind you. ${elapsedSeconds}s in the gate.'
                        : 'You pull back through the tear. The gate stays open, and '
                          'everything you earned in there is still yours.',
                    style: const TextStyle(
                        color: boneDim, fontSize: 12.5, height: 1.45),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A verified next chapter, not an invented unlock. GateScreen supplies this
/// only after reading the controller's real availability evaluator.
class RaidStoryBridge extends StatelessWidget {
  final String characterId;
  final String title;
  final bool postRaid;

  const RaidStoryBridge({
    super.key,
    required this.characterId,
    required this.title,
    required this.postRaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(postRaid ? 'raid-post-story-bridge' : 'raid-ready-story-bridge'),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: gold.withValues(alpha: .65)),
        gradient: LinearGradient(
          colors: [gold.withValues(alpha: .12), night2],
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CharacterSprite(
            characterId,
            size: 66,
            plate: false,
            glow: .75,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(postRaid ? 'AFTER THE GATE' : 'NEXT STORY CHAPTER',
                    style: const TextStyle(
                      color: gold,
                      fontSize: 10,
                      letterSpacing: 1.1,
                    )),
                const SizedBox(height: 4),
                Text(title,
                    style: const TextStyle(
                        color: bone, fontSize: 14, height: 1.3)),
                const SizedBox(height: 4),
                Text(
                  postRaid
                      ? 'A companion has something to say about the raid.'
                      : 'An available scene awaits in Story.',
                  style: const TextStyle(
                      color: boneDim, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
