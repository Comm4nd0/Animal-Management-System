/// Common animal species presets.
class Species {
  static const String dog = 'Dog';
  static const String cat = 'Cat';
  static const String horse = 'Horse';
  static const String cattle = 'Cattle';
  static const String sheep = 'Sheep';
  static const String goat = 'Goat';
  static const String rabbit = 'Rabbit';
  static const String poultry = 'Poultry';

  static const List<String> all = [
    dog, cat, horse, cattle, sheep, goat, rabbit, poultry,
  ];
}

/// Common dog breeds for quick selection.
class DogBreeds {
  static const List<String> popular = [
    'Labrador Retriever',
    'German Shepherd',
    'Golden Retriever',
    'French Bulldog',
    'Bulldog',
    'Poodle',
    'Beagle',
    'Rottweiler',
    'Dachshund',
    'German Shorthaired Pointer',
    'Pembroke Welsh Corgi',
    'Australian Shepherd',
    'Yorkshire Terrier',
    'Cavalier King Charles Spaniel',
    'Doberman Pinscher',
    'Boxer',
    'Miniature Schnauzer',
    'Cane Corso',
    'Great Dane',
    'Shih Tzu',
    'Siberian Husky',
    'Bernese Mountain Dog',
    'Pomeranian',
    'Border Collie',
    'Cocker Spaniel',
  ];
}

/// Average gestation periods in days by species.
class GestationPeriods {
  static const Map<String, int> days = {
    'Dog': 63,
    'Cat': 65,
    'Horse': 340,
    'Cattle': 283,
    'Sheep': 152,
    'Goat': 150,
    'Rabbit': 31,
    'Poultry': 21,
  };

  static int? forSpecies(String species) => days[species];
}

/// Recommended breeding age ranges in years.
class BreedingAgeRanges {
  static const Map<String, List<double>> sire = {
    'Dog': [1.5, 10.0],
    'Cat': [1.0, 10.0],
    'Horse': [3.0, 20.0],
    'Cattle': [1.5, 12.0],
  };

  static const Map<String, List<double>> dam = {
    'Dog': [2.0, 7.0],
    'Cat': [1.5, 8.0],
    'Horse': [4.0, 18.0],
    'Cattle': [2.0, 10.0],
  };
}
