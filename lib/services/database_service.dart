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
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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
        registrationDate INTEGER,
        microchipNumber TEXT,
        dnaProfileId TEXT,
        sireId TEXT,
        damId TEXT,
        breederId TEXT,
        currentOwnerId TEXT,
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
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        farmName TEXT DEFAULT '',
        email TEXT DEFAULT '',
        phone TEXT DEFAULT '',
        address TEXT DEFAULT '',
        prefix TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        customFields TEXT DEFAULT '{}',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_field_definitions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        fieldKey TEXT NOT NULL,
        fieldType INTEGER NOT NULL DEFAULT 0,
        entityType INTEGER NOT NULL DEFAULT 0,
        required INTEGER NOT NULL DEFAULT 0,
        showInPedigree INTEGER NOT NULL DEFAULT 0,
        applicableBreeds TEXT DEFAULT '[]',
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
        'CREATE UNIQUE INDEX idx_custom_field_key ON custom_field_definitions (fieldKey, entityType)');

    await _createAnimalImagesTable(db);
    await _createTeamMembersTable(db);
    await _createWeightRecordsTable(db);
    await _createShowResultsTable(db);
    await _createFinancialRecordsTable(db);
    await _createDocumentAttachmentsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createAnimalImagesTable(db);
    }
    if (oldVersion < 3) {
      await _createTeamMembersTable(db);
    }
    if (oldVersion < 4) {
      await _createWeightRecordsTable(db);
      await _createShowResultsTable(db);
      await _createFinancialRecordsTable(db);
      await _createDocumentAttachmentsTable(db);
    }
    if (oldVersion < 5) {
      await db.execute(
          'ALTER TABLE animals ADD COLUMN registrationDate INTEGER');
    }
    if (oldVersion < 6) {
      await db.execute(
          'ALTER TABLE custom_field_definitions ADD COLUMN entityType INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE custom_field_definitions ADD COLUMN showInPedigree INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE custom_field_definitions ADD COLUMN applicableBreeds TEXT DEFAULT \'[]\'');
      await db.execute(
          'ALTER TABLE contacts ADD COLUMN customFields TEXT DEFAULT \'{}\'');
      // Recreate the unique index to include entityType
      await db.execute(
          'DROP INDEX IF EXISTS idx_custom_field_key');
      await db.execute(
          'CREATE UNIQUE INDEX idx_custom_field_key ON custom_field_definitions (fieldKey, entityType)');
    }
  }

  Future<void> _createAnimalImagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS animal_images (
        id TEXT PRIMARY KEY,
        animalId TEXT NOT NULL,
        imagePath TEXT NOT NULL,
        caption TEXT DEFAULT '',
        isProfile INTEGER DEFAULT 0,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (animalId) REFERENCES animals (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_animal_images_animal ON animal_images (animalId)');
  }

  Future<void> _createTeamMembersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS team_members (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        email TEXT DEFAULT '',
        firstName TEXT DEFAULT '',
        lastName TEXT DEFAULT '',
        role INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createWeightRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weight_records (
        id TEXT PRIMARY KEY,
        animalId TEXT NOT NULL,
        date INTEGER NOT NULL,
        weight REAL,
        height REAL,
        notes TEXT DEFAULT '',
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (animalId) REFERENCES animals (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_weight_animal ON weight_records (animalId, date)');
  }

  Future<void> _createShowResultsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS show_results (
        id TEXT PRIMARY KEY,
        animalId TEXT NOT NULL,
        showName TEXT NOT NULL,
        showDate INTEGER NOT NULL,
        className TEXT DEFAULT '',
        placement INTEGER DEFAULT 99,
        judge TEXT DEFAULT '',
        points REAL,
        notes TEXT DEFAULT '',
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (animalId) REFERENCES animals (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_show_animal ON show_results (animalId, showDate)');
  }

  Future<void> _createFinancialRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_records (
        id TEXT PRIMARY KEY,
        animalId TEXT NOT NULL,
        date INTEGER NOT NULL,
        transactionType INTEGER NOT NULL DEFAULT 0,
        category INTEGER NOT NULL DEFAULT 99,
        amount REAL NOT NULL,
        description TEXT DEFAULT '',
        receiptPath TEXT,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (animalId) REFERENCES animals (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_financial_animal ON financial_records (animalId, date)');
  }

  Future<void> _createDocumentAttachmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_attachments (
        id TEXT PRIMARY KEY,
        animalId TEXT NOT NULL,
        title TEXT NOT NULL,
        documentType INTEGER NOT NULL DEFAULT 99,
        filePath TEXT NOT NULL,
        notes TEXT DEFAULT '',
        uploadedAt INTEGER NOT NULL,
        FOREIGN KEY (animalId) REFERENCES animals (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_document_animal ON document_attachments (animalId)');
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

  Future<Map<String, Animal>> getAnimalsByIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    final db = await database;
    final result = <String, Animal>{};
    const chunkSize = 500;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, (i + chunkSize).clamp(0, ids.length));
      final placeholders = List.filled(chunk.length, '?').join(',');
      final maps = await db.rawQuery(
        'SELECT * FROM animals WHERE id IN ($placeholders)',
        chunk,
      );
      for (final m in maps) {
        final animal = Animal.fromMap(m);
        result[animal.id] = animal;
      }
    }
    return result;
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

  // ─── Contacts CRUD ─────────────────────────────────────────────

  Future<void> insertContact(Contact contact) async {
    final db = await database;
    await db.insert('contacts', contact.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateContact(Contact contact) async {
    final db = await database;
    await db.update('contacts', contact.toMap(),
        where: 'id = ?', whereArgs: [contact.id]);
  }

  Future<void> deleteContact(String id) async {
    final db = await database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  Future<Contact?> getContact(String id) async {
    final db = await database;
    final maps =
        await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Contact.fromMap(maps.first);
  }

  Future<List<Contact>> getAllContacts() async {
    final db = await database;
    final maps = await db.query('contacts', orderBy: 'name ASC');
    return maps.map((m) => Contact.fromMap(m)).toList();
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

  // ─── Animal Images CRUD ──────────────────────────────────────────

  Future<void> insertAnimalImage(AnimalImage image) async {
    final db = await database;
    if (image.isProfile) {
      // Clear existing profile for this animal
      await db.update(
        'animal_images',
        {'isProfile': 0},
        where: 'animalId = ? AND isProfile = 1',
        whereArgs: [image.animalId],
      );
    }
    await db.insert('animal_images', image.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAnimalImage(String id) async {
    final db = await database;
    await db.delete('animal_images', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AnimalImage>> getAnimalImages(String animalId) async {
    final db = await database;
    final maps = await db.query('animal_images',
        where: 'animalId = ?',
        whereArgs: [animalId],
        orderBy: 'isProfile DESC, createdAt DESC');
    return maps.map((m) => AnimalImage.fromMap(m)).toList();
  }

  Future<AnimalImage?> getProfileImage(String animalId) async {
    final db = await database;
    final maps = await db.query('animal_images',
        where: 'animalId = ? AND isProfile = 1',
        whereArgs: [animalId],
        limit: 1);
    if (maps.isEmpty) return null;
    return AnimalImage.fromMap(maps.first);
  }

  Future<void> setProfileImage(String animalId, String imageId) async {
    final db = await database;
    // Clear existing profile
    await db.update(
      'animal_images',
      {'isProfile': 0},
      where: 'animalId = ?',
      whereArgs: [animalId],
    );
    // Set new profile
    await db.update(
      'animal_images',
      {'isProfile': 1},
      where: 'id = ? AND animalId = ?',
      whereArgs: [imageId, animalId],
    );
  }

  // ─── Team Members CRUD ────────────────────────────────────────

  Future<void> insertTeamMember(TeamMember member) async {
    final db = await database;
    await db.insert('team_members', member.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTeamMember(String id) async {
    final db = await database;
    await db.delete('team_members', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTeamMemberRole(String id, int role) async {
    final db = await database;
    await db.update(
      'team_members',
      {'role': role},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TeamMember>> getAllTeamMembers() async {
    final db = await database;
    final maps = await db.query('team_members', orderBy: 'role DESC, username ASC');
    return maps.map((m) => TeamMember.fromMap(m)).toList();
  }

  Future<void> replaceAllTeamMembers(List<TeamMember> members) async {
    final db = await database;
    await db.delete('team_members');
    final batch = db.batch();
    for (final member in members) {
      batch.insert('team_members', member.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ─── Weight Records CRUD ─────────────────────────────────────

  Future<void> insertWeightRecord(WeightRecord record) async {
    final db = await database;
    await db.insert('weight_records', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteWeightRecord(String id) async {
    final db = await database;
    await db.delete('weight_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WeightRecord>> getWeightRecords(String animalId) async {
    final db = await database;
    final maps = await db.query('weight_records',
        where: 'animalId = ?',
        whereArgs: [animalId],
        orderBy: 'date DESC');
    return maps.map((m) => WeightRecord.fromMap(m)).toList();
  }

  // ─── Show Results CRUD ────────────────────────────────────────

  Future<void> insertShowResult(ShowResult result) async {
    final db = await database;
    await db.insert('show_results', result.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteShowResult(String id) async {
    final db = await database;
    await db.delete('show_results', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ShowResult>> getShowResults(String animalId) async {
    final db = await database;
    final maps = await db.query('show_results',
        where: 'animalId = ?',
        whereArgs: [animalId],
        orderBy: 'showDate DESC');
    return maps.map((m) => ShowResult.fromMap(m)).toList();
  }

  // ─── Financial Records CRUD ───────────────────────────────────

  Future<void> insertFinancialRecord(FinancialRecord record) async {
    final db = await database;
    await db.insert('financial_records', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteFinancialRecord(String id) async {
    final db = await database;
    await db.delete('financial_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FinancialRecord>> getFinancialRecords(String animalId) async {
    final db = await database;
    final maps = await db.query('financial_records',
        where: 'animalId = ?',
        whereArgs: [animalId],
        orderBy: 'date DESC');
    return maps.map((m) => FinancialRecord.fromMap(m)).toList();
  }

  // ─── Document Attachments CRUD ────────────────────────────────

  Future<void> insertDocumentAttachment(DocumentAttachment doc) async {
    final db = await database;
    await db.insert('document_attachments', doc.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteDocumentAttachment(String id) async {
    final db = await database;
    await db.delete('document_attachments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DocumentAttachment>> getDocumentAttachments(String animalId) async {
    final db = await database;
    final maps = await db.query('document_attachments',
        where: 'animalId = ?',
        whereArgs: [animalId],
        orderBy: 'uploadedAt DESC');
    return maps.map((m) => DocumentAttachment.fromMap(m)).toList();
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

  // ─── Batch Operations (for import) ──────────────────────────────

  /// Inserts animals in batches using sqflite's batch API for performance.
  /// Calls [onProgress] with (inserted, total) after each batch.
  /// Returns the number of successfully inserted animals.
  Future<int> batchInsertAnimals(
    List<Animal> animals, {
    int batchSize = 500,
    void Function(int inserted, int total)? onProgress,
  }) async {
    final db = await database;
    int inserted = 0;
    final total = animals.length;

    for (var i = 0; i < total; i += batchSize) {
      final end = (i + batchSize > total) ? total : i + batchSize;
      final chunk = animals.sublist(i, end);

      final batch = db.batch();
      for (final animal in chunk) {
        batch.insert('animals', animal.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
      inserted += chunk.length;
      onProgress?.call(inserted, total);
    }

    return inserted;
  }

  /// Returns the total count of animals (faster than loading all objects).
  Future<int> getAnimalCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM animals')) ??
        0;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
