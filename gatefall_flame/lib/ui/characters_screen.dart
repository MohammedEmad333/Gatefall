import 'package:flutter/material.dart';
import 'package:gatefall_dialogue_engine/models/route.dart';

import '../art/sprites.dart';
import '../data/ascension.dart';
import '../data/element.dart';
import '../data/house.dart';
import '../data/roster.dart';
import '../state/game_controller.dart';
import 'dialogue_screen.dart';
import 'theme.dart';

/// The cast directory and permanent story archive.
///
/// The Party tab answers "who fights?"; this tab answers "who are they?".
/// Every core character is visible from the start, while residence, Bond and
/// story completion still reflect the real save. Completed scenes can be
/// replayed, but [DialogueScreen.replay] guarantees that doing so cannot farm
/// Bond or rewrite a choice the player's actual route already remembers.
class CharactersScreen extends StatelessWidget {
  final GameController game;

  const CharactersScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) => ScreenBody(
        children: [
          ScreenHeader(
            'Characters',
            trailing: Text(
              '${House.residents.length} people',
              style: const TextStyle(color: boneDim, fontSize: 11),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Everyone drawn to the house, and every story you have shared.',
            style: TextStyle(
              color: boneDim,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          for (final (index, resident) in House.residents.indexed) ...[
            Reveal(
              delay: Duration(milliseconds: 55 * index),
              child: _characterCard(context, resident),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );

  Widget _characterCard(BuildContext context, Resident resident) {
    final atHome = game.settled.contains(resident.id);
    final encountered = game.clears >= resident.clearsToEncounter;
    final route = game.routes[resident.id];
    final completed = route?.beats
            .where((b) => game.state.completedBeats.contains(b.beatId))
            .length ??
        0;
    final total = route?.beats.length ?? 0;
    final status = atHome
        ? 'At home · Bond ${game.bondTier(resident.id)}'
        : encountered
            ? 'Encountered · room not ready'
            : 'Not yet encountered';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('character-${resident.id}'),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CharacterDetailScreen(
            game: game,
            resident: resident,
          ),
        )),
        child: Panel(
          borderColor: atHome ? rift : riftDim,
          child: Row(
            children: [
              CharacterSprite(
                resident.id,
                size: 66,
                glow: atHome ? .8 : .25,
                dimmed: !encountered,
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
                          child: Text(resident.name,
                              style: const TextStyle(
                                  color: bone, fontSize: 15)),
                        ),
                        const Icon(Icons.chevron_right,
                            color: boneDim, size: 20),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(resident.species,
                        style: const TextStyle(color: gold, fontSize: 11)),
                    const SizedBox(height: 7),
                    Text(status,
                        style: TextStyle(
                            color: atHome ? verdant : boneDim, fontSize: 10.5)),
                    const SizedBox(height: 3),
                    Text('$completed/$total stories remembered',
                        style: const TextStyle(color: rose, fontSize: 10.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CharacterDetailScreen extends StatelessWidget {
  final GameController game;
  final Resident resident;

  const CharacterDetailScreen({
    super.key,
    required this.game,
    required this.resident,
  });

  @override
  Widget build(BuildContext context) {
    final route = game.routes[resident.id];
    final fighter = Roster.byId(resident.id);
    final atHome = game.settled.contains(resident.id);
    final ascension = Ascension.byId(resident.id);
    final beats = route == null ? <Beat>[] : List<Beat>.of(route.beats);
    beats.sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      backgroundColor: night,
      body: SafeArea(
        child: ScreenBody(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: bone),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(resident.name,
                      style: const TextStyle(color: bone, fontSize: 18)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Panel(
              borderColor: atHome ? rift : riftDim,
              child: Column(
                children: [
                  CharacterSprite(
                    resident.id,
                    size: 150,
                    glow: atHome ? 1 : .35,
                    dimmed: !atHome,
                    calm: true,
                  ),
                  const SizedBox(height: 12),
                  Text(resident.name,
                      style: const TextStyle(color: bone, fontSize: 22)),
                  const SizedBox(height: 3),
                  Text('${resident.species} · ${fighter.role}',
                      style: const TextStyle(color: gold, fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(fighter.element.label,
                      style: const TextStyle(color: verdant, fontSize: 11)),
                  const SizedBox(height: 12),
                  Text(
                    resident.encounterLine,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: boneDim,
                        fontSize: 12.5,
                        height: 1.55,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Profile',
                      style: TextStyle(color: bone, fontSize: 14)),
                  const SizedBox(height: 9),
                  _fact('Status', atHome ? 'Lives at the house' : 'Not settled'),
                  _fact('Bond',
                      '${game.bondPoints(resident.id)} points · tier ${game.bondTier(resident.id)}/${game.maxBondTier}'),
                  _fact('Combat role', fighter.role),
                  _fact('Ascension', game.isAscended(resident.id)
                      ? '${ascension.title} · unlocked'
                      : '${ascension.title} · complete her route'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('Story archive',
                style: TextStyle(color: bone, fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
              'Completed stories can be replayed without changing your Bond or choices.',
              style: TextStyle(color: boneDim, fontSize: 11.5, height: 1.45),
            ),
            const SizedBox(height: 10),
            if (beats.isEmpty)
              const Callout('No route data is available for this character.')
            else
              for (final beat in beats) ...[
                _storyRow(context, beat, atHome),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  Widget _fact(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(label,
                  style: const TextStyle(color: boneDim, fontSize: 10.5)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(color: bone, fontSize: 11.5)),
            ),
          ],
        ),
      );

  Widget _storyRow(BuildContext context, Beat beat, bool atHome) {
    final completed = game.state.completedBeats.contains(beat.beatId);
    final upcoming = game.upcomingBeat(resident.id);
    final available = game.nextBeat(resident.id);
    final ready = available?.beatId == beat.beatId;

    String status;
    if (completed) {
      status = 'Remembered · ${_contextLabel(beat.triggerContext)}';
    } else if (!atHome) {
      status = 'Locked · meet and settle ${resident.name}';
    } else if (upcoming?.beatId != beat.beatId) {
      status = 'Locked · complete earlier stories';
    } else if (ready) {
      status = 'Ready · play from ${_contextLabel(beat.triggerContext)}';
    } else {
      status = 'Locked · ${game.lockReason(resident.id) ?? "not yet"}';
    }

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: completed ? rose.withValues(alpha: .65) : riftDim,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${beat.order}',
                style: TextStyle(
                    color: completed ? rose : boneDim,
                    fontSize: 16,
                    fontFamily: 'monospace')),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(beat.title,
                    style: TextStyle(
                        color: completed ? bone : boneDim, fontSize: 12.5)),
                const SizedBox(height: 3),
                Text(status,
                    style: TextStyle(
                        color: completed ? rose : boneDim,
                        fontSize: 10.5,
                        height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: SlabButton(
              completed ? 'Replay' : (ready ? 'New' : 'Locked'),
              key: Key('replay-${beat.beatId}'),
              tone: completed ? rose : boneDim,
              padding: const EdgeInsets.symmetric(vertical: 9),
              onPressed: completed
                  ? () => DialogueScreen.replay(
                        context,
                        game: game,
                        characterId: resident.id,
                        beat: beat,
                      )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  String _contextLabel(String context) => switch (context) {
        'home_visit' => 'the House',
        'post_raid' => 'a raid',
        'date' => 'a date',
        'gift' => 'a gift',
        _ => 'the story',
      };
}
