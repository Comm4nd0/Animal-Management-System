import '../models/models.dart';
import 'database_service.dart';

/// Severity of a data issue found during validation.
enum IssueSeverity { error, warning }

/// A single data issue found during validation.
class DataIssue {
  final String animalId;
  final String animalName;
  final IssueSeverity severity;
  final String code;
  final String message;

  const DataIssue({
    required this.animalId,
    required this.animalName,
    required this.severity,
    required this.code,
    required this.message,
  });
}

/// Validates pedigree data integrity.
///
/// Designed to scale to millions of animals:
/// - Single-animal checks walk the ancestor chain which is bounded by
///   pedigree depth (typically < 20), not total animal count.
/// - Bulk audit loads all animals once into a HashMap for O(1) lookups,
///   then validates each animal without additional DB queries.
class PedigreeValidator {
  final DatabaseService _db;

  PedigreeValidator({DatabaseService? db}) : _db = db ?? DatabaseService();

  // ─── Single-Animal Validation ─────────────────────────────────
  // Used when adding or editing an animal. Returns null if valid,
  // or an error message string if invalid.

  /// Validates that setting [sireId] and [damId] on an animal with [animalId]
  /// does not create impossible pedigree relationships.
  ///
  /// Runs O(depth) checks, not O(n), so safe for large datasets.
  Future<String?> validateParentage({
    required String animalId,
    String? sireId,
    String? damId,
    DateTime? dateOfBirth,
    required List<Animal> allAnimals,
  }) async {
    // Build lookup map from the provided list (avoids DB round-trips)
    final lookup = <String, Animal>{};
    for (final a in allAnimals) {
      lookup[a.id] = a;
    }

    // 1. Self-reference
    if (sireId == animalId || damId == animalId) {
      return 'An animal cannot be its own parent.';
    }

    // 2. Sire and dam are the same animal
    if (sireId != null && sireId == damId) {
      return 'Sire and dam cannot be the same animal.';
    }

    // 3. Sex mismatch
    if (sireId != null) {
      final sire = lookup[sireId];
      if (sire != null && sire.sex == Sex.female) {
        return 'The selected sire (${sire.name}) is female. A sire must be male.';
      }
    }
    if (damId != null) {
      final dam = lookup[damId];
      if (dam != null && dam.sex == Sex.male) {
        return 'The selected dam (${dam.name}) is male. A dam must be female.';
      }
    }

    // 4. Date-of-birth checks
    if (dateOfBirth != null) {
      if (sireId != null) {
        final sire = lookup[sireId];
        if (sire != null && sire.dateOfBirth != null) {
          if (!sire.dateOfBirth!.isBefore(dateOfBirth)) {
            return 'The sire (${sire.name}) was born on or after this animal. '
                'A parent must be born before its offspring.';
          }
        }
      }
      if (damId != null) {
        final dam = lookup[damId];
        if (dam != null && dam.dateOfBirth != null) {
          if (!dam.dateOfBirth!.isBefore(dateOfBirth)) {
            return 'The dam (${dam.name}) was born on or after this animal. '
                'A parent must be born before its offspring.';
          }
        }
      }
    }

    // 5. Circular ancestry — walk the ancestor chain from each proposed
    //    parent and ensure we never reach the animal being edited.
    //    This is O(depth), bounded by real pedigree depth (< 20 typically).
    if (sireId != null) {
      final cycle = _detectCycle(animalId, sireId, lookup);
      if (cycle != null) {
        return 'Circular pedigree detected: setting this sire would create '
            'a loop ($cycle).';
      }
    }
    if (damId != null) {
      final cycle = _detectCycle(animalId, damId, lookup);
      if (cycle != null) {
        return 'Circular pedigree detected: setting this dam would create '
            'a loop ($cycle).';
      }
    }

    return null; // Valid
  }

  /// Walks ancestors from [startId] looking for [targetId].
  /// Returns a description of the cycle path if found, or null if safe.
  ///
  /// Uses iterative BFS with a visited set to avoid infinite loops
  /// even on already-corrupted data.
  String? _detectCycle(
    String targetId,
    String startId,
    Map<String, Animal> lookup,
  ) {
    final visited = <String>{};
    final queue = <String>[startId];

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      if (currentId == targetId) {
        return '${lookup[startId]?.name ?? startId} -> ... -> '
            '${lookup[targetId]?.name ?? targetId}';
      }
      if (visited.contains(currentId)) continue;
      visited.add(currentId);

      final animal = lookup[currentId];
      if (animal == null) continue;
      if (animal.sireId != null) queue.add(animal.sireId!);
      if (animal.damId != null) queue.add(animal.damId!);
    }

    return null;
  }

  // ─── Bulk Data Audit ───────────────────────────────────────────
  // Scans all animals for data integrity issues. Loads everything
  // into a HashMap once, then iterates — no repeated DB queries.

  /// Runs a full audit of all pedigree data and returns a list of issues.
  ///
  /// When [animals] is provided the audit runs entirely in-memory without
  /// touching the database.  This is required on web where sqflite is not
  /// available, and avoids a redundant DB round-trip on mobile when the
  /// caller already holds the full animal list.
  ///
  /// Streams progress via [onProgress] callback with (processed, total).
  Future<List<DataIssue>> auditAll({
    List<Animal>? animals,
    void Function(int processed, int total)? onProgress,
  }) async {
    animals ??= await _db.getAllAnimals();
    final issues = <DataIssue>[];

    // Build fast lookup
    final lookup = <String, Animal>{};
    for (final a in animals) {
      lookup[a.id] = a;
    }

    // Track duplicate registration numbers
    final regNumbers = <String, List<Animal>>{};

    final total = animals.length;
    for (var i = 0; i < total; i++) {
      final animal = animals[i];
      _auditAnimal(animal, lookup, issues, regNumbers);

      // Report progress every 500 animals to keep UI responsive
      if (onProgress != null && (i % 500 == 0 || i == total - 1)) {
        onProgress(i + 1, total);
      }
    }

    // Report duplicate registration numbers
    for (final entry in regNumbers.entries) {
      if (entry.value.length > 1) {
        for (final animal in entry.value) {
          issues.add(DataIssue(
            animalId: animal.id,
            animalName: animal.name,
            severity: IssueSeverity.warning,
            code: 'DUPLICATE_REG',
            message: 'Registration number "${entry.key}" is shared with '
                '${entry.value.length - 1} other animal(s): '
                '${entry.value.where((a) => a.id != animal.id).map((a) => a.name).join(", ")}.',
          ));
        }
      }
    }

    return issues;
  }

  void _auditAnimal(
    Animal animal,
    Map<String, Animal> lookup,
    List<DataIssue> issues,
    Map<String, List<Animal>> regNumbers,
  ) {
    // Track registration numbers
    if (animal.registrationNumber != null &&
        animal.registrationNumber!.isNotEmpty) {
      regNumbers
          .putIfAbsent(animal.registrationNumber!, () => [])
          .add(animal);
    }

    // Self-reference
    if (animal.sireId == animal.id) {
      issues.add(DataIssue(
        animalId: animal.id,
        animalName: animal.name,
        severity: IssueSeverity.error,
        code: 'SELF_SIRE',
        message: '${animal.name} is listed as its own sire.',
      ));
    }
    if (animal.damId == animal.id) {
      issues.add(DataIssue(
        animalId: animal.id,
        animalName: animal.name,
        severity: IssueSeverity.error,
        code: 'SELF_DAM',
        message: '${animal.name} is listed as its own dam.',
      ));
    }

    // Same animal as both parents
    if (animal.sireId != null &&
        animal.sireId == animal.damId) {
      issues.add(DataIssue(
        animalId: animal.id,
        animalName: animal.name,
        severity: IssueSeverity.error,
        code: 'SAME_PARENTS',
        message: '${animal.name} has the same animal as both sire and dam.',
      ));
    }

    // Orphan sire reference
    if (animal.sireId != null && !lookup.containsKey(animal.sireId)) {
      issues.add(DataIssue(
        animalId: animal.id,
        animalName: animal.name,
        severity: IssueSeverity.warning,
        code: 'ORPHAN_SIRE',
        message: '${animal.name} references a sire that does not exist in the database.',
      ));
    }

    // Orphan dam reference
    if (animal.damId != null && !lookup.containsKey(animal.damId)) {
      issues.add(DataIssue(
        animalId: animal.id,
        animalName: animal.name,
        severity: IssueSeverity.warning,
        code: 'ORPHAN_DAM',
        message: '${animal.name} references a dam that does not exist in the database.',
      ));
    }

    // Sex mismatch — sire should be male
    if (animal.sireId != null && lookup.containsKey(animal.sireId)) {
      final sire = lookup[animal.sireId]!;
      if (sire.sex == Sex.female) {
        issues.add(DataIssue(
          animalId: animal.id,
          animalName: animal.name,
          severity: IssueSeverity.error,
          code: 'SIRE_IS_FEMALE',
          message: '${animal.name}\'s sire (${sire.name}) is recorded as female.',
        ));
      }
    }

    // Sex mismatch — dam should be female
    if (animal.damId != null && lookup.containsKey(animal.damId)) {
      final dam = lookup[animal.damId]!;
      if (dam.sex == Sex.male) {
        issues.add(DataIssue(
          animalId: animal.id,
          animalName: animal.name,
          severity: IssueSeverity.error,
          code: 'DAM_IS_MALE',
          message: '${animal.name}\'s dam (${dam.name}) is recorded as male.',
        ));
      }
    }

    // Date-of-birth sanity
    if (animal.dateOfBirth != null) {
      if (animal.sireId != null && lookup.containsKey(animal.sireId)) {
        final sire = lookup[animal.sireId]!;
        if (sire.dateOfBirth != null &&
            !sire.dateOfBirth!.isBefore(animal.dateOfBirth!)) {
          issues.add(DataIssue(
            animalId: animal.id,
            animalName: animal.name,
            severity: IssueSeverity.error,
            code: 'SIRE_BORN_AFTER',
            message: '${animal.name}\'s sire (${sire.name}) was born on or '
                'after this animal.',
          ));
        }
      }
      if (animal.damId != null && lookup.containsKey(animal.damId)) {
        final dam = lookup[animal.damId]!;
        if (dam.dateOfBirth != null &&
            !dam.dateOfBirth!.isBefore(animal.dateOfBirth!)) {
          issues.add(DataIssue(
            animalId: animal.id,
            animalName: animal.name,
            severity: IssueSeverity.error,
            code: 'DAM_BORN_AFTER',
            message: '${animal.name}\'s dam (${dam.name}) was born on or '
                'after this animal.',
          ));
        }
      }

      // Date of death before birth
      if (animal.dateOfDeath != null &&
          animal.dateOfDeath!.isBefore(animal.dateOfBirth!)) {
        issues.add(DataIssue(
          animalId: animal.id,
          animalName: animal.name,
          severity: IssueSeverity.error,
          code: 'DEATH_BEFORE_BIRTH',
          message: '${animal.name}\'s date of death is before date of birth.',
        ));
      }
    }

    // Circular ancestry — walk up the ancestor chain from this animal
    // using the in-memory lookup. Bounded by depth, not total count.
    final visited = <String>{animal.id};
    final ancestorQueue = <String>[];
    if (animal.sireId != null) ancestorQueue.add(animal.sireId!);
    if (animal.damId != null) ancestorQueue.add(animal.damId!);

    while (ancestorQueue.isNotEmpty) {
      final id = ancestorQueue.removeAt(0);
      if (id == animal.id) {
        issues.add(DataIssue(
          animalId: animal.id,
          animalName: animal.name,
          severity: IssueSeverity.error,
          code: 'CIRCULAR_PEDIGREE',
          message: '${animal.name} appears in its own ancestry, '
              'creating a circular pedigree.',
        ));
        break;
      }
      if (visited.contains(id)) continue;
      visited.add(id);

      final ancestor = lookup[id];
      if (ancestor == null) continue;
      if (ancestor.sireId != null) ancestorQueue.add(ancestor.sireId!);
      if (ancestor.damId != null) ancestorQueue.add(ancestor.damId!);
    }
  }
}
