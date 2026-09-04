import 'dart:math';

import 'package:flutter/material.dart';

import '../data/element.dart';
import '../ui/theme.dart';
import 'motion.dart';
import 'palette.dart';

/// The cast, drawn.
///
/// Version 3 needed characters on screen and had no illustrator, so the art
/// is *generated* rather than imported: every companion is a hand-written
/// silhouette in a stained-glass style — flat dark shapes, an element-lit
/// outline, a glow behind. That is a deliberate style, not a placeholder
/// one. It scales from a 30px chip to a 160px dialogue portrait, it costs
/// nothing to ship, it can never drift from the roster, and it reads at a
/// glance: you know Faelen by her ears and Kess by hers before you read a
/// single name.
///
/// docs/art-direction.md still describes the rendered-splash-art path (the
/// locked Faelen reference lives there). Nothing here forecloses it — a
/// painted portrait can replace [CharacterPortrait] one character at a
/// time, because everything else in the UI asks for a *widget*, not for a
/// painter.
enum Build {
  /// Long hair, high collar, pointed ears. Faelen.
  elf,

  /// Ears up, bob, tail. Kess.
  fox,

  /// All hood, two lights where a face would be. Momo.
  hooded,

  /// Wide, tusked, braided. Thora.
  orc,

  /// Neat, collared, badge on a lanyard. Dana.
  clerk,

  /// The player: hooded and faceless, with a gate where the face is.
  awakened,
}

class CharacterLook {
  final Build build;
  final GateElement element;

  /// Hair, cloak, or hood — the one colour that is not the element.
  final Color hair;

  const CharacterLook({
    required this.build,
    required this.element,
    required this.hair,
  });

  Color get accent => elementColor(element);
}

class CharacterArt {
  CharacterArt._();

  static const Map<String, CharacterLook> looks = {
    'player': CharacterLook(
        build: Build.awakened, element: GateElement.sever, hair: Color(0xFF2A2540)),
    'faelen': CharacterLook(
        build: Build.elf, element: GateElement.verdant, hair: Color(0xFFD8D3E4)),
    'kess': CharacterLook(
        build: Build.fox, element: GateElement.ember, hair: Color(0xFFC8703C)),
    'momo': CharacterLook(
        build: Build.hooded, element: GateElement.gloam, hair: Color(0xFF4A3A6E)),
    'thora': CharacterLook(
        build: Build.orc, element: GateElement.stone, hair: Color(0xFF8C7A5E)),
    'dana': CharacterLook(
        build: Build.clerk, element: GateElement.sever, hair: Color(0xFF6E6288)),
  };

  /// Anyone the art does not know about is still drawn — as the awakened
  /// silhouette in their own element. A missing look must never be a
  /// missing widget.
  static CharacterLook of(String id, {GateElement? element}) =>
      looks[id] ??
      CharacterLook(
          build: Build.awakened,
          element: element ?? GateElement.sever,
          hair: const Color(0xFF2A2540));
}

/// A character, framed and lit. Breathes and blinks while [Motion.ambient]
/// is on, and holds a still frame when it is off.
class CharacterPortrait extends StatefulWidget {
  final String id;
  final double size;

  /// 0 for a bench-warmer, 1 for the person currently talking. Drives the
  /// backlight and the eye glow, nothing else.
  final double glow;

  /// Down, benched, or otherwise not in this: drains the colour out.
  final bool dimmed;

  /// Slower breath, dimmer light: used for a portrait that is decoration
  /// rather than the subject of the screen.
  final bool calm;

  const CharacterPortrait(
    this.id, {
    super.key,
    this.size = 46,
    this.glow = .6,
    this.dimmed = false,
    this.calm = false,
  });

  @override
  State<CharacterPortrait> createState() => _CharacterPortraitState();
}

class _CharacterPortraitState extends State<CharacterPortrait>
    with SingleTickerProviderStateMixin {
  AnimationController? _loop;

  /// Every portrait on screen must not breathe in unison — that reads as a
  /// screensaver. The offset is derived from the id so it is stable across
  /// rebuilds and identical between runs.
  late final double _phase =
      (widget.id.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0xFF)) / 255.0;

  @override
  void initState() {
    super.initState();
    if (Motion.ambient) {
      _loop = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: widget.calm ? 7400 : 5200),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _loop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = CharacterArt.of(widget.id);
    _PortraitPainter painter(double t) => _PortraitPainter(
          look: look,
          t: t,
          glow: widget.glow,
          dimmed: widget.dimmed,
        );
    final loop = _loop;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: loop == null
          // Still frame: mid-breath, eyes open. A test and a
          // reduced-motion device see the character, just not the motion.
          ? CustomPaint(painter: painter(_phase))
          : AnimatedBuilder(
              animation: loop,
              builder: (_, __) =>
                  CustomPaint(painter: painter((loop.value + _phase) % 1.0)),
            ),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  final CharacterLook look;
  final double t;
  final double glow;
  final bool dimmed;

  _PortraitPainter({
    required this.look,
    required this.t,
    required this.glow,
    required this.dimmed,
  });

  Color get _accent => dimmed
      ? Color.lerp(look.accent, boneDim, .72)!.withValues(alpha: .55)
      : look.accent;

  Color get _hair =>
      dimmed ? Color.lerp(look.hair, night2, .55)! : look.hair;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);

    // The whole figure breathes: a shallow rise and fall, an order of
    // magnitude smaller than it wants to be, because anything you can
    // consciously see here reads as a bug.
    final breath = sin(t * 2 * pi);
    final lift = breath * s * .006;

    _backdrop(canvas, s);
    canvas.save();
    // Scaled up from the bottom edge: fills the frame the way a hero card
    // does, without lifting the shoulders off the bottom of it.
    canvas.translate(s * .5, s);
    canvas.scale(1.09);
    canvas.translate(-s * .5, -s);
    canvas.translate(0, lift);
    _figure(canvas, s, breath);
    canvas.restore();
    _vignette(canvas, s);
    canvas.restore();
  }

  // ------------------------------------------------------------- backdrop

  void _backdrop(Canvas canvas, double s) {
    final rect = Rect.fromLTWH(0, 0, s, s);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [night2, night],
        ).createShader(rect),
    );

    // The backlight — the one thing that makes a flat silhouette look lit.
    final halo = Offset(s * .5, s * .36);
    final strength = (dimmed ? .16 : .30) * (.55 + .45 * glow);
    canvas.drawCircle(
      halo,
      s * (.34 + .015 * sin(t * 2 * pi)),
      Paint()
        ..shader = RadialGradient(
          colors: [
            _accent.withValues(alpha: strength),
            _accent.withValues(alpha: .0),
          ],
        ).createShader(Rect.fromCircle(center: halo, radius: s * .40)),
    );

    // Two rays out of the halo, angled so the frame never reads as
    // perfectly symmetrical.
    final ray = Paint()..color = _accent.withValues(alpha: dimmed ? .04 : .08);
    for (final dx in [-.20, .26]) {
      final p = Path()
        ..moveTo(s * (.5 + dx * .3), s * .05)
        ..lineTo(s * (.5 + dx), s * .78)
        ..lineTo(s * (.5 + dx + .09), s * .78)
        ..lineTo(s * (.5 + dx * .3 + .05), s * .05)
        ..close();
      canvas.drawPath(p, ray);
    }

    // Floor glow, so the figure stands on something.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(s * .5, s * .97), width: s * .9, height: s * .22),
      Paint()..color = _accent.withValues(alpha: dimmed ? .05 : .10),
    );

    _motes(canvas, s);
  }

  void _motes(Canvas canvas, double s) {
    if (s < 40) return; // At chip size they are just noise.
    final paint = Paint()..color = _accent.withValues(alpha: dimmed ? .12 : .3);
    for (var i = 0; i < 5; i++) {
      final seed = (i * 37 + look.build.index * 11) % 100 / 100.0;
      // Each mote runs its own slow lap of the frame, bottom to top.
      final y = 1.0 - ((t * (.35 + seed * .4) + seed) % 1.0);
      final x = .12 + seed * .76 + .04 * sin((t + seed) * 2 * pi);
      final fade = sin(y * pi).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(s * x, s * (.12 + y * .8)),
        s * (.006 + .004 * seed) * fade,
        paint,
      );
    }
  }

  void _vignette(Canvas canvas, double s) {
    final rect = Rect.fromLTWH(0, 0, s, s);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: .78,
          colors: [Colors.transparent, night.withValues(alpha: .78)],
          stops: const [.55, 1.0],
        ).createShader(rect),
    );
  }

  // --------------------------------------------------------------- figure

  /// Silhouette fill: near-black, lifted very slightly toward the element
  /// at the top so the shape has some depth in it.
  Paint _bodyPaint(double s) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(const Color(0xFF15122A), _accent, dimmed ? .06 : .14)!,
        const Color(0xFF0B0916),
      ],
    ).createShader(Rect.fromLTWH(0, s * .2, s, s * .8));

  Paint _linePaint(double s, {double alpha = .55, double width = .012}) =>
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * width
        ..strokeJoin = StrokeJoin.round
        ..color = _accent.withValues(alpha: dimmed ? alpha * .45 : alpha);

  void _figure(Canvas canvas, double s, double breath) {
    switch (look.build) {
      case Build.elf:
        _elf(canvas, s, breath);
      case Build.fox:
        _fox(canvas, s, breath);
      case Build.hooded:
        _hooded(canvas, s, breath);
      case Build.orc:
        _orc(canvas, s, breath);
      case Build.clerk:
        _clerk(canvas, s, breath);
      case Build.awakened:
        _awakened(canvas, s, breath);
    }
  }

  /// Shoulders and neck — every build starts here. [width] widens the
  /// frame (Thora) or narrows it (Momo).
  void _torso(Canvas canvas, double s, {double width = 1.0, double top = .70}) {
    final half = .34 * width;
    final neck = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .445, s * .50, s * .11, s * .24),
        Radius.circular(s * .028),
      ));
    canvas.drawPath(neck, _bodyPaint(s));

    final body = Path()
      ..moveTo(s * (.5 - half - .05), s)
      ..cubicTo(s * (.5 - half - .01), s * (top + .10), s * (.5 - half * .62),
          s * top, s * .5, s * top)
      ..cubicTo(s * (.5 + half * .62), s * top, s * (.5 + half + .01),
          s * (top + .10), s * (.5 + half + .05), s)
      ..close();
    canvas.drawPath(body, _bodyPaint(s));
    canvas.drawPath(body, _linePaint(s, alpha: .42));
  }

  Path _headPath(double s, {double ry = .175}) => Path()
    ..addOval(Rect.fromCenter(
      center: Offset(s * .5, s * .38),
      width: s * .29,
      height: s * ry * 2,
    ));

  void _head(Canvas canvas, double s) {
    final head = _headPath(s);
    canvas.drawPath(head, _bodyPaint(s));
    canvas.drawPath(head, _linePaint(s, alpha: .5));
  }

  /// Hair, cloak and braid all use this: dark enough to stay a silhouette,
  /// light enough to separate from the head in front of it.
  Paint _hairPaint({double toward = .62}) =>
      Paint()..color = Color.lerp(_hair, const Color(0xFF0B0916), toward)!;

  /// Two lit eyes, and the blink that stops them being headlights. The
  /// blink is a short pinch once every few seconds, phase-locked to the
  /// portrait's own loop.
  void _eyes(Canvas canvas, double s,
      {double y = .40, double spread = .055, double glowScale = 1.0}) {
    final blinkPhase = (t * 3) % 1.0;
    final open = blinkPhase > .96 ? (1 - (blinkPhase - .96) / .04 * .9) : 1.0;
    final paint = Paint()..color = _accent.withValues(alpha: dimmed ? .5 : .95);
    final halo = Paint()
      ..color = _accent.withValues(alpha: (dimmed ? .12 : .34) * glow)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .03);
    for (final dx in [-spread, spread]) {
      final c = Offset(s * (.5 + dx), s * y);
      final r = Rect.fromCenter(
          center: c, width: s * .044 * glowScale, height: s * .028 * open);
      canvas.drawOval(r, halo);
      canvas.drawOval(r, paint);
    }
  }

  // ------------------------------------------------------------- the cast

  void _elf(Canvas canvas, double s, double breath) {
    // Hair first: a long fall behind everything, which is what makes the
    // silhouette read as Faelen at 30 pixels.
    final hair = Path()
      ..moveTo(s * .36, s * .24)
      ..cubicTo(s * .26, s * .34, s * .25, s * .62, s * .29, s * .84)
      ..lineTo(s * .40, s * .80)
      ..cubicTo(s * .37, s * .62, s * .38, s * .40, s * .44, s * .28)
      ..close();
    final hair2 = Path()
      ..moveTo(s * .64, s * .24)
      ..cubicTo(s * .74, s * .34, s * .75, s * .62, s * .71, s * .84)
      ..lineTo(s * .60, s * .80)
      ..cubicTo(s * .63, s * .62, s * .62, s * .40, s * .56, s * .28)
      ..close();
    canvas.drawPath(hair, _hairPaint());
    canvas.drawPath(hair2, _hairPaint());
    canvas.drawPath(hair, _linePaint(s, alpha: .22, width: .007));
    canvas.drawPath(hair2, _linePaint(s, alpha: .22, width: .007));

    _torso(canvas, s);

    // The Warden's cloak: a yoke across the shoulders, closed at the
    // throat by the clasp her locked design describes as a shutting gate.
    final yoke = Path()
      ..moveTo(s * .22, s * .88)
      ..cubicTo(s * .30, s * .68, s * .40, s * .62, s * .5, s * .62)
      ..cubicTo(s * .60, s * .62, s * .70, s * .68, s * .78, s * .88)
      ..cubicTo(s * .66, s * .80, s * .34, s * .80, s * .22, s * .88)
      ..close();
    canvas.drawPath(yoke, _bodyPaint(s));
    canvas.drawPath(yoke, _linePaint(s, alpha: .6));
    canvas.drawCircle(
        Offset(s * .5, s * .68), s * .028, Paint()..color = _accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .012);

    // Ears. Long, swept back, unmistakable.
    for (final dir in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(s * (.5 + dir * .13), s * .34)
        ..lineTo(s * (.5 + dir * .29), s * .19)
        ..lineTo(s * (.5 + dir * .15), s * .44)
        ..close();
      canvas.drawPath(ear, _bodyPaint(s));
      canvas.drawPath(ear, _linePaint(s, alpha: .55));
    }

    _head(canvas, s);
    // A crown-line where the hair is tied back.
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(s * .5, s * .38), width: s * .27, height: s * .32),
      pi * 1.13,
      pi * .74,
      false,
      _linePaint(s, alpha: .5, width: .008),
    );
    _eyes(canvas, s);
  }

  void _fox(Canvas canvas, double s, double breath) {
    // Tail, drawn behind: a wide stroke sweeping out and up.
    final tail = Path()
      ..moveTo(s * .72, s * .96)
      ..cubicTo(s * .96, s * .92, s * .97, s * (.60 + breath * .02), s * .84,
          s * .50);
    canvas.drawPath(
      tail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * .105
        ..color = _hairPaint(toward: .55).color,
    );
    canvas.drawPath(
      tail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * .032
        ..color = _accent.withValues(alpha: dimmed ? .18 : .4),
    );

    _torso(canvas, s, width: .92);

    // Ears — the fastest read in the roster.
    for (final dir in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(s * (.5 + dir * .08), s * .26)
        ..lineTo(s * (.5 + dir * .25), s * .05)
        ..lineTo(s * (.5 + dir * .27), s * .29)
        ..close();
      canvas.drawPath(ear, _bodyPaint(s));
      canvas.drawPath(ear, _linePaint(s, alpha: .6));
      final inner = Path()
        ..moveTo(s * (.5 + dir * .13), s * .25)
        ..lineTo(s * (.5 + dir * .22), s * .12)
        ..lineTo(s * (.5 + dir * .23), s * .26)
        ..close();
      canvas.drawPath(
          inner, Paint()..color = _accent.withValues(alpha: dimmed ? .18 : .34));
    }

    // A short, sharp bob, behind the face.
    final bob = Path()
      ..moveTo(s * .38, s * .25)
      ..cubicTo(s * .32, s * .36, s * .32, s * .48, s * .36, s * .54)
      ..lineTo(s * .42, s * .48)
      ..cubicTo(s * .39, s * .40, s * .40, s * .32, s * .45, s * .27)
      ..close();
    final bob2 = Path()
      ..moveTo(s * .62, s * .25)
      ..cubicTo(s * .68, s * .36, s * .68, s * .48, s * .64, s * .54)
      ..lineTo(s * .58, s * .48)
      ..cubicTo(s * .61, s * .40, s * .60, s * .32, s * .55, s * .27)
      ..close();
    canvas.drawPath(bob, _hairPaint(toward: .5));
    canvas.drawPath(bob2, _hairPaint(toward: .5));

    _head(canvas, s);

    // A swept fringe over the brow — the streamer, not the soldier.
    final fringe = Path()
      ..moveTo(s * .36, s * .29)
      ..cubicTo(s * .42, s * .21, s * .60, s * .21, s * .66, s * .28)
      ..cubicTo(s * .58, s * .27, s * .46, s * .30, s * .39, s * .36)
      ..close();
    canvas.drawPath(fringe, _hairPaint(toward: .5));
    _eyes(canvas, s, y: .41);
  }

  void _hooded(Canvas canvas, double s, double breath) {
    _torso(canvas, s, width: .86, top: .72);

    // The hood is the character: one shape, over everything, with the face
    // as a hole cut in it.
    final hood = Path()
      ..moveTo(s * .25, s * .86)
      ..cubicTo(s * .19, s * .54, s * .30, s * .14, s * .50, s * .14)
      ..cubicTo(s * .70, s * .14, s * .81, s * .54, s * .75, s * .86)
      ..cubicTo(s * .65, s * .78, s * .35, s * .78, s * .25, s * .86)
      ..close();
    canvas.drawPath(hood, _bodyPaint(s));
    canvas.drawPath(hood, _linePaint(s, alpha: .5));

    // The dark inside the hood.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(s * .5, s * .42), width: s * .28, height: s * .34),
      Paint()..color = const Color(0xFF07060F),
    );

    // Two lights, and nothing else. Momo is what is looking at you.
    _eyes(canvas, s, y: .43, spread: .06, glowScale: 1.15);

    // A gloam-lit hem, so the hood does not read as a hole in the frame.
    canvas.drawPath(
      Path()
        ..moveTo(s * .27, s * .82)
        ..cubicTo(s * .38, s * .74, s * .62, s * .74, s * .73, s * .82),
      _linePaint(s, alpha: .5, width: .01),
    );
  }

  void _orc(Canvas canvas, double s, double breath) {
    // A braid over the shoulder, drawn behind the body.
    final braid = Path()
      ..moveTo(s * .34, s * .28)
      ..cubicTo(s * .25, s * .48, s * .28, s * .74, s * .33, s * .92);
    canvas.drawPath(
      braid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * .075
        ..color = _hairPaint(toward: .5).color,
    );

    _torso(canvas, s, width: 1.18, top: .68);
    _head(canvas, s);

    // Tusks: two short uprights at the jaw. Small, but they are the whole
    // silhouette difference between Thora and everyone else.
    for (final dir in [-1.0, 1.0]) {
      final tusk = Path()
        ..moveTo(s * (.5 + dir * .045), s * .52)
        ..lineTo(s * (.5 + dir * .07), s * .44)
        ..lineTo(s * (.5 + dir * .095), s * .52)
        ..close();
      canvas.drawPath(
          tusk, Paint()..color = bone.withValues(alpha: dimmed ? .35 : .78));
    }

    // Headband, above the eyes.
    canvas.drawLine(
      Offset(s * .37, s * .31),
      Offset(s * .63, s * .31),
      _linePaint(s, alpha: .7, width: .015)..strokeCap = StrokeCap.round,
    );
    _eyes(canvas, s, y: .40, spread: .058);
  }

  void _clerk(Canvas canvas, double s, double breath) {
    // Hair behind, then the head, then the fringe — the only order that
    // keeps a bob from swallowing a face.
    final bob = Path()
      ..moveTo(s * .36, s * .24)
      ..cubicTo(s * .29, s * .38, s * .30, s * .54, s * .35, s * .60)
      ..lineTo(s * .43, s * .52)
      ..cubicTo(s * .39, s * .42, s * .40, s * .32, s * .45, s * .26)
      ..close();
    final bob2 = Path()
      ..moveTo(s * .64, s * .24)
      ..cubicTo(s * .71, s * .38, s * .70, s * .54, s * .65, s * .60)
      ..lineTo(s * .57, s * .52)
      ..cubicTo(s * .61, s * .42, s * .60, s * .32, s * .55, s * .26)
      ..close();
    canvas.drawPath(bob, _hairPaint(toward: .30));
    canvas.drawPath(bob2, _hairPaint(toward: .30));

    _torso(canvas, s, width: .96);
    _head(canvas, s);

    canvas.drawPath(
      Path()
        ..moveTo(s * .36, s * .28)
        ..cubicTo(s * .42, s * .20, s * .58, s * .20, s * .65, s * .28)
        ..cubicTo(s * .57, s * .26, s * .44, s * .27, s * .38, s * .33)
        ..close(),
      _hairPaint(toward: .30),
    );

    // Lanyard and badge. The audit never really stops.
    canvas.drawPath(
      Path()
        ..moveTo(s * .43, s * .72)
        ..lineTo(s * .5, s * .84)
        ..lineTo(s * .57, s * .72),
      _linePaint(s, alpha: .5, width: .008),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(s * .5, s * .88), width: s * .10, height: s * .075),
        Radius.circular(s * .012),
      ),
      Paint()..color = _accent.withValues(alpha: dimmed ? .35 : .78),
    );
    _eyes(canvas, s, y: .41);
  }

  void _awakened(Canvas canvas, double s, double breath) {
    _torso(canvas, s, width: 1.0, top: .70);

    final hood = Path()
      ..moveTo(s * .28, s * .82)
      ..cubicTo(s * .24, s * .50, s * .33, s * .16, s * .50, s * .16)
      ..cubicTo(s * .67, s * .16, s * .76, s * .50, s * .72, s * .82)
      ..cubicTo(s * .64, s * .74, s * .36, s * .74, s * .28, s * .82)
      ..close();
    canvas.drawPath(hood, _bodyPaint(s));
    canvas.drawPath(hood, _linePaint(s, alpha: .45));

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(s * .5, s * .42), width: s * .25, height: s * .31),
      Paint()..color = const Color(0xFF07060F),
    );

    // No face. A gate, standing open, where one would be — the player is
    // the thing the gates came through, and this is the only portrait in
    // the game that does not look back at you.
    final gate = Path()
      ..moveTo(s * .5, s * .30)
      ..cubicTo(s * .59, s * .34, s * .59, s * .50, s * .5, s * .54)
      ..cubicTo(s * .41, s * .50, s * .41, s * .34, s * .5, s * .30)
      ..close();
    canvas.drawPath(
      gate,
      Paint()
        ..color =
            _accent.withValues(alpha: (dimmed ? .25 : .5) * (.6 + .4 * glow))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .02),
    );
    canvas.drawPath(gate, _linePaint(s, alpha: .8, width: .01));
    canvas.drawLine(
      Offset(s * .5, s * .32),
      Offset(s * .5, s * .52),
      _linePaint(s, alpha: .5, width: .006),
    );
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter old) =>
      old.t != t ||
      old.glow != glow ||
      old.dimmed != dimmed ||
      old.look != look;
}
