import 'package:flutter/material.dart';

/// Stops expensive character sprite-frame timers while the newest panel is
/// outside the visible portion of a lazy comic list. Previous panels already
/// have their TickerMode disabled by the reader.
///
/// [trailingExtent] is the measured last item height plus list bottom padding.
/// The last item intersects the viewport while extentAfter <= that distance.
///
/// The wrapper listens to scrolling without rebuilding the parent chapter,
/// and passes through the same [child] on each visibility transition.
class WebtoonVisibleTicker extends StatefulWidget {
  final ScrollController controller;
  final double trailingExtent;
  final Widget child;

  const WebtoonVisibleTicker({
    super.key,
    required this.controller,
    required this.trailingExtent,
    required this.child,
  });

  @override
  State<WebtoonVisibleTicker> createState() => _WebtoonVisibleTickerState();
}

class _WebtoonVisibleTickerState extends State<WebtoonVisibleTicker> {
  bool _visible = true;
  bool _pendingCheck = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_queueCheck);
    _queueCheck();
  }

  @override
  void didUpdateWidget(covariant WebtoonVisibleTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_queueCheck);
      widget.controller.addListener(_queueCheck);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.trailingExtent != widget.trailingExtent) {
      _queueCheck();
    }
  }

  // Scroll metrics can change during layout; never call setState from a
  // controller notification fired by SliverList's own layout work.
  void _queueCheck() {
    if (_pendingCheck) return;
    _pendingCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingCheck = false;
      if (!mounted || !widget.controller.hasClients) return;
      final position = widget.controller.position;
      if (!position.hasContentDimensions) return;
      final visible =
          position.extentAfter <= widget.trailingExtent + 1;
      if (visible != _visible) setState(() => _visible = visible);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_queueCheck);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TickerMode(
        enabled: _visible,
        child: widget.child,
      );
}
