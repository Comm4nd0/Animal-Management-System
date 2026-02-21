import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/animal_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/demo_write_guard.dart';

class WeightRecordsTab extends StatelessWidget {
  final String animalId;
  const WeightRecordsTab({super.key, required this.animalId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AnimalProvider>(
      builder: (context, provider, _) {
        final records = provider.weightRecords;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (!await guardWriteAction(context)) return;
                  _showAddDialog(context, provider);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Weight Entry'),
              ),
            ),
            if (records.length >= 2)
              SizedBox(
                height: 200,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _WeightChart(records: records),
                ),
              ),
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.monitor_weight,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No weight records yet'),
                          const SizedBox(height: 4),
                          Text(
                            'Track growth over time',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.monitor_weight,
                                color: AppTheme.primaryColor),
                            title: Text(
                              [
                                if (record.weight != null)
                                  '${record.weight!.toStringAsFixed(1)} kg',
                                if (record.height != null)
                                  '${record.height!.toStringAsFixed(1)} cm',
                              ].join(' / '),
                            ),
                            subtitle: Text(
                                DateFormat.yMMMd().format(record.date)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () async {
                                if (!await guardWriteAction(context)) return;
                                _confirmDelete(context, provider, record);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, AnimalProvider provider) {
    final weightCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Weight Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'Date: ${DateFormat.yMMMd().format(selectedDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                TextField(
                  controller: weightCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    suffixText: 'kg',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: heightCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    suffixText: 'cm',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final w = double.tryParse(weightCtrl.text);
                final h = double.tryParse(heightCtrl.text);
                if (w == null && h == null) return;
                provider.addWeightRecord(WeightRecord(
                  animalId: animalId,
                  date: selectedDate,
                  weight: w,
                  height: h,
                  notes: notesCtrl.text,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AnimalProvider provider, WeightRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Delete this weight record?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              provider.deleteWeightRecord(record.id, animalId);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<WeightRecord> records;
  const _WeightChart({required this.records});

  @override
  Widget build(BuildContext context) {
    final sorted = List<WeightRecord>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));
    final weightSpots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      if (sorted[i].weight != null) {
        weightSpots.add(FlSpot(i.toDouble(), sorted[i].weight!));
      }
    }
    if (weightSpots.isEmpty) return const SizedBox.shrink();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= sorted.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    DateFormat.MMMd().format(sorted[idx].date),
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text('${value.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 10)),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: weightSpots,
            isCurved: true,
            color: AppTheme.primaryColor,
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
