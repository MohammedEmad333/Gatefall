import 'package:flutter/material.dart';

import 'theme.dart';

/// An overlay that only rebuilds itself while a long transcript is scrolled.
/// The ListView and its painted panels are not rebuilt on every scroll tick.
class WebtoonLatestButton extends StatelessWidget {
  final ScrollController controller;
  final VoidCallback onPressed;

  const WebtoonLatestButton({
    super.key,
    required this.controller,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.hasClients ||
              !controller.position.hasContentDimensions ||
              controller.position.extentAfter < 220) {
            return const SizedBox.shrink();
          }
          return TextButton.icon(
            key: const Key('dialogue-back-to-latest'),
            onPressed: onPressed,
            style: TextButton.styleFrom(
              backgroundColor: night2,
              foregroundColor: verdant,
              side: const BorderSide(color: riftDim),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
            icon: const Icon(Icons.arrow_downward, size: 16),
            label: const Text('Latest panel', style: TextStyle(fontSize: 12)),
          );
        },
      );
}
