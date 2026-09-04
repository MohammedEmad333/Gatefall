import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../runtime_stub.dart' if (dart.library.io) '../runtime_io.dart';

/// Every sound the game can make. The files behind these are synthesised by
/// `tool/make_sounds.py` and committed under `assets/audio/` — see that
/// script for how each one is built and why it sounds the way it does.
enum Sfx {
  uiTap('ui_tap', 0.5),
  uiSelect('ui_select', 0.7),
  uiBack('ui_back', 0.6),
  page('page', 0.7),
  gateOpen('gate_open', 0.85),
  hit('hit', 0.45),
  crit('crit', 0.7),
  ability('ability', 0.7),
  ultimate('ultimate', 0.9),
  heal('heal', 0.7),
  enemyDown('enemy_down', 0.8),
  bossStir('boss_stir', 0.85),
  partyDown('party_down', 0.8),
  victory('victory', 0.9),
  defeat('defeat', 0.8),
  reward('reward', 0.7),
  bond('bond', 0.75),
  ascend('ascend', 0.95),
  gift('gift', 0.7),
  blip('blip', 0.35);

  final String file;

  /// Baked-in mix level, so callers ask for a *sound* and never for a
  /// number. One place to fix "the crit is too loud".
  final double gain;

  const Sfx(this.file, this.gain);

  String get asset => 'audio/$file.wav';
}

/// The two ambient beds. One per half of the game, which is the same split
/// the whole design runs on.
enum Ambience {
  house('amb_house', 0.30),
  gate('amb_gate', 0.34);

  final String file;
  final double gain;

  const Ambience(this.file, this.gain);

  String get asset => 'audio/$file.wav';
}

/// The sound bus.
///
/// Deliberately fire-and-forget: nothing in the game should ever await a
/// sound, and a platform with no audio at all (a test, a locked-down
/// browser, a CI emulator) must degrade to silence rather than to an
/// exception in the middle of a fight. Every call is wrapped, and the first
/// hard failure switches the bus off for the session instead of throwing
/// once per frame.
class Audio {
  Audio._();

  static final Audio instance = Audio._();

  /// Player settings, persisted by GameController.
  bool sfxOn = true;
  bool musicOn = true;

  /// Set once if the platform turns out to have no working audio.
  bool _broken = false;

  /// Under `flutter test` there is no plugin to talk to, so the bus is a
  /// no-op and tests can still assert on [lastPlayed].
  bool get _live => !runningUnderTest && !_broken;

  /// Round-robin players. Enough voices that a crit landing on top of a hit
  /// on top of an ultimate does not cut anything off, few enough that we
  /// are not holding a dozen decoders open.
  static const int voices = 6;
  final List<AudioPlayer> _pool = [];
  int _next = 0;

  AudioPlayer? _musicPlayer;
  Ambience? _track;

  /// The last sound asked for, and every sound asked for this session.
  /// Tests read these; nothing else should.
  Sfx? lastPlayed;
  final List<Sfx> log = [];

  /// Rate limits, by sound. Combat can ask for `hit` sixty times a second
  /// at 4× speed, and dialogue asks for `blip` once per revealed character;
  /// both would turn to mush without a floor on the gap between them.
  static const Map<Sfx, int> _minGapMs = {
    Sfx.hit: 70,
    Sfx.crit: 90,
    Sfx.blip: 34,
    Sfx.ability: 60,
    Sfx.uiTap: 40,
  };
  final Map<Sfx, DateTime> _lastAt = {};

  /// True once a user gesture has reached us. Browsers refuse to start
  /// audio before one, so the ambience waits for it rather than failing
  /// silently on load and never trying again.
  bool _gestured = false;

  /// Play a sound. Never throws, never awaits, never blocks a frame.
  void play(Sfx sound, {double gain = 1.0}) {
    lastPlayed = sound;
    log.add(sound);
    if (log.length > 64) log.removeAt(0);
    if (!sfxOn || !_live) return;

    final gap = _minGapMs[sound];
    if (gap != null) {
      final last = _lastAt[sound];
      final now = DateTime.now();
      if (last != null && now.difference(last).inMilliseconds < gap) return;
      _lastAt[sound] = now;
    }

    _fire(sound, gain);
  }

  Future<void> _fire(Sfx sound, double gain) async {
    try {
      final player = await _voice();
      await player.stop();
      await player.play(
        AssetSource(sound.asset),
        volume: (sound.gain * gain).clamp(0.0, 1.0),
      );
    } catch (e) {
      _fail('sfx ${sound.file}', e);
    }
  }

  Future<AudioPlayer> _voice() async {
    if (_pool.length < voices) {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      _pool.add(p);
      return p;
    }
    _next = (_next + 1) % _pool.length;
    return _pool[_next];
  }

  /// Cross to a different ambient bed, or to silence with null. Calling it
  /// with the track already playing does nothing, so screens can say what
  /// they want to hear on every build.
  void ambience(Ambience? track) {
    if (_track == track) return;
    _track = track;
    if (!_live) return;
    _applyAmbience();
  }

  Future<void> _applyAmbience() async {
    final track = _track;
    try {
      if (track == null || !musicOn || !_gestured) {
        await _musicPlayer?.stop();
        return;
      }
      final player = _musicPlayer ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.stop();
      await player.play(AssetSource(track.asset), volume: track.gain);
    } catch (e) {
      _fail('ambience', e);
    }
  }

  /// Called from the first tap anywhere in the app. Web will not start
  /// audio before a gesture; this is where the bed actually begins.
  void noteGesture() {
    if (_gestured) return;
    _gestured = true;
    if (_live && _track != null) _applyAmbience();
  }

  void setSfxOn(bool on) {
    sfxOn = on;
    if (on) play(Sfx.uiSelect);
  }

  void setMusicOn(bool on) {
    musicOn = on;
    if (_live) _applyAmbience();
  }

  void _fail(String what, Object e) {
    // One report, then silence for the session. An audio problem is never
    // worth a wall of console noise or a broken frame.
    if (_broken) return;
    _broken = true;
    debugPrint('Gatefall: audio disabled after $what failed ($e)');
  }

  /// Test seam: lets a widget test assert on what the game tried to play
  /// without a plugin anywhere in sight.
  @visibleForTesting
  void resetLog() {
    log.clear();
    lastPlayed = null;
  }
}
