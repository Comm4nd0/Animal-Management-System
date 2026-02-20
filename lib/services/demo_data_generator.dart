import 'dart:math';
import '../models/models.dart';
import 'database_service.dart';

/// Generates ~200 demo animals directly into local SQLite when the
/// backend API is unreachable. Uses a deterministic seed so the demo
/// data is consistent across sessions.
class DemoDataGenerator {
  final DatabaseService _db;
  final Random _rng = Random(42); // deterministic

  DemoDataGenerator({DatabaseService? db}) : _db = db ?? DatabaseService();

  /// Generates all demo data: animals, health records, contacts,
  /// weight records, breeding records, litters.
  Future<void> generate() async {
    final animals = <Animal>[];

    // ── Species configs ─────────────────────────────────────────
    final speciesConfigs = [
      _SpeciesConfig(
        species: 'Horse',
        breeds: ['Thoroughbred', 'Arabian', 'Quarter Horse', 'Warmblood'],
        count: 80,
        namePatterns: _horseNames,
      ),
      _SpeciesConfig(
        species: 'Cattle',
        breeds: ['Angus', 'Hereford', 'Charolais', 'Holstein'],
        count: 70,
        namePatterns: _cattleNames,
      ),
      _SpeciesConfig(
        species: 'Sheep',
        breeds: ['Suffolk', 'Merino', 'Dorper', 'Texel'],
        count: 50,
        namePatterns: _sheepNames,
      ),
    ];

    // ── Generate animals with pedigrees ──────────────────────────
    for (final config in speciesConfigs) {
      final speciesAnimals = _generateSpecies(config);
      animals.addAll(speciesAnimals);
    }

    // ── Insert into database ────────────────────────────────────
    for (final animal in animals) {
      await _db.insertAnimal(animal);
    }

    // ── Health records ──────────────────────────────────────────
    for (final animal in animals) {
      final recordCount = 1 + _rng.nextInt(3); // 1-3 records
      for (int i = 0; i < recordCount; i++) {
        final record = _generateHealthRecord(animal);
        await _db.insertHealthRecord(record);
      }
    }

    // ── Weight records (50% of animals) ──────────────────────────
    for (final animal in animals) {
      if (_rng.nextBool()) {
        final count = 2 + _rng.nextInt(4); // 2-5 records
        for (int i = 0; i < count; i++) {
          final record = _generateWeightRecord(animal, i);
          await _db.insertWeightRecord(record);
        }
      }
    }

    // ── Contacts ─────────────────────────────────────────────────
    for (int i = 0; i < 10; i++) {
      await _db.insertContact(_generateContact(i));
    }

    // ── Custom field definitions ─────────────────────────────────
    final customFields = [
      CustomFieldDefinition(
        name: 'Ear Tag',
        fieldKey: 'ear_tag',
        fieldType: CustomFieldType.text,
      ),
      CustomFieldDefinition(
        name: 'Fleece Weight (kg)',
        fieldKey: 'fleece_weight',
        fieldType: CustomFieldType.number,
      ),
      CustomFieldDefinition(
        name: 'Racing Class',
        fieldKey: 'racing_class',
        fieldType: CustomFieldType.dropdown,
        options: ['Maiden', 'Class 1', 'Class 2', 'Open'],
      ),
    ];
    for (final field in customFields) {
      await _db.insertCustomFieldDefinition(field);
    }
  }

  // ─── Animal generation ──────────────────────────────────────────

  List<Animal> _generateSpecies(_SpeciesConfig config) {
    final result = <Animal>[];
    final foundersCount = (config.count * 0.4).round();
    final gen1Count = (config.count * 0.25).round();
    final gen2Count = (config.count * 0.20).round();
    final gen3Count = config.count - foundersCount - gen1Count - gen2Count;

    final now = DateTime.now();

    // Gen 0: founders (no parents)
    final founders = <Animal>[];
    for (int i = 0; i < foundersCount; i++) {
      final breed = config.breeds[i % config.breeds.length];
      final sex = i % 2 == 0 ? Sex.male : Sex.female;
      final yearsAgo = 8 + _rng.nextInt(7); // 8-14 years ago
      final dob = DateTime(now.year - yearsAgo, 1 + _rng.nextInt(12), 1 + _rng.nextInt(28));
      final name = _pickName(config.namePatterns, i);
      final animal = Animal(
        name: name,
        species: config.species,
        breed: breed,
        sex: sex,
        dateOfBirth: dob,
        status: AnimalStatus.alive,
        registrationNumber: '${config.species.substring(0, 2).toUpperCase()}-${dob.year}-${(i + 1).toString().padLeft(3, '0')}',
        color: _pickColor(config.species),
      );
      founders.add(animal);
      result.add(animal);
    }

    // Gen 1
    final gen1 = <Animal>[];
    for (int i = 0; i < gen1Count; i++) {
      final breed = config.breeds[i % config.breeds.length];
      final sire = _pickParent(founders, Sex.male, breed);
      final dam = _pickParent(founders, Sex.female, breed);
      final yearsAgo = 5 + _rng.nextInt(3); // 5-7 years ago
      final dob = DateTime(now.year - yearsAgo, 1 + _rng.nextInt(12), 1 + _rng.nextInt(28));
      final sex = i % 2 == 0 ? Sex.male : Sex.female;
      final name = _pickName(config.namePatterns, foundersCount + i);
      final animal = Animal(
        name: name,
        species: config.species,
        breed: breed,
        sex: sex,
        dateOfBirth: dob,
        sireId: sire?.id,
        damId: dam?.id,
        status: AnimalStatus.alive,
        registrationNumber: '${config.species.substring(0, 2).toUpperCase()}-${dob.year}-${(foundersCount + i + 1).toString().padLeft(3, '0')}',
        color: _pickColor(config.species),
      );
      gen1.add(animal);
      result.add(animal);
    }

    // Gen 2
    final gen2 = <Animal>[];
    final gen1Pool = [...gen1, ...founders];
    for (int i = 0; i < gen2Count; i++) {
      final breed = config.breeds[i % config.breeds.length];
      final sire = _pickParent(gen1Pool, Sex.male, breed);
      final dam = _pickParent(gen1Pool, Sex.female, breed);
      final yearsAgo = 2 + _rng.nextInt(3); // 2-4 years ago
      final dob = DateTime(now.year - yearsAgo, 1 + _rng.nextInt(12), 1 + _rng.nextInt(28));
      final sex = i % 2 == 0 ? Sex.male : Sex.female;
      final name = _pickName(config.namePatterns, foundersCount + gen1Count + i);
      final animal = Animal(
        name: name,
        species: config.species,
        breed: breed,
        sex: sex,
        dateOfBirth: dob,
        sireId: sire?.id,
        damId: dam?.id,
        status: AnimalStatus.alive,
        registrationNumber: '${config.species.substring(0, 2).toUpperCase()}-${dob.year}-${(foundersCount + gen1Count + i + 1).toString().padLeft(3, '0')}',
        color: _pickColor(config.species),
      );
      gen2.add(animal);
      result.add(animal);
    }

    // Gen 3
    final gen2Pool = [...gen2, ...gen1];
    for (int i = 0; i < gen3Count; i++) {
      final breed = config.breeds[i % config.breeds.length];
      final sire = _pickParent(gen2Pool, Sex.male, breed);
      final dam = _pickParent(gen2Pool, Sex.female, breed);
      final yearsAgo = _rng.nextInt(2); // 0-1 years ago
      final dob = DateTime(now.year - yearsAgo, 1 + _rng.nextInt(12), 1 + _rng.nextInt(28));
      final sex = i % 2 == 0 ? Sex.male : Sex.female;
      final name = _pickName(config.namePatterns, foundersCount + gen1Count + gen2Count + i);
      final animal = Animal(
        name: name,
        species: config.species,
        breed: breed,
        sex: sex,
        dateOfBirth: dob,
        sireId: sire?.id,
        damId: dam?.id,
        status: AnimalStatus.alive,
        registrationNumber: '${config.species.substring(0, 2).toUpperCase()}-${dob.year}-${(foundersCount + gen1Count + gen2Count + i + 1).toString().padLeft(3, '0')}',
        color: _pickColor(config.species),
      );
      result.add(animal);
    }

    return result;
  }

  Animal? _pickParent(List<Animal> pool, Sex sex, String breed) {
    // Prefer same breed, fall back to any of matching sex
    final sameBreedsex = pool.where((a) => a.sex == sex && a.breed == breed).toList();
    if (sameBreedsex.isNotEmpty) return sameBreedsex[_rng.nextInt(sameBreedsex.length)];
    final anySex = pool.where((a) => a.sex == sex).toList();
    if (anySex.isNotEmpty) return anySex[_rng.nextInt(anySex.length)];
    return null;
  }

  // ─── Health record generation ──────────────────────────────────

  HealthRecord _generateHealthRecord(Animal animal) {
    final types = HealthRecordType.values;
    final type = types[_rng.nextInt(types.length)];
    final titles = {
      HealthRecordType.vaccination: ['Annual Vaccination', '5-in-1 Vaccine', 'Tetanus Booster', 'Rabies Vaccine'],
      HealthRecordType.examination: ['Annual Exam', 'Pre-breeding Check', 'Lameness Exam', 'Dental Check'],
      HealthRecordType.other: ['Deworming', 'Wound Treatment', 'Antibiotic Course', 'Hoof Trim'],
      HealthRecordType.surgery: ['Castration', 'Caesarean', 'Abscess Drainage'],
      HealthRecordType.medication: ['Ivermectin', 'Penicillin', 'Flunixin', 'Dexamethasone'],
    };
    final titleList = titles[type] ?? ['General Record'];
    final title = titleList[_rng.nextInt(titleList.length)];
    final daysAgo = _rng.nextInt(365);
    final date = DateTime.now().subtract(Duration(days: daysAgo));

    return HealthRecord(
      animalId: animal.id,
      type: type,
      title: title,
      date: date,
      nextDueDate: type == HealthRecordType.vaccination
          ? date.add(Duration(days: 180 + _rng.nextInt(185)))
          : null,
      veterinarian: _vets[_rng.nextInt(_vets.length)],
      cost: (30 + _rng.nextInt(470)).toDouble(),
    );
  }

  // ─── Weight record generation ─────────────────────────────────

  WeightRecord _generateWeightRecord(Animal animal, int index) {
    final baseWeight = animal.species == 'Horse'
        ? 400.0
        : animal.species == 'Cattle'
            ? 350.0
            : 50.0;
    final weight = baseWeight + _rng.nextInt(100) + index * 10;
    final daysAgo = 365 - (index * 60);
    final date = DateTime.now().subtract(Duration(days: daysAgo.clamp(0, 730)));

    return WeightRecord(
      animalId: animal.id,
      weight: weight,
      date: date,
    );
  }

  // ─── Contact generation ───────────────────────────────────────

  Contact _generateContact(int index) {
    final names = [
      ('Dr. Sarah Mitchell', 'Veterinarian'),
      ('Green Valley Farm', 'Breeder'),
      ('James Wilson', 'Trainer'),
      ('Blue Ridge Stud', 'Breeder'),
      ('Dr. Michael Chen', 'Veterinarian'),
      ('Oakwood Livestock', 'Supplier'),
      ('Emily Davis', 'Handler'),
      ('Highland Ranch', 'Breeder'),
      ('Dr. Lisa Park', 'Veterinarian'),
      ('Riverside Farm', 'Buyer'),
    ];
    final entry = names[index % names.length];
    return Contact(
      name: entry.$1,
      notes: 'Role: ${entry.$2}',
      phone: '+1 555 ${100 + _rng.nextInt(900)} ${1000 + _rng.nextInt(9000)}',
      email: entry.$1.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '') + '@example.com',
    );
  }

  // ─── Name data ─────────────────────────────────────────────────

  String _pickName(List<String> patterns, int index) {
    return patterns[index % patterns.length];
  }

  String _pickColor(String species) {
    final colors = {
      'Horse': ['Bay', 'Chestnut', 'Black', 'Grey', 'Palomino', 'Dun', 'Roan'],
      'Cattle': ['Black', 'Red', 'White', 'Roan', 'Brindle', 'Brown', 'Spotted'],
      'Sheep': ['White', 'Black', 'Brown', 'Grey', 'Spotted'],
    };
    final list = colors[species] ?? ['Unknown'];
    return list[_rng.nextInt(list.length)];
  }

  static const _horseNames = [
    'Greenfield Eclipse', 'Thunder Valley', 'Silver Moonlight', 'Rising Dawn',
    'Golden Promise', 'Storm Chaser', 'Midnight Star', 'Crystal Springs',
    'Iron Will', 'Diamond Dust', 'Autumn Blaze', 'Northern Light',
    'River Dance', 'Shadow Hawk', 'Brave Heart', 'Wild Spirit',
    'Ocean Breeze', 'Prairie Song', 'Mountain Echo', 'Sunset Glory',
    'Royal Flush', 'Noble Quest', 'Dark Knight', 'Swift Arrow',
    'Velvet Touch', 'Morning Dew', 'Copper Ridge', 'Starlight Express',
    'Desert Rose', 'Winter Storm', 'Lucky Charm', 'Blue Thunder',
    'Fire Dancer', 'Dream Weaver', 'Silver Lining', 'Gold Standard',
    'Phantom Run', 'Crimson Tide', 'Wind Rider', 'Steel Magnolia',
    'Pearl Harbor', 'Mystic Moon', 'Canyon Run', 'Bright Side',
    'Ember Glow', 'Frost Bite', 'Cedar Creek', 'Jasper Stone',
    'Blazing Trail', 'Gentle Rain', 'Harvest Moon', 'Iron Horse',
    'Lightning Bolt', 'Maple Leaf', 'North Star', 'Oak Ridge',
    'Painted Lady', 'Quick Silver', 'Raven Wing', 'Sage Brush',
    'Tidal Wave', 'Umbrella Pine', 'Valley Rose', 'Whispering Wind',
    'Xenon Flash', 'Yearling Star', 'Zephyr Breeze', 'Alpine Glow',
    'Berry Patch', 'Cloud Nine', 'Dusty Trail', 'Evening Star',
    'Falcon Crest', 'Granite Peak', 'Honey Bee', 'Ivory Tower',
    'Jade Dragon', 'Kestrel Flight', 'Luna Belle', 'Marble Arch',
  ];

  static const _cattleNames = [
    'GF-2020-001', 'GF-2020-002', 'GF-2020-003', 'GF-2020-004',
    'GF-2021-001', 'GF-2021-002', 'GF-2021-003', 'GF-2021-004',
    'GF-2022-001', 'GF-2022-002', 'GF-2022-003', 'GF-2022-004',
    'GF-2023-001', 'GF-2023-002', 'GF-2023-003', 'GF-2023-004',
    'BR-2020-001', 'BR-2020-002', 'BR-2020-003', 'BR-2020-004',
    'BR-2021-001', 'BR-2021-002', 'BR-2021-003', 'BR-2021-004',
    'BR-2022-001', 'BR-2022-002', 'BR-2022-003', 'BR-2022-004',
    'BR-2023-001', 'BR-2023-002', 'BR-2023-003', 'BR-2023-004',
    'HL-2020-001', 'HL-2020-002', 'HL-2020-003', 'HL-2020-004',
    'HL-2021-001', 'HL-2021-002', 'HL-2021-003', 'HL-2021-004',
    'HL-2022-001', 'HL-2022-002', 'HL-2022-003', 'HL-2022-004',
    'HL-2023-001', 'HL-2023-002', 'HL-2023-003', 'HL-2023-004',
    'MW-2020-001', 'MW-2020-002', 'MW-2020-003', 'MW-2020-004',
    'MW-2021-001', 'MW-2021-002', 'MW-2021-003', 'MW-2021-004',
    'MW-2022-001', 'MW-2022-002', 'MW-2022-003', 'MW-2022-004',
    'MW-2023-001', 'MW-2023-002', 'MW-2023-003', 'MW-2023-004',
    'SR-2020-001', 'SR-2020-002', 'SR-2020-003', 'SR-2020-004',
    'SR-2021-001', 'SR-2021-002', 'SR-2021-003', 'SR-2021-004',
  ];

  static const _sheepNames = [
    'Woolly Wonder', 'Cloud Fleece', 'Meadow Star', 'Clover Bell',
    'Daisy Mae', 'Buttercup', 'Snowball', 'Patches',
    'Cotton Tail', 'Misty Morning', 'Blossom', 'Bramble',
    'Pebble', 'Rosemary', 'Thyme', 'Sage',
    'Bluebell', 'Primrose', 'Hazel', 'Ivy',
    'Fern', 'Heather', 'Holly', 'Jasmine',
    'Lavender', 'Maple', 'Olive', 'Pearl',
    'Ruby', 'Willow', 'Aurora', 'Stella',
    'Luna', 'Poppy', 'Flora', 'Amber',
    'Coral', 'Crystal', 'Dawn', 'Eden',
    'Faith', 'Grace', 'Hope', 'Iris',
    'Joy', 'Kate', 'Lily', 'May',
    'Nell', 'Opal', 'Quinn', 'Rose',
  ];

  static const _vets = [
    'Dr. Sarah Mitchell',
    'Dr. Michael Chen',
    'Dr. Lisa Park',
    'Dr. James Thompson',
    'Dr. Emily Davis',
  ];
}

class _SpeciesConfig {
  final String species;
  final List<String> breeds;
  final int count;
  final List<String> namePatterns;

  _SpeciesConfig({
    required this.species,
    required this.breeds,
    required this.count,
    required this.namePatterns,
  });
}
