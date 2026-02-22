import 'animal.dart';

/// Represents a suggested breeding pair with compatibility analysis.
class BreedingSuggestion {
  final Animal sire;
  final Animal dam;
  final double compatibilityScore;
  final double estimatedCoi;
  final List<String> pros;
  final List<String> cons;
  final List<String> geneticRisks;
  final Map<String, double> traitPredictions;

  const BreedingSuggestion({
    required this.sire,
    required this.dam,
    required this.compatibilityScore,
    required this.estimatedCoi,
    this.pros = const [],
    this.cons = const [],
    this.geneticRisks = const [],
    this.traitPredictions = const {},
  });

  /// Parse a breeding suggestion from the backend API response.
  factory BreedingSuggestion.fromApi(Map<String, dynamic> json) {
    return BreedingSuggestion(
      sire: _animalFromSuggestionApi(json['sire'] as Map<String, dynamic>),
      dam: _animalFromSuggestionApi(json['dam'] as Map<String, dynamic>),
      compatibilityScore: (json['compatibility_score'] as num).toDouble(),
      estimatedCoi: (json['estimated_coi'] as num).toDouble(),
      pros: List<String>.from(json['pros'] as List? ?? []),
      cons: List<String>.from(json['cons'] as List? ?? []),
      geneticRisks: List<String>.from(json['genetic_risks'] as List? ?? []),
      traitPredictions: (json['trait_predictions'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ) ??
          {},
    );
  }

  /// Parse the lightweight animal object embedded in a suggestion response.
  static Animal _animalFromSuggestionApi(Map<String, dynamic> m) {
    return Animal(
      id: m['id'] as String,
      name: m['name'] as String,
      species: m['species'] as String? ?? '',
      breed: m['breed'] as String? ?? '',
      sex: Sex.values[m['sex'] as int? ?? 0],
      dateOfBirth: m['date_of_birth'] != null
          ? DateTime.tryParse(m['date_of_birth'] as String)
          : null,
      dateOfDeath: m['date_of_death'] != null
          ? DateTime.tryParse(m['date_of_death'] as String)
          : null,
      color: m['color'] as String?,
      registrationNumber: m['registration_number'] as String?,
      sireId: m['sire'] as String?,
      damId: m['dam'] as String?,
      breederId: m['breeder'] as String?,
      currentOwnerId: m['current_owner'] as String?,
      status: AnimalStatus.values[m['status'] as int? ?? 0],
      geneticTraits: {},
      customFields: {},
    );
  }

  String get scoreGrade {
    if (compatibilityScore >= 90) return 'Excellent';
    if (compatibilityScore >= 75) return 'Good';
    if (compatibilityScore >= 60) return 'Fair';
    if (compatibilityScore >= 40) return 'Caution';
    return 'Not Recommended';
  }

  String get coiRating {
    if (estimatedCoi < 3.0) return 'Low';
    if (estimatedCoi < 6.25) return 'Moderate';
    if (estimatedCoi < 12.5) return 'High';
    return 'Very High';
  }

  bool get isRecommended => compatibilityScore >= 60 && estimatedCoi < 12.5;
}
