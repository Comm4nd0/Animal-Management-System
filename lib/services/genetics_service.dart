import 'dart:math';
import '../models/models.dart';
import 'database_service.dart';

/// Service that handles pedigree tree building, COI calculation,
/// and breeding pair compatibility analysis.
class GeneticsService {
  final DatabaseService _db;

  GeneticsService({DatabaseService? db}) : _db = db ?? DatabaseService();

  // ─── Pedigree Tree ─────────────────────────────────────────────

  /// Builds a pedigree tree for the given animal up to [maxGenerations] deep.
  Future<PedigreeNode?> buildPedigreeTree(
    String animalId, {
    int maxGenerations = 5,
  }) async {
    return _buildNode(animalId, 0, maxGenerations);
  }

  Future<PedigreeNode?> _buildNode(
    String animalId,
    int generation,
    int maxGenerations,
  ) async {
    final animal = await _db.getAnimal(animalId);
    if (animal == null) return null;

    PedigreeNode? sireNode;
    PedigreeNode? damNode;

    if (generation < maxGenerations) {
      if (animal.sireId != null) {
        sireNode = await _buildNode(animal.sireId!, generation + 1, maxGenerations);
      }
      if (animal.damId != null) {
        damNode = await _buildNode(animal.damId!, generation + 1, maxGenerations);
      }
    }

    return PedigreeNode(
      animal: animal,
      sire: sireNode,
      dam: damNode,
      generation: generation,
    );
  }

  // ─── Coefficient of Inbreeding (COI) ──────────────────────────

  /// Calculates Wright's Coefficient of Inbreeding for a hypothetical
  /// mating between sire and dam, or for an existing animal's pedigree.
  ///
  /// Uses a path-based method: for each common ancestor found in both
  /// the sire's and dam's pedigree trees, COI contribution is:
  ///   (0.5)^(n1 + n2 + 1) * (1 + Fa)
  /// where n1 = generations from sire to ancestor,
  ///       n2 = generations from dam to ancestor,
  ///       Fa  = inbreeding coefficient of the common ancestor.
  Future<double> calculateCOI({
    required String sireId,
    required String damId,
    int maxGenerations = 5,
  }) async {
    final sireTree = await buildPedigreeTree(sireId, maxGenerations: maxGenerations);
    final damTree = await buildPedigreeTree(damId, maxGenerations: maxGenerations);

    if (sireTree == null || damTree == null) return 0.0;

    final sireAncestors = _collectAncestorsWithDepth(sireTree, 0);
    final damAncestors = _collectAncestorsWithDepth(damTree, 0);

    // Find common ancestors
    final sireIds = sireAncestors.keys.toSet();
    final damIds = damAncestors.keys.toSet();
    final commonAncestorIds = sireIds.intersection(damIds);

    if (commonAncestorIds.isEmpty) return 0.0;

    double coi = 0.0;
    for (final ancestorId in commonAncestorIds) {
      final sireDepths = sireAncestors[ancestorId]!;
      final damDepths = damAncestors[ancestorId]!;

      for (final n1 in sireDepths) {
        for (final n2 in damDepths) {
          coi += pow(0.5, n1 + n2 + 1);
        }
      }
    }

    return (coi * 100).clamp(0.0, 100.0);
  }

  /// Collects all ancestors with their generational depths from the node.
  Map<String, List<int>> _collectAncestorsWithDepth(
    PedigreeNode node,
    int depth,
  ) {
    final result = <String, List<int>>{};

    if (node.sire != null) {
      result.putIfAbsent(node.sire!.animal.id, () => []).add(depth + 1);
      final sireAncestors = _collectAncestorsWithDepth(node.sire!, depth + 1);
      for (final entry in sireAncestors.entries) {
        result.putIfAbsent(entry.key, () => []).addAll(entry.value);
      }
    }

    if (node.dam != null) {
      result.putIfAbsent(node.dam!.animal.id, () => []).add(depth + 1);
      final damAncestors = _collectAncestorsWithDepth(node.dam!, depth + 1);
      for (final entry in damAncestors.entries) {
        result.putIfAbsent(entry.key, () => []).addAll(entry.value);
      }
    }

    return result;
  }

  // ─── Breeding Suggestions ─────────────────────────────────────

  /// Generates breeding suggestions for a given animal by evaluating
  /// all compatible mates of the opposite sex within the same breed.
  Future<List<BreedingSuggestion>> generateBreedingSuggestions(
    String animalId, {
    int maxResults = 10,
    double maxCoiThreshold = 12.5,
  }) async {
    final animal = await _db.getAnimal(animalId);
    if (animal == null) return [];

    // Get potential mates: opposite sex, same species, alive
    final allAnimals = await _db.getAllAnimals();
    final potentialMates = allAnimals.where((a) =>
        a.id != animalId &&
        a.sex != animal.sex &&
        a.species == animal.species &&
        a.status == AnimalStatus.alive);

    final suggestions = <BreedingSuggestion>[];

    for (final mate in potentialMates) {
      final sire = animal.sex == Sex.male ? animal : mate;
      final dam = animal.sex == Sex.female ? animal : mate;

      final coi = await calculateCOI(
        sireId: sire.id,
        damId: dam.id,
        maxGenerations: 5,
      );

      final analysis = _analyzePairing(sire, dam, coi);

      suggestions.add(BreedingSuggestion(
        sire: sire,
        dam: dam,
        compatibilityScore: analysis['score'] as double,
        estimatedCoi: coi,
        pros: List<String>.from(analysis['pros'] as List),
        cons: List<String>.from(analysis['cons'] as List),
        geneticRisks: List<String>.from(analysis['risks'] as List),
        traitPredictions:
            Map<String, double>.from(analysis['predictions'] as Map),
      ));
    }

    // Sort by compatibility score descending
    suggestions.sort((a, b) => b.compatibilityScore.compareTo(a.compatibilityScore));

    return suggestions.take(maxResults).toList();
  }

  /// Analyzes a potential pairing and returns scores, pros, cons, and risks.
  Map<String, dynamic> _analyzePairing(
    Animal sire,
    Animal dam,
    double coi,
  ) {
    double score = 100.0;
    final pros = <String>[];
    final cons = <String>[];
    final risks = <String>[];
    final predictions = <String, double>{};

    // COI scoring (most important factor)
    if (coi < 3.0) {
      pros.add('Very low inbreeding coefficient (${coi.toStringAsFixed(1)}%)');
    } else if (coi < 6.25) {
      score -= 10;
      pros.add('Acceptable inbreeding coefficient (${coi.toStringAsFixed(1)}%)');
    } else if (coi < 12.5) {
      score -= 30;
      cons.add('Elevated inbreeding coefficient (${coi.toStringAsFixed(1)}%)');
      risks.add('Increased risk of genetic disorders due to inbreeding');
    } else {
      score -= 60;
      cons.add('Very high inbreeding coefficient (${coi.toStringAsFixed(1)}%)');
      risks.add('Significant risk of inbreeding depression');
      risks.add('High probability of homozygous genetic defects');
    }

    // Breed compatibility
    if (sire.breed == dam.breed) {
      pros.add('Same breed - predictable offspring type');
    } else {
      score -= 5;
      cons.add('Different breeds - offspring traits less predictable');
      predictions['breed_consistency'] = 0.5;
    }

    // Age considerations
    final sireAge = sire.ageInDays;
    final damAge = dam.ageInDays;
    if (sireAge != null && damAge != null) {
      final sireYears = sireAge / 365;
      final damYears = damAge / 365;

      if (sireYears >= 2 && sireYears <= 8) {
        pros.add('Sire is in prime breeding age');
      } else if (sireYears < 1) {
        score -= 20;
        cons.add('Sire may be too young for breeding');
        risks.add('Immature sire may affect offspring quality');
      } else if (sireYears > 10) {
        score -= 10;
        cons.add('Sire is of advanced age');
      }

      if (damYears >= 2 && damYears <= 7) {
        pros.add('Dam is in prime breeding age');
      } else if (damYears < 1.5) {
        score -= 25;
        cons.add('Dam may be too young for breeding');
        risks.add('Early breeding can harm dam health');
      } else if (damYears > 8) {
        score -= 15;
        cons.add('Dam is of advanced age');
        risks.add('Higher risk of complications for older dam');
      }
    }

    // Health check - if both have health data that is recent
    if (sire.weight != null && dam.weight != null) {
      final weightRatio = sire.weight! / dam.weight!;
      if (weightRatio > 1.5) {
        cons.add('Significant size difference between sire and dam');
        risks.add('Size disparity may cause whelping difficulties');
        score -= 10;
      }
      predictions['avg_offspring_weight'] =
          (sire.weight! + dam.weight!) / 2;
    }

    // Genetic diversity bonus for animals from different breeders
    if (sire.breederId != null &&
        dam.breederId != null &&
        sire.breederId != dam.breederId) {
      pros.add('Different breeders - promotes genetic diversity');
      score += 5;
    }

    return {
      'score': score.clamp(0.0, 100.0),
      'pros': pros,
      'cons': cons,
      'risks': risks,
      'predictions': predictions,
    };
  }

  // ─── Lineage Analysis ─────────────────────────────────────────

  /// Returns all offspring (direct and descendants) for an animal.
  Future<List<Animal>> getDescendants(String animalId, {int maxDepth = 5}) async {
    final descendants = <Animal>[];
    await _collectDescendants(animalId, descendants, 0, maxDepth);
    return descendants;
  }

  Future<void> _collectDescendants(
    String animalId,
    List<Animal> descendants,
    int depth,
    int maxDepth,
  ) async {
    if (depth >= maxDepth) return;
    final offspring = await _db.getOffspring(animalId);
    for (final child in offspring) {
      if (!descendants.any((d) => d.id == child.id)) {
        descendants.add(child);
        await _collectDescendants(child.id, descendants, depth + 1, maxDepth);
      }
    }
  }

  /// Checks if two animals share common ancestors.
  Future<List<Animal>> findCommonAncestors(
    String animalId1,
    String animalId2, {
    int maxGenerations = 5,
  }) async {
    final tree1 = await buildPedigreeTree(animalId1, maxGenerations: maxGenerations);
    final tree2 = await buildPedigreeTree(animalId2, maxGenerations: maxGenerations);

    if (tree1 == null || tree2 == null) return [];

    final ancestors1 = tree1.uniqueAncestorIds;
    final ancestors2 = tree2.uniqueAncestorIds;
    final commonIds = ancestors1.intersection(ancestors2);

    final commonAnimals = <Animal>[];
    for (final id in commonIds) {
      final animal = await _db.getAnimal(id);
      if (animal != null) commonAnimals.add(animal);
    }
    return commonAnimals;
  }
}
