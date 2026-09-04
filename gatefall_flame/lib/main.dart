import 'package:flutter/material.dart';

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

class _BootScreen extends StatelessWidget {
  final String? error;
  const _BootScreen({this.error});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: night,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('GATEFALL',
                    style: TextStyle(
                        color: bone, fontSize: 26, letterSpacing: 6)),
                const SizedBox(height: 10),
                Text(
                  error == null
                      ? 'The door is still open.'
                      : 'Something went wrong opening the door.\n$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: error == null ? boneDim : blood,
                      fontSize: 13,
                      height: 1.6,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      );
}
