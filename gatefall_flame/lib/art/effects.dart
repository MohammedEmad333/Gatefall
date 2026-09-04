import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../ui/theme.dart';
import 'motion.dart';

/// The small motions that make a static panel feel like a fight: something
/// shaking, a number leaving the screen, a bar catching up, a line of
/// dialogue arriving a character at a time.
///
/// Everything here is *one-shot*. That is not an accident — a finite
/// animation finishes, which is what lets `pumpAndSettle` work and what
/// lets a widget test assert that a screen has arrived. The endless
/// animations all live behind [Motion.ambient] instead.

/// Wraps a subtree and shakes it on demand.
///
///     final shake = GlobalKey<ShakeBoxState>();
///     ShakeBox(key: shake, child: …);
///     shake.currentState?.shake();
class ShakeBox extends StatefulWidget {
  final Widget child;
  const ShakeBox({super.key, required this.child});

  @override
  State<ShakeBox> createState() => ShakeBoxState();
}

class ShakeBoxState extends State<ShakeBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  double _power = 0;
  final Random _rng = Random();
  double _angle = 0;

  /// [power] 1 is an ability landing; 2 is the boss turning up.
  void shake([double power = 1]) {
    if (!Motion.transitions) return;
    _power = power.clamp(.2, 3);
    _angle = _rng.nextDouble() * pi * 2;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          if (!_c.isAnimating) return child!;
          // Decaying oscillation: hard at the start, gone by the end, and
          // never a drift that leaves the layout moved.
          final decay = (1 - _c.value) * (1 - _c.value);
          final wobble = sin(_c.value * pi * 7) * decay * _power * 5;
          return Transform.translate(
            offset: Offset(cos(_angle) * wobble, sin(_angle) * wobble * .6),
            child: child,
          );
        },
        child: widget.child,
      );
}

/// Damage, healing and mana, leaving the screen upward.
class DamageLayer extends StatefulWidget {
  const DamageLayer({super.key});

  @override
  State<DamageLayer> createState() => DamageLayerState();
}

class DamageLayerState extends State<DamageLayer> {
  final List<_Floater> _floaters = [];
  int _seq = 0;

  /// Throw a number (or a word) up the screen. [big] is for a crit or an
  /// ultimate — the two things worth interrupting the player's eye for.
  void spawn(String text, Color color, {bool big = false}) {
    if (!mounted || !Motion.transitions) return;
    setState(() {
      _floaters.add(_Floater(id: _seq++, text: text, color: color, big: big));
      // A fight at 4× speed can queue these faster than they expire.
      if (_floaters.length > 12) _floaters.removeAt(0);
    });
  }

  void _retire(int id) {
    if (!mounted) return;
    setState(() => _floaters.removeWhere((f) => f.id == id));
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final f in _floaters)
              _FloatingText(
                key: ValueKey(f.id),
                floater: f,
                onDone: () => _retire(f.id),
              ),
          ],
        ),
      );
}

class _Floater {
  final int id;
  final String text;
  final Color color;
  final bool big;

  /// Where along the width it starts, so two numbers in the same frame do
  /// not stack exactly on top of each other.
  final double x = .18 + Random().nextDouble() * .64;

  _Floater({
    required this.id,
    required this.text,
    required this.color,
    required this.big,
  });
}

class _FloatingText extends StatefulWidget {
  final _Floater floater;
  final VoidCallback onDone;

  const _FloatingText({super.key, required this.floater, required this.onDone});

  @override
  State<_FloatingText> createState() => _FloatingTextState();
}

class _FloatingTextState extends State<_FloatingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.floater.big ? 1100 : 850),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.floater;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // Out fast, then slow — the shape of something thrown.
        final rise = 1 - pow(1 - t, 2.2).toDouble();
        return Align(
          alignment: Alignment(f.x * 2 - 1, .75 - rise * 1.5),
          child: Opacity(
            opacity: (1 - pow(t, 2.6)).toDouble().clamp(0, 1),
            child: Transform.scale(
              scale: f.big ? 1.0 + .25 * (1 - rise) : 1.0,
              child: Text(
                f.text,
                style: TextStyle(
                  color: f.color,
                  fontSize: f.big ? 21 : 14,
                  fontFamily: 'monospace',
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 5),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A [Bar] that catches up rather than teleporting, with a slower ghost
/// behind it showing what was just lost. The ghost is the whole trick: it
/// is what makes a hit read as damage taken instead of as a smaller bar.
class AnimatedBar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;
  final bool ghost;

  const AnimatedBar(
    this.fraction,
    this.color, {
    super.key,
    this.height = 7,
    this.ghost = true,
  });

  /// `heightFactor: 1` is load-bearing: without it the fill gets loose
  /// height constraints, and a [ColoredBox] with no child under loose
  /// constraints collapses to zero — a bar that is there in the widget
  /// tree and invisible on screen.
  Widget _fill(double v, Color c) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: v.clamp(0, 1),
        heightFactor: 1,
        child: ColoredBox(color: c),
      );

  @override
  Widget build(BuildContext context) {
    final value = fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Colors.white.withValues(alpha: .07)),
            ),
            if (ghost)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: value, end: value),
                  duration: const Duration(milliseconds: 620),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => _fill(v, color.withValues(alpha: .28)),
                ),
              ),
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: value, end: value),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                builder: (_, v, __) => _fill(v, color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades and lifts its child in, once, after [delay]. Used to stage a
/// screen so it arrives in reading order instead of all at once.
class Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offset;

  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.quick(const Duration(milliseconds: 460)),
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      // A Future, not a Timer.periodic: it completes, so a test settles.
      Future<void>.delayed(Motion.quick(widget.delay)).then((_) {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = Curves.easeOutCubic.transform(_c.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * widget.offset),
              child: child,
            ),
          );
        },
        child: widget.child,
      );
}

/// A line of dialogue, arriving. Ticks the blip sound as it goes, and can
/// be finished early — the impatient tap is the most-used control in any
/// game that has one of these.
class Typewriter extends StatefulWidget {
  final String text;
  final TextStyle style;

  /// Seconds per character. Narration is slower than speech on purpose.
  final double perChar;
  final bool sound;
  final VoidCallback? onComplete;

  const Typewriter(
    this.text, {
    super.key,
    required this.style,
    this.perChar = .018,
    this.sound = true,
    this.onComplete,
  });

  @override
  State<Typewriter> createState() => TypewriterState();
}

class TypewriterState extends State<Typewriter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _durationFor(widget.text),
  )
    ..addListener(_onTick)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onComplete?.call();
    })
    ..forward();
  int _lastBlip = 0;

  /// One controller for the life of the widget, re-aimed when the line
  /// changes. Building a second one would need a full TickerProvider, and
  /// a line of dialogue is not worth one.
  Duration _durationFor(String text) => Motion.quick(Duration(
      milliseconds:
          (text.length * widget.perChar * 1000).round().clamp(120, 6000)));

  void _onTick() {
    final shown = (_c.value * widget.text.length).floor();
    if (shown == _lastBlip) return;
    // One blip every few characters, and never on a space: any more than
    // this and a paragraph sounds like a printer.
    if (widget.sound && shown - _lastBlip >= 3) {
      final ch = shown > 0 && shown <= widget.text.length
          ? widget.text[shown - 1]
          : ' ';
      if (ch.trim().isNotEmpty) Audio.instance.play(Sfx.blip);
    }
    setState(() => _lastBlip = shown);
  }

  @override
  void didUpdateWidget(Typewriter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _lastBlip = 0;
      _c
        ..duration = _durationFor(widget.text)
        ..forward(from: 0);
    }
  }

  /// Show the whole line now.
  void finish() {
    if (!_c.isCompleted) _c.value = 1.0;
  }

  bool get done => _c.isCompleted;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = (_c.value * widget.text.length).round().clamp(0, widget.text.length);
    return RichText(
      text: TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: widget.text.substring(0, shown)),
          // The rest of the line is drawn transparent rather than omitted,
          // so the paragraph does not reflow under the reader as it types.
          TextSpan(
            text: widget.text.substring(shown),
            style: const TextStyle(color: Colors.transparent),
          ),
        ],
      ),
    );
  }
}

/// A slow breathing highlight — a ready ability, a scene waiting to be
/// played. Holds still (at its brightest) when ambient motion is off, so
/// the thing it is pointing at is still visibly the thing it is pointing
/// at.
class Beacon extends StatefulWidget {
  final Widget child;
  final Color color;
  final bool active;

  const Beacon({
    super.key,
    required this.child,
    required this.color,
    this.active = true,
  });

  @override
  State<Beacon> createState() => _BeaconState();
}

class _BeaconState extends State<Beacon> with SingleTickerProviderStateMixin {
  AnimationController? _c;


  @override
  void initState() {
    super.initState();
    if (Motion.ambient) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1900),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    final c = _c;
    Widget glow(double t) => CustomPaint(
          painter: _BeaconPainter(color: widget.color, t: t),
          child: widget.child,
        );
    return c == null
        ? glow(1)
        : AnimatedBuilder(animation: c, builder: (_, __) => glow(c.value));
  }
}

/// The glow is painted as a blurred *outline*, not as a box shadow.
///
/// A shadow is a filled rectangle behind the child, and every panel in this
/// game is deliberately translucent — so a shadow shows straight through
/// the card it is supposed to be behind and reads as a solid fill. An
/// outline only ever lights the edge.
class _BeaconPainter extends CustomPainter {
  final Color color;
  final double t;

  _BeaconPainter({required this.color, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + 2 * t
        ..color = color.withValues(alpha: .12 + .22 * t)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, 5 + 5 * t),
    );
  }

  @override
  bool shouldRepaint(covariant _BeaconPainter old) =>
      old.t != t || old.color != color;
}

/// The colour a number should be when it leaves the screen.
Color damageColor(String kind) => switch (kind) {
      'crit' => gold,
      'ultimate' => rose,
      'heal' => verdant,
      'reward' => verdant,
      _ => bone,
    };
