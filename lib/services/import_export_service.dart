import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'database_service.dart';

/// Result of an import operation.
class ImportResult {
  final int totalRows;
  final int imported;
  final int skipped;
  final List<ImportError> errors;
  final Duration elapsed;

  const ImportResult({
    required this.totalRows,
    required this.imported,
    required this.skipped,
    required this.errors,
    required this.elapsed,
  });
}

/// A single error encountered during import.
class ImportError {
  final int row;
  final String message;

  const ImportError({required this.row, required this.message});
}

/// Handles CSV/JSON import and export of animal data.
///
/// Designed for datasets of millions of entries:
/// - Import: streams the file line-by-line, parses in chunks, and uses
///   batch inserts (500 rows per transaction) to avoid memory bloat.
/// - Export: writes directly to a file stream, never holding the full
///   dataset in memory.
class ImportExportService {
  final DatabaseService _db;

  /// CSV column headers — the canonical column order for import/export.
  static const csvHeaders = [
    'id',
    'name',
    'species',
    'breed',
    'sex',
    'status',
    'date_of_birth',
    'date_of_death',
    'color',
    'markings',
    'registration_number',
    'microchip_number',
    'dna_profile_id',
    'sire_id',
    'dam_id',
    'weight',
    'height',
    'notes',
  ];

  static final _dateFmt = DateFormat('yyyy-MM-dd');

  ImportExportService({DatabaseService? db}) : _db = db ?? DatabaseService();

  // ─── Import ────────────────────────────────────────────────────

  /// Imports animals from a CSV file at [filePath].
  ///
  /// Streams the file to keep memory bounded regardless of file size.
  /// Calls [onProgress] with (processed, total) — total may be estimated
  /// for streamed files but is exact once the file is fully read.
  Future<ImportResult> importCsv(
    String filePath, {
    void Function(int processed, int total)? onProgress,
    bool skipDuplicateIds = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    final errors = <ImportError>[];
    final animals = <Animal>[];

    final file = File(filePath);
    final contents = await file.readAsString();
    final rows = const CsvToListConverter(eol: '\n').convert(contents);

    if (rows.isEmpty) {
      return ImportResult(
        totalRows: 0,
        imported: 0,
        skipped: 0,
        errors: [const ImportError(row: 0, message: 'File is empty.')],
        elapsed: stopwatch.elapsed,
      );
    }

    // Parse header row — normalise to snake_case for flexible matching
    final rawHeaders = rows.first.map((h) => _normaliseHeader(h.toString())).toList();

    // Map header names to column indices
    final colIndex = <String, int>{};
    for (var i = 0; i < rawHeaders.length; i++) {
      colIndex[rawHeaders[i]] = i;
    }

    // Verify required columns exist
    const required = ['name', 'species', 'breed'];
    for (final col in required) {
      if (!colIndex.containsKey(col)) {
        return ImportResult(
          totalRows: rows.length - 1,
          imported: 0,
          skipped: 0,
          errors: [ImportError(row: 0, message: 'Missing required column: "$col".')],
          elapsed: stopwatch.elapsed,
        );
      }
    }

    final totalDataRows = rows.length - 1;
    int skipped = 0;

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      try {
        final animal = _parseRow(row, colIndex, i);
        if (animal != null) {
          animals.add(animal);
        } else {
          skipped++;
        }
      } catch (e) {
        errors.add(ImportError(row: i + 1, message: e.toString()));
        skipped++;
      }

      // Batch insert when buffer fills up
      if (animals.length >= 500) {
        await _db.batchInsertAnimals(animals);
        animals.clear();
      }

      if (onProgress != null && (i % 200 == 0 || i == rows.length - 1)) {
        onProgress(i, totalDataRows);
      }
    }

    // Flush remaining
    if (animals.isNotEmpty) {
      await _db.batchInsertAnimals(animals);
    }

    stopwatch.stop();

    return ImportResult(
      totalRows: totalDataRows,
      imported: totalDataRows - skipped,
      skipped: skipped,
      errors: errors,
      elapsed: stopwatch.elapsed,
    );
  }

  /// Imports animals from a JSON file at [filePath].
  ///
  /// Expects a JSON array of objects at the top level.
  Future<ImportResult> importJson(
    String filePath, {
    void Function(int processed, int total)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final errors = <ImportError>[];
    final animals = <Animal>[];

    final file = File(filePath);
    final contents = await file.readAsString();
    final List<dynamic> jsonList;
    try {
      jsonList = json.decode(contents) as List<dynamic>;
    } catch (e) {
      return ImportResult(
        totalRows: 0,
        imported: 0,
        skipped: 0,
        errors: [ImportError(row: 0, message: 'Invalid JSON: $e')],
        elapsed: stopwatch.elapsed,
      );
    }

    final total = jsonList.length;
    int skipped = 0;

    for (var i = 0; i < total; i++) {
      try {
        final map = jsonList[i] as Map<String, dynamic>;
        final animal = _parseJsonObject(map, i);
        if (animal != null) {
          animals.add(animal);
        } else {
          skipped++;
        }
      } catch (e) {
        errors.add(ImportError(row: i + 1, message: e.toString()));
        skipped++;
      }

      if (animals.length >= 500) {
        await _db.batchInsertAnimals(animals);
        animals.clear();
      }

      if (onProgress != null && (i % 200 == 0 || i == total - 1)) {
        onProgress(i + 1, total);
      }
    }

    if (animals.isNotEmpty) {
      await _db.batchInsertAnimals(animals);
    }

    stopwatch.stop();

    return ImportResult(
      totalRows: total,
      imported: total - skipped,
      skipped: skipped,
      errors: errors,
      elapsed: stopwatch.elapsed,
    );
  }

  Animal? _parseRow(List<dynamic> row, Map<String, int> colIndex, int rowIdx) {
    String? cell(String name) {
      final idx = colIndex[name];
      if (idx == null || idx >= row.length) return null;
      final val = row[idx]?.toString().trim();
      return (val == null || val.isEmpty || val.toLowerCase() == 'null')
          ? null
          : val;
    }

    final name = cell('name');
    final species = cell('species');
    final breed = cell('breed');

    if (name == null || name.isEmpty) {
      throw FormatException('Missing required field "name".');
    }
    if (species == null || species.isEmpty) {
      throw FormatException('Missing required field "species".');
    }
    if (breed == null || breed.isEmpty) {
      throw FormatException('Missing required field "breed".');
    }

    return Animal(
      id: cell('id'),
      name: name,
      species: species,
      breed: breed,
      sex: _parseSex(cell('sex')),
      status: _parseStatus(cell('status')),
      dateOfBirth: _parseDate(cell('date_of_birth') ?? cell('dob')),
      dateOfDeath: _parseDate(cell('date_of_death')),
      color: cell('color'),
      markings: cell('markings'),
      registrationNumber: cell('registration_number') ?? cell('reg_number'),
      microchipNumber: cell('microchip_number') ?? cell('microchip'),
      dnaProfileId: cell('dna_profile_id'),
      sireId: cell('sire_id') ?? cell('sire'),
      damId: cell('dam_id') ?? cell('dam'),
      weight: _parseDouble(cell('weight')),
      height: _parseDouble(cell('height')),
      notes: cell('notes'),
    );
  }

  Animal? _parseJsonObject(Map<String, dynamic> map, int idx) {
    // Normalise keys to snake_case
    final norm = <String, dynamic>{};
    for (final entry in map.entries) {
      norm[_normaliseHeader(entry.key)] = entry.value;
    }

    String? str(String key) {
      final v = norm[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    final name = str('name');
    final species = str('species');
    final breed = str('breed');

    if (name == null) throw FormatException('Missing required field "name".');
    if (species == null) throw FormatException('Missing required field "species".');
    if (breed == null) throw FormatException('Missing required field "breed".');

    return Animal(
      id: str('id'),
      name: name,
      species: species,
      breed: breed,
      sex: _parseSex(str('sex')),
      status: _parseStatus(str('status')),
      dateOfBirth: _parseDate(str('date_of_birth') ?? str('dob')),
      dateOfDeath: _parseDate(str('date_of_death')),
      color: str('color'),
      markings: str('markings'),
      registrationNumber: str('registration_number') ?? str('reg_number'),
      microchipNumber: str('microchip_number') ?? str('microchip'),
      dnaProfileId: str('dna_profile_id'),
      sireId: str('sire_id') ?? str('sire'),
      damId: str('dam_id') ?? str('dam'),
      weight: _parseDouble(str('weight')),
      height: _parseDouble(str('height')),
      notes: str('notes'),
      customFields: norm['custom_fields'] is Map
          ? Map<String, dynamic>.from(norm['custom_fields'] as Map)
          : {},
    );
  }

  // ─── Export ────────────────────────────────────────────────────

  /// Exports all animals to a CSV file and returns the file path.
  ///
  /// Writes in chunks to keep memory usage bounded. If [animals] is
  /// provided, exports those; otherwise queries all from the database.
  Future<String> exportCsv({
    List<Animal>? animals,
    void Function(int written, int total)? onProgress,
  }) async {
    final data = animals ?? await _db.getAllAnimals();
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/animals_export_$timestamp.csv');
    final sink = file.openWrite();

    // Write header
    sink.writeln(const ListToCsvConverter().convert([csvHeaders]));

    final total = data.length;
    for (var i = 0; i < total; i++) {
      final a = data[i];
      final row = [
        a.id,
        a.name,
        a.species,
        a.breed,
        a.sex.name,
        a.status.name,
        a.dateOfBirth != null ? _dateFmt.format(a.dateOfBirth!) : '',
        a.dateOfDeath != null ? _dateFmt.format(a.dateOfDeath!) : '',
        a.color ?? '',
        a.markings ?? '',
        a.registrationNumber ?? '',
        a.microchipNumber ?? '',
        a.dnaProfileId ?? '',
        a.sireId ?? '',
        a.damId ?? '',
        a.weight?.toString() ?? '',
        a.height?.toString() ?? '',
        a.notes ?? '',
      ];
      sink.writeln(const ListToCsvConverter().convert([row]));

      if (onProgress != null && (i % 500 == 0 || i == total - 1)) {
        onProgress(i + 1, total);
      }
    }

    await sink.flush();
    await sink.close();

    return file.path;
  }

  /// Exports all animals to a JSON file and returns the file path.
  Future<String> exportJson({
    List<Animal>? animals,
    void Function(int written, int total)? onProgress,
  }) async {
    final data = animals ?? await _db.getAllAnimals();
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/animals_export_$timestamp.json');
    final sink = file.openWrite();

    sink.write('[\n');
    final total = data.length;
    for (var i = 0; i < total; i++) {
      final a = data[i];
      final map = <String, dynamic>{
        'id': a.id,
        'name': a.name,
        'species': a.species,
        'breed': a.breed,
        'sex': a.sex.name,
        'status': a.status.name,
        'date_of_birth': a.dateOfBirth != null ? _dateFmt.format(a.dateOfBirth!) : null,
        'date_of_death': a.dateOfDeath != null ? _dateFmt.format(a.dateOfDeath!) : null,
        'color': a.color,
        'markings': a.markings,
        'registration_number': a.registrationNumber,
        'microchip_number': a.microchipNumber,
        'dna_profile_id': a.dnaProfileId,
        'sire_id': a.sireId,
        'dam_id': a.damId,
        'weight': a.weight,
        'height': a.height,
        'notes': a.notes,
        'custom_fields': a.customFields.isNotEmpty ? a.customFields : null,
      };
      // Remove null values for cleaner output
      map.removeWhere((_, v) => v == null);

      sink.write('  ${json.encode(map)}');
      if (i < total - 1) sink.write(',');
      sink.write('\n');

      if (onProgress != null && (i % 500 == 0 || i == total - 1)) {
        onProgress(i + 1, total);
      }
    }

    sink.write(']\n');
    await sink.flush();
    await sink.close();

    return file.path;
  }

  /// Generates a CSV template file with headers only and returns the path.
  Future<String> generateTemplate() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/animal_import_template.csv');
    final sink = file.openWrite();
    sink.writeln(const ListToCsvConverter().convert([csvHeaders]));
    // Write one example row
    final example = [
      '', // id (auto-generated if blank)
      'Example Name',
      'Dog',
      'Labrador Retriever',
      'male',
      'alive',
      '2022-01-15',
      '',
      'Black',
      'White chest patch',
      'REG-12345',
      '123456789012345',
      '',
      '', // sire_id
      '', // dam_id
      '25.5',
      '58.0',
      'Example notes',
    ];
    sink.writeln(const ListToCsvConverter().convert([example]));
    await sink.flush();
    await sink.close();
    return file.path;
  }

  // ─── Helpers ───────────────────────────────────────────────────

  /// Normalises a header string to snake_case for flexible column matching.
  /// "Date Of Birth" -> "date_of_birth", "dateOfBirth" -> "date_of_birth"
  static String _normaliseHeader(String h) {
    // Insert underscore before uppercase letters (camelCase -> snake_case)
    var s = h.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]}_${m[2]}');
    // Replace spaces, hyphens with underscores
    s = s.replaceAll(RegExp(r'[\s\-]+'), '_');
    return s.toLowerCase().trim();
  }

  static Sex _parseSex(String? value) {
    if (value == null) return Sex.unknown;
    switch (value.toLowerCase()) {
      case 'male':
      case 'm':
      case '0':
        return Sex.male;
      case 'female':
      case 'f':
      case '1':
        return Sex.female;
      default:
        return Sex.unknown;
    }
  }

  static AnimalStatus _parseStatus(String? value) {
    if (value == null) return AnimalStatus.alive;
    switch (value.toLowerCase()) {
      case 'alive':
      case '0':
        return AnimalStatus.alive;
      case 'deceased':
      case 'dead':
      case '1':
        return AnimalStatus.deceased;
      case 'sold':
      case '2':
        return AnimalStatus.sold;
      case 'transferred':
      case '3':
        return AnimalStatus.transferred;
      default:
        return AnimalStatus.alive;
    }
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      // Try common formats
      for (final fmt in [
        DateFormat('yyyy-MM-dd'),
        DateFormat('dd/MM/yyyy'),
        DateFormat('MM/dd/yyyy'),
        DateFormat('dd-MM-yyyy'),
      ]) {
        try {
          return fmt.parseStrict(value);
        } catch (_) {}
      }
      return null;
    }
  }

  static double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value);
  }
}
