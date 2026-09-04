/// The house — the Gold half of the game (docs/HANDOFF.md, Economy:
/// "Gold — from rent, drops, odd jobs. Powers house/room upgrades,
/// furniture, gifts, dates.").
///
/// This is also where acquisition lives (docs/story-bible.md, three layers:
/// **Encounter** -> **Settle** -> **Unlock**). A resident is *encountered*
/// once the house is big enough to be worth their notice, *settles* when
/// you build and pay for their room, and their route *unlocks* from their
/// Beat 0 the moment they move in. The core five are guaranteed — nothing
/// here is missable, only paced.
class Resident {
  final String id;
  final String name;
  final String species;

  /// One line of who they are before you know anything about them.
  final String encounterLine;

  /// What the room costs in Gold. Faelen's is free: she arrives bleeding on
  /// the doorstep in Act 1 and the room already exists.
  final int roomCost;

  /// Lifetime gate clears before they turn up at all. Paces arrivals
  /// against the raid loop so the house fills as the fighting escalates.
  final int clearsToEncounter;

  /// Gold per hour they contribute once settled.
  final int rentPerHour;

  /// False for Dana — she is the late wildcard who does not fight until her
  /// own route awakens her (docs/companion-routes.md, Dana). She still
  /// lives here, takes gifts, and has a full seven-beat route.
  final bool deployable;

  const Resident({
    required this.id,
    required this.name,
    required this.species,
    required this.encounterLine,
    required this.roomCost,
    required this.clearsToEncounter,
    required this.rentPerHour,
    this.deployable = true,
  });
}

class House {
  /// Ordered by arrival. Faelen first because her Beat 0 *is* the opening.
  static const List<Resident> residents = [
    Resident(
      id: 'faelen',
      name: 'Faelen',
      species: 'Elf, ex-Warden',
      encounterLine:
          'Outnumbered over a stranger she has never met, refusing to fall.',
      roomCost: 0,
      clearsToEncounter: 0,
      rentPerHour: 20,
    ),
    Resident(
      id: 'kess',
      name: 'Kess',
      species: 'Fox beastkin',
      encounterLine:
          'A gate-clip streamer with a following and nowhere to sleep.',
      roomCost: 260,
      clearsToEncounter: 1,
      rentPerHour: 34,
    ),
    Resident(
      id: 'momo',
      name: 'Momo',
      species: 'Gloamkin',
      encounterLine:
          'Living rough and moving constantly, because gates follow her.',
      roomCost: 540,
      clearsToEncounter: 3,
      rentPerHour: 18,
    ),
    Resident(
      id: 'thora',
      name: 'Thora',
      species: 'Orc-kin',
      encounterLine:
          'She adopts the house roughly nine minutes before anyone agrees.',
      roomCost: 900,
      clearsToEncounter: 5,
      rentPerHour: 26,
    ),
    Resident(
      id: 'dana',
      name: 'Dana',
      species: 'Human caseworker',
      encounterLine:
          'Assigned to audit an unregistered building full of Gatekin.',
      roomCost: 1400,
      clearsToEncounter: 8,
      rentPerHour: 40,
      deployable: false,
    ),
  ];

  static Resident byId(String id) => residents.firstWhere((r) => r.id == id);

  static bool exists(String id) => residents.any((r) => r.id == id);

  /// Rent accrues in real time and is capped, same shape as offline Mana
  /// (docs/combat-spec.md §7) — an idle trickle you come back to, never a
  /// reason to set an alarm.
  static const int rentCapHours = 12;

  /// An odd job: instant Gold with a real cooldown, so a player who is
  /// gold-starved early (one resident, no rent worth collecting) always has
  /// a way forward that isn't waiting.
  static const int oddJobGold = 45;
  static const Duration oddJobCooldown = Duration(minutes: 2);

  /// A date costs Gold and pays Bond directly, on top of unlocking any
  /// `date`-context beat that happens to be available.
  static const int dateGoldCost = 120;
  static const int dateBondReward = 25;
}
