import 'package:flutter/material.dart';

import '../art/gate_art.dart';
import '../art/sprites.dart';
import '../data/element.dart';
import 'theme.dart';

/// Narrative-first cover for the House. Presentation only: it is handed the
/// next real action by HomeScreen, never computes or changes progression.
class HouseHero extends StatelessWidget {
  final String characterId;
  final String actTitle;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onAction;
  final Color tone;

  const HouseHero({
    super.key,
    required this.characterId,
    required this.actTitle,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    this.tone = gold,
  });

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('house-hero'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: night2,
          border: Border.all(color: rift),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 166,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [night, Color(0xFF342459), night2],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -56,
                    left: -62,
                    child: Opacity(
                      opacity: .42,
                      child: RiftView(
                        element: GateElement.verdant,
                        size: 218,
                        intensity: .8,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -10,
                    top: 0,
                    width: 190,
                    child: CharacterHero(
                      characterId,
                      height: 166,
                      glow: .8,
                    ),
                  ),
                  // Keep the game logo readable regardless of hero art.
                  const Positioned(
                    top: 19,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GATEFALL',
                          style: TextStyle(
                            color: bone,
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                blurRadius: 12,
                                color: night,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'A HOUSE BETWEEN WORLDS',
                          style: TextStyle(
                            color: gold,
                            fontSize: 9,
                            letterSpacing: 1,
                            shadows: [
                              Shadow(blurRadius: 8, color: night),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 13,
                    right: 16,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: night.withValues(alpha: .84),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: riftDim),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          child: Text(
                            actTitle,
                            style: const TextStyle(
                              color: bone,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: bone,
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: boneDim,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SlabButton(
                    actionLabel,
                    key: const Key('house-hero-action'),
                    filled: true,
                    tone: tone,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    onPressed: onAction,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
