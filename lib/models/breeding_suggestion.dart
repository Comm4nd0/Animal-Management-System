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
