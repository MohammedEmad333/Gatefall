import 'package:flutter/material.dart';

import '../state/game_controller.dart';
import 'characters_screen.dart';
import 'companions_screen.dart';
import 'theme.dart';

/// Groups both existing progression surfaces under a single destination.
/// TabBarView retains each page; no character or battle state is duplicated.
class AlliesScreen extends StatelessWidget {
  final GameController game;
  const AlliesScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: const TabBar(
                key: Key('allies-sections'),
                indicatorColor: rift,
                labelColor: bone,
                unselectedLabelColor: boneDim,
                tabs: [
                  Tab(text: 'Party'),
                  Tab(text: 'Characters'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CompanionsScreen(game: game),
                  CharactersScreen(game: game),
                ],
              ),
            ),
          ],
        ),
      );
