import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pedigree_manager.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE animals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        species TEXT NOT NULL,
        breed TEXT NOT NULL,
        sex INTEGER NOT NULL,
        dateOfBirth INTEGER,
        dateOfDeath INTEGER,
        color TEXT,
        markings TEXT,
        registrationNumber TEXT,
        microchipNumber TEXT,
        dnaProfileId TEXT,
        sireId TEXT,
        damId TEXT,
        ownerId TEXT,
        breederName TEXT,
        imagePath TEXT,
        weight REAL,
        height REAL,
        status INTEGER DEFAULT 0,
        geneticTraits TEXT DEFAULT '{}',
        customFields TEXT DEFAULT '{}',
        notes TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE health_records (
        id TEXT PRIMARY KEY,
        animalId TEXT NOT NULL,
        type INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        date INTEGER NOT NULL,
        nextDueDate INTEGER,
        veterinarian TEXT,
        clinic TEXT,
        cost REAL,
        documentPath TEXT,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (animalId) REFERENCES animals (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE breeding_records (
        id TEXT PRIMARY KEY,
        sireId TEXT NOT NULL,
        damId TEXT NOT NULL,
        breedingDate INTEGER NOT NULL,
        expectedDueDate INTEGER,
        actualDueDate INTEGER,
        status INTEGER DEFAULT 0,
        litterId TEXT,
        method TEXT,
        veterinarian TEXT,
        notes TEXT,
        sireCoiContribution REAL,
        damCoiContribution REAL,
        expectedOffspringCoi REAL,
        geneticTestResults TEXT,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (sireId) REFERENCES animals (id),
        FOREIGN KEY (damId) REFERENCES animals (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE litters (
        id TEXT PRIMARY KEY,
        sireId TEXT NOT NULL,
        damId TEXT NOT NULL,
        breedingRecordId TEXT,
        dateOfBirth INTEGER NOT NULL,
        totalPuppies INTEGER DEFAULT 0,
        maleCount INTEGER DEFAULT 0,
        femaleCount INTEGER DEFAULT 0,
        stillborn INTEGER DEFAULT 0,
        offspringIds TEXT,
        registrationNumber TEXT,
        notes TEXT,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (sireId) REFERENCES animals (id),
        FOREIGN KEY (damId) REFERENCES animals (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_field_definitions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        fieldKey TEXT NOT NULL,
        fieldType INTEGER NOT NULL DEFAULT 0,
        required INTEGER NOT NULL DEFAULT 0,
        options TEXT DEFAULT '',
        displayOrder INTEGER DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    // Create indices for faster queries
    await db.execute(
        'CREATE INDEX idx_animals_species ON animals (species)');
    await db.execute(
        'CREATE INDEX idx_animals_breed ON animals (breed)');
    await db.execute(
        'CREATE INDEX idx_animals_sire ON animals (sireId)');
    await db.execute(
        'CREATE INDEX idx_animals_dam ON animals (damId)');
    await db.execute(
        'CREATE INDEX idx_health_animal ON health_records (animalId)');
    await db.execute(
        'CREATE INDEX idx_breeding_sire ON breeding_records (sireId)');
    await db.execute(
        'CREATE INDEX idx_breeding_dam ON breeding_records (damId)');
    await db.execute(
        'CREATE UNIQUE INDEX idx_custom_field_key ON custom_field_definitions (fieldKey)');
  }

  // ─── Animal CRUD ────────────────────────────────────────────────

  Future<void> insertAnimal(Animal animal) async {
    final db = await database;
    await db.insert('animals', animal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateAnimal(Animal animal) async {
    final db = await database;
    await db.update('animals', animal.toMap(),
        where: 'id = ?', whereArgs: [animal.id]);
  }

  Future<void> deleteAnimal(String id) async {
    final db = await database;
    await db.delete('animals', where: 'id = ?', whereArgs: [id]);
  }

  Future<Animal?> getAnimal(String id) async {
    final db = await database;
    final maps = await db.query('animals', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Animal.fromMap(maps.first);
  }

  Future<List<Animal>> getAllAnimals() async {
    final db = await database;
    final maps = await db.query('animals', orderBy: 'name ASC');
    return maps.map((m) => Animal.fromMap(m)).toList();
  }

  Future<List<Animal>> getAnimalsBySpecies(String species) async {
    final db = await database;
    final maps = await db.query('animals',
        where: 'species = ?', whereArgs: [species], orderBy: 'name ASC');
    return maps.map((m) => Animal.fromMap(m)).toList();
  }

  Future<List<Animal>> getAnimalsByBreed(String breed) async {
    final db = await database;
    final maps = await db.query('animals',
        where: 'breed = ?', whereArgs: [breed], orderBy: 'name ASC');
    return maps.map((m) => Animal.fromMap(m)).toList();
  }

  Future<List<Animal>> getOffspring(String parentId) async {
    final db = await database;
    final maps = await db.query('animals',
        where: 'sireId = ? OR damId = ?',
        whereArgs: [parentId, parentId],
        orderBy: 'dateOfBirth DESC');
    return maps.map((m) => Animal.fromMap(m)).toList();
  }

  Future<List<Animal>> searchAnimals(String query) async {
    final db = await database;
    final maps = await db.query('animals',
        where:
            'name LIKE ? OR breed LIKE ? OR registrationNumber LIKE ? OR microchipNumber LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
        orderBy: 'name ASC');
    return maps.map((m) => Animal.fromMap(m)).toList();
  }

  // ─── Health Records CRUD ────────────────────────────────────────

  Future<void> insertHealthRecord(HealthRecord record) async {
    final db = await database;
    await db.insert('health_records', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteHealthRecord(String id) async {
    final db = await database;
    await db.delete('health_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<HealthRecord>> getHealthRecords(String animalId) async {
    final db = await database;
    final maps = await db.query('health_records',
        where: 'animalId = ?',
        whereArgs: [animalId],
        orderBy: 'date DESC');
    return maps.map((m) => HealthRecord.fromMap(m)).toList();
  }

  Future<List<HealthRecord>> getUpcomingHealthRecords() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final future =
        DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
    final maps = await db.query('health_records',
        where: 'nextDueDate IS NOT NULL AND nextDueDate BETWEEN ? AND ?',
        whereArgs: [now, future],
        orderBy: 'nextDueDate ASC');
    return maps.map((m) => HealthRecord.fromMap(m)).toList();
  }

  // ─── Breeding Records CRUD ──────────────────────────────────────

  Future<void> insertBreedingRecord(BreedingRecord record) async {
    final db = await database;
    await db.insert('breeding_records', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateBreedingRecord(BreedingRecord record) async {
    final db = await database;
    await db.update('breeding_records', record.toMap(),
        where: 'id = ?', whereArgs: [record.id]);
  }

  Future<List<BreedingRecord>> getBreedingRecords({
    String? sireId,
    String? damId,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (sireId != null && damId != null) {
      where = 'sireId = ? AND damId = ?';
      whereArgs = [sireId, damId];
    } else if (sireId != null) {
      where = 'sireId = ?';
      whereArgs = [sireId];
    } else if (damId != null) {
      where = 'damId = ?';
      whereArgs = [damId];
    }
    final maps = await db.query('breeding_records',
        where: where, whereArgs: whereArgs, orderBy: 'breedingDate DESC');
    return maps.map((m) => BreedingRecord.fromMap(m)).toList();
  }

  Future<List<BreedingRecord>> getActiveBreedings() async {
    final db = await database;
    final maps = await db.query('breeding_records',
        where: 'status IN (?, ?, ?, ?)',
        whereArgs: [
          BreedingStatus.planned.index,
          BreedingStatus.confirmed.index,
          BreedingStatus.pregnant.index,
          BreedingStatus.whelping.index,
        ],
        orderBy: 'breedingDate DESC');
    return maps.map((m) => BreedingRecord.fromMap(m)).toList();
  }

  // ─── Litters CRUD ──────────────────────────────────────────────

  Future<void> insertLitter(Litter litter) async {
    final db = await database;
    await db.insert('litters', litter.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Litter>> getLitters({String? sireId, String? damId}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (sireId != null) {
      where = 'sireId = ?';
      whereArgs = [sireId];
    } else if (damId != null) {
      where = 'damId = ?';
      whereArgs = [damId];
    }
    final maps = await db.query('litters',
        where: where, whereArgs: whereArgs, orderBy: 'dateOfBirth DESC');
    return maps.map((m) => Litter.fromMap(m)).toList();
  }

  Future<List<Litter>> getAllLitters() async {
    final db = await database;
    final maps = await db.query('litters', orderBy: 'dateOfBirth DESC');
    return maps.map((m) => Litter.fromMap(m)).toList();
  }

  // ─── Custom Field Definitions CRUD ──────────────────────────────

  Future<void> insertCustomFieldDefinition(CustomFieldDefinition field) async {
    final db = await database;
    await db.insert('custom_field_definitions', field.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCustomFieldDefinition(CustomFieldDefinition field) async {
    final db = await database;
    await db.update('custom_field_definitions', field.toMap(),
        where: 'id = ?', whereArgs: [field.id]);
  }

  Future<void> deleteCustomFieldDefinition(String id) async {
    final db = await database;
    await db.delete('custom_field_definitions',
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CustomFieldDefinition>> getCustomFieldDefinitions() async {
    final db = await database;
    final maps = await db.query('custom_field_definitions',
        orderBy: 'displayOrder ASC, name ASC');
    return maps.map((m) => CustomFieldDefinition.fromMap(m)).toList();
  }

  // ─── Stats ─────────────────────────────────────────────────────

  Future<Map<String, int>> getAnimalStats() async {
    final db = await database;
    final total =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM animals')) ?? 0;
    final males = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM animals WHERE sex = ${Sex.male.index}')) ??
        0;
    final females = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM animals WHERE sex = ${Sex.female.index}')) ??
        0;
    final breeds = Sqflite.firstIntValue(await db
            .rawQuery('SELECT COUNT(DISTINCT breed) FROM animals')) ??
        0;
    final species = Sqflite.firstIntValue(await db
            .rawQuery('SELECT COUNT(DISTINCT species) FROM animals')) ??
        0;
    return {
      'total': total,
      'males': males,
      'females': females,
      'breeds': breeds,
      'species': species,
    };
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
