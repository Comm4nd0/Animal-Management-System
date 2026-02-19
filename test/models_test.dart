import 'package:flutter_test/flutter_test.dart';
import 'package:pedigree_manager/models/models.dart';

void main() {
  group('Animal Model', () {
    test('creates animal with required fields', () {
      final animal = Animal(
        name: 'Rex',
        species: 'Dog',
        breed: 'German Shepherd',
        sex: Sex.male,
      );
      expect(animal.name, 'Rex');
      expect(animal.species, 'Dog');
      expect(animal.breed, 'German Shepherd');
      expect(animal.sex, Sex.male);
      expect(animal.id, isNotEmpty);
    });

    test('calculates age display', () {
      final animal = Animal(
        name: 'Bella',
        species: 'Dog',
        breed: 'Labrador',
        sex: Sex.female,
        dateOfBirth: DateTime.now().subtract(const Duration(days: 730)),
      );
      expect(animal.ageDisplay, isNotNull);
      expect(animal.ageDisplay, contains('yr'));
    });

    test('age is null without date of birth', () {
      final animal = Animal(
        name: 'Unknown',
        species: 'Dog',
        breed: 'Mixed',
        sex: Sex.unknown,
      );
      expect(animal.ageDisplay, isNull);
      expect(animal.ageInDays, isNull);
    });

    test('serializes to map and back', () {
      final original = Animal(
        name: 'Max',
        species: 'Dog',
        breed: 'Poodle',
        sex: Sex.male,
        dateOfBirth: DateTime(2020, 1, 15),
        color: 'White',
        weight: 15.5,
      );
      final map = original.toMap();
      final restored = Animal.fromMap(map);
      expect(restored.name, original.name);
      expect(restored.breed, original.breed);
      expect(restored.sex, original.sex);
      expect(restored.color, original.color);
      expect(restored.weight, original.weight);
    });

    test('copyWith creates modified copy', () {
      final original = Animal(
        name: 'Luna',
        species: 'Dog',
        breed: 'Husky',
        sex: Sex.female,
      );
      final modified = original.copyWith(name: 'Luna Star', weight: 25.0);
      expect(modified.name, 'Luna Star');
      expect(modified.weight, 25.0);
      expect(modified.breed, 'Husky');
      expect(modified.id, original.id);
    });

    test('equality by id', () {
      final a = Animal(id: 'abc', name: 'A', species: 'Dog', breed: 'Lab', sex: Sex.male);
      final b = Animal(id: 'abc', name: 'B', species: 'Cat', breed: 'Mix', sex: Sex.female);
      expect(a, equals(b));
    });
  });

  group('HealthRecord Model', () {
    test('detects overdue records', () {
      final record = HealthRecord(
        animalId: 'test',
        type: HealthRecordType.vaccination,
        title: 'Rabies',
        date: DateTime.now().subtract(const Duration(days: 400)),
        nextDueDate: DateTime.now().subtract(const Duration(days: 35)),
      );
      expect(record.isOverdue, true);
      expect(record.isDueSoon, false);
    });

    test('detects due soon records', () {
      final record = HealthRecord(
        animalId: 'test',
        type: HealthRecordType.vaccination,
        title: 'Booster',
        date: DateTime.now().subtract(const Duration(days: 340)),
        nextDueDate: DateTime.now().add(const Duration(days: 15)),
      );
      expect(record.isOverdue, false);
      expect(record.isDueSoon, true);
    });

    test('type display names', () {
      for (final type in HealthRecordType.values) {
        final record = HealthRecord(
          animalId: 'test',
          type: type,
          title: 'Test',
          date: DateTime.now(),
        );
        expect(record.typeDisplay, isNotEmpty);
      }
    });
  });

  group('BreedingSuggestion Model', () {
    test('score grades', () {
      final sire = Animal(name: 'S', species: 'Dog', breed: 'L', sex: Sex.male);
      final dam = Animal(name: 'D', species: 'Dog', breed: 'L', sex: Sex.female);

      expect(
        BreedingSuggestion(sire: sire, dam: dam, compatibilityScore: 95, estimatedCoi: 1).scoreGrade,
        'Excellent',
      );
      expect(
        BreedingSuggestion(sire: sire, dam: dam, compatibilityScore: 80, estimatedCoi: 1).scoreGrade,
        'Good',
      );
      expect(
        BreedingSuggestion(sire: sire, dam: dam, compatibilityScore: 65, estimatedCoi: 1).scoreGrade,
        'Fair',
      );
      expect(
        BreedingSuggestion(sire: sire, dam: dam, compatibilityScore: 45, estimatedCoi: 1).scoreGrade,
        'Caution',
      );
      expect(
        BreedingSuggestion(sire: sire, dam: dam, compatibilityScore: 30, estimatedCoi: 1).scoreGrade,
        'Not Recommended',
      );
    });

    test('COI ratings', () {
      final sire = Animal(name: 'S', species: 'Dog', breed: 'L', sex: Sex.male);
      final dam = Animal(name: 'D', species: 'Dog', breed: 'L', sex: Sex.female);

      expect(
        BreedingSuggestion(sire: sire, dam: dam, compatibilityScore: 90, estimatedCoi: 1).coiRating,
        'Low',
      );
      expect(
        BreedingSuggestion(sire: sire, dam: dam, compatibilityScore: 90, estimatedCoi: 5).coiRating,
        'Moderate',
      );
      expect(
        BreedingSuggestion(sire: sire, dam: dam, compatibilityScore: 90, estimatedCoi: 10).coiRating,
        'High',
      );
      expect(
        BreedingSuggestion(sire: sire, dam: dam, compatibilityScore: 90, estimatedCoi: 15).coiRating,
        'Very High',
      );
    });
  });

  group('PedigreeNode Model', () {
    test('depth calculation', () {
      final grandparent = Animal(name: 'GP', species: 'Dog', breed: 'L', sex: Sex.male);
      final parent = Animal(name: 'P', species: 'Dog', breed: 'L', sex: Sex.male);
      final child = Animal(name: 'C', species: 'Dog', breed: 'L', sex: Sex.male);

      final tree = PedigreeNode(
        animal: child,
        sire: PedigreeNode(
          animal: parent,
          sire: PedigreeNode(animal: grandparent, generation: 2),
          generation: 1,
        ),
        generation: 0,
      );

      expect(tree.depth, 2);
      expect(tree.allAncestors.length, 2);
    });
  });
}
