/// Pre-aggregated dashboard statistics from the API.
///
/// This avoids loading all animal records into memory just to compute
/// counts and chart data on the client.
class DashboardStats {
  final Map<String, int> counts;
  final List<TimelineEntry> registrationTimeline;
  final List<ChartEntry> sexDistribution;
  final List<ChartEntry> statusDistribution;
  final List<ChartEntry> breedDistribution;
  final List<ChartEntry> ageDistribution;
  final GeneticDiversityStats geneticDiversity;
  final List<ChartEntry> healthSummary;
  final List<Map<String, dynamic>> recentAnimals;
  final HealthReminderData healthReminders;
  final List<Map<String, dynamic>> activeBreedings;

  const DashboardStats({
    required this.counts,
    required this.registrationTimeline,
    required this.sexDistribution,
    required this.statusDistribution,
    required this.breedDistribution,
    required this.ageDistribution,
    required this.geneticDiversity,
    required this.healthSummary,
    required this.recentAnimals,
    required this.healthReminders,
    required this.activeBreedings,
  });

  factory DashboardStats.fromApi(Map<String, dynamic> json) {
    final statsMap = json['stats'] as Map<String, dynamic>? ?? {};
    return DashboardStats(
      counts: statsMap.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      registrationTimeline: (json['registration_timeline'] as List? ?? [])
          .map((e) => TimelineEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      sexDistribution: _parseChartEntries(json['sex_distribution']),
      statusDistribution: _parseChartEntries(json['status_distribution']),
      breedDistribution: _parseChartEntries(json['breed_distribution']),
      ageDistribution: _parseChartEntries(json['age_distribution']),
      geneticDiversity: GeneticDiversityStats.fromJson(
        json['genetic_diversity'] as Map<String, dynamic>? ?? {},
      ),
      healthSummary: _parseChartEntries(json['health_summary']),
      recentAnimals: (json['recent_animals'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      healthReminders: HealthReminderData.fromJson(
        json['health_reminders'] as Map<String, dynamic>? ?? {},
      ),
      activeBreedings: (json['active_breedings'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  static List<ChartEntry> _parseChartEntries(dynamic data) {
    if (data == null) return [];
    return (data as List)
        .map((e) => ChartEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  bool get isEmpty => (counts['total'] ?? 0) == 0;
}

class TimelineEntry {
  final String month;
  final int count;

  const TimelineEntry({required this.month, required this.count});

  factory TimelineEntry.fromJson(Map<String, dynamic> json) {
    return TimelineEntry(
      month: json['month'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChartEntry {
  final String label;
  final int value;

  const ChartEntry({required this.label, required this.value});

  factory ChartEntry.fromJson(Map<String, dynamic> json) {
    return ChartEntry(
      label: json['label'] as String? ?? '',
      value: (json['value'] as num?)?.toInt() ?? 0,
    );
  }
}

class GeneticDiversityStats {
  final int totalAnimals;
  final int uniqueSires;
  final int uniqueDams;
  final int animalsWithSire;
  final int animalsWithDam;
  final double? averageCoi;
  final int coiSampleSize;
  final double? effectivePopulationSize;

  const GeneticDiversityStats({
    required this.totalAnimals,
    required this.uniqueSires,
    required this.uniqueDams,
    required this.animalsWithSire,
    required this.animalsWithDam,
    this.averageCoi,
    required this.coiSampleSize,
    this.effectivePopulationSize,
  });

  factory GeneticDiversityStats.fromJson(Map<String, dynamic> json) {
    return GeneticDiversityStats(
      totalAnimals: (json['total_animals'] as num?)?.toInt() ?? 0,
      uniqueSires: (json['unique_sires'] as num?)?.toInt() ?? 0,
      uniqueDams: (json['unique_dams'] as num?)?.toInt() ?? 0,
      animalsWithSire: (json['animals_with_sire'] as num?)?.toInt() ?? 0,
      animalsWithDam: (json['animals_with_dam'] as num?)?.toInt() ?? 0,
      averageCoi: (json['average_coi'] as num?)?.toDouble(),
      coiSampleSize: (json['coi_sample_size'] as num?)?.toInt() ?? 0,
      effectivePopulationSize: (json['effective_population_size'] as num?)?.toDouble(),
    );
  }

  double get sireRatio =>
      animalsWithSire > 0 ? uniqueSires / animalsWithSire : 0.0;
  double get damRatio =>
      animalsWithDam > 0 ? uniqueDams / animalsWithDam : 0.0;
  double get pedigreeCoverage =>
      totalAnimals > 0
          ? (animalsWithSire + animalsWithDam) / (totalAnimals * 2)
          : 0.0;
}

class HealthReminderData {
  final List<HealthReminderEntry> overdue;
  final List<HealthReminderEntry> upcoming;

  const HealthReminderData({required this.overdue, required this.upcoming});

  factory HealthReminderData.fromJson(Map<String, dynamic> json) {
    return HealthReminderData(
      overdue: (json['overdue'] as List? ?? [])
          .map((e) => HealthReminderEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      upcoming: (json['upcoming'] as List? ?? [])
          .map((e) => HealthReminderEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isEmpty => overdue.isEmpty && upcoming.isEmpty;
}

class HealthReminderEntry {
  final String id;
  final String title;
  final String animalId;
  final String animalName;
  final String nextDueDate;
  final int type;

  const HealthReminderEntry({
    required this.id,
    required this.title,
    required this.animalId,
    required this.animalName,
    required this.nextDueDate,
    required this.type,
  });

  factory HealthReminderEntry.fromJson(Map<String, dynamic> json) {
    return HealthReminderEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      animalId: json['animal_id'] as String? ?? '',
      animalName: json['animal_name'] as String? ?? '',
      nextDueDate: json['next_due_date'] as String? ?? '',
      type: (json['type'] as num?)?.toInt() ?? 0,
    );
  }
}
