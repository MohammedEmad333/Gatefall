/// Step-3 combat constants: party of 4 with front/back rows and elements.
///
/// These numbers are simulation-tuned, not guessed. At these values every
/// composition clears (96-100%) but they trade speed against safety —
/// fast-and-fragile finishes around 300s, safe-with-a-healer around 340s.
///
/// Five of these are load-bearing. Changing them casually will break the
/// design, so the reasoning is recorded here:
///
///  * [bossEnrage] — without a damage ramp, sustain-vs-incoming is a hard
///    threshold: below it you cannot lose, above it you cannot win, and the
///    flip happens within a few points of boss damage. The ramp turns that
///    cliff into a race.
///  * Elements (step 3) sit directly on that cliff: a single disadvantaged
///    character costs the party ~30% of one damage source, and at the old
///    enrage rate (0.25) that alone crashed a viable comp's win rate to
///    ~15-23% — a wall, not "slower," which docs/combat-spec.md §3
///    explicitly rules out. Lowering enrage to 0.18 buys back the margin:
///    the same disadvantaged comp clears ~97% of the time but still takes
///    noticeably longer (~302s neutral vs ~342s disadvantaged), while every
///    step-2 composition still clears 100% of the time at full element
///    neutrality. Re-check this whenever ability power, HP, or the
///    advantage/disadvantage multipliers change.
///  * Faelen's Guard is a TAUNT (see Roster). With row-weighted targeting,
///    damage spreads across the party, so a self-only shield sustains
///    nobody — every no-healer composition sat at 0% until Guard began
///    pulling damage onto her.
///  * [waveRecovery] / [reviveAtWave] — these stop a death spiral. Without
///    them, one early death drops party damage, which lengthens the fight,
///    which causes more deaths. They keep a poor formation *slower* rather
///    than unwinnable, which is what the no-fail-state design promises.
///  * A party of fewer than 4 loses ~100% of the time. That's intended as a
///    visible choice, never the default.
class CombatConfig {
  static const int waves = 5;
  static const double tickSeconds = 0.1;
  static const int partyMax = 4;

  // Wave enemies
  static const double waveEnemyHp = 2800;
  static const double waveEnemyHpGrowth = 800; // per wave index
  static const double enemyDps = 24;
  static const double enemyDpsGrowth = 3.0;

  // Boss
  static const double bossHp = 16000;
  static const double bossDps = 30;
  static const double bossEnrage = 0.18; // dps added per second of boss fight

  // Rows
  static const double frontAggroWeight = 3.0; // front is 3x as likely targeted
  static const double backDamageTaken = 0.5; // back takes half damage
  static const double backMeleePenalty = 0.6; // melee from back is weaker

  // Between-wave relief
  static const double waveRecovery = 0.35; // % max HP restored
  static const double reviveAtWave = 0.40; // downed allies return at this %

  // Rewards
  static const int bossMana = 250;
  static const int waveManaBase = 30;
  static const int waveManaGrowth = 6;

  // Crit
  static const double allyCritChance = 0.15;
  static const double allyCritMult = 1.9;
  static const double abilityCritChance = 0.20;
  static const double abilityCritMult = 1.8;

  // Speed
  static const List<int> speedOptions = [1, 2, 4];

  /// 2x speed is unlocked by clearing the gate once — a reward, not a default.
  static const int clearsToUnlockDoubleSpeed = 1;

  /// 4x follows at ten clears. Not in the original locked decisions (which
  /// name 2x only), but an idle game whose raids run 5-10 minutes needs a
  /// second speed step once the player has cleared the same gate a dozen
  /// times. Purely a presentation rate — the simulation still runs at
  /// [tickSeconds], so balance is untouched.
  static const int clearsToUnlockFastSpeed = 10;

  // Bond earned per clear, per deployed companion. Scales with gate tier:
  // fighting something worse together is worth more than farming the
  // easiest gate on the board (docs/combat-spec.md §5, bond as the fourth
  // and softest progression track).
  static const int bondPerClearBase = 10;
  static const int bondPerClearPerTier = 5;

  // Offline accrual (docs/combat-spec.md §7). "Cleared gates yield ~50%
  // Mana, capped 8-12h. New gates/bosses require you present." Modelled as
  // a slow drip of already-solved clears rather than a share of the active
  // rate: active play at 2x earns several times this per hour, so coming
  // back is a head start and never a substitute for playing.
  static const double offlineClearsPerHour = 4;
  static const double offlineManaRate = 0.5;
  static const int offlineCapHours = 10;
}
