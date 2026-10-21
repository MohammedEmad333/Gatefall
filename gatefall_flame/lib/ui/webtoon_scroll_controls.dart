import 'package:flutter/material.dart';

import 'theme.dart';

/// An overlay that only rebuilds itself while a long transcript is scrolled.
/// The ListView and its painted panels are not rebuilt on every scroll tick.
class WebtoonLatestButton extends StatefulWidget {
  final ScrollController controller;
  final VoidCallback onPressed;

  const WebtoonLatestButton({
    super.key,
    required this.controller,
    required this.onPressed,
  });

  @override
  State<WebtoonLatestButton> createState() => _WebtoonLatestButtonState();
}

class _WebtoonLatestButtonState extends State<WebtoonLatestButton> {
  @override
  void initState() {
    super.initState();
    // ScrollController does not notify listeners when its first ScrollPosition
    // attaches, and metrics are not ready during the initial build. Refresh
    // once after layout so the shortcut is visible before the first drag.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant WebtoonLatestButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      // A replacement controller may not have a ScrollPosition until the
      // next layout. Recheck the shortcut after its first attachment.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          if (!widget.controller.hasClients ||
              !widget.controller.position.hasContentDimensions ||
              widget.controller.position.extentAfter < 220) {
            return const SizedBox.shrink();
          }
          return TextButton.icon(
            key: const Key('dialogue-back-to-latest'),
            onPressed: widget.onPressed,
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
