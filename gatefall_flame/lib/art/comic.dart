import 'dart:math';

import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'motion.dart';

/// The comic layer: panels, balloons, captions, lettering and the two
/// establishing shots the prologue needs.
///
/// Same rule as the rest of `lib/art/` — nothing here is an imported asset.
/// A comic is mostly ink, paper and screen tone, and all three are cheaper
/// to draw than to ship: a bordered box with a hard drop shadow, a grid of
/// halftone dots, and text with a stroke behind it. That means the opening
/// can never fall out of step with the palette, and it costs the repo a
/// file rather than a megabyte.
///
/// The style is a *midnight* comic rather than a newsstand one: ink is the
/// night the rest of the game is already lit against, paper is bone, and
/// the screen tone takes the colour of whatever element the panel is
/// about. It reads as a comic page without ever leaving the game's palette.

/// The black a panel is inked and shadowed with. Darker than [night], so a
/// panel edge separates from the backdrop it sits on.
const Color inkBlack = Color(0xFF05040C);

/// Caption boxes and speech balloons. Warmer than [bone]: paper, not UI.
const Color paper = Color(0xFFEDE7DA);

/// Lettering wants a heavy condensed face and the game ships no fonts, so
/// this is a fallback chain through the ones a phone, a desktop and a
/// browser are each likely to have. Whatever it lands on, the lettering is
/// set in caps with wide tracking, which is most of what sells it.
const List<String> comicFaces = [
  'Impact',
  'Haettenschweiler',
  'Arial Black',
  'Roboto',
  'sans-serif',
];

/// Caps, tight, heavy — the voice of a sound effect or a logo.
TextStyle letterStyle({
  required double size,
  Color color = paper,
  double spacing = 2,
}) =>
    TextStyle(
      fontFamily: comicFaces.first,
      fontFamilyFallback: comicFaces.sublist(1),
      fontSize: size,
      height: 1.05,
      letterSpacing: spacing,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      color: color,
    );

/// A word with ink behind every edge of it. Two passes — a stroked copy
/// under a filled one — because that is what makes lettering survive being
/// drawn over art rather than over paper.
class InkedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double stroke;
  final Color strokeColor;
  final TextAlign align;

  const InkedText(
    this.text, {
    super.key,
    required this.style,
    this.stroke = 5,
    this.strokeColor = inkBlack,
    this.align = TextAlign.center,
  });

  /// The same style with the fill swapped for a stroke. Built field by
  /// field rather than with `copyWith`, because `copyWith(color: null)`
  /// keeps the colour it was given — and a style carrying both a colour
  /// and a foreground trips an assertion at paint time.
  TextStyle get _strokeStyle => TextStyle(
        fontFamily: style.fontFamily,
        fontFamilyFallback: style.fontFamilyFallback,
        fontSize: style.fontSize,
        height: style.height,
        letterSpacing: style.letterSpacing,
        wordSpacing: style.wordSpacing,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.round
          ..color = strokeColor,
      );

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Text(text, textAlign: align, style: _strokeStyle),
          Text(text, textAlign: align, style: style),
        ],
      );
}

/// A deterministic wobble in [-1, 1] from an integer step. Used for the
/// hand-inked border and the paper grain — anything that should look drawn
/// by a hand rather than a compass, and must land in the same place on
/// every repaint so it does not flicker.
double _wobble(int n) {
  final s = sin(n * 12.9898 + 78.233) * 43758.5453;
  return (s - s.floorToDouble()) * 2 - 1;
}

/// The four edges of a panel, sampled and nudged perpendicular by a few
/// pixels so the box reads as inked with a brush rather than ruled with a
/// pen. Corners are left crisp — a brush eases off at a corner, it does not
/// round it — so the four edges still meet cleanly.
///
/// The same [seed] gives the same path, which is why the clip, the fill and
/// the border all agree: the art is masked to exactly the shape the ink is
/// drawn around.
Path comicFramePath(Size size, int seed, {double amp = 1.7}) {
  final path = Path();
  var k = seed * 131 + 7;
  double wob() => _wobble(k++) * amp;

  const tl = Offset(1.5, 1.5);
  final tr = Offset(size.width - 1.5, 1.5);
  final br = Offset(size.width - 1.5, size.height - 1.5);
  final bl = Offset(1.5, size.height - 1.5);

  void edge(Offset a, Offset b, Offset normal) {
    final steps = max(3, (a - b).distance ~/ 26);
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final base = Offset.lerp(a, b, t)!;
      // Ends of an edge stay put; the middle is where the brush wanders.
      final w = i == steps ? 0.0 : wob();
      final p = base + normal * w;
      path.lineTo(p.dx, p.dy);
    }
  }

  path.moveTo(tl.dx, tl.dy);
  edge(tl, tr, const Offset(0, 1));
  edge(tr, br, const Offset(1, 0));
  edge(br, bl, const Offset(0, 1));
  edge(bl, tl, const Offset(1, 0));
  return path..close();
}

/// Masks a panel's art to its inked shape, so nothing bleeds past the brush.
class _FrameClipper extends CustomClipper<Path> {
  final int seed;
  const _FrameClipper(this.seed);

  @override
  Path getClip(Size size) => comicFramePath(size, seed);

  @override
  bool shouldReclip(_FrameClipper old) => old.seed != seed;
}

/// The panel's hard offset shadow and its paper fill, both drawn to the
/// inked outline rather than to a rectangle — the shadow a real panel casts
/// carries the same wobble as its border.
class _FrameGroundPainter extends CustomPainter {
  final int seed;
  const _FrameGroundPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = comicFramePath(size, seed);
    canvas.save();
    canvas.translate(4, 5);
    // Hard, unblurred, offset: ink on paper, not elevation.
    canvas.drawPath(path, Paint()..color = inkBlack);
    canvas.restore();
    canvas.drawPath(path, Paint()..color = night);
  }

  @override
  bool shouldRepaint(_FrameGroundPainter old) => old.seed != seed;
}

/// The panel border, drawn over the art so the art tucks under it. The page
/// it sits on is night, so the border is drawn light — a lit paper edge that
/// separates the panel from the dark around it, the job [bone] did when the
/// border was a ruled rectangle.
///
/// What is new is the hand in it. A dark core is laid down first and the
/// bone edge over it, so the line reads as ink caught by light rather than a
/// flat rule; and a second, lighter bone pass is nudged off the first, so no
/// stretch of the edge is quite the same weight as the next — the giveaway
/// of a brush over a pen.
class _FrameInkPainter extends CustomPainter {
  final int seed;
  const _FrameInkPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = comicFramePath(size, seed);
    // The ink core, a touch wider, so a dark rim shows either side of the
    // bright edge.
    canvas.drawPath(
      path,
      Paint()
        ..color = inkBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = bone
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.save();
    canvas.translate(.8, .8);
    canvas.drawPath(
      path,
      Paint()
        ..color = bone.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FrameInkPainter old) => old.seed != seed;
}

/// One panel of a page: an inked box with a hard shadow, a hair of tilt,
/// and a screen tone over whatever is drawn inside it.
///
/// The border is brush-inked rather than ruled — [comicFramePath] gives it
/// a hand's wobble, and the same path masks the art and casts the shadow so
/// the three never disagree. A [seed] taken from the panel's tilt keeps each
/// panel's wobble its own, and stable across repaints.
///
/// [shown] is the whole reveal animation. A panel that is not shown yet
/// still takes up its space — a comic page is laid out all at once and read
/// one panel at a time, and a page that reflowed under the reader would
/// stop being a page.
class ComicPanel extends StatelessWidget {
  final Widget child;

  /// Radians. A few tenths of a degree each way is the difference between
  /// a comic page and a table of contents.
  final double tilt;

  /// The colour of the halftone dots, and roughly what the panel is about.
  final Color tone;

  /// 0 for no screen tone, 1 for a heavy one.
  final double toneDensity;

  /// Where the tone is densest — the light source, in effect.
  final Alignment toneOrigin;

  final bool shown;

  const ComicPanel({
    super.key,
    required this.child,
    this.tilt = 0,
    this.tone = rift,
    this.toneDensity = .55,
    this.toneOrigin = Alignment.center,
    this.shown = true,
  });

  @override
  Widget build(BuildContext context) {
    // The tilt is unique per panel and constant, so it makes a stable seed
    // without threading a new field through every caller.
    final seed = (tilt * 100000).round();
    return AnimatedOpacity(
      opacity: shown ? 1 : 0,
      duration: Motion.quick(const Duration(milliseconds: 170)),
      child: AnimatedScale(
        // Panels land, they do not fade up: the overshoot is the snap.
        scale: shown ? 1 : .93,
        duration: Motion.quick(const Duration(milliseconds: 260)),
        curve: Curves.easeOutBack,
        child: Transform.rotate(
          angle: tilt,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _FrameGroundPainter(seed)),
              ClipPath(
                clipper: _FrameClipper(seed),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    child,
                    if (toneDensity > 0)
                      IgnorePointer(
                        child: CustomPaint(
                          painter: HalftonePainter(
                            color: tone,
                            density: toneDensity,
                            origin: toneOrigin,
                          ),
                        ),
                      ),
                    // The printed-paper grain sits over everything inside
                    // the panel: it is the tooth of the page, not of any one
                    // thing drawn on it.
                    IgnorePointer(
                      child: CustomPaint(painter: NewsprintPainter(seed: seed)),
                    ),
                  ],
                ),
              ),
              IgnorePointer(child: CustomPaint(painter: _FrameInkPainter(seed))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen tone: a dot grid that thins out with distance from [origin].
/// Static by design — it is print, and print does not move.
class HalftonePainter extends CustomPainter {
  final Color color;
  final double density;
  final double spacing;
  final Alignment origin;

  HalftonePainter({
    required this.color,
    this.density = .55,
    this.spacing = 7,
    this.origin = Alignment.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final dot = Paint()..color = color.withValues(alpha: .5 * density);
    // The plate never quite lands where the ink plate did. A faint dark
    // ghost a hair up-left of each colour dot is that misregistration — the
    // single thing that most says "printed" rather than "rendered".
    final ghost = Paint()..color = inkBlack.withValues(alpha: .18 * density);
    final o = origin.alongSize(size);
    final reach = size.longestSide;
    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
        final falloff =
            min(1.0, max(0.0, 1 - (Offset(x, y) - o).distance / reach));
        final r = spacing * .5 * density * falloff;
        if (r > .18) {
          canvas.drawCircle(Offset(x - .8, y - .8), r, ghost);
          canvas.drawCircle(Offset(x, y), r, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(HalftonePainter old) =>
      old.color != color ||
      old.density != density ||
      old.spacing != spacing ||
      old.origin != origin;
}

/// The tooth of cheap paper: a sparse, even scatter of ink flecks and a few
/// bright pinholes where the press missed. Deterministic from [seed] so it
/// holds still — paper does not crawl — and kept faint, because grain you
/// can *read* is dirt, not print.
class NewsprintPainter extends CustomPainter {
  final int seed;
  const NewsprintPainter({this.seed = 0});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final dark = Paint()..color = inkBlack.withValues(alpha: .05);
    final light = Paint()..color = bone.withValues(alpha: .04);
    var k = seed * 2003 + 11;
    const step = 6.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        final r = _wobble(k++);
        // Roughly a fifth of the cells get a fleck; a rarer few get a
        // pinhole. Everything else is clean paper.
        if (r > .6) {
          final jx = x + _wobble(k++) * step * .5;
          final jy = y + _wobble(k++) * step * .5;
          canvas.drawCircle(Offset(jx, jy), .6, r > .88 ? light : dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(NewsprintPainter old) => old.seed != seed;
}

/// Which edge a balloon's tail leaves from, and therefore who is speaking.
enum Tail { none, bottomLeft, bottomRight, topLeft, topRight }

/// A speech balloon. [shout] swaps the soft outline for a spiked one — the
/// same line, said louder.
class SpeechBalloon extends StatelessWidget {
  final String text;
  final Tail tail;
  final bool shout;
  final double fontSize;
  final Widget? typing;

  const SpeechBalloon(
    this.text, {
    super.key,
    this.tail = Tail.bottomLeft,
    this.shout = false,
    this.fontSize = 13,
    this.typing,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _BalloonPainter(tail: tail, shout: shout),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            tail == Tail.topLeft || tail == Tail.topRight ? 18 : 11,
            14,
            tail == Tail.bottomLeft || tail == Tail.bottomRight ? 19 : 12,
          ),
          child: typing ??
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: inkBlack,
                  fontSize: fontSize,
                  height: 1.35,
                  fontWeight: shout ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
        ),
      );
}

/// The text style a balloon's words are set in, exposed so a [Typewriter]
/// inside one can match the plain text it replaces.
TextStyle balloonTextStyle({double fontSize = 13, bool shout = false}) =>
    TextStyle(
      color: inkBlack,
      fontSize: fontSize,
      height: 1.35,
      fontWeight: shout ? FontWeight.w800 : FontWeight.w600,
    );

class _BalloonPainter extends CustomPainter {
  final Tail tail;
  final bool shout;

  _BalloonPainter({required this.tail, required this.shout});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fill = Paint()..color = paper;
    final ink = Paint()
      ..color = inkBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;

    final body = shout ? _spiked(size) : _rounded(size);
    canvas.drawPath(body, fill);

    // The same tooth the paper of a caption box has, kept inside the
    // balloon's outline so the flecks never spill past the ink.
    canvas.save();
    canvas.clipPath(body);
    PaperTexturePainter(seed: size.width.round()).paint(canvas, size);
    canvas.restore();

    canvas.drawPath(body, ink);

    if (tail != Tail.none) {
      // Order matters: the tail is filled *over* the body's outline so it
      // hides the segment it crosses, and only its two sides are inked —
      // stroking its base would draw that segment straight back in.
      canvas.drawPath(_tail(size), fill);
      canvas.drawPath(_tailSides(size), ink);
    }
  }

  Path _rounded(Size size) => Path()
    ..addRRect(RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(min(size.height, size.width) * .34),
    ));

  /// A shout is the same box with its edge broken into spikes.
  Path _spiked(Size size) {
    final path = Path();
    const spikes = 26;
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (var i = 0; i < spikes; i++) {
      final a = i / spikes * 2 * pi - pi / 2;
      final out = i.isEven ? 1.0 : .84;
      final p = Offset(cx + cos(a) * cx * out, cy + sin(a) * cy * out);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// The three corners of the tail: two on the balloon's edge (pulled a
  /// little inside it, so the fill overlaps the outline) and the tip.
  ({Offset a, Offset b, Offset tip}) _tailPoints(Size size) {
    final bottom = tail == Tail.bottomLeft || tail == Tail.bottomRight;
    final left = tail == Tail.bottomLeft || tail == Tail.topLeft;
    final double y = bottom ? size.height - 4 : 4;
    final tipY = bottom ? size.height + size.height * .34 : -size.height * .34;
    final x = left ? size.width * .30 : size.width * .70;
    final tipX = left ? size.width * .07 : size.width * .93;
    final half = min(size.width * .09, 16.0);
    return (
      a: Offset(x - half, y),
      b: Offset(x + half, y),
      tip: Offset(tipX, tipY),
    );
  }

  Path _tail(Size size) {
    final p = _tailPoints(size);
    return Path()
      ..moveTo(p.a.dx, p.a.dy)
      ..lineTo(p.b.dx, p.b.dy)
      ..lineTo(p.tip.dx, p.tip.dy)
      ..close();
  }

  Path _tailSides(Size size) {
    final p = _tailPoints(size);
    return Path()
      ..moveTo(p.a.dx, p.a.dy)
      ..lineTo(p.tip.dx, p.tip.dy)
      ..lineTo(p.b.dx, p.b.dy);
  }

  @override
  bool shouldRepaint(_BalloonPainter old) =>
      old.tail != tail || old.shout != shout;
}

/// Ink flecks on the cream of a caption box or a balloon — the same tooth
/// the panels have, tuned for paper the reader is meant to read text off,
/// so it stays under the words rather than in them.
class PaperTexturePainter extends CustomPainter {
  final int seed;
  const PaperTexturePainter({this.seed = 0});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fleck = Paint()..color = inkBlack.withValues(alpha: .045);
    var k = seed * 911 + 5;
    const step = 5.0;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        if (_wobble(k++) > .72) {
          canvas.drawCircle(
            Offset(x + _wobble(k++) * 2, y + _wobble(k++) * 2),
            .55,
            fleck,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(PaperTexturePainter old) => old.seed != seed;
}

/// The narrator's box. Square corners, hard shadow, one ink rule down the
/// side in the colour of whatever the page is about, on stock with a hint of
/// tooth to it.
class CaptionBox extends StatelessWidget {
  final String text;
  final Color accent;
  final Widget? typing;

  const CaptionBox(this.text, {super.key, this.accent = rift, this.typing});

  static TextStyle get textStyle => const TextStyle(
        color: inkBlack,
        fontSize: 12.5,
        height: 1.45,
        fontStyle: FontStyle.italic,
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: paper,
          border: Border(
            left: BorderSide(color: accent, width: 4),
            top: const BorderSide(color: inkBlack, width: 1.6),
            right: const BorderSide(color: inkBlack, width: 1.6),
            bottom: const BorderSide(color: inkBlack, width: 1.6),
          ),
          boxShadow: const [BoxShadow(color: inkBlack, offset: Offset(3, 3))],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: PaperTexturePainter(seed: text.length),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: typing ?? Text(text, style: textStyle),
            ),
          ],
        ),
      );
}

/// Onomatopoeia, on a burst. The one place this game shouts.
class SfxWord extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  final double tilt;

  const SfxWord(
    this.text, {
    super.key,
    this.color = gold,
    this.size = 34,
    this.tilt = -.12,
  });

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: tilt,
        child: CustomPaint(
          painter: _BurstPainter(color: color),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: size * .7, vertical: size * .45),
            child: InkedText(
              text,
              stroke: size * .18,
              style: letterStyle(size: size, color: color, spacing: 1),
            ),
          ),
        ),
      );
}

class _BurstPainter extends CustomPainter {
  final Color color;

  _BurstPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final path = Path();
    const spikes = 20;
    for (var i = 0; i < spikes; i++) {
      final a = i / spikes * 2 * pi - pi / 2;
      // The irregularity is deterministic: a burst that changed shape on
      // every repaint would flicker.
      final jitter = i.isEven ? 1.0 : .58 + ((i * 37) % 11) / 55;
      final p = Offset(cx + cos(a) * cx * jitter, cy + sin(a) * cy * jitter);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = inkBlack.withValues(alpha: .92));
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.color != color;
}

/// Motion, drawn: straight lines converging on [origin], drawn only in the
/// outer part of the panel so they frame the subject instead of crossing it.
class SpeedLinesPainter extends CustomPainter {
  final Color color;
  final Alignment origin;
  final int lines;
  final double innerRadius;

  SpeedLinesPainter({
    this.color = bone,
    this.origin = Alignment.center,
    this.lines = 34,
    this.innerRadius = .42,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final o = origin.alongSize(size);
    final reach = size.longestSide;
    final p = Paint()
      ..color = color.withValues(alpha: .22)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < lines; i++) {
      final a = i / lines * 2 * pi + (i % 3) * .04;
      final start = innerRadius + ((i * 29) % 13) / 90;
      canvas.drawLine(
        o + Offset(cos(a), sin(a)) * (reach * start),
        o + Offset(cos(a), sin(a)) * reach,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(SpeedLinesPainter old) =>
      old.color != color ||
      old.origin != origin ||
      old.lines != lines ||
      old.innerRadius != innerRadius;
}

/// The city the gates opened over. Two ranks of blocks and a scatter of lit
/// windows — an establishing shot, not a place you ever go.
class SkylinePainter extends CustomPainter {
  final Color glow;

  SkylinePainter({this.glow = rift});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [night, Color.lerp(night2, glow, .28)!],
        ).createShader(Offset.zero & size),
    );

    void rank(double baseline, Color fill, int count, double seed) {
      final block = Paint()..color = fill;
      final lit = Paint()..color = glow.withValues(alpha: .5);
      var x = -size.width * .04;
      for (var i = 0; i < count; i++) {
        final w = size.width * (.07 + ((i * 17 + seed) % 7) / 70);
        final h = size.height * (.16 + ((i * 31 + seed) % 11) / 34);
        final top = baseline - h;
        canvas.drawRect(Rect.fromLTWH(x, top, w, h), block);
        for (double wy = top + 7; wy < baseline - 5; wy += 11) {
          for (double wx = x + 5; wx < x + w - 4; wx += 9) {
            if ((wx.round() * 7 + wy.round() * 13 + i) % 5 == 0) {
              canvas.drawRect(Rect.fromLTWH(wx, wy, 3, 4), lit);
            }
          }
        }
        x += w + size.width * .012;
        if (x > size.width) break;
      }
    }

    rank(size.height * .88, Color.lerp(night, rift, .12)!, 14, 3);
    rank(size.height, inkBlack, 11, 8);
  }

  @override
  bool shouldRepaint(SkylinePainter old) => old.glow != glow;
}

/// The building the whole game is about: four storeys, most of the windows
/// dark, a light on at the top and someone about to be on the step.
class HousePainter extends CustomPainter {
  final Color warm;

  /// How much of the panel's height the building stands in, and where its
  /// middle sits across the width. Both are here because a panel with a
  /// caption box over its top-left corner needs the building smaller and
  /// pushed out from under it, and a panel with someone standing on the
  /// step needs it pushed the other way.
  final double heightFactor;
  final double centerX;

  HousePainter({
    this.warm = gold,
    this.heightFactor = .78,
    this.centerX = .5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [night, Color.lerp(night, warm, .10)!],
        ).createShader(Offset.zero & size),
    );

    final h = size.height * heightFactor;
    final w = h * .59;
    final left = size.width * centerX - w / 2;
    final top = size.height - h;
    final body = Rect.fromLTWH(left, top, w, h);

    // Facade.
    canvas.drawRect(body, Paint()..color = inkBlack);
    canvas.drawRect(
      body,
      Paint()
        ..color = bone.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Roofline, one chimney, and the sag that makes it rundown rather than
    // merely old.
    final roof = Path()
      ..moveTo(left - w * .08, top)
      ..lineTo(left + w / 2, top - h * .10)
      ..lineTo(left + w + w * .08, top)
      ..close();
    canvas.drawPath(roof, Paint()..color = inkBlack);
    canvas.drawPath(
      roof,
      Paint()
        ..color = bone.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRect(
      Rect.fromLTWH(left + w * .72, top - h * .16, w * .11, h * .16),
      Paint()..color = inkBlack,
    );

    // Windows: three storeys of two, one of them lit.
    final pane = Paint()..color = night2;
    final glass = Paint()..color = warm.withValues(alpha: .8);
    final frame = Paint()
      ..color = bone.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 2; col++) {
        final r = Rect.fromLTWH(
          left + w * (col == 0 ? .16 : .58),
          top + h * (.14 + row * .20),
          w * .26,
          h * .13,
        );
        canvas.drawRect(r, row == 0 && col == 1 ? glass : pane);
        canvas.drawRect(r, frame);
      }
    }

    // The door, lit from inside, and the two steps it sits above.
    final door = Rect.fromLTWH(
      left + w * .36,
      size.height - h * .26,
      w * .28,
      h * .26,
    );
    canvas.drawRect(door, Paint()..color = warm.withValues(alpha: .62));
    canvas.drawRect(door, frame);
    canvas.drawRect(
      Rect.fromLTWH(left + w * .24, size.height - 7, w * .52, 7),
      Paint()..color = Color.lerp(inkBlack, bone, .18)!,
    );
  }

  @override
  bool shouldRepaint(HousePainter old) =>
      old.warm != warm ||
      old.heightFactor != heightFactor ||
      old.centerX != centerX;
}
