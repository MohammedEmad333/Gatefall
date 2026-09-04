import 'package:flutter/material.dart';

import '../state/game_controller.dart';
import 'companions_screen.dart';
import 'gate_screen.dart';
import 'home_screen.dart';
import 'theme.dart';

/// Three tabs, because the game is two halves and the thing that joins them:
/// the House (Gold, bond, story), the Gate (Mana, combat), and the roster
/// where Mana turns back into power you take through the door.
class GatefallShell extends StatefulWidget {
  final GameController game;
  const GatefallShell({super.key, required this.game});

  @override
  State<GatefallShell> createState() => _GatefallShellState();
}

class _GatefallShellState extends State<GatefallShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.game.addListener(_onGameChanged);
  }

  @override
  void dispose() {
    widget.game.removeListener(_onGameChanged);
    super.dispose();
  }

  void _onGameChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final storyWaiting = game.pendingStoryBeats.isNotEmpty ||
        (game.act >= 3 && game.gateAnswer == null);

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(game: game),
            GateScreen(game: game),
            CompanionsScreen(game: game),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: riftDim)),
          color: night2,
        ),
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
            onDestinationSelected: (i) => setState(() => _index = i),
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
            ],
          ),
        ),
      ),
    );
  }
}
