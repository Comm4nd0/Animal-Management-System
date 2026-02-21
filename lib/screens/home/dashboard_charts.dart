import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';

// ─── Chart colour palette ────────────────────────────────────────
const _chartColors = [
  Color(0xFF2E7D32), // green
  Color(0xFF42A5F5), // blue
  Color(0xFFEF5350), // red
  Color(0xFFFFA726), // orange
  Color(0xFF7E57C2), // purple
  Color(0xFF26C6DA), // cyan
  Color(0xFFEC407A), // pink
  Color(0xFF66BB6A), // light green
  Color(0xFF5C6BC0), // indigo
  Color(0xFFFFCA28), // amber
  Color(0xFF78909C), // grey-blue
];

// ═══════════════════════════════════════════════════════════════════
// 1. Registration Timeline – Line chart of animals added per month
// ═══════════════════════════════════════════════════════════════════

class RegistrationTimelineChart extends StatelessWidget {
  final List<Animal> animals;
  const RegistrationTimelineChart({super.key, required this.animals});

  @override
  Widget build(BuildContext context) {
    if (animals.isEmpty) return const SizedBox.shrink();

    // Group by year-month
    final counts = <String, int>{};
    for (final a in animals) {
      final key =
          '${a.createdAt.year}-${a.createdAt.month.toString().padLeft(2, '0')}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final sortedKeys = counts.keys.toList()..sort();
    if (sortedKeys.length < 2) {
      // Need at least 2 points for a meaningful line
      return _ChartCard(
        title: 'Animals Added Over Time',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${animals.length} animal${animals.length == 1 ? '' : 's'} registered',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < sortedKeys.length; i++) {
      spots.add(FlSpot(i.toDouble(), counts[sortedKeys[i]]!.toDouble()));
    }

    final maxY = spots.map((s) => s.y).reduce(max);

    return _ChartCard(
      title: 'Animals Added Over Time',
      child: SizedBox(
        height: 200,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, top: 8),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: max(1, (maxY / 4).ceilToDouble()),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: max(1, (maxY / 4).ceilToDouble()),
                    getTitlesWidget: (value, _) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: max(1, (sortedKeys.length / 5).ceilToDouble()),
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= sortedKeys.length) {
                        return const SizedBox.shrink();
                      }
                      final parts = sortedKeys[idx].split('-');
                      return Text(
                        '${parts[1]}/${parts[0].substring(2)}',
                        style: const TextStyle(fontSize: 9),
                      );
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: AppTheme.primaryColor,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: spots.length <= 12,
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            '${sortedKeys[s.x.toInt()]}\n${s.y.toInt()} added',
                            const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 2. Sex Distribution – Pie chart
// ═══════════════════════════════════════════════════════════════════

class SexDistributionChart extends StatelessWidget {
  final List<Animal> animals;
  const SexDistributionChart({super.key, required this.animals});

  @override
  Widget build(BuildContext context) {
    if (animals.isEmpty) return const SizedBox.shrink();

    final males = animals.where((a) => a.sex == Sex.male).length;
    final females = animals.where((a) => a.sex == Sex.female).length;
    final unknown = animals.where((a) => a.sex == Sex.unknown).length;
    final total = animals.length;

    final sections = <PieChartSectionData>[];
    final legends = <_LegendItem>[];

    if (males > 0) {
      sections.add(PieChartSectionData(
        value: males.toDouble(),
        title: '${(males / total * 100).round()}%',
        color: AppTheme.maleColor,
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      legends.add(_LegendItem('Males ($males)', AppTheme.maleColor));
    }
    if (females > 0) {
      sections.add(PieChartSectionData(
        value: females.toDouble(),
        title: '${(females / total * 100).round()}%',
        color: AppTheme.femaleColor,
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      legends.add(_LegendItem('Females ($females)', AppTheme.femaleColor));
    }
    if (unknown > 0) {
      sections.add(PieChartSectionData(
        value: unknown.toDouble(),
        title: '${(unknown / total * 100).round()}%',
        color: Colors.grey,
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      legends.add(_LegendItem('Unknown ($unknown)', Colors.grey));
    }

    return _ChartCard(
      title: 'Sex Distribution',
      child: SizedBox(
        height: 180,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: legends
                    .map((l) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: l.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(l.label,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 3. Breed Distribution – Horizontal bar chart
// ═══════════════════════════════════════════════════════════════════

class BreedDistributionChart extends StatelessWidget {
  final List<Animal> animals;
  const BreedDistributionChart({super.key, required this.animals});

  @override
  Widget build(BuildContext context) {
    if (animals.isEmpty) return const SizedBox.shrink();

    final counts = <String, int>{};
    for (final a in animals) {
      counts[a.breed] = (counts[a.breed] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    final maxVal = top.first.value.toDouble();

    return _ChartCard(
      title: 'Breed Distribution',
      child: SizedBox(
        height: max(120, top.length * 36.0),
        child: Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.15,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, gIdx, rod, rIdx) =>
                      BarTooltipItem(
                    '${top[group.x.toInt()].key}: ${rod.toY.toInt()}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= top.length) {
                        return const SizedBox.shrink();
                      }
                      final label = top[idx].key;
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: SizedBox(
                          width: 60,
                          child: Text(
                            label.length > 10
                                ? '${label.substring(0, 9)}...'
                                : label,
                            style: const TextStyle(fontSize: 9),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(top.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: top[i].value.toDouble(),
                      color: _chartColors[i % _chartColors.length],
                      width: 22,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 4. Age Distribution – Bar chart
// ═══════════════════════════════════════════════════════════════════

class AgeDistributionChart extends StatelessWidget {
  final List<Animal> animals;
  const AgeDistributionChart({super.key, required this.animals});

  @override
  Widget build(BuildContext context) {
    if (animals.isEmpty) return const SizedBox.shrink();

    final buckets = <String, int>{
      '< 1 yr': 0,
      '1-2 yrs': 0,
      '3-5 yrs': 0,
      '6-9 yrs': 0,
      '10+ yrs': 0,
    };
    int unknownCount = 0;

    for (final a in animals) {
      if (a.dateOfBirth == null) {
        unknownCount++;
        continue;
      }
      final days = DateTime.now().difference(a.dateOfBirth!).inDays;
      final years = days / 365.25;
      if (years < 1) {
        buckets['< 1 yr'] = buckets['< 1 yr']! + 1;
      } else if (years < 3) {
        buckets['1-2 yrs'] = buckets['1-2 yrs']! + 1;
      } else if (years < 6) {
        buckets['3-5 yrs'] = buckets['3-5 yrs']! + 1;
      } else if (years < 10) {
        buckets['6-9 yrs'] = buckets['6-9 yrs']! + 1;
      } else {
        buckets['10+ yrs'] = buckets['10+ yrs']! + 1;
      }
    }

    final entries = buckets.entries.toList();
    if (unknownCount > 0) {
      entries.add(MapEntry('Unknown', unknownCount));
    }
    // Remove empty buckets
    entries.removeWhere((e) => e.value == 0);
    if (entries.isEmpty) return const SizedBox.shrink();

    final maxVal = entries.map((e) => e.value).reduce(max).toDouble();

    return _ChartCard(
      title: 'Age Distribution',
      child: SizedBox(
        height: 180,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.2,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: max(1, (maxVal / 4).ceilToDouble()),
                    getTitlesWidget: (value, _) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        entries[idx].key,
                        style: const TextStyle(fontSize: 9),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: max(1, (maxVal / 4).ceilToDouble()),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(entries.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: entries[i].value.toDouble(),
                      color: AppTheme.primaryColor,
                      width: 28,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 5. Genetic Diversity – Summary card with key metrics
// ═══════════════════════════════════════════════════════════════════

class GeneticDiversityCard extends StatelessWidget {
  final List<Animal> animals;
  const GeneticDiversityCard({super.key, required this.animals});

  @override
  Widget build(BuildContext context) {
    if (animals.isEmpty) return const SizedBox.shrink();

    final total = animals.length;
    final withSire = animals.where((a) => a.sireId != null).length;
    final withDam = animals.where((a) => a.damId != null).length;
    final uniqueSires = animals
        .where((a) => a.sireId != null)
        .map((a) => a.sireId!)
        .toSet()
        .length;
    final uniqueDams = animals
        .where((a) => a.damId != null)
        .map((a) => a.damId!)
        .toSet()
        .length;

    // COI values from genetic traits
    final coiValues = <double>[];
    for (final a in animals) {
      final coi = a.geneticTraits['coi'];
      if (coi != null) {
        final val = coi is num ? coi.toDouble() : double.tryParse(coi.toString());
        if (val != null) coiValues.add(val);
      }
    }
    final avgCoi = coiValues.isNotEmpty
        ? coiValues.reduce((a, b) => a + b) / coiValues.length
        : null;

    // Effective population size: Ne = (4 * Nm * Nf) / (Nm + Nf)
    double? effectivePopSize;
    if (uniqueSires > 0 && uniqueDams > 0) {
      effectivePopSize =
          (4 * uniqueSires * uniqueDams) / (uniqueSires + uniqueDams);
    }

    // Sire/dam usage ratio (lower = more concentrated breeding)
    final sireRatio = withSire > 0 ? uniqueSires / withSire : 0.0;
    final damRatio = withDam > 0 ? uniqueDams / withDam : 0.0;

    return _ChartCard(
      title: 'Genetic Diversity',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            // Diversity bars
            if (withSire > 0 || withDam > 0) ...[
              _DiversityBar(
                label: 'Sire diversity',
                value: sireRatio,
                subtitle: '$uniqueSires unique sires across $withSire animals',
                color: AppTheme.maleColor,
              ),
              const SizedBox(height: 12),
              _DiversityBar(
                label: 'Dam diversity',
                value: damRatio,
                subtitle: '$uniqueDams unique dams across $withDam animals',
                color: AppTheme.femaleColor,
              ),
              const SizedBox(height: 16),
            ],
            // Stat chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  label: 'Total',
                  value: '$total',
                  icon: Icons.pets,
                ),
                if (effectivePopSize != null)
                  _MetricChip(
                    label: 'Eff. Pop Size',
                    value: effectivePopSize.toStringAsFixed(1),
                    icon: Icons.group,
                  ),
                if (avgCoi != null)
                  _MetricChip(
                    label: 'Avg COI',
                    value: '${(avgCoi * 100).toStringAsFixed(2)}%',
                    icon: Icons.science,
                    color: avgCoi > 0.0625
                        ? AppTheme.errorColor
                        : avgCoi > 0.03
                            ? AppTheme.accentColor
                            : AppTheme.primaryColor,
                  ),
                _MetricChip(
                  label: 'Pedigree coverage',
                  value: '${((withSire + withDam) / (total * 2) * 100).round()}%',
                  icon: Icons.account_tree,
                ),
              ],
            ),
            if (withSire == 0 && withDam == 0)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Add sire/dam data to see genetic diversity metrics',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiversityBar extends StatelessWidget {
  final String label;
  final double value; // 0.0 to 1.0
  final String subtitle;
  final Color color;

  const _DiversityBar({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${(value * 100).round()}%',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: chipColor),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 6. Status Distribution – Pie chart
// ═══════════════════════════════════════════════════════════════════

class StatusDistributionChart extends StatelessWidget {
  final List<Animal> animals;
  const StatusDistributionChart({super.key, required this.animals});

  @override
  Widget build(BuildContext context) {
    if (animals.isEmpty) return const SizedBox.shrink();

    final statusData = <AnimalStatus, int>{};
    for (final a in animals) {
      statusData[a.status] = (statusData[a.status] ?? 0) + 1;
    }
    // Only show if there's more than one status
    if (statusData.length <= 1) return const SizedBox.shrink();

    final total = animals.length;
    final statusMeta = {
      AnimalStatus.alive: ('Alive', const Color(0xFF66BB6A)),
      AnimalStatus.deceased: ('Deceased', const Color(0xFF78909C)),
      AnimalStatus.sold: ('Sold', const Color(0xFFFFA726)),
      AnimalStatus.transferred: ('Transferred', const Color(0xFF42A5F5)),
    };

    final sections = <PieChartSectionData>[];
    final legends = <_LegendItem>[];

    for (final entry in statusData.entries) {
      final meta = statusMeta[entry.key]!;
      sections.add(PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${(entry.value / total * 100).round()}%',
        color: meta.$2,
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      legends.add(_LegendItem('${meta.$1} (${entry.value})', meta.$2));
    }

    return _ChartCard(
      title: 'Status Breakdown',
      child: SizedBox(
        height: 180,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: legends
                    .map((l) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: l.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(l.label,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 7. Health Reminders – Upcoming & overdue health records
// ═══════════════════════════════════════════════════════════════════

class HealthRemindersCard extends StatelessWidget {
  final List<HealthRecord> upcoming;
  final List<HealthRecord> overdue;
  final List<Animal> animals;

  const HealthRemindersCard({
    super.key,
    required this.upcoming,
    required this.overdue,
    required this.animals,
  });

  String _animalName(String animalId) {
    try {
      return animals.firstWhere((a) => a.id == animalId).name;
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (upcoming.isEmpty && overdue.isEmpty) return const SizedBox.shrink();

    return _ChartCard(
      title: 'Health Reminders',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overdue.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppTheme.errorColor),
                  const SizedBox(width: 6),
                  Text(
                    '${overdue.length} overdue',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            ...overdue.take(3).map((r) => _ReminderTile(
                  record: r,
                  animalName: _animalName(r.animalId),
                  isOverdue: true,
                )),
            if (overdue.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  '+${overdue.length - 3} more overdue',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            if (upcoming.isNotEmpty)
              const Divider(height: 20),
          ],
          if (upcoming.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: AppTheme.accentColor),
                  const SizedBox(width: 6),
                  Text(
                    '${upcoming.length} upcoming (next 30 days)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            ...upcoming.take(5).map((r) => _ReminderTile(
                  record: r,
                  animalName: _animalName(r.animalId),
                  isOverdue: false,
                )),
            if (upcoming.length > 5)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  '+${upcoming.length - 5} more upcoming',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final HealthRecord record;
  final String animalName;
  final bool isOverdue;

  const _ReminderTile({
    required this.record,
    required this.animalName,
    required this.isOverdue,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOverdue ? AppTheme.errorColor : AppTheme.accentColor;
    final dueText = record.nextDueDate != null
        ? '${record.nextDueDate!.day}/${record.nextDueDate!.month}/${record.nextDueDate!.year}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$animalName  \u2022  Due: $dueText',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;
  const _LegendItem(this.label, this.color);
}

// ═══════════════════════════════════════════════════════════════════
// Aggregated chart widgets – use pre-computed API data instead of
// iterating through all animals in memory.
// ═══════════════════════════════════════════════════════════════════

class AggregatedTimelineChart extends StatelessWidget {
  final List<TimelineEntry> data;
  const AggregatedTimelineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) {
      return _ChartCard(
        title: 'Animals Added Over Time',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              data.isEmpty
                  ? 'No data yet'
                  : '${data.first.count} animal${data.first.count == 1 ? '' : 's'} registered',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].count.toDouble()));
    }
    final maxY = spots.map((s) => s.y).reduce(max);

    return _ChartCard(
      title: 'Animals Added Over Time',
      child: SizedBox(
        height: 200,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, top: 8),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: max(1, (maxY / 4).ceilToDouble()),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: max(1, (maxY / 4).ceilToDouble()),
                    getTitlesWidget: (value, _) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: max(1, (data.length / 5).ceilToDouble()),
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= data.length) {
                        return const SizedBox.shrink();
                      }
                      final parts = data[idx].month.split('-');
                      if (parts.length < 2) return const SizedBox.shrink();
                      return Text(
                        '${parts[1]}/${parts[0].substring(2)}',
                        style: const TextStyle(fontSize: 9),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: AppTheme.primaryColor,
                  barWidth: 3,
                  dotData: FlDotData(show: spots.length <= 12),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            '${data[s.x.toInt()].month}\n${s.y.toInt()} added',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AggregatedPieChart extends StatelessWidget {
  final String title;
  final List<ChartEntry> data;
  const AggregatedPieChart({super.key, required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.length <= 1) return const SizedBox.shrink();

    final total = data.fold<int>(0, (sum, e) => sum + e.value);
    if (total == 0) return const SizedBox.shrink();

    final sections = <PieChartSectionData>[];
    final legends = <_LegendItem>[];

    for (var i = 0; i < data.length; i++) {
      final entry = data[i];
      if (entry.value <= 0) continue;
      final color = _chartColors[i % _chartColors.length];
      sections.add(PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${(entry.value / total * 100).round()}%',
        color: color,
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      legends.add(_LegendItem('${entry.label} (${entry.value})', color));
    }

    return _ChartCard(
      title: title,
      child: SizedBox(
        height: 180,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: PieChart(PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              )),
            ),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: legends
                    .map((l) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: l.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(l.label,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AggregatedBarChart extends StatelessWidget {
  final String title;
  final List<ChartEntry> data;
  const AggregatedBarChart({super.key, required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxVal = data.map((e) => e.value).reduce(max).toDouble();
    if (maxVal == 0) return const SizedBox.shrink();

    return _ChartCard(
      title: title,
      child: SizedBox(
        height: max(120, data.length * 36.0),
        child: Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.15,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, gIdx, rod, rIdx) => BarTooltipItem(
                    '${data[group.x.toInt()].label}: ${rod.toY.toInt()}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= data.length) {
                        return const SizedBox.shrink();
                      }
                      final label = data[idx].label;
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: SizedBox(
                          width: 60,
                          child: Text(
                            label.length > 10
                                ? '${label.substring(0, 9)}...'
                                : label,
                            style: const TextStyle(fontSize: 9),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(data.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].value.toDouble(),
                      color: _chartColors[i % _chartColors.length],
                      width: 22,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class AggregatedGeneticDiversityCard extends StatelessWidget {
  final GeneticDiversityStats stats;
  const AggregatedGeneticDiversityCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.totalAnimals == 0) return const SizedBox.shrink();

    return _ChartCard(
      title: 'Genetic Diversity',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            if (stats.animalsWithSire > 0 || stats.animalsWithDam > 0) ...[
              _DiversityBar(
                label: 'Sire diversity',
                value: stats.sireRatio,
                subtitle: '${stats.uniqueSires} unique sires across ${stats.animalsWithSire} animals',
                color: AppTheme.maleColor,
              ),
              const SizedBox(height: 12),
              _DiversityBar(
                label: 'Dam diversity',
                value: stats.damRatio,
                subtitle: '${stats.uniqueDams} unique dams across ${stats.animalsWithDam} animals',
                color: AppTheme.femaleColor,
              ),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  label: 'Total',
                  value: '${stats.totalAnimals}',
                  icon: Icons.pets,
                ),
                if (stats.effectivePopulationSize != null)
                  _MetricChip(
                    label: 'Eff. Pop Size',
                    value: stats.effectivePopulationSize!.toStringAsFixed(1),
                    icon: Icons.group,
                  ),
                if (stats.averageCoi != null)
                  _MetricChip(
                    label: 'Avg COI',
                    value: '${(stats.averageCoi! * 100).toStringAsFixed(2)}%',
                    icon: Icons.science,
                    color: stats.averageCoi! > 0.0625
                        ? AppTheme.errorColor
                        : stats.averageCoi! > 0.03
                            ? AppTheme.accentColor
                            : AppTheme.primaryColor,
                  ),
                _MetricChip(
                  label: 'Pedigree coverage',
                  value: '${(stats.pedigreeCoverage * 100).round()}%',
                  icon: Icons.account_tree,
                ),
              ],
            ),
            if (stats.animalsWithSire == 0 && stats.animalsWithDam == 0)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Add sire/dam data to see genetic diversity metrics',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AggregatedHealthRemindersCard extends StatelessWidget {
  final HealthReminderData reminders;
  const AggregatedHealthRemindersCard({super.key, required this.reminders});

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) return const SizedBox.shrink();

    return _ChartCard(
      title: 'Health Reminders',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reminders.overdue.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppTheme.errorColor),
                  const SizedBox(width: 6),
                  Text(
                    '${reminders.overdue.length} overdue',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            ...reminders.overdue.take(3).map((r) => _AggregatedReminderTile(
                  entry: r,
                  isOverdue: true,
                )),
            if (reminders.overdue.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  '+${reminders.overdue.length - 3} more overdue',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            if (reminders.upcoming.isNotEmpty) const Divider(height: 20),
          ],
          if (reminders.upcoming.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: AppTheme.accentColor),
                  const SizedBox(width: 6),
                  Text(
                    '${reminders.upcoming.length} upcoming (next 30 days)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            ...reminders.upcoming.take(5).map((r) => _AggregatedReminderTile(
                  entry: r,
                  isOverdue: false,
                )),
            if (reminders.upcoming.length > 5)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  '+${reminders.upcoming.length - 5} more upcoming',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AggregatedReminderTile extends StatelessWidget {
  final HealthReminderEntry entry;
  final bool isOverdue;

  const _AggregatedReminderTile({
    required this.entry,
    required this.isOverdue,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOverdue ? AppTheme.errorColor : AppTheme.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${entry.animalName}  \u2022  Due: ${entry.nextDueDate}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
