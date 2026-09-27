import 'package:flutter/material.dart';

import '../art/gate_art.dart';
import '../audio/sfx.dart';
import '../state/game_controller.dart';
import 'characters_screen.dart';
import 'companions_screen.dart';
import 'gate_screen.dart';
import 'home_screen.dart';
import 'theme.dart';

/// Four tabs: the House (Gold and current story), the Gate (combat), the
/// Party (power and formation), and Characters (profiles and story archive).
class GatefallShell extends StatefulWidget {
  final GameController game;
  const GatefallShell({super.key, required this.game});

  @override
  State<GatefallShell> createState() => _GatefallShellState();
}

class _GatefallShellState extends State<GatefallShell> {
  int _index = 0;

  /// Which bed is playing. The house and the gates are the two halves of
  /// the game, and they get one each; the party screen is bookkeeping done
  /// at home, so it keeps the house's.
  Ambience get _ambience =>
      _index == 1 ? Ambience.gate : Ambience.house;

  @override
  void initState() {
    super.initState();
    widget.game.addListener(_onGameChanged);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Audio.instance.ambience(_ambience));
  }

  @override
  void dispose() {
    widget.game.removeListener(_onGameChanged);
    super.dispose();
  }

  void _onGameChanged() {
    if (mounted) setState(() {});
  }

  void _openGates() {
    if (_index == 1) return;
    Audio.instance.noteGesture();
    Audio.instance.play(Sfx.page);
    setState(() => _index = 1);
    Audio.instance.ambience(_ambience);
  }

  void _openHouse() {
    if (_index == 0) return;
    Audio.instance.noteGesture();
    Audio.instance.play(Sfx.page);
    setState(() => _index = 0);
    Audio.instance.ambience(_ambience);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final storyWaiting = game.pendingStoryBeats.isNotEmpty ||
        (game.act >= 3 && game.gateAnswer == null);

    return Scaffold(
      // One Listener over the whole app: browsers refuse to start audio
      // before a gesture, and this is the first one we are guaranteed to
      // see wherever the player happens to tap.
      body: Listener(
        onPointerDown: (_) => Audio.instance.noteGesture(),
        child: AmbientBackdrop(
          element: _index == 1 ? game.board.firstOrNull?.element : null,
          child: SafeArea(
            child: IndexedStack(
              index: _index,
              children: [
                HomeScreen(game: game, onOpenGates: _openGates),
                GateScreen(game: game, onOpenHouse: _openHouse),
                CompanionsScreen(game: game),
                CharactersScreen(game: game),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: riftDim)),
          color: night2,
        ),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              indicatorColor: rift.withValues(alpha: .25),
              labelTextStyle: WidgetStateProperty.all(
                  const TextStyle(color: boneDim, fontSize: 11)),
            ),
            child: NavigationBar(
              height: 62,
            selectedIndex: _index,
            onDestinationSelected: (i) {
              Audio.instance.noteGesture();
              Audio.instance.play(i == _index ? Sfx.uiTap : Sfx.page);
              setState(() => _index = i);
              Audio.instance.ambience(_ambience);
            },
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: storyWaiting,
                  backgroundColor: gold,
                  child: const Icon(Icons.home_outlined, color: boneDim),
                ),
                selectedIcon: const Icon(Icons.home, color: bone),
                label: 'House',
              ),
              const NavigationDestination(
                icon: Icon(Icons.blur_circular_outlined, color: boneDim),
                selectedIcon: Icon(Icons.blur_circular, color: bone),
                label: 'Gates',
              ),
              const NavigationDestination(
                icon: Icon(Icons.groups_outlined, color: boneDim),
                selectedIcon: Icon(Icons.groups, color: bone),
                label: 'Party',
              ),
              const NavigationDestination(
                icon: Icon(Icons.people_outline, color: boneDim),
                selectedIcon: Icon(Icons.people, color: bone),
                label: 'Characters',
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
