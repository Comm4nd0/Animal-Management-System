/// Common animal species presets - focused on farm animals and horses.
class Species {
  static const String horse = 'Horse';
  static const String cattle = 'Cattle';
  static const String sheep = 'Sheep';
  static const String goat = 'Goat';
  static const String pig = 'Pig';
  static const String alpaca = 'Alpaca';
  static const String donkey = 'Donkey';
  static const String poultry = 'Poultry';

  static const List<String> all = [
    horse, cattle, sheep, goat, pig, alpaca, donkey, poultry,
  ];
}

/// Common horse breeds for quick selection.
class HorseBreeds {
  static const List<String> popular = [
    'Thoroughbred',
    'Arabian',
    'Quarter Horse',
    'Warmblood',
    'Friesian',
    'Appaloosa',
    'Paint Horse',
    'Morgan',
    'Clydesdale',
    'Shire',
    'Hanoverian',
    'Andalusian',
    'Tennessee Walking Horse',
    'Standardbred',
    'Mustang',
    'Welsh Pony',
    'Shetland Pony',
    'Connemara',
    'Irish Draught',
    'Percheron',
  ];
}

/// Common cattle breeds for quick selection.
class CattleBreeds {
  static const List<String> popular = [
    'Angus',
    'Hereford',
    'Charolais',
    'Simmental',
    'Limousin',
    'Brahman',
    'Holstein',
    'Jersey',
    'Shorthorn',
    'Highland',
    'Dexter',
    'Wagyu',
    'Galloway',
    'Red Poll',
    'Longhorn',
    'Belgian Blue',
    'Piedmontese',
    'Salers',
    'Murray Grey',
    'Ayrshire',
  ];
}

/// Common sheep breeds for quick selection.
class SheepBreeds {
  static const List<String> popular = [
    'Suffolk',
    'Merino',
    'Dorper',
    'Texel',
    'Romney',
    'Hampshire',
    'Dorset',
    'Corriedale',
    'Border Leicester',
    'Jacob',
    'Cheviot',
    'Shropshire',
    'Southdown',
    'Katahdin',
    'Rambouillet',
  ];
}

/// Common goat breeds for quick selection.
class GoatBreeds {
  static const List<String> popular = [
    'Boer',
    'Nubian',
    'Alpine',
    'Saanen',
    'Toggenburg',
    'LaMancha',
    'Oberhasli',
    'Nigerian Dwarf',
    'Kiko',
    'Pygmy',
    'Angora',
    'Cashmere',
    'Spanish',
  ];
}

/// Common pig breeds for quick selection.
class PigBreeds {
  static const List<String> popular = [
    'Large White',
    'Landrace',
    'Duroc',
    'Hampshire',
    'Berkshire',
    'Pietrain',
    'Tamworth',
    'Saddleback',
    'Mangalica',
    'Gloucestershire Old Spots',
    'Oxford Sandy and Black',
    'Large Black',
    'Kunekune',
  ];
}

/// Returns breed suggestions for a given species.
List<String> breedsForSpecies(String species) {
  switch (species) {
    case Species.horse:
      return HorseBreeds.popular;
    case Species.cattle:
      return CattleBreeds.popular;
    case Species.sheep:
      return SheepBreeds.popular;
    case Species.goat:
      return GoatBreeds.popular;
    case Species.pig:
      return PigBreeds.popular;
    default:
      return [];
  }
}

/// Average gestation periods in days by species.
class GestationPeriods {
  static const Map<String, int> days = {
    'Horse': 340,
    'Cattle': 283,
    'Sheep': 152,
    'Goat': 150,
    'Pig': 114,
    'Alpaca': 345,
    'Donkey': 365,
    'Poultry': 21,
  };

  static int? forSpecies(String species) => days[species];
}

/// Recommended breeding age ranges in years.
class BreedingAgeRanges {
  static const Map<String, List<double>> sire = {
    'Horse': [3.0, 20.0],
    'Cattle': [1.5, 12.0],
    'Sheep': [1.0, 8.0],
    'Goat': [1.0, 8.0],
    'Pig': [0.8, 5.0],
    'Alpaca': [2.5, 15.0],
    'Donkey': [3.0, 20.0],
  };

  static const Map<String, List<double>> dam = {
    'Horse': [4.0, 18.0],
    'Cattle': [2.0, 10.0],
    'Sheep': [1.5, 7.0],
    'Goat': [1.5, 7.0],
    'Pig': [0.8, 5.0],
    'Alpaca': [2.0, 14.0],
    'Donkey': [3.0, 18.0],
  };
}

/// Service tier definitions matching the backend.
enum ServiceTier {
  starter,
  standard,
  professional,
  enterprise,
}

class ServiceTierInfo {
  final ServiceTier tier;
  final String label;
  final String description;
  final int? maxAnimals; // null = unlimited
  final bool allowsMultiBreed;

  const ServiceTierInfo({
    required this.tier,
    required this.label,
    required this.description,
    required this.maxAnimals,
    required this.allowsMultiBreed,
  });

  bool get isUnlimited => maxAnimals == null;
}

const List<ServiceTierInfo> serviceTiers = [
  ServiceTierInfo(
    tier: ServiceTier.starter,
    label: 'Starter',
    description: 'Up to 10 animals, single breed',
    maxAnimals: 10,
    allowsMultiBreed: false,
  ),
  ServiceTierInfo(
    tier: ServiceTier.standard,
    label: 'Standard',
    description: 'Up to 50 animals, single breed',
    maxAnimals: 50,
    allowsMultiBreed: false,
  ),
  ServiceTierInfo(
    tier: ServiceTier.professional,
    label: 'Professional',
    description: 'Up to 200 animals, single breed',
    maxAnimals: 200,
    allowsMultiBreed: false,
  ),
  ServiceTierInfo(
    tier: ServiceTier.enterprise,
    label: 'Enterprise',
    description: 'Unlimited animals, multiple species and breeds',
    maxAnimals: null,
    allowsMultiBreed: true,
  ),
];

ServiceTierInfo getTierInfo(ServiceTier tier) {
  return serviceTiers.firstWhere((t) => t.tier == tier);
}
