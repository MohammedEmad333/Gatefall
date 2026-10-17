import 'package:flutter/material.dart';
import 'package:gatefall_dialogue_engine/models/route.dart';

import '../art/sprites.dart';
import '../data/companion_routes.dart';
import '../data/house.dart';
import '../data/story.dart';
import '../state/game_controller.dart';
import 'dialogue_screen.dart';
import 'start_scene.dart';
import 'theme.dart';

/// Canonical route timeline, not a second story engine.
///
/// The map derives its status from GameController and never applies flags,
/// Bond, rewards or completion. A beat may be launched here only when its
/// real trigger context is 'story'; House and post-raid scenes stay owned by
/// their existing gameplay flows.
class StoryScreen extends StatelessWidget {
  final GameController game;
  final VoidCallback onOpenHouse;
  final VoidCallback onOpenGates;

  const StoryScreen({
    super.key,
    required this.game,
    required this.onOpenHouse,
    required this.onOpenGates,
  });

  @override
  Widget build(BuildContext context) => ScreenBody(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ScreenHeader(
            'Your story',
            trailing: Text(
              '${game.completedBeatCount} scenes remembered',
              style: const TextStyle(color: boneDim, fontSize: 11),
            ),
          ),
          const SizedBox(height: 10),
          Panel(
            borderColor: rift,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_stories_outlined, color: gold, size: 23),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'THE GATES. THE HOUSE. THE PEOPLE.',
                        style: TextStyle(
                          color: gold,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  Acts.title[game.act] ?? 'GateFall',
                  style: const TextStyle(color: bone, fontSize: 22, height: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  Acts.blurb[game.act] ?? '',
                  style: const TextStyle(color: boneDim, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const Key('story-replay-prologue'),
                  onPressed: () => StartScene.replay(context),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Read the opening'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'THE THREE ACTS',
            style: TextStyle(
              color: gold,
              letterSpacing: 1.5,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          for (var act = 1; act <= Acts.maxAct; act++) ...[
            _actCard(act),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 18),
          const Text(
            'COMPANION STORIES',
            style: TextStyle(
              color: gold,
              letterSpacing: 1.5,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choices and Bond unlock chapters. Some scenes happen at home '
            'or after a gate; their original triggers are preserved.',
            style: TextStyle(color: boneDim, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          for (final id in CompanionRoutes.ids) ...[
            _routeCard(context, id),
            const SizedBox(height: 10),
          ],
          if (game.act >= Acts.maxAct && game.gateAnswer == null) ...[
            const SizedBox(height: 6),
            const Callout(
              'The final question about the gates awaits at the House.',
              tone: gold,
            ),
            const SizedBox(height: 10),
            SlabButton(
              'Return to the House',
              onPressed: onOpenHouse,
              tone: gold,
            ),
          ],
        ],
      );

  Widget _actCard(int act) {
    final completed = act < game.act;
    final active = act == game.act;
    final color = active ? gold : (completed ? verdant : boneDim);
    return Panel(
      borderColor: active ? rift : riftDim,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(
            completed
                ? Icons.check_circle_outline
                : (active ? Icons.adjust : Icons.lock_outline),
            color: color,
            size: 24,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Acts.title[act] ?? 'Act $act',
                  style: TextStyle(
                    color: active || completed ? bone : boneDim,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  active ? 'CURRENT ACT' : (completed ? 'REACHED' : 'LOCKED'),
                  style: TextStyle(color: color, fontSize: 10, letterSpacing: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeCard(BuildContext context, String id) {
    final route = game.routes[id];
    final resident = House.byId(id);
    final atHome = game.settled.contains(id);
    final upcoming = game.upcomingBeat(id);
    final ready = atHome &&
        upcoming != null &&
        game.nextBeat(id)?.beatId == upcoming.beatId;
    final canPlayHere = ready && upcoming.triggerContext == 'story';
    final completed = route?.beats
            .where((beat) => game.state.completedBeats.contains(beat.beatId))
            .length ??
        0;
    final total = route?.beats.length ?? 0;

    final String status;
    if (upcoming == null) {
      status = 'Route complete · revisit memories in Allies';
    } else if (!atHome) {
      status = 'Meet and settle ${resident.name} to continue';
    } else if (!ready) {
      status = game.lockReason(id) ?? 'Not available yet';
    } else {
      status = switch (upcoming.triggerContext) {
        'story' => 'New story ready',
        'post_raid' => 'Continue after a gate raid',
        'home_visit' => 'Continue at the House',
        'gift' => 'Continue with a gift at the House',
        'date' => 'Continue with a date at the House',
        _ => 'Continue through ${upcoming.triggerContext}',
      };
    }
    final VoidCallback? action = canPlayHere
        ? () => _play(context, id, upcoming)
        : (ready
            ? (upcoming.triggerContext == 'post_raid'
                ? onOpenGates
                : onOpenHouse)
            : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('story-route-$id'),
        onTap: action,
        borderRadius: BorderRadius.circular(10),
        child: Panel(
          borderColor: canPlayHere ? rift : riftDim,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CharacterSprite(
                id,
                size: 56,
                glow: atHome ? .7 : .2,
                dimmed: !atHome,
                calm: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            resident.name,
                            style: const TextStyle(color: bone, fontSize: 15),
                          ),
                        ),
                        Text(
                          '$completed / $total',
                          style: const TextStyle(color: rose, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      upcoming?.title ?? 'All memories unlocked',
                      style: TextStyle(
                        color: atHome ? bone : boneDim,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      status,
                      style: TextStyle(
                        color: ready ? verdant : boneDim,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: gold),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _play(BuildContext context, String id, Beat beat) =>
      DialogueScreen.play(
        context,
        game: game,
        characterId: id,
        beat: beat,
      );
}
