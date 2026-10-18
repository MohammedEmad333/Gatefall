import 'package:flutter/material.dart';

import '../art/comic.dart';
import '../art/effects.dart';
import '../art/sprites.dart';
import '../data/house.dart';
import 'dialogue_scene_backdrop.dart';
import 'theme.dart';

/// An illustrated panel for a node the real dialogue engine has reached.
/// Never reads or mutates game progression or decides a story branch.
class DialogueWebtoonPanel extends StatelessWidget {
  final int index;
  final String characterId;
  final String? speakerId;
  final String speakerName;
  final String text;
  final String? emotion;
  final bool isChoice;
  final bool isLatest;
  final String contextTag;

  const DialogueWebtoonPanel({
    super.key,
    required this.index,
    required this.characterId,
    required this.speakerId,
    required this.speakerName,
    required this.text,
    this.emotion,
    this.isChoice = false,
    this.isLatest = false,
    this.contextTag = 'story',
  });

  @override
  Widget build(BuildContext context) {
    final narration = text.startsWith('(') && !isChoice;
    final playerLine = speakerId == 'player' && !narration;
    final accent = isChoice ? rose : narration ? rift : playerLine ? verdant : gold;
    final figureId = playerLine
        ? 'player'
        : House.exists(speakerId ?? '') ? speakerId! : characterId;
    final label = isChoice
        ? 'YOUR CHOICE'
        : narration ? 'NARRATION' : speakerName.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Semantics(
        label: 'Panel ${index + 1}. $label. $text',
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Text length alone cannot size a portrait panel: a 280px
              // handset and large text scaling need more vertical room.
              final width = constraints.maxWidth;
              final textScale =
                  MediaQuery.textScalerOf(context).scale(14) / 14;
              final charsPerRow = ((width - 62) / (7.0 * textScale))
                  .floor()
                  .clamp(12, 60);
              final rows = (text.runes.length / charsPerRow).ceil() + 1;
              final panelHeight =
                  (255 + rows * 22 * textScale).clamp(298, 1250).toDouble();
              final figureSize = (width * .49).clamp(100, 192).toDouble();

              return SizedBox(
                height: panelHeight,
                child: ComicPanel(
                  tone: accent,
                  tilt: index.isEven ? -.006 : .005,
                  toneDensity: .20,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DialogueSceneBackdrop(
                        contextTag: contextTag,
                        accent: accent,
                        isLatest: isLatest,
                        isChoice: isChoice,
                      ),
                      if (!isChoice && !narration)
                        Positioned(
                          top: 38,
                          right: playerLine ? null : 8,
                          left: playerLine ? 8 : null,
                          child: CharacterSprite(
                            figureId,
                            size: figureSize,
                            plate: false,
                            glow: .95,
                            calm: true,
                            expression: playerLine ? null : emotion,
                          ),
                        ),
                      if (!isChoice && narration)
                        Positioned(
                          top: 42,
                          right: 6,
                          child: Opacity(
                            opacity: .53,
                            child: CharacterSprite(
                              characterId,
                              size: figureSize * .82,
                              plate: false,
                              calm: true,
                              glow: .35,
                            ),
                          ),
                        ),
                      // Secondary actor anchors the opposite edge of the
                      // frame, so every dialogue panel has a readable focus.
                      if (!isChoice && !narration)
                        Positioned(
                          top: 72,
                          left: playerLine ? null : 8,
                          right: playerLine ? 8 : null,
                          child: Opacity(
                            opacity: .32,
                            child: CharacterSprite(
                              playerLine ? characterId : 'player',
                              size: figureSize * .55,
                              plate: false,
                              calm: true,
                              glow: .25,
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
                              style: const TextStyle(
                                color: boneDim,
                                fontSize: 10,
                              ),
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
                              color: night.withValues(alpha: .94),
                              border: Border(
                                left: BorderSide(color: accent, width: 3),
                                top: BorderSide(
                                  color: accent.withValues(alpha: .3),
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                            child: Text(
                              text,
                              style: TextStyle(
                                color: isChoice
                                    ? rose
                                    : narration ? boneDim : bone,
                                fontSize: narration ? 13 : 14,
                                height: 1.48,
                                fontStyle: narration
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Only newly reached lines animate; scrolling earlier history does not
/// restart their entrances. [Reveal] obeys the app's reduced-motion switch.
class DialoguePanelEntrance extends StatelessWidget {
  final Widget child;
  final int index;

  const DialoguePanelEntrance({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  Widget build(BuildContext context) => Reveal(
        key: ValueKey('chapter-panel-entrance-$index'),
        offset: 18,
        child: child,
      );
}
