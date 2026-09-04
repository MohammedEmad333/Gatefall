import 'package:flutter/material.dart';
import 'package:gatefall_dialogue_engine/engine/dialogue_engine.dart';
import 'package:gatefall_dialogue_engine/models/dialogue_node.dart';
import 'package:gatefall_dialogue_engine/models/route.dart';
import 'package:gatefall_dialogue_engine/models/scene.dart';

import '../data/companion_routes.dart';
import '../data/house.dart';
import '../state/game_controller.dart';
import 'theme.dart';

/// The scene renderer — the piece docs/HANDOFF.md called the real gap left
/// by step 6: "there's nowhere in the app to trigger a home_visit/gift/date
/// beat […] Even a bare-bones screen that walks a DialogueEngine through one
/// beat's nodes would close the loop."
///
/// It is a thin shell over the engine on purpose. Every branch, every
/// conditional insert, every flag write and bond delta is the engine's
/// decision applied to the controller's own [GameState]; this widget only
/// decides what a line looks like and when the player taps.
class DialogueScreen extends StatefulWidget {
  final GameController game;
  final String characterId;
  final Beat beat;

  const DialogueScreen({
    super.key,
    required this.game,
    required this.characterId,
    required this.beat,
  });

  /// Loads the beat's scene and pushes the screen. Returns once the scene
  /// ends and the beat has been marked complete.
  static Future<void> play(
    BuildContext context, {
    required GameController game,
    required String characterId,
    required Beat beat,
  }) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DialogueScreen(
        game: game,
        characterId: characterId,
        beat: beat,
      ),
      fullscreenDialog: true,
    ));
  }

  @override
  State<DialogueScreen> createState() => _DialogueScreenState();
}

class _DialogueScreenState extends State<DialogueScreen> {
  DialogueEngine? _engine;
  String? _error;

  /// Lines already played, so a scene reads as a transcript rather than one
  /// line at a time with no memory of what was just said.
  final List<_Line> _history = [];

  @override
  void initState() {
    super.initState();
    // Scenes are preloaded at boot, so the common path is synchronous and
    // the first line is on screen in the same frame the screen opens.
    final cached = CompanionRoutes.cachedScene(widget.beat.sceneRef);
    if (cached != null) {
      _start(cached);
    } else {
      _load();
    }
  }

  void _start(Scene scene) {
    final engine = DialogueEngine(
      scene: scene,
      state: widget.game.state,
      characterId: widget.characterId,
    );
    _engine = engine;
    _pushCurrent(engine);
  }

  Future<void> _load() async {
    try {
      final Scene scene =
          await CompanionRoutes.loadScene(widget.beat.sceneRef);
      if (!mounted) return;
      setState(() => _start(scene));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  void _pushCurrent(DialogueEngine engine) {
    final node = engine.currentNode;
    if (node.text != null && node.text!.isNotEmpty) {
      _history.add(_Line(speaker: node.speaker, text: node.text!));
    }
  }

  String _speakerName(String? speakerId) {
    if (speakerId == null) return '';
    if (speakerId == 'player') return 'You';
    if (House.exists(speakerId)) return House.byId(speakerId).name;
    return speakerId;
  }

  void _advance() {
    final engine = _engine;
    if (engine == null) return;
    if (engine.isEnd) {
      _finish();
      return;
    }
    if (engine.currentNode.isBranch) return;
    setState(() {
      engine.advance();
      _pushCurrent(engine);
      if (engine.isEnd && engine.currentNode.text == null) {
        // A terminal node with no line of its own — nothing left to read.
      }
    });
  }

  void _choose(Choice choice) {
    final engine = _engine;
    if (engine == null) return;
    setState(() {
      _history.add(_Line(speaker: null, text: choice.text, isChoice: true));
      engine.choose(choice.choiceId);
      _pushCurrent(engine);
    });
  }

  void _finish() {
    widget.game.completeBeat(widget.beat.beatId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    final choices = engine?.currentNode.isBranch == true
        ? engine!.visibleChoices()
        : const <Choice>[];
    final atEnd = engine != null && engine.isEnd;

    return Scaffold(
      backgroundColor: night,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('This scene could not be loaded.\n$_error',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: blood, fontSize: 13, height: 1.6)),
                          ),
                        )
                      : engine == null
                          ? const Center(
                              child: Text('…',
                                  style: TextStyle(color: boneDim, fontSize: 22)))
                          : GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: choices.isEmpty ? _advance : null,
                              child: _transcript(),
                            ),
                ),
                if (choices.isNotEmpty)
                  _choicePanel(choices)
                else if (engine != null)
                  _continueBar(atEnd),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.beat.title,
                      style: const TextStyle(color: bone, fontSize: 17)),
                  const SizedBox(height: 2),
                  Text(
                    '${_speakerName(widget.characterId)} · beat '
                    '${widget.beat.order} · ${widget.beat.triggerContext}',
                    style: const TextStyle(color: boneDim, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _transcript() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        itemCount: _history.length,
        itemBuilder: (_, i) {
          final line = _history[i];
          final isLatest = i == _history.length - 1;
          if (line.isChoice) {
            return Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Text('› ${line.text}',
                  style: const TextStyle(
                      color: rose, fontSize: 13.5, height: 1.55)),
            );
          }
          final speaker = _speakerName(line.speaker);
          final isNarration = line.text.startsWith('(');
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (speaker.isNotEmpty && !isNarration) ...[
                  Text(speaker.toUpperCase(),
                      style: TextStyle(
                          color: line.speaker == 'player' ? verdant : gold,
                          fontSize: 10.5,
                          letterSpacing: 1.4)),
                  const SizedBox(height: 4),
                ],
                Opacity(
                  opacity: isLatest ? 1 : .55,
                  child: Text(
                    line.text,
                    style: TextStyle(
                      color: isNarration ? boneDim : bone,
                      fontSize: isNarration ? 13 : 15,
                      height: 1.65,
                      fontStyle:
                          isNarration ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

  Widget _choicePanel(List<Choice> choices) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: riftDim)),
          color: night2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('What do you say?',
                  style: TextStyle(
                      color: boneDim,
                      fontSize: 11,
                      fontStyle: FontStyle.italic)),
            ),
            for (final c in choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: InkWell(
                  onTap: () => _choose(c),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: rose.withValues(alpha: .55)),
                      color: rose.withValues(alpha: .06),
                    ),
                    child: Text(c.text,
                        style: const TextStyle(
                            color: bone, fontSize: 13.5, height: 1.45)),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _continueBar(bool atEnd) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: riftDim)),
          color: night2,
        ),
        child: SlabButton(
          atEnd ? 'End of scene' : 'Continue',
          filled: true,
          tone: atEnd ? verdant : rift,
          onPressed: atEnd ? _finish : _advance,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
}

class _Line {
  final String? speaker;
  final String text;
  final bool isChoice;

  _Line({required this.speaker, required this.text, this.isChoice = false});
}
