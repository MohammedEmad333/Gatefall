/// The gift shop — the Gold half of the Bond economy.
///
/// Item ids here are the *same strings* the route JSON already lists under
/// `gift_preferences` (see docs/dialogue-data-model.md), so a character's
/// reaction is looked up through the shared
/// [CharacterRoute.reactionTierFor] rather than duplicated here. Adding a
/// character's loved item to a route file is enough — nothing in this file
/// needs to know who likes what.
///
/// The shop is deliberately mixed: some items two characters love, some
/// items somebody actively dislikes. Buying blind is a real (cheap)
/// mistake, and reading a character well is the skill.
class GiftItem {
  final String id;
  final String name;
  final String flavor;
  final int goldCost;

  const GiftItem({
    required this.id,
    required this.name,
    required this.flavor,
    required this.goldCost,
  });
}

/// Bond deltas per reaction tier — the exact table in
/// docs/dialogue-data-model.md §gift_reactions.
const Map<String, int> giftBondDelta = {
  'loved': 20,
  'liked': 10,
  'neutral': 2,
  'disliked': -5,
};

class Gifts {
  static const List<GiftItem> shop = [
    GiftItem(
        id: 'plain_meal',
        name: 'A plain home-cooked meal',
        flavor: 'Nothing fancy. Warm, and made for you.',
        goldCost: 30),
    GiftItem(
        id: 'street_food',
        name: 'Skewers from the night market',
        flavor: 'Too much chili. Eaten standing up.',
        goldCost: 35),
    GiftItem(
        id: 'bitter_tea',
        name: 'Bitter black tea',
        flavor: 'Strong enough to stand a spoon in.',
        goldCost: 45),
    GiftItem(
        id: 'garden_seeds',
        name: 'Seeds that might not grow here',
        flavor: 'Sold by someone who wouldn\'t say where they came from.',
        goldCost: 50),
    GiftItem(
        id: 'pressed_flowers',
        name: 'Pressed flowers, species unlisted',
        flavor: 'Flat between glass. Still faintly luminous.',
        goldCost: 55),
    GiftItem(
        id: 'flashy_trinket',
        name: 'A very fake gold chain',
        flavor: 'Loud, cheap, and completely unembarrassed about it.',
        goldCost: 60),
    GiftItem(
        id: 'whetstone',
        name: 'Whetstone and oil kit',
        flavor: 'The good grit. Worth carrying.',
        goldCost: 70),
    GiftItem(
        id: 'soft_blanket',
        name: 'Heavy wool blanket',
        flavor: 'Enough weight to feel like being held.',
        goldCost: 80),
    GiftItem(
        id: 'reading_lamp',
        name: 'A good reading lamp',
        flavor: 'Warm bulb. Doesn\'t buzz.',
        goldCost: 95),
    GiftItem(
        id: 'homeworld_spice',
        name: 'Spice tin, orc-kin trade route',
        flavor: 'The label is in a script nobody at the market could read.',
        goldCost: 110),
    GiftItem(
        id: 'cooking_knife',
        name: 'A properly weighted knife',
        flavor: 'Balanced at the bolster. Someone will notice.',
        goldCost: 120),
    GiftItem(
        id: 'rare_book',
        name: 'A water-damaged first edition',
        flavor: 'Half the margins are somebody else\'s arguing.',
        goldCost: 135),
    GiftItem(
        id: 'stream_gear',
        name: 'A secondhand ring light',
        flavor: 'One dead LED. Fixable, probably.',
        goldCost: 150),
    GiftItem(
        id: 'star_map',
        name: 'Star map of a sky that isn\'t here',
        flavor: 'Charted by someone who could still go home.',
        goldCost: 175),
    GiftItem(
        id: 'luxury_item',
        name: 'Something expensive and useless',
        flavor: 'It photographs beautifully. It does nothing.',
        goldCost: 210),
  ];

  static GiftItem byId(String id) => shop.firstWhere((g) => g.id == id);
}
