import 'package:flutter/material.dart';

import 'theme.dart';

/// The first panel intersecting the upper reading region. [panelEnds] holds
/// cumulative bottom edges including preceding panel heights and top padding,
/// so this is logarithmic in chapter length even during a fast fling.
int webtoonVisiblePanelIndex(
  List<double> panelEnds, {
  required double offset,
  required double viewportExtent,
}) {
  if (panelEnds.isEmpty) return 0;
  final target = (offset + viewportExtent * .28).clamp(0, panelEnds.last);
  var low = 0;
  var high = panelEnds.length;
  while (low < high) {
    final mid = low + (high - low) ~/ 2;
    if (panelEnds[mid] <= target) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low >= panelEnds.length ? panelEnds.length - 1 : low;
}

/// Small, non-interactive reading progress. Listening to scroll locally keeps
/// the full dialogue, illustrations, and game engine out of the scroll loop.
class WebtoonPanelProgress extends StatefulWidget {
  final ScrollController controller;
  final List<double> panelEnds;

  const WebtoonPanelProgress({
    super.key,
    required this.controller,
    required this.panelEnds,
  });

  @override
  State<WebtoonPanelProgress> createState() => _WebtoonPanelProgressState();
}

class _WebtoonPanelProgressState extends State<WebtoonPanelProgress> {
  @override
  void initState() {
    super.initState();
    // A newly attached ListView has no dimensions on the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant WebtoonPanelProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final position = widget.controller.hasClients
              ? widget.controller.position
              : null;
          final index = position == null || !position.hasContentDimensions
              ? 0
              : webtoonVisiblePanelIndex(
                  widget.panelEnds,
                  offset: position.pixels,
                  viewportExtent: position.viewportDimension,
                );
          final total = widget.panelEnds.length;
          return Semantics(
            label: 'Reading panel ${total == 0 ? 0 : index + 1} of $total',
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Container(
                  key: const Key('dialogue-panel-progress'),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: night2.withValues(alpha: .94),
                    border: Border.all(color: riftDim),
                  ),
                  child: Text(
                    'PANEL ${total == 0 ? 0 : index + 1} / $total',
                    style: const TextStyle(
                      color: boneDim,
                      fontSize: 10,
                      letterSpacing: .8,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
