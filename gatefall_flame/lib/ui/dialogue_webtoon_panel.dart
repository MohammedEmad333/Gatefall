import 'package:flutter/material.dart';

import '../art/comic.dart';
import '../art/sprites.dart';
import '../data/house.dart';
import 'theme.dart';

/// A comic frame for a dialogue node the real engine has already reached.
/// Pure presentation: decisions, story flags, Bond and saves stay in the engine.
class DialogueWebtoonPanel extends StatelessWidget {
  final int index;
  final String characterId;
  final String? speakerId;
  final String speakerName;
  final String text;
  final String? emotion;
  final bool isChoice;

  const DialogueWebtoonPanel({
    super.key,
    required this.index,
    required this.characterId,
    required this.speakerId,
    required this.speakerName,
    required this.text,
    this.emotion,
    this.isChoice = false,
  });

  @override
  Widget build(BuildContext context) {
    final narration = text.startsWith('(') && !isChoice;
    final playerLine = speakerId == 'player' && !narration;
    final accent = isChoice ? rose : narration ? rift : playerLine ? verdant : gold;
    final figureId = playerLine
        ? 'player'
        : House.exists(speakerId ?? '') ? speakerId! : characterId;
    final panelHeight =
        (232 + (text.length / 38).ceil() * 23).clamp(260, 620).toDouble();
    final label = isChoice
        ? 'YOUR CHOICE'
        : narration ? 'NARRATION' : speakerName.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Semantics(
        label: 'Panel ${index + 1}. $label. $text',
        child: ExcludeSemantics(
          child: SizedBox(
            height: panelHeight,
            child: ComicPanel(
              tone: accent,
              tilt: index.isEven ? -.006 : .005,
              toneDensity: .22,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [night2, accent.withValues(alpha: .22), night],
                      ),
                    ),
                  ),
                  if (!isChoice)
                    Positioned(
                      top: 26,
                      right: playerLine ? null : 18,
                      left: playerLine ? 18 : null,
                      child: Opacity(
                        opacity: narration ? .55 : .95,
                        child: CharacterSprite(
                          figureId,
                          size: 136,
                          plate: false,
                          glow: narration ? .35 : .85,
                          calm: true,
                          expression: narration || playerLine ? null : emotion,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 14,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.35,
                            ),
                          ),
                        ),
                        Text(
                          '${(index + 1).toString().padLeft(2, '0')}',
                          style: const TextStyle(color: boneDim, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: night.withValues(alpha: .91),
                          border: Border(
                            left: BorderSide(color: accent, width: 3),
                            top: BorderSide(color: accent.withValues(alpha: .3)),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: isChoice ? rose : narration ? boneDim : bone,
                            fontSize: narration ? 13 : 14,
                            height: 1.48,
                            fontStyle: narration ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
