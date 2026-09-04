import 'package:flutter/material.dart';

import '../data/house.dart';
import '../data/story.dart';
import '../state/game_controller.dart';
import 'theme.dart';

/// The epilogue. Both dials, resolved: what you did about the gates, and
/// what each person in the house became because of how you treated them.
///
/// The romance dial is not decided here — [Evaluator.resolveEnding] reads
/// each route's own `endings` block from the JSON, in priority order,
/// specific before generic (finding #6 in docs/HANDOFF.md). This screen only
/// prints what that returns.
class EndingScreen extends StatelessWidget {
  final GameController game;
  const EndingScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final answer = game.gateAnswer;
    final endings = game.resolveEndings();

    return Scaffold(
      backgroundColor: night,
      appBar: AppBar(
        backgroundColor: night,
        elevation: 0,
        iconTheme: const IconThemeData(color: boneDim),
        title: const Text('Gatefall',
            style: TextStyle(color: bone, fontSize: 16, letterSpacing: 2)),
      ),
      body: SafeArea(
        child: ScreenBody(
          children: [
            if (answer != null) ...[
              Panel(
                borderColor: rift,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('THE GATES',
                        style: TextStyle(
                            color: rift, fontSize: 10.5, letterSpacing: 1.6)),
                    const SizedBox(height: 7),
                    Text(answer.label,
                        style: const TextStyle(color: bone, fontSize: 18)),
                    const SizedBox(height: 9),
                    Text(answer.epilogue,
                        style: const TextStyle(
                            color: boneDim, fontSize: 13.5, height: 1.7)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('THE HOUSE',
                  style: TextStyle(
                      color: rose, fontSize: 10.5, letterSpacing: 1.6)),
            ),
            for (final id in House.residents
                .map((r) => r.id)
                .where(game.settled.contains)) ...[
              _routeEnding(id, endings[id]?.endingId),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 6),
            const Text(
              'You can keep playing. Nothing here is locked, and a route that '
              'ended short will resolve differently once it goes further.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: boneDim,
                  fontSize: 11.5,
                  height: 1.6,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeEnding(String id, String? endingId) {
    final r = House.byId(id);
    final label = Endings.labelFor(endingId);
    final tone = switch (label) {
      'True' => rose,
      'Bittersweet' => gold,
      'Lost' => blood,
      _ => boneDim,
    };
    return Panel(
      borderColor: tone.withValues(alpha: .6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.name,
                    style: const TextStyle(color: bone, fontSize: 15)),
              ),
              Text(label.toUpperCase(),
                  style: TextStyle(
                      color: tone, fontSize: 10.5, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 9),
          Text(Endings.forId(endingId),
              style:
                  const TextStyle(color: boneDim, fontSize: 13, height: 1.7)),
          const SizedBox(height: 7),
          Text('bond tier ${game.bondTier(id)}/${game.maxBondTier}',
              style: const TextStyle(color: boneDim, fontSize: 10.5)),
        ],
      ),
    );
  }
}
