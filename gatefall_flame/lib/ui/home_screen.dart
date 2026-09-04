import 'package:flutter/material.dart';
import 'package:gatefall_dialogue_engine/engine/evaluator.dart';
import 'package:gatefall_dialogue_engine/models/route.dart';

import '../art/character_art.dart';
import '../art/effects.dart';
import '../audio/sfx.dart';
import '../data/ascension.dart';
import '../data/barks.dart';
import '../data/gifts.dart';
import '../data/house.dart';
import '../data/story.dart';
import '../state/game_controller.dart';
import 'dialogue_screen.dart';
import 'ending_screen.dart';
import 'start_scene.dart';
import 'theme.dart';

/// The house — the Gold half of the game, and the only place a
/// `home_visit`, `gift` or `date` beat can fire.
///
/// Version 3: everyone who lives here now has a face on their panel, a
/// scene that is ready to play glows instead of merely being gold, and the
/// two sound switches live at the bottom next to "start over" — the one
/// place in the game that is already about settings rather than about the
/// house.
class HomeScreen extends StatefulWidget {
  final GameController game;
  const HomeScreen({super.key, required this.game});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameController get game => widget.game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcomeBack());
  }

  void _showWelcomeBack() {
    final msg = game.welcomeBackMessage;
    if (msg == null || !mounted) return;
    game.welcomeBackMessage = null;
    _tell('While you were out', msg);
  }

  Future<void> _tell(String title, String body, {Sfx? sound}) {
    if (sound != null) Audio.instance.play(sound);
    return _dialog(title, body);
  }

  Future<void> _dialog(String title, String body) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: night2,
          shape: const RoundedRectangleBorder(
              side: BorderSide(color: riftDim)),
          title: Text(title, style: const TextStyle(color: bone, fontSize: 16)),
          content: Text(body,
              style: const TextStyle(color: boneDim, fontSize: 13.5, height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: verdant)),
            ),
          ],
        ),
      );

  Future<void> _play(String characterId, Beat beat) async {
    await DialogueScreen.play(context,
        game: game, characterId: characterId, beat: beat);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pending = game.pendingStoryBeats;
    final arrivals = game.encounteredNotSettled;

    return ScreenBody(
      children: [
        _actHeader(),
        const SizedBox(height: 12),
        if (pending.isNotEmpty) ...[
          for (final p in pending) ...[
            _storyCard(p.characterId, p.beat),
            const SizedBox(height: 10),
          ],
        ],
        if (game.finaleAvailable) ...[
          _finaleCard(),
          const SizedBox(height: 12),
        ] else if (game.act >= Acts.maxAct && game.gateAnswer == null) ...[
          _gatesDecisionCard(),
          const SizedBox(height: 12),
        ],
        _incomePanel(),
        const SizedBox(height: 12),
        for (final id in House.residents
            .map((r) => r.id)
            .where(game.settled.contains)) ...[
          _residentPanel(id),
          const SizedBox(height: 12),
        ],
        if (arrivals.isNotEmpty) ...[
          _arrivalsPanel(arrivals),
          const SizedBox(height: 12),
        ],
        _soundPanel(),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_readOpening(), _startOver()],
        ),
      ],
    );
  }

  // ---------------- header ----------------

  Widget _actHeader() {
    final req = game.nextActRequirement;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(Acts.title[game.act] ?? 'Gatefall',
              trailing: CurrencyChip('${game.gold}', 'gold', gold)),
          const SizedBox(height: 5),
          Text(Acts.blurb[game.act] ?? '',
              style: const TextStyle(
                  color: boneDim,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.5)),
          if (req != null) ...[
            const SizedBox(height: 9),
            Callout(req, tone: boneDim),
          ],
        ],
      ),
    );
  }

  // ---------------- story ----------------

  Widget _storyCard(String characterId, Beat beat) => Beacon(
        color: gold,
        child: InkWell(
          onTap: () {
            Audio.instance.play(Sfx.page);
            _play(characterId, beat);
          },
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              border: Border.all(color: gold),
              color: gold.withValues(alpha: .07),
            ),
            child: Row(
              children: [
                CharacterPortrait(characterId, size: 46, glow: .9),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Something is happening',
                          style: TextStyle(
                              color: gold.withValues(alpha: .85),
                              fontSize: 10.5,
                              letterSpacing: 1.3)),
                      const SizedBox(height: 5),
                      Text('${House.byId(characterId).name} — "${beat.title}"',
                          style: const TextStyle(color: bone, fontSize: 14.5)),
                    ],
                  ),
                ),
                const Icon(Icons.play_arrow, color: gold),
              ],
            ),
          ),
        ),
      );

  Widget _gatesDecisionCard() => Panel(
        borderColor: rift,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PanelTitle('The last question',
                subtitle:
                    'Act III. The house has an answer to give about the gates, '
                    'and it is yours to give. This is decided once.'),
            const SizedBox(height: 10),
            for (final a in GateAnswer.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () async {
                    game.answerTheGates(a);
                    if (!mounted) return;
                    setState(() {});
                    await _tell(a.label, a.pitch);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      border: Border.all(color: riftDim),
                      color: night2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.label,
                            style: const TextStyle(color: bone, fontSize: 13.5)),
                        const SizedBox(height: 4),
                        Text(a.pitch,
                            style: const TextStyle(
                                color: boneDim, fontSize: 11.5, height: 1.5)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _finaleCard() => Panel(
        borderColor: rose,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelTitle('The house, after',
                subtitle:
                    'You have answered the gates: "${game.gateAnswer!.label}". '
                    'Everything anyone here became is settled. Read it when '
                    'you are ready — you can keep playing afterwards.'),
            const SizedBox(height: 10),
            SlabButton('See how it ends',
                filled: true,
                tone: rose,
                padding: const EdgeInsets.symmetric(vertical: 13),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EndingScreen(game: game)))),
          ],
        ),
      );

  // ---------------- income ----------------

  Widget _incomePanel() {
    final due = game.rentDue;
    final jobReady = game.oddJobReady;
    final left = game.oddJobRemaining;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelTitle('The books',
              subtitle:
                  'Rent from everyone with a room, and whatever odd work the '
                  'neighbourhood has. Gold builds rooms and buys gifts; it '
                  'never buys power.'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SlabButton(
                  due > 0 ? 'Collect rent · $due' : 'No rent yet',
                  tone: gold,
                  onPressed: due > 0
                      ? () {
                          final got = game.collectRent();
                          setState(() {});
                          _tell('Rent collected',
                              '+$got gold. Everyone paid, more or less on time.',
                              sound: Sfx.reward);
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SlabButton(
                  jobReady
                      ? 'Odd job · +${House.oddJobGold}'
                      : 'Odd job · ${left.inMinutes}m ${left.inSeconds % 60}s',
                  tone: verdant,
                  onPressed: jobReady
                      ? () {
                          final got = game.workOddJob();
                          setState(() {});
                          _tell('A few hours\' work',
                              '+$got gold. Somebody\'s cellar had something in '
                              'it that was not, technically, a monster.',
                              sound: Sfx.reward);
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${game.settled.length} resident${game.settled.length == 1 ? "" : "s"} · '
            '${game.settled.where(House.exists).fold<int>(0, (a, id) => a + House.byId(id).rentPerHour)} gold/hour · '
            'caps at ${House.rentCapHours}h',
            style: const TextStyle(color: boneDim, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  // ---------------- residents ----------------

  Widget _residentPanel(String id) {
    final r = House.byId(id);
    final tier = game.bondTier(id);
    final points = game.bondPoints(id);
    final available = game.nextBeat(id);
    final upcoming = game.upcomingBeat(id);
    final locked = game.lockReason(id);
    final visit = game.beatFor(id, 'home_visit');
    final date = game.beatFor(id, 'date');

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Bond lights them: tier 0 is a silhouette in the dark, a
              // finished route is somebody standing in their own colour.
              CharacterPortrait(id,
                  size: 54, glow: (.25 + tier * .18).clamp(0.0, 1.0)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: bone, fontSize: 15)),
                    Text(r.species,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: boneDim, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CurrencyChip('$tier/${game.maxBondTier}', 'bond', rose),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBar(_tierFraction(points), rose, height: 5, ghost: false),
          const SizedBox(height: 6),
          Text(
            upcoming == null
                ? '$points bond · their route is finished'
                : available != null
                    ? '$points bond · ready: "${available.title}" '
                        '(${available.triggerContext})'
                    : '$points bond · next: "${upcoming.title}" — $locked',
            style: TextStyle(
                color: available != null ? gold : boneDim, fontSize: 10.5),
          ),
          if (Ascension.exists(id)) ...[
            const SizedBox(height: 6),
            Text(
              game.isAscended(id)
                  ? 'Ascended — ${Ascension.byId(id).title}'
                  : game.awaitingAwakening(id)
                      ? 'Lives here, does not fight. Her route is the thing '
                          'that changes that.'
                      : 'Ascension waiting at the end of her route.',
              style: TextStyle(
                  color: game.isAscended(id) ? rose : boneDim, fontSize: 10.5),
            ),
          ],
          const SizedBox(height: 10),
          Text(Barks.idle(id),
              style: const TextStyle(
                  color: boneDim,
                  fontSize: 12,
                  height: 1.5,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: SlabButton(
                  visit != null ? 'Talk · new scene' : 'Talk',
                  tone: visit != null ? gold : boneDim,
                  onPressed: visit != null
                      ? () => _play(id, visit)
                      : () => _tell(r.name, Barks.idle(id)),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: SlabButton('Gift',
                    tone: verdant, onPressed: () => _giftSheet(id)),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: SlabButton(
                  date != null
                      ? 'Date · scene'
                      : 'Date · ${House.dateGoldCost}',
                  tone: rose,
                  onPressed: game.canAfford(House.dateGoldCost)
                      ? () => _takeOnDate(id, date)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// How far along the *current* tier a bond total is, for the progress bar.
  /// Thresholds come from the shared evaluator rather than a second copy —
  /// retuning pacing there must not leave this bar reading a stale scale
  /// (docs/HANDOFF.md finding #10).
  double _tierFraction(int points) {
    const thresholds = Evaluator.bondTierThresholds;
    if (points >= thresholds.last) return 1;
    var lo = 0, hi = thresholds.last;
    for (var i = 0; i < thresholds.length - 1; i++) {
      if (points >= thresholds[i] && points < thresholds[i + 1]) {
        lo = thresholds[i];
        hi = thresholds[i + 1];
        break;
      }
    }
    return (points - lo) / (hi - lo);
  }

  Future<void> _takeOnDate(String id, Beat? dateBeat) async {
    final line = game.goOnDate(id);
    if (line == null) return;
    setState(() {});
    await _tell('An evening out', line, sound: Sfx.bond);
    if (!mounted) return;
    // A date is exactly where a `date`-context beat belongs. Re-check after
    // the bond gain, since that gain may be what unlocked it.
    final beat = dateBeat ?? game.beatFor(id, 'date');
    if (beat != null) await _play(id, beat);
  }

  Future<void> _giftSheet(String id) async {
    final r = House.byId(id);
    final chosen = await showModalBottomSheet<GiftItem>(
      context: context,
      backgroundColor: night2,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * .7),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Text('Something for ${r.name}',
                  style: const TextStyle(color: bone, fontSize: 16)),
              const SizedBox(height: 4),
              const Text(
                'Nobody tells you what they like. Read them, or waste the gold.',
                style: TextStyle(
                    color: boneDim, fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 14),
              for (final item in Gifts.shop)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: game.canAfford(item.goldCost)
                        ? () => Navigator.of(context).pop(item)
                        : null,
                    child: Opacity(
                      opacity: game.canAfford(item.goldCost) ? 1 : .38,
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          border: Border.all(color: riftDim),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: const TextStyle(
                                          color: bone, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(item.flavor,
                                      style: const TextStyle(
                                          color: boneDim,
                                          fontSize: 11,
                                          height: 1.4)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            CurrencyChip('${item.goldCost}', '', gold),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (chosen == null || !mounted) return;
    final bark = game.giveGift(id, chosen);
    if (bark == null) return;
    setState(() {});
    await _tell(chosen.name, bark, sound: Sfx.gift);
    if (!mounted) return;
    final beat = game.beatFor(id, 'gift');
    if (beat != null) await _play(id, beat);
  }

  // ---------------- arrivals ----------------

  Widget _arrivalsPanel(List<Resident> arrivals) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PanelTitle('On the step',
                subtitle:
                    'A room costs Gold and is the only thing standing between '
                    'them and a place to sleep. Nobody here is missable — the '
                    'only question is when.'),
            const SizedBox(height: 10),
            for (final r in arrivals)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(border: Border.all(color: riftDim)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CharacterPortrait(r.id, size: 40, glow: .2, calm: true),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text('${r.name} · ${r.species}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: bone, fontSize: 13.5)),
                          ),
                          const SizedBox(width: 8),
                          CurrencyChip('${r.roomCost}', 'gold', gold),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(r.encounterLine,
                          style: const TextStyle(
                              color: boneDim,
                              fontSize: 11.5,
                              height: 1.45,
                              fontStyle: FontStyle.italic)),
                      if (!r.deployable) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'She does not fight. Not yet — her route is what '
                          'changes that.',
                          style: TextStyle(color: rose, fontSize: 10.5),
                        ),
                      ],
                      const SizedBox(height: 9),
                      SlabButton(
                        game.canAfford(r.roomCost)
                            ? 'Build her room · ${r.roomCost} gold'
                            : 'Need ${r.roomCost - game.gold} more gold',
                        tone: gold,
                        onPressed: game.canAfford(r.roomCost)
                            ? () async {
                                final beat = game.settleResident(r.id);
                                if (!mounted) return;
                                setState(() {});
                                if (beat != null) await _play(r.id, beat);
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  /// Version 3's one settings panel. Two switches, both saved: sound
  /// effects, and the ambient bed. Separate because they are separate
  /// annoyances — a player on a bus wants the music off and the taps left
  /// alone, and a player at a desk often wants the opposite.
  Widget _soundPanel() => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PanelTitle('Sound',
                subtitle:
                    'Everything you hear was synthesised for this game — see '
                    'tool/make_sounds.py. Both switches are saved.'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SlabButton(
                    game.sfxOn ? 'Effects · on' : 'Effects · off',
                    tone: game.sfxOn ? verdant : boneDim,
                    sound: Sfx.uiTap,
                    onPressed: () => setState(() => game.setSfxOn(!game.sfxOn)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SlabButton(
                    game.musicOn ? 'Ambience · on' : 'Ambience · off',
                    tone: game.musicOn ? rift : boneDim,
                    sound: Sfx.uiTap,
                    onPressed: () =>
                        setState(() => game.setMusicOn(!game.musicOn)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  /// The opening comic, again. Reading it costs nothing and changes
  /// nothing — it is the one thing on this screen that cannot alter a save.
  Widget _readOpening() => TextButton(
        onPressed: () => StartScene.replay(context),
        child: const Text('read the opening',
            style: TextStyle(color: boneDim, fontSize: 11)),
      );

  Widget _startOver() => TextButton(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: night2,
              shape: const RoundedRectangleBorder(
                  side: BorderSide(color: riftDim)),
              title: const Text('Start over?',
                  style: TextStyle(color: bone, fontSize: 16)),
              content: const Text(
                'Every level, every gift, every scene played. Gone. The '
                'house is empty again except for the elf on the step.',
                style: TextStyle(color: boneDim, fontSize: 13, height: 1.6),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Keep playing',
                        style: TextStyle(color: verdant))),
                TextButton(
                    onPressed: () {
                      Audio.instance.play(Sfx.defeat);
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Erase it',
                        style: TextStyle(color: blood))),
              ],
            ),
          );
          if (ok == true) {
            await game.resetGame();
            if (mounted) setState(() {});
          }
        },
        child: const Text('start over',
            style: TextStyle(color: boneDim, fontSize: 11)),
      );
}
