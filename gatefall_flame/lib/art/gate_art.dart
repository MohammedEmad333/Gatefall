import 'dart:math';

import 'package:flutter/material.dart';

import '../data/element.dart';
import '../ui/theme.dart';
import 'motion.dart';
import 'palette.dart';

/// The world, drawn: the tear itself, the things that come through it, and
/// the dust in the air of every screen. Same rule as character_art.dart —
/// generated shapes rather than imported assets, so the art can never fall
/// out of step with the simulation that decides what to draw.

/// A gate, turning. [intensity] is how alive it is: a card on the board sits
/// around .5, the gate you are standing in sits at 1.
class RiftView extends StatefulWidget {
  final GateElement element;
  final double size;
  final double intensity;

  /// A boss makes the tear bloom wider and beat harder.
  final bool boss;

  const RiftView({
    super.key,
    required this.element,
    this.size = 90,
    this.intensity = 1,
    this.boss = false,
  });

  @override
  State<RiftView> createState() => _RiftViewState();
}

class _RiftViewState extends State<RiftView>
    with SingleTickerProviderStateMixin {
  AnimationController? _spin;

  @override
  void initState() {
    super.initState();
    if (Motion.ambient) {
      _spin = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: widget.boss ? 9000 : 13000),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(RiftView old) {
    super.didUpdateWidget(old);
    if (old.boss != widget.boss && _spin != null) {
      _spin!.duration = Duration(milliseconds: widget.boss ? 9000 : 13000);
      _spin!.repeat();
    }
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spin = _spin;
    _RiftPainter painter(double t) => _RiftPainter(
          element: widget.element,
          t: t,
          intensity: widget.intensity,
          boss: widget.boss,
        );
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: spin == null
          ? CustomPaint(painter: painter(.2))
          : AnimatedBuilder(
              animation: spin,
              builder: (_, __) => CustomPaint(painter: painter(spin.value)),
            ),
    );
  }
}

class _RiftPainter extends CustomPainter {
  final GateElement element;
  final double t;
  final double intensity;
  final bool boss;

  _RiftPainter({
    required this.element,
    required this.t,
    required this.intensity,
    required this.boss,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2);
    final accent = elementColor(element);
    final pulse = .5 + .5 * sin(t * 2 * pi * (boss ? 2 : 1));

    // The glow the tear casts on the room around it.
    canvas.drawCircle(
      c,
      s * (.46 + .03 * pulse),
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: .26 * intensity),
            accent.withValues(alpha: .0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: s * .5)),
    );

    // Three rings, each turning at its own rate and in its own direction —
    // the reason a still frame of this still reads as "spinning".
    for (var ring = 0; ring < 3; ring++) {
      final dir = ring.isEven ? 1.0 : -1.0;
      final r = s * (.20 + ring * .085);
      final sweep = pi * (.7 + .35 * ring);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * (.022 - ring * .004)
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * pi,
          colors: [
            accent.withValues(alpha: .0),
            accent.withValues(alpha: (.75 - ring * .16) * intensity),
            accent.withValues(alpha: .0),
          ],
          stops: const [0, .5, 1],
          transform: GradientRotation(t * 2 * pi * dir * (1 + ring * .35)),
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawArc(Rect.fromCircle(center: c, radius: r),
          t * 2 * pi * dir, sweep, false, paint);
    }

    // The tear: a lens standing on its end, lit from inside.
    final h = s * (.30 + .015 * pulse);
    final w = s * (.11 + .012 * pulse) * (boss ? 1.35 : 1.0);
    final tear = Path()
      ..moveTo(c.dx, c.dy - h)
      ..cubicTo(c.dx + w, c.dy - h * .45, c.dx + w, c.dy + h * .45, c.dx,
          c.dy + h)
      ..cubicTo(c.dx - w, c.dy + h * .45, c.dx - w, c.dy - h * .45, c.dx,
          c.dy - h)
      ..close();
    canvas.drawPath(
      tear,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(accent, Colors.white, .55)!
                .withValues(alpha: .9 * intensity),
            accent.withValues(alpha: .35 * intensity),
            night.withValues(alpha: .9),
          ],
          stops: const [0, .45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: h)),
    );
    canvas.drawPath(
      tear,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .008
        ..color = Color.lerp(accent, Colors.white, .4)!
            .withValues(alpha: .8 * intensity),
    );

    // Motes falling in. Nothing that comes out of a gate is drawn here —
    // that is the creature's job.
    final mote = Paint()..color = accent.withValues(alpha: .55 * intensity);
    for (var i = 0; i < 9; i++) {
      final seed = i / 9;
      final phase = (t * (.6 + seed * .8) + seed) % 1.0;
      final angle = seed * 2 * pi + t * pi * .4;
      final r = s * (.46 - .30 * phase);
      canvas.drawCircle(
        c + Offset(cos(angle) * r, sin(angle) * r * .85),
        s * .012 * (1 - phase) + s * .003,
        mote,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RiftPainter old) =>
      old.t != t || old.intensity != intensity || old.element != element ||
      old.boss != boss;
}

/// What comes through. Five wave silhouettes and a guardian, keyed by the
/// wave index so the thing on screen is the thing in the simulation —
/// battle.dart names five wave enemies in order, and so does this.
enum Beastform { stalker, hound, shade, husk, thornbound, guardian }

Beastform beastformFor({required int waveIndex, required bool boss}) =>
    boss ? Beastform.guardian : Beastform.values[waveIndex % 5];

class CreatureView extends StatefulWidget {
  final Beastform form;
  final GateElement element;
  final double size;

  /// 0…1, decayed by the caller: how recently this thing was hit.
  final double hurt;

  /// Dead: collapses and fades rather than vanishing between frames.
  final bool falling;

  const CreatureView({
    super.key,
    required this.form,
    required this.element,
    this.size = 120,
    this.hurt = 0,
    this.falling = false,
  });

  @override
  State<CreatureView> createState() => _CreatureViewState();
}

class _CreatureViewState extends State<CreatureView>
    with SingleTickerProviderStateMixin {
  AnimationController? _idle;

  @override
  void initState() {
    super.initState();
    if (Motion.ambient) {
      _idle = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2600),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _idle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idle = _idle;
    _CreaturePainter painter(double t) => _CreaturePainter(
          form: widget.form,
          element: widget.element,
          t: t,
          hurt: widget.hurt,
          falling: widget.falling,
        );
    return SizedBox(
      width: widget.size,
      height: widget.size * .78,
      child: idle == null
          ? CustomPaint(painter: painter(.25))
          : AnimatedBuilder(
              animation: idle,
              builder: (_, __) => CustomPaint(painter: painter(idle.value)),
            ),
    );
  }
}

class _CreaturePainter extends CustomPainter {
  final Beastform form;
  final GateElement element;
  final double t;
  final double hurt;
  final bool falling;

  _CreaturePainter({
    required this.form,
    required this.element,
    required this.t,
    required this.hurt,
    required this.falling,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final accent = elementColor(element);
    final bob = sin(t * 2 * pi) * h * .018;

    canvas.save();
    if (falling) {
      // Collapse: it folds toward the floor rather than blinking out.
      canvas.translate(w * .5, h);
      canvas.scale(1.0, .55);
      canvas.translate(-w * .5, -h);
    }
    canvas.translate(0, bob);

    // A hit reads as the shape flashing to the element's own colour — the
    // one moment the silhouette stops being a silhouette.
    final flash = hurt.clamp(0.0, 1.0);
    final fill = Paint()
      ..color = Color.lerp(const Color(0xFF120E22),
          Color.lerp(accent, Colors.white, .35)!, flash * .85)!
          .withValues(alpha: falling ? .5 : 1);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .008
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: (falling ? .3 : .7) + .3 * flash);
    final eye = Paint()
      ..color = Color.lerp(accent, Colors.white, .5)!
          .withValues(alpha: falling ? .2 : .95);

    // Ground shadow, so nothing floats unless it is meant to.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * .5, h * .95), width: w * .62, height: h * .09),
      Paint()..color = Colors.black.withValues(alpha: .45),
    );

    switch (form) {
      case Beastform.stalker:
        _stalker(canvas, w, h, fill, line, eye);
      case Beastform.hound:
        _hound(canvas, w, h, fill, line, eye);
      case Beastform.shade:
        _shade(canvas, w, h, fill, line, eye);
      case Beastform.husk:
        _husk(canvas, w, h, fill, line, eye);
      case Beastform.thornbound:
        _thornbound(canvas, w, h, fill, line, eye);
      case Beastform.guardian:
        _guardian(canvas, w, h, fill, line, eye);
    }
    canvas.restore();
  }

  void _legs(Canvas canvas, double w, double h, Paint line,
      List<double> xs, double top, double bottom) {
    for (final x in xs) {
      canvas.drawLine(Offset(w * x, h * top), Offset(w * (x - .02), h * bottom),
          line);
    }
  }

  void _eyes(Canvas canvas, double w, double h, Paint eye, double cx, double cy,
      double spread, double r) {
    for (final dx in [-spread, spread]) {
      canvas.drawCircle(Offset(w * (cx + dx), h * cy), w * r, eye);
    }
  }

  /// Low, long, four-legged. The thing you meet first.
  void _stalker(Canvas canvas, double w, double h, Paint fill, Paint line,
      Paint eye) {
    canvas.drawPath(
      Path()
        ..moveTo(w * .26, h * .58)
        ..cubicTo(w * .12, h * .52, w * .09, h * .36, w * .17, h * .28),
      line,
    );
    final body = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * .46, h * .60), width: w * .50, height: h * .32));
    canvas.drawPath(body, fill);
    canvas.drawPath(body, line);
    _legs(canvas, w, h, line, [.32, .42, .56, .64], .70, .93);
    // The head overlaps the body rather than floating beside it, and it is
    // low and forward — this thing is already stalking something.
    final head = Path()
      ..moveTo(w * .64, h * .52)
      ..lineTo(w * .88, h * .56)
      ..lineTo(w * .86, h * .68)
      ..lineTo(w * .64, h * .70)
      ..close();
    canvas.drawPath(head, fill);
    canvas.drawPath(head, line);
    _eyes(canvas, w, h, eye, .76, .58, .035, .016);
  }

  /// Hunched, eared, and faster than it looks.
  void _hound(Canvas canvas, double w, double h, Paint fill, Paint line,
      Paint eye) {
    final body = Path()
      ..moveTo(w * .24, h * .78)
      ..cubicTo(w * .22, h * .44, w * .48, h * .38, w * .62, h * .48)
      ..cubicTo(w * .76, h * .56, w * .74, h * .74, w * .70, h * .80)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, line);
    _legs(canvas, w, h, line, [.30, .40, .60, .68], .76, .92);
    final head = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * .70, h * .40), width: w * .26, height: h * .22));
    canvas.drawPath(head, fill);
    canvas.drawPath(head, line);
    for (final dir in [0.0, 1.0]) {
      final ear = Path()
        ..moveTo(w * (.62 + dir * .10), h * .32)
        ..lineTo(w * (.60 + dir * .12), h * .14)
        ..lineTo(w * (.70 + dir * .10), h * .30)
        ..close();
      canvas.drawPath(ear, fill);
      canvas.drawPath(ear, line);
    }
    canvas.drawPath(
      Path()
        ..moveTo(w * .82, h * .40)
        ..lineTo(w * .94, h * .44)
        ..lineTo(w * .82, h * .48)
        ..close(),
      fill,
    );
    _eyes(canvas, w, h, eye, .70, .38, .045, .015);
  }

  /// No legs, no floor: a hanging rag with two lights in it.
  void _shade(Canvas canvas, double w, double h, Paint fill, Paint line,
      Paint eye) {
    final sway = sin(t * 2 * pi) * w * .014;
    // Tall and narrow, and the hem is genuinely torn — a ghost with a
    // rounded bottom edge reads as a cartoon, which this is not.
    final body = Path()..moveTo(w * .36 + sway, h * .90);
    for (var i = 1; i <= 8; i++) {
      final x = .36 + i * .035;
      final tear = i.isEven ? .74 : .95;
      body.lineTo(w * x + sway * (1 - i / 16),
          h * (tear + .03 * sin(t * 2 * pi + i)));
    }
    body
      ..lineTo(w * .64 + sway * .4, h * .34)
      ..cubicTo(w * .64, h * .10, w * .36, h * .10, w * .36 + sway, h * .34)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, line);
    // Two rags hanging off the shoulders, out of phase with the sway.
    for (final dir in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(w * (.5 + dir * .13), h * .40)
          ..cubicTo(w * (.5 + dir * .24), h * .50, w * (.5 + dir * .20),
              h * .62, w * (.5 + dir * .26) + sway * .5, h * .74),
        line,
      );
    }
    _eyes(canvas, w, h, eye, .5, .28, .052, .018);
  }

  /// A body something grew back out of: hunched, arms hanging, a crown of
  /// twigs rather than the guardian's full antlers.
  void _husk(Canvas canvas, double w, double h, Paint fill, Paint line,
      Paint eye) {
    final body = Path()
      ..moveTo(w * .34, h * .94)
      ..cubicTo(w * .28, h * .70, w * .34, h * .50, w * .46, h * .44)
      ..cubicTo(w * .60, h * .42, w * .66, h * .60, w * .68, h * .94)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, line);

    // Arms, hanging past where hands should stop.
    canvas.drawPath(
      Path()
        ..moveTo(w * .36, h * .54)
        ..cubicTo(w * .26, h * .66, w * .24, h * .78, w * .28, h * .90),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * .64, h * .56)
        ..cubicTo(w * .74, h * .68, w * .75, h * .80, w * .71, h * .92),
      line,
    );

    // Head, low and forward on a bowed spine.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * .53, h * .36), width: w * .19, height: h * .17),
      fill,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * .53, h * .36), width: w * .19, height: h * .17),
      line,
    );
    for (final dir in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(w * (.53 + dir * .06), h * .30)
          ..lineTo(w * (.53 + dir * .13), h * .18),
        line,
      );
    }
    _eyes(canvas, w, h, eye, .53, .36, .038, .013);
  }

  /// Mostly spikes.
  void _thornbound(Canvas canvas, double w, double h, Paint fill, Paint line,
      Paint eye) {
    final c = Offset(w * .5, h * .58);
    final r = w * .21;
    final spikes = Path();
    for (var i = 0; i < 11; i++) {
      final a = i / 11 * 2 * pi + t * .4;
      final len = r * (1.5 + .25 * sin(i * 2.3));
      spikes
        ..moveTo(c.dx + cos(a) * r * .8, c.dy + sin(a) * r * .8)
        ..lineTo(c.dx + cos(a) * len, c.dy + sin(a) * len);
    }
    canvas.drawPath(spikes, line);
    canvas.drawCircle(c, r, fill);
    canvas.drawCircle(c, r, line);
    _legs(canvas, w, h, line, [.42, .58], .72, .92);
    _eyes(canvas, w, h, eye, .5, .56, .05, .017);
  }

  /// The Root That Walks. Bigger, antlered, and it has more eyes than it
  /// needs.
  void _guardian(Canvas canvas, double w, double h, Paint fill, Paint line,
      Paint eye) {
    final body = Path()
      ..moveTo(w * .22, h * .96)
      ..cubicTo(w * .18, h * .58, w * .34, h * .34, w * .50, h * .32)
      ..cubicTo(w * .66, h * .34, w * .82, h * .58, w * .78, h * .96)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, line);

    // Roots for legs.
    for (final x in [.30, .42, .58, .70]) {
      canvas.drawPath(
        Path()
          ..moveTo(w * x, h * .80)
          ..cubicTo(w * (x - .03), h * .88, w * (x + .03), h * .92, w * (x - .01),
              h * .99),
        line,
      );
    }

    // Antlers, spreading wider than the frame is comfortable with.
    for (final dir in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(w * (.5 + dir * .10), h * .34)
          ..cubicTo(w * (.5 + dir * .26), h * .22, w * (.5 + dir * .34),
              h * .16, w * (.5 + dir * .30), h * .02),
        line,
      );
      canvas.drawPath(
        Path()
          ..moveTo(w * (.5 + dir * .22), h * .22)
          ..lineTo(w * (.5 + dir * .42), h * .12),
        line,
      );
      canvas.drawPath(
        Path()
          ..moveTo(w * (.5 + dir * .27), h * .13)
          ..lineTo(w * (.5 + dir * .16), h * .04),
        line,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * .5, h * .40), width: w * .30, height: h * .20),
      fill,
    );
    _eyes(canvas, w, h, eye, .5, .40, .075, .020);
    _eyes(canvas, w, h, eye, .5, .50, .045, .013);
    canvas.drawCircle(Offset(w * .5, h * .35), w * .015, eye);
  }

  @override
  bool shouldRepaint(covariant _CreaturePainter old) =>
      old.t != t ||
      old.hurt != hurt ||
      old.falling != falling ||
      old.form != form ||
      old.element != element;
}

/// The dust every screen sits in. Deliberately almost invisible: it is
/// there to stop a flat colour reading as a flat colour, not to be looked
/// at. Holds still under `flutter test`.
class AmbientBackdrop extends StatefulWidget {
  final Widget child;
  final GateElement? element;

  const AmbientBackdrop({super.key, required this.child, this.element});

  @override
  State<AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<AmbientBackdrop>
    with SingleTickerProviderStateMixin {
  AnimationController? _drift;

  @override
  void initState() {
    super.initState();
    if (Motion.ambient) {
      _drift = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 48),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _drift?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drift = _drift;
    final accent =
        widget.element == null ? rift : elementColor(widget.element!);
    Widget paint(double t) => CustomPaint(
          painter: _DustPainter(t: t, accent: accent),
          isComplex: true,
          willChange: drift != null,
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: night),
        Positioned.fill(
          child: drift == null
              ? paint(.3)
              : AnimatedBuilder(
                  animation: drift,
                  builder: (_, __) => paint(drift.value),
                ),
        ),
        widget.child,
      ],
    );
  }
}

class _DustPainter extends CustomPainter {
  final double t;
  final Color accent;

  _DustPainter({required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    // A slow band of light, low and wide, that keeps the top of a screen
    // from being pure black.
    final band = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: .06),
            Colors.transparent,
            accent.withValues(alpha: .04),
          ],
          stops: [
            0,
            .45 + .1 * sin(t * 2 * pi),
            1,
          ],
        ).createShader(band),
    );

    final paint = Paint()..color = accent.withValues(alpha: .16);
    for (var i = 0; i < 26; i++) {
      final seed = i / 26;
      final speed = .3 + seed * .7;
      final y = 1.0 - ((t * speed + seed * 3.7) % 1.0);
      final x = (seed * 7.3) % 1.0 + .03 * sin((t + seed) * 2 * pi);
      final r = size.width * (.0012 + .0022 * ((i * 37) % 10) / 10);
      canvas.drawCircle(
        Offset(size.width * (x % 1.0), size.height * y),
        r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter old) =>
      old.t != t || old.accent != accent;
}
