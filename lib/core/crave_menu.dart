import '../models/models.dart';

/// Crave café's menu with its prices in pesos, read off its posters (2026-11-04), as rewards staff add in one tap.
/// Points follow the price ([craveMenuPoints]); stock is unlimited. Afterwards each is an ordinary reward staff can
/// edit or delete. Drinks go under Coffee (shown to customers as "Drinks"). Photos come from the name.
const _menu = <(String id, String title, String description, String category, int peso)>[
  ('mocha', 'Mocha', 'Iced coffee', 'Coffee', 94),
  ('caramel_drip', 'Caramel Drip', 'Iced coffee', 'Coffee', 99),
  ('classic', 'Classic', 'Iced coffee', 'Coffee', 66),
  ('salted_classic', 'Salted Classic', 'Iced coffee', 'Coffee', 74),
  ('sweet_and_salty', 'Sweet & Salty', 'Iced coffee', 'Coffee', 94),
  ('sweet_classic', 'Sweet Classic', 'Iced coffee', 'Coffee', 94),
  ('orange_americano', 'Orange Americano', 'Iced coffee', 'Coffee', 89),
  ('cookies_and_brew', 'Cookies & Brew', 'Iced coffee', 'Coffee', 98),
  ('sweet_oat', 'Sweet Oat', 'Iced coffee', 'Coffee', 129),
  ('sunrise', 'Sunrise', 'Tropical Series', 'Coffee', 63),
  ('signature_blend', 'Signature Blend', 'Tropical Series', 'Coffee', 74),
  ('strawberry_dream', 'Strawberry Dream', 'Iced, coffee-free', 'Coffee', 79),
  ('mango_mirage', 'Mango Mirage', 'Iced, coffee-free', 'Coffee', 79),
  ('blueberry_haze', 'Blueberry Haze', 'Iced, coffee-free', 'Coffee', 84),
  ('strawberry_matcha', 'Strawberry Matcha', 'Iced, coffee-free', 'Coffee', 94),
  ('matcha_cookies', 'Matcha Cookies', 'Iced, coffee-free', 'Coffee', 94),
  ('matcha_dream', 'Matcha Dream', 'Iced, coffee-free', 'Coffee', 79),
  ('dark_choco_dream', 'Dark Choco Dream', 'Iced, coffee-free', 'Coffee', 79),
  ('chocnut_cloud', 'Chocnut Cloud', 'Iced, coffee-free', 'Coffee', 94),
  ('choco_berry', 'Choco Berry', 'Iced, coffee-free', 'Coffee', 89),
  ('tocino', 'Sweet Glazed Tocino', 'Rice bowl with egg, sweet and savory', 'Food', 99),
  ('tapa', 'Smokey Garlic Tapa', 'Rice bowl with egg, smokey and savory', 'Food', 109),
  ('buzz_n_burn', "Buzz n' Burn", 'Crunch Bowl', 'Food', 99),
  ('smokey_classic', 'Smokey Classic', 'Crunch Bowl', 'Food', 89),
  ('spicy_mango', 'Spicy Mango', 'Crunch Bowl', 'Food', 89),
  ('og_burger', 'The OG Burger', 'Quarter pounder beef patty, lettuce, OG sauce, cheese, tomato, cucumber and onion',
      'Food', 129),
  ('pizza_burger', 'Pizza Burger', 'Quarter pounder beef patty, cheese, ham, sweet-style pizza sauce and pineapple',
      'Food', 129),
  ('samgy_burger', 'Samgy Burger', 'Quarter pounder beef patty, cheese, lettuce, samgy sauce, kimchi and cucumber',
      'Food', 134),
];

/// Points for a menu price in pesos, the owner's tiers (2026-11-04): under 60 → 100, under 70 → 120, under 80 → 125,
/// under 90 → 130, under 100 → 135; from 100 the owner gave 140-160, split here as under 110 → 140, under 130 → 150,
/// else 160.
int craveMenuPoints(int peso) => switch (peso) {
      < 60 => 100,
      < 70 => 120,
      < 80 => 125,
      < 90 => 130,
      < 100 => 135,
      < 110 => 140,
      < 130 => 150,
      _ => 160,
    };

/// The menu items not yet among [existing] rewards. An item counts as there when a reward has its name (any case or
/// spacing) or its fixed id, so one staff renamed is not added again. Fixed ids also make a double tap write the
/// same documents twice, never copies.
List<Reward> craveMenuToAdd(List<Reward> existing) {
  String key(String title) => title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  final names = {for (final r in existing) key(r.title)};
  final ids = {for (final r in existing) r.id};
  return [
    for (final (id, title, description, category, peso) in _menu)
      if (!names.contains(key(title)) && !ids.contains('crave_$id'))
        Reward(id: 'crave_$id', title: title, description: description, pointsCost: craveMenuPoints(peso),
            category: category),
  ];
}

/// Menu items already added (by fixed id) whose points differ from their price tier: id → the tier's points.
Map<String, int> craveMenuRepricing(List<Reward> existing) {
  final points = {for (final (id, _, _, _, peso) in _menu) 'crave_$id': craveMenuPoints(peso)};
  return {
    for (final r in existing)
      if (points[r.id] case final p? when p != r.pointsCost) r.id!: p,
  };
}
