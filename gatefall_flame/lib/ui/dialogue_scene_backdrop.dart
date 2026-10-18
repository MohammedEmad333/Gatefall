import 'package:flutter/material.dart';

import '../art/comic.dart';
import '../art/gate_art.dart';
import '../data/element.dart';
import 'theme.dart';

/// Broad, non-canonical atmospheres keyed to the *existing* beat context.
/// Exact scene events are still told only by the authored dialogue text.
String chapterAtmosphere(String contextTag) => switch (contextTag) {
      'home_visit' => 'home',
      'gift' => 'gift',
      'date' => 'date',
      'post_raid' => 'aftermath',
      _ => 'rift',
    };

/// Reuses GateFall's painted scenery. No generated image replaces approved
/// character art, and earlier panels use still art to conserve frame budget.
class DialogueSceneBackdrop extends StatelessWidget {
  final String contextTag;
  final Color accent;
  final bool isLatest;
  final bool isChoice;

  const DialogueSceneBackdrop({
    super.key,
    required this.contextTag,
    required this.accent,
    required this.isLatest,
    this.isChoice = false,
  });

  @override
  Widget build(BuildContext context) {
    final setting = chapterAtmosphere(contextTag);
    final home = setting == 'home' || setting == 'gift' || setting == 'date';
    final warm = switch (setting) {
      'gift' => gold,
      'date' => rose,
      _ => accent,
    };

    return Stack(
      key: Key('chapter-setting-$setting'),
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                night,
                warm.withValues(alpha: .30),
                night2,
              ],
            ),
          ),
        ),
        if (!isChoice && home)
          CustomPaint(
            painter: HousePainter(
              warm: warm,
              heightFactor: .65,
              centerX: setting == 'date' ? .58 : .40,
            ),
          ),
        if (!isChoice && !home)
          CustomPaint(
            painter: SpeedLinesPainter(
              color: accent,
              lines: setting == 'aftermath' ? 28 : 18,
              innerRadius: .32,
            ),
          ),
        if (!isChoice && !home && isLatest)
          Align(
            alignment: const Alignment(.6, -.2),
            child: Opacity(
              opacity: .55,
              child: RiftView(
                element: GateElement.gloam,
                intensity: setting == 'aftermath' ? .85 : .52,
                size: 142,
              ),
            ),
          ),
        // An inked vignette separates captions from painted scenery without
        // obscuring the original character assets placed above this layer.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                night.withValues(alpha: .06),
                Colors.transparent,
                night.withValues(alpha: .72),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
