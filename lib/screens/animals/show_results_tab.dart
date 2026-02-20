import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/animal_provider.dart';
import '../../utils/app_theme.dart';

class ShowResultsTab extends StatelessWidget {
  final String animalId;
  const ShowResultsTab({super.key, required this.animalId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AnimalProvider>(
      builder: (context, provider, _) {
        final results = provider.showResults;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton.icon(
                onPressed: () => _showAddDialog(context, provider),
                icon: const Icon(Icons.add),
                label: const Text('Add Show Result'),
              ),
            ),
            if (results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSummaryCard(results),
              ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No show results yet'),
                          const SizedBox(height: 4),
                          Text(
                            'Record competition achievements',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return Card(
                          child: ListTile(
                            leading: _placementIcon(result.placement),
                            title: Text(result.showName),
                            subtitle: Text(
                              [
                                DateFormat.yMMMd().format(result.showDate),
                                if (result.className.isNotEmpty)
                                  result.className,
                                result.placement.label,
                              ].join(' - '),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _confirmDelete(
                                  context, provider, result),
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

  Widget _buildSummaryCard(List<ShowResult> results) {
    final totalPoints =
        results.fold<double>(0, (sum, r) => sum + (r.points ?? 0));
    final wins = results.where((r) =>
        r.placement == ShowPlacement.first ||
        r.placement == ShowPlacement.champion ||
        r.placement == ShowPlacement.bestInShow).length;

    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatColumn('Shows', results.length.toString()),
            _StatColumn('Wins', wins.toString()),
            _StatColumn('Points', totalPoints.toStringAsFixed(0)),
          ],
        ),
      ),
    );
  }

  Widget _placementIcon(ShowPlacement placement) {
    final icon = switch (placement) {
      ShowPlacement.champion ||
      ShowPlacement.bestInShow =>
        Icons.emoji_events,
      ShowPlacement.first => Icons.looks_one,
      ShowPlacement.second => Icons.looks_two,
      ShowPlacement.third => Icons.looks_3,
      _ => Icons.emoji_events_outlined,
    };
    final color = switch (placement) {
      ShowPlacement.bestInShow => Colors.amber,
      ShowPlacement.champion => Colors.purple,
      ShowPlacement.first => Colors.amber.shade700,
      ShowPlacement.second => Colors.grey.shade400,
      ShowPlacement.third => Colors.brown.shade300,
      _ => Colors.grey,
    };
    return Icon(icon, color: color);
  }

  void _showAddDialog(BuildContext context, AnimalProvider provider) {
    final nameCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    final judgeCtrl = TextEditingController();
    final pointsCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    ShowPlacement selectedPlacement = ShowPlacement.participated;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Show Result'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Show Name *'),
                ),
                const SizedBox(height: 8),
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
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                TextField(
                  controller: classCtrl,
                  decoration: const InputDecoration(labelText: 'Class'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ShowPlacement>(
                  value: selectedPlacement,
                  decoration: const InputDecoration(labelText: 'Placement'),
                  items: ShowPlacement.values
                      .map((p) => DropdownMenuItem(
                          value: p, child: Text(p.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedPlacement = v);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: judgeCtrl,
                  decoration: const InputDecoration(labelText: 'Judge'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pointsCtrl,
                  decoration: const InputDecoration(labelText: 'Points'),
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
                if (nameCtrl.text.isEmpty) return;
                provider.addShowResult(ShowResult(
                  animalId: animalId,
                  showName: nameCtrl.text,
                  showDate: selectedDate,
                  className: classCtrl.text,
                  placement: selectedPlacement,
                  judge: judgeCtrl.text,
                  points: double.tryParse(pointsCtrl.text),
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
      BuildContext context, AnimalProvider provider, ShowResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Result'),
        content: const Text('Delete this show result?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              provider.deleteShowResult(result.id, animalId);
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

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
