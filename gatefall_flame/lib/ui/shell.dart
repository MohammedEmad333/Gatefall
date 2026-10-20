import 'package:flutter/material.dart';

import '../art/gate_art.dart';
import '../audio/sfx.dart';
import '../state/game_controller.dart';
import 'allies_screen.dart';
import 'gate_screen.dart';
import 'home_screen.dart';
import 'story_screen.dart';
import 'theme.dart';

/// The portrait-first hub: House, Story, Gates and Allies.
///
/// Keeping the destinations in an IndexedStack preserves live raid state.
/// GateScreen pauses itself whenever its [active] flag becomes false; no
/// tab switch may silently resume a raid.
class GatefallShell extends StatefulWidget {
  final GameController game;
  const GatefallShell({super.key, required this.game});

  @override
  State<GatefallShell> createState() => _GatefallShellState();
}

class _GatefallShellState extends State<GatefallShell> {
  static const int _house = 0;
  static const int _story = 1;
  static const int _gates = 2;

  int _index = _house;

  Ambience get _ambience =>
      _index == _gates ? Ambience.gate : Ambience.house;

  @override
  void initState() {
    super.initState();
    widget.game.addListener(_onGameChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Audio.instance.ambience(_ambience),
    );
  }

  @override
  void dispose() {
    widget.game.removeListener(_onGameChanged);
    super.dispose();
  }

  void _onGameChanged() {
    if (mounted) setState(() {});
  }

  void _selectTab(int index) {
    Audio.instance.noteGesture();
    Audio.instance.play(index == _index ? Sfx.uiTap : Sfx.page);
    if (index == _index) return;
    setState(() => _index = index);
    Audio.instance.ambience(_ambience);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final storyWaiting = game.pendingStoryBeats.isNotEmpty ||
        (game.act >= 3 && game.gateAnswer == null);

    // Keep the OS Back action inside the portrait hub until House is
    // selected. A dialogue or character-details route above the hub still
    // pops normally because only the top route receives that pop.
    return PopScope(
      canPop: _index == _house,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != _house) _selectTab(_house);
      },
      child: Scaffold(
      body: Listener(
        // Browsers allow sound only after a user gesture.
        onPointerDown: (_) => Audio.instance.noteGesture(),
        child: AmbientBackdrop(
          element: _index == _gates ? game.board.firstOrNull?.element : null,
          child: SafeArea(
            child: IndexedStack(
              index: _index,
              children: [
                // IndexedStack retains tab state, but inactive routes do
                // not need repeating rift / portrait animations. An active
                // raid's real timer is paused separately by GateScreen.
                TickerMode(
                  enabled: _index == _house,
                  child: HomeScreen(
                    game: game,
                    onOpenGates: () => _selectTab(_gates),
                  ),
                ),
                TickerMode(
                  enabled: _index == _story,
                  child: StoryScreen(
                    game: game,
                    onOpenHouse: () => _selectTab(_house),
                    onOpenGates: () => _selectTab(_gates),
                  ),
                ),
                TickerMode(
                  enabled: _index == _gates,
                  child: GateScreen(
                    game: game,
                    active: _index == _gates,
                    onOpenHouse: () => _selectTab(_house),
                    onOpenStory: () => _selectTab(_story),
                  ),
                ),
                TickerMode(
                  enabled: _index == 3,
                  child: AlliesScreen(game: game),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: night2,
          border: Border(top: BorderSide(color: riftDim)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: Colors.transparent,
                  indicatorColor: rift.withValues(alpha: .25),
                  labelTextStyle: WidgetStateProperty.all(
                    const TextStyle(color: boneDim, fontSize: 11),
                  ),
                ),
                child: NavigationBar(
                  key: const Key('gatefall-primary-navigation'),
                  height: 64,
                  selectedIndex: _index,
                  onDestinationSelected: _selectTab,
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
                      icon: Icon(Icons.menu_book_outlined, color: boneDim),
                      selectedIcon: Icon(Icons.menu_book, color: bone),
                      label: 'Story',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.blur_circular_outlined, color: boneDim),
                      selectedIcon: Icon(Icons.blur_circular, color: bone),
                      label: 'Gates',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.groups_outlined, color: boneDim),
                      selectedIcon: Icon(Icons.groups, color: bone),
                      label: 'Allies',
                    ),
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
}
