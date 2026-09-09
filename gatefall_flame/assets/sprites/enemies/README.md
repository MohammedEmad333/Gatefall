# Enemy battle sprites

Drop a creature's rendered sprite here and the fight shows it in place of the
painted `CreatureView` — no code change. Missing or broken art falls back to
the painter.

## Naming

`assets/sprites/enemies/<beastform>.png`, where `<beastform>` is a value of the
`Beastform` enum (`lib/art/gate_art.dart`):

| form         | role                          |
|--------------|-------------------------------|
| `stalker`    | wave creature                 |
| `hound`      | wave creature                 |
| `shade`      | wave creature                 |
| `husk`       | wave creature                 |
| `thornbound` | wave creature                 |
| `guardian`   | gate boss                     |

Example: `assets/sprites/enemies/guardian.png`.

The wave form on screen is chosen by `beastformFor(waveIndex:, boss:)`, keyed
off the same wave index the simulation uses — so the sprite you name is exactly
the creature being fought.

## Export guidance

- **Transparent PNG**, roughly square. The sprite is drawn over the turning
  rift, scaled to ~138 px (wave) or ~176 px (boss).
- A hit tints the sprite's own pixels (not its bounding box) and death fades +
  drops it, approximating the painter's flash and collapse.

No pubspec edit is needed: `assets/sprites/enemies/` is already declared.
