import 'package:flutter/material.dart';

import 'art/gate_art.dart';
import 'data/element.dart';
import 'state/game_controller.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

/// Gatefall — idle action-RPG × romance simulation.
///
/// Two halves that feed each other: the House (Gold — rooms, gifts, dates,
/// the seven-beat routes) and the Gates (Mana — the auto-battler, levels,
/// gear). Bond is the hinge: earned by fighting together *and* by everything
/// that happens at home, it gates the story and buffs the party.
///
/// Note this is plain Flutter widgets, not a Flame render loop. That's
/// deliberate at this stage: the open question is whether the *loop* feels
/// good, and widgets get you there far faster. Swap in FlameGame + sprite
/// components once the pacing is proven and you actually need sprites,
/// particles and animation — combat/battle.dart won't change, you just call
/// battle.tick(dt) from Flame's update() instead of a Timer.
///
/// Version 3 ("Illumination") added the art, the animation and the sound
/// without needing that swap: everything is drawn by CustomPainters in
/// lib/art/ and driven by AnimationControllers, and the sound is a bus over
/// synthesised WAVs (lib/audio/, tool/make_sounds.py). The simulation still
/// does not know anything is being drawn.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GatefallApp());
}

class GatefallApp extends StatefulWidget {
  const GatefallApp({super.key});

  @override
  State<GatefallApp> createState() => _GatefallAppState();
}

class _GatefallAppState extends State<GatefallApp> {
  final GameController _game = GameController();
  late final Future<void> _boot = _game.boot();

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gatefall',
      debugShowCheckedModeBanner: false,
      theme: gatefallTheme(),
      home: FutureBuilder<void>(
        future: _boot,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _BootScreen();
          }
          if (snap.hasError) {
            return _BootScreen(error: '${snap.error}');
          }
          return GatefallShell(game: _game);
        },
      ),
    );
  }
}

/// The first thing anyone sees: a gate opening, and the game's name coming
/// up out of it. It is on screen for as long as the routes and scenes take
/// to load, which on a phone is a beat — long enough to be an entrance,
/// short enough that nobody waits for it.
class _BootScreen extends StatefulWidget {
  final String? error;
  const _BootScreen({this.error});

  @override
  State<_BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<_BootScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failed = widget.error != null;
    return Scaffold(
      backgroundColor: night,
      body: AmbientBackdrop(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: AnimatedBuilder(
              animation: _open,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_open.value);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: failed ? .35 : t,
                      child: RiftView(
                        element:
                            failed ? GateElement.sever : GateElement.verdant,
                        size: 132,
                        intensity: failed ? .4 : t,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: t,
                      child: Text('GATEFALL',
                          style: TextStyle(
                              color: bone,
                              fontSize: 26,
                              // The name resolves out of the light rather
                              // than simply appearing in it.
                              letterSpacing: 6 + (1 - t) * 16)),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: t * t,
                      child: Text(
                        failed
                            ? 'Something went wrong opening the door.\n${widget.error}'
                            : 'The door is still open.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: failed ? blood : boneDim,
                            fontSize: 13,
                            height: 1.6,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
