import 'animal.dart';

/// Represents a node in a pedigree tree, linking an animal to its
/// ancestors recursively.
class PedigreeNode {
  final Animal animal;
  final PedigreeNode? sire;
  final PedigreeNode? dam;
  final int generation;

  const PedigreeNode({
    required this.animal,
    this.sire,
    this.dam,
    this.generation = 0,
  });

  /// Returns all ancestors as a flat list.
  List<Animal> get allAncestors {
    final ancestors = <Animal>[];
    if (sire != null) {
      ancestors.add(sire!.animal);
      ancestors.addAll(sire!.allAncestors);
    }
    if (dam != null) {
      ancestors.add(dam!.animal);
      ancestors.addAll(dam!.allAncestors);
    }
    return ancestors;
  }

  /// Returns the number of complete generations in this pedigree.
  int get depth {
    if (sire == null && dam == null) return 0;
    final sireDepth = sire?.depth ?? 0;
    final damDepth = dam?.depth ?? 0;
    return 1 + (sireDepth > damDepth ? sireDepth : damDepth);
  }

  /// Returns all unique ancestor IDs.
  Set<String> get uniqueAncestorIds {
    final ids = <String>{};
    if (sire != null) {
      ids.add(sire!.animal.id);
      ids.addAll(sire!.uniqueAncestorIds);
    }
    if (dam != null) {
      ids.add(dam!.animal.id);
      ids.addAll(dam!.uniqueAncestorIds);
    }
    return ids;
  }

  /// Counts total ancestor slots (filled and empty) for COI calculation.
  int get totalAncestorSlots {
    if (sire == null && dam == null) return 0;
    return 2 + (sire?.totalAncestorSlots ?? 0) + (dam?.totalAncestorSlots ?? 0);
  }
}
