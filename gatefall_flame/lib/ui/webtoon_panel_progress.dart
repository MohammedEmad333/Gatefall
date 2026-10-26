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

/// A screen-independent bookmark. Keeping the panel and relative position
/// avoids restoring the wrong dialogue line when font scale/width changes.
class WebtoonReadingAnchor {
  final int panelIndex;
  final double fraction;
  const WebtoonReadingAnchor(this.panelIndex, this.fraction);
}

/// Capture the panel intersecting the top of the viewport. This is based on
/// measured item ends, not an estimate or an index into unvisited story nodes.
WebtoonReadingAnchor webtoonAnchorAt(
  List<double> panelEnds,
  double offset,
) {
  if (panelEnds.isEmpty) return const WebtoonReadingAnchor(0, 0);
  final target = offset.clamp(0.0, panelEnds.last);
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
  final index = low >= panelEnds.length ? panelEnds.length - 1 : low;
  final start = index == 0 ? 0.0 : panelEnds[index - 1];
  final length = panelEnds[index] - start;
  return WebtoonReadingAnchor(
    index,
    length <= 0 ? 0.0 : ((target - start) / length).clamp(0.0, 1.0),
  );
}

double webtoonOffsetForAnchor(
  List<double> panelEnds,
  WebtoonReadingAnchor anchor,
) {
  if (panelEnds.isEmpty) return 0;
  final index = anchor.panelIndex < 0
      ? 0
      : anchor.panelIndex >= panelEnds.length
          ? panelEnds.length - 1
          : anchor.panelIndex;
  final start = index == 0 ? 0.0 : panelEnds[index - 1];
  return start + (panelEnds[index] - start) * anchor.fraction.clamp(0, 1);
}

/// The start of a reached panel, for direct reader navigation.
double webtoonPanelStart(List<double> panelEnds, int panelIndex) {
  if (panelEnds.isEmpty || panelIndex <= 0) return 0;
  final index = panelIndex >= panelEnds.length
      ? panelEnds.length - 1
      : panelIndex;
  return panelEnds[index - 1];
}

/// Small, accessible reading progress. Listening to scroll locally keeps
/// the full dialogue, illustrations, and game engine out of the scroll loop.
class WebtoonPanelProgress extends StatefulWidget {
  final ScrollController controller;
  final List<double> panelEnds;
  final ValueChanged<int>? onJumpToPanel;

  const WebtoonPanelProgress({
    super.key,
    required this.controller,
    required this.panelEnds,
    this.onJumpToPanel,
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

  void _showPanelPicker(int visibleIndex) {
    final total = widget.panelEnds.length;
    if (total <= 1 || widget.onJumpToPanel == null) return;
    var selected = visibleIndex.clamp(0, total - 1) + 1;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: night2,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: StatefulBuilder(
            builder: (context, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Go to panel',
                    style: TextStyle(color: bone, fontSize: 18)),
                const SizedBox(height: 9),
                Text('Panel $selected of $total',
                    key: const Key('dialogue-target-panel'),
                    style: const TextStyle(color: boneDim, fontSize: 13)),
                Slider(
                  key: const Key('dialogue-panel-slider'),
                  min: 1,
                  max: total.toDouble(),
                  divisions: total - 1,
                  value: selected.toDouble(),
                  label: '$selected',
                  onChanged: (value) =>
                      setSheetState(() => selected = value.round()),
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IconButton(
                      key: const Key('dialogue-previous-panel'),
                      tooltip: 'Previous panel',
                      onPressed: selected <= 1
                          ? null
                          : () => setSheetState(() => selected--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      key: const Key('dialogue-next-panel'),
                      tooltip: 'Next panel',
                      onPressed: selected >= total
                          ? null
                          : () => setSheetState(() => selected++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      key: const Key('dialogue-jump-to-panel'),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        widget.onJumpToPanel?.call(selected - 1);
                      },
                      child: const Text('Go to panel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
            button: total > 1 && widget.onJumpToPanel != null,
            label: 'Reading panel ${total == 0 ? 0 : index + 1} of $total. '
                'Choose a panel',
            child: InkWell(
              key: const Key('dialogue-panel-progress'),
              onTap: total > 1 && widget.onJumpToPanel != null
                  ? () => _showPanelPicker(index)
                  : null,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: night2.withValues(alpha: .94),
                    border: Border.all(color: riftDim),
                  ),
                  child: Text(
                    'PANEL ${total == 0 ? 0 : index + 1} / $total',
                    style: const TextStyle(
                      color: boneDim,
                      fontSize: 11,
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
