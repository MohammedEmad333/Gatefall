import 'package:flutter/material.dart';

import '../art/character_art.dart';
import '../art/comic.dart';
import '../art/effects.dart';
import '../art/gate_art.dart';
import '../art/palette.dart';
import '../audio/sfx.dart';
import '../data/element.dart';
import 'theme.dart';

/// The opening — the thing that plays before the house, once, told as a
/// comic.
///
/// The premise this game runs on is three sentences long and the game had
/// nowhere to say them: a new player used to land on a rent panel with an
/// elf already asleep upstairs and no idea why. A comic is the cheapest
/// honest way to say them — it is *pictures*, so it costs one screen rather
/// than a cutscene system, and it is *paged*, so it is skippable and
/// re-readable without touching the save.
///
/// It reads like a page rather than a slideshow: the whole page is laid out
/// at once and revealed one panel at a time, so nothing reflows under the
/// reader, and a tap while a line is still lettering finishes that line
/// first — the same impatient-tap rule the dialogue screen uses.
class StartScene extends StatefulWidget {
  /// Called when the reader reaches the end, or skips. Marking the
  /// prologue as read is the caller's business, not the scene's.
  final VoidCallback onDone;

  /// What the button on the last page says. "BEGIN" when this is the way
  /// into the game; something else when it is a re-read and there is
  /// nothing to begin.
  final String finishLabel;

  const StartScene({
    super.key,
    required this.onDone,
    this.finishLabel = 'BEGIN',
  });

  /// Plays the opening again over whatever is on screen, from the house.
  static Future<void> replay(BuildContext context) => Navigator.of(context)
      .push<void>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => StartScene(
          finishLabel: 'BACK',
          onDone: () => Navigator.of(ctx).pop(),
        ),
      ));

  @override
  State<StartScene> createState() => _StartSceneState();
}

/// What a panel is a picture of. Every one of these is drawn by code that
/// already existed for the game proper — the same rift, the same cast, the
/// same creatures — so the opening cannot show you a world the game then
/// fails to be.
enum Shot { skyline, tear, beast, refugees, awakened, house, doorstep, fallen, title }

class _Panel {
  final Shot shot;

  /// The narrator's box. A panel carries this or [line], never both: one
  /// beat, one thing to read.
  final String? caption;

  /// A line of speech, in a balloon.
  final String? line;
  final Tail tail;

  /// Onomatopoeia, on a burst.
  final String? sfx;
  final Color sfxColor;

  /// Played when the panel lands.
  final Sfx? sound;

  /// Share of the page's height.
  final int flex;
  final double tilt;

  /// Screen-tone colour: what the panel is about, in one colour.
  final Color tone;

  const _Panel(
    this.shot, {
    this.caption,
    this.line,
    this.tail = Tail.bottomLeft,
    this.sfx,
    this.sfxColor = gold,
    this.sound,
    this.flex = 1,
    this.tilt = 0,
    this.tone = rift,
  });
}

class _Page {
  final List<_Panel> panels;
  const _Page(this.panels);
}

/// The script. Six pages, thirteen panels: the gates, what came through,
/// what woke up, the building, and the elf on the step — which is exactly
/// where `GameController._newGame()` starts the player.
const List<_Page> _script = [
  _Page([
    _Panel(
      Shot.skyline,
      caption: 'Three years ago, the sky came apart.',
      sfx: 'KRAKK',
      sfxColor: gold,
      sound: Sfx.gateOpen,
      flex: 5,
      tilt: -.008,
      tone: rift,
    ),
    _Panel(
      Shot.tear,
      caption: 'Not one door. Thousands — and no two of them opened onto '
          'the same world.',
      sound: Sfx.bossStir,
      flex: 4,
      tilt: .009,
      tone: gloam,
    ),
  ]),
  _Page([
    _Panel(
      Shot.beast,
      caption: 'Monsters came through.',
      sfx: 'SKRAAA',
      sfxColor: blood,
      sound: Sfx.hit,
      flex: 5,
      tilt: .01,
      tone: ember,
    ),
    _Panel(
      Shot.refugees,
      caption: 'So did people. Elves, beastkin, stranger folk — running '
          'from the same tide, into a world with no room for them.',
      sound: Sfx.page,
      flex: 4,
      tilt: -.007,
      tone: verdant,
    ),
  ]),
  _Page([
    _Panel(
      Shot.awakened,
      caption: 'And in a few ordinary people, something woke up.',
      sfx: 'THRUMM',
      sfxColor: sever,
      sound: Sfx.ability,
      flex: 5,
      tilt: .008,
      tone: sever,
    ),
    _Panel(
      Shot.house,
      caption: 'No prophecy. No bloodline. A tired building you inherited, '
          'a rent bill, and mana you never asked for.',
      sound: Sfx.uiSelect,
      flex: 4,
      tilt: -.009,
      tone: gold,
    ),
  ]),
  _Page([
    _Panel(
      Shot.doorstep,
      caption: 'The first one reached your door still on her feet. '
          'Outnumbered. Bleeding. Refusing to fall.',
      sound: Sfx.bossStir,
      flex: 5,
      tilt: -.008,
      tone: verdant,
    ),
    _Panel(
      Shot.doorstep,
      line: "I don't need shelter.",
      tail: Tail.bottomRight,
      sound: Sfx.uiSelect,
      flex: 4,
      tilt: .009,
      tone: verdant,
    ),
  ]),
  _Page([
    _Panel(
      Shot.fallen,
      caption: 'She collapses two steps later. You catch her before the '
          'ground does.',
      sfx: 'THMP',
      sfxColor: bone,
      sound: Sfx.partyDown,
      flex: 5,
      tilt: .009,
      tone: gloam,
    ),
    _Panel(
      Shot.fallen,
      line: "...One night. I'll be gone by morning.",
      tail: Tail.bottomLeft,
      sound: Sfx.bond,
      flex: 4,
      tilt: -.008,
      tone: rose,
    ),
  ]),
  _Page([
    _Panel(
      Shot.title,
      caption: 'She stayed. Others followed. The door is still open.',
      sound: Sfx.gateOpen,
      flex: 1,
      tone: rift,
    ),
  ]),
];

class _StartSceneState extends State<StartScene> {
  int _page = 0;

  /// How many of this page's panels have landed. Never zero: opening a
  /// page draws its first panel.
  int _shown = 1;

  /// The line currently lettering itself in, held so a tap can finish it.
  final GlobalKey<TypewriterState> _typing = GlobalKey<TypewriterState>();

  _Page get _current => _script[_page];
  bool get _pageComplete => _shown >= _current.panels.length;
  bool get _atEnd => _page == _script.length - 1 && _pageComplete;

  @override
  void initState() {
    super.initState();
    // The first panel's sound belongs to the panel, not to the tap that
    // never happened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sound(_current.panels.first);
    });
  }

  void _sound(_Panel panel) {
    final s = panel.sound;
    if (s != null) Audio.instance.play(s);
  }

  void _advance() {
    Audio.instance.noteGesture();

    // First tap finishes the lettering, second tap moves on.
    final typing = _typing.currentState;
    if (typing != null && !typing.done) {
      setState(typing.finish);
      return;
    }
    if (!_pageComplete) {
      setState(() => _shown++);
      _sound(_current.panels[_shown - 1]);
      return;
    }
    if (_page < _script.length - 1) {
      Audio.instance.play(Sfx.page);
      setState(() {
        _page++;
        _shown = 1;
      });
      _sound(_current.panels.first);
      return;
    }
    _finish();
  }

  void _finish() {
    Audio.instance.noteGesture();
    Audio.instance.play(Sfx.gateOpen);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final panels = _current.panels;
    return Scaffold(
      backgroundColor: night,
      body: AmbientBackdrop(
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _advance,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < panels.length; i++)
                              Expanded(
                                flex: panels[i].flex,
                                child: Padding(
                                  // Room on the right and underneath for
                                  // the hard shadow, and a little slack all
                                  // round for the tilt.
                                  padding: const EdgeInsets.fromLTRB(2, 4, 6, 9),
                                  child: _panelView(panels[i],
                                      shown: i < _shown, active: i == _shown - 1),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _footer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- page furniture ----------------

  Widget _header() => Row(
        children: [
          InkedText(
            'GATEFALL',
            stroke: 3,
            style: letterStyle(size: 15, color: bone, spacing: 3),
          ),
          const SizedBox(width: 8),
          const Text('no. 1',
              style: TextStyle(color: boneDim, fontSize: 11)),
          const Spacer(),
          for (var i = 0; i < _script.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                width: 7,
                height: 7,
                color: i <= _page ? bone : riftDim,
              ),
            ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: _finish,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('skip',
                style: TextStyle(color: boneDim, fontSize: 11)),
          ),
        ],
      );

  Widget _footer() => SizedBox(
        height: 42,
        child: Center(
          child: _atEnd
              ? SlabButton(
                  widget.finishLabel,
                  filled: true,
                  sound: Sfx.gateOpen,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 34),
                  onPressed: _finish,
                )
              : Text(
                  _pageComplete ? 'tap to turn the page' : 'tap to continue',
                  style: const TextStyle(
                      color: boneDim, fontSize: 11, fontStyle: FontStyle.italic),
                ),
        ),
      );

  // ---------------- a panel ----------------

  Widget _panelView(_Panel panel, {required bool shown, required bool active}) {
    return ComicPanel(
      shown: shown,
      tilt: panel.tilt,
      tone: panel.tone,
      toneDensity: panel.shot == Shot.title ? .35 : .5,
      toneOrigin: Alignment.topCenter,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          fit: StackFit.expand,
          children: [
            _shot(panel, c),
            if (panel.sfx != null)
              Positioned(
                right: -4,
                bottom: 4,
                child: SfxWord(
                  panel.sfx!,
                  color: panel.sfxColor,
                  size: (c.maxHeight * .16).clamp(18.0, 32.0),
                ),
              ),
            if (panel.caption != null)
              Positioned(
                left: 8,
                top: 8,
                right: c.maxWidth * .22,
                child: CaptionBox(
                  panel.caption!,
                  accent: panel.tone,
                  typing: active
                      ? Typewriter(panel.caption!,
                          key: _typing,
                          perChar: .022,
                          style: CaptionBox.textStyle)
                      : null,
                ),
              ),
            if (panel.line != null)
              Positioned(
                left: panel.tail == Tail.bottomRight ? 10 : c.maxWidth * .28,
                right: panel.tail == Tail.bottomRight ? c.maxWidth * .28 : 10,
                top: 10,
                child: SpeechBalloon(
                  panel.line!,
                  tail: panel.tail,
                  typing: active
                      ? Typewriter(panel.line!,
                          key: _typing,
                          perChar: .03,
                          style: balloonTextStyle())
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------- what a panel is a picture of ----------------

  Widget _shot(_Panel panel, BoxConstraints c) {
    final w = c.maxWidth;
    final h = c.maxHeight;
    final square = w < h ? w : h;

    switch (panel.shot) {
      case Shot.skyline:
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: SkylinePainter(glow: rift)),
            Positioned(
              right: w * .12,
              top: h * .06,
              child: RiftView(
                  element: GateElement.gloam, size: square * .42, intensity: .9),
            ),
          ],
        );

      case Shot.tear:
        return Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: SpeedLinesPainter(color: gloam, lines: 40)),
            Center(
              child: RiftView(
                  element: GateElement.gloam, size: square * .78, boss: true),
            ),
          ],
        );

      case Shot.beast:
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
                painter: SpeedLinesPainter(
                    color: blood, lines: 44, innerRadius: .3)),
            Align(
              alignment: const Alignment(.02, .8),
              child: CreatureView(
                form: Beastform.stalker,
                element: GateElement.ember,
                size: (w * .8 < h * 1.1 ? w * .8 : h * 1.1).clamp(60.0, 300.0),
              ),
            ),
          ],
        );

      case Shot.refugees:
        // Three of the people the gates put on this side of the door, at
        // three sizes so the row reads as a group rather than a line-up.
        // The unit is taken from the *width* as well as the height — three
        // portraits side by side is the one shot here that can outgrow a
        // wide, short panel — and the FittedBox is the belt to that braces.
        final unit = (h * .78 < w * .30 ? h * .78 : w * .30);
        return Align(
          alignment: const Alignment(.25, .7),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CharacterPortrait('thora',
                    size: unit * .95,
                    glow: .35,
                    calm: true,
                    plate: false),
                CharacterPortrait('momo',
                    size: unit * .80,
                    glow: .5,
                    calm: true,
                    plate: false),
                CharacterPortrait('kess',
                    size: unit,
                    glow: .45,
                    calm: true,
                    plate: false),
              ],
            ),
          ),
        );

      case Shot.awakened:
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
                painter: SpeedLinesPainter(
                    color: sever,
                    lines: 30,
                    innerRadius: .34,
                    origin: const Alignment(.2, .1))),
            Align(
              alignment: const Alignment(.42, .55),
              child: CharacterPortrait('player',
                  size: h * .72 < w * .5 ? h * .72 : w * .5,
                  glow: 1,
                  plate: false),
            ),
          ],
        );

      case Shot.house:
        return CustomPaint(
            painter: HousePainter(
                warm: gold, heightFactor: .66, centerX: .62));

      case Shot.doorstep:
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
                painter: HousePainter(
                    warm: gold, heightFactor: .72, centerX: .36)),
            Align(
              alignment: const Alignment(.78, 1),
              child: CharacterPortrait('faelen',
                  size: h * .58 < w * .42 ? h * .58 : w * .42,
                  glow: .8,
                  plate: false),
            ),
          ],
        );

      case Shot.fallen:
        final figure = h * .54 < w * .36 ? h * .54 : w * .36;
        // The house moves to the right of frame here, which leaves the two
        // figures the left of it and the sound effect the corner. Three
        // things in a panel need somewhere each to be.
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
                painter: HousePainter(
                    warm: gold, heightFactor: .68, centerX: .74)),
            Align(
              alignment: const Alignment(-.85, 1),
              child: CharacterPortrait('player',
                  size: figure, glow: .55, plate: false),
            ),
            Align(
              alignment: const Alignment(-.15, .92),
              // Off her feet: the tilt is the whole picture.
              child: Transform.rotate(
                angle: .42,
                child: CharacterPortrait('faelen',
                    size: figure * .95,
                    glow: .35,
                    dimmed: true,
                    calm: true,
                    plate: false),
              ),
            ),
          ],
        );

      case Shot.title:
        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: RiftView(
                  element: GateElement.verdant,
                  size: (w < h * .55 ? w : h * .55) * 1.12,
                  intensity: .85),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: w * .06),
                // Scaled down rather than wrapped: a logo that breaks
                // across two lines is not a logo.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: InkedText(
                    'GATEFALL',
                    stroke: 7,
                    style: letterStyle(
                        size: (w * .13).clamp(22.0, 54.0),
                        color: bone,
                        spacing: 5),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }
}
