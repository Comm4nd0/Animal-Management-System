import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/animal_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';

class HealthRecordsScreen extends StatefulWidget {
  final String animalId;

  const HealthRecordsScreen({super.key, required this.animalId});

  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnimalProvider>().loadHealthRecords(widget.animalId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnimalProvider>(
      builder: (context, provider, _) {
        final animal = provider.getAnimalById(widget.animalId);
        return Scaffold(
          appBar: AppBar(
            title: Text('${animal?.name ?? "Animal"} - Health'),
          ),
          body: provider.healthRecords.isEmpty
              ? _buildEmptyState()
              : _buildRecordsList(provider),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddRecordDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No health records',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          const Text('Tap + to add vaccinations, exams, and more'),
        ],
      ),
    );
  }

  Widget _buildRecordsList(AnimalProvider provider) {
    final records = provider.healthRecords;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return Dismissible(
          key: Key(record.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) => showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Record'),
              content: const Text('Are you sure?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ),
          onDismissed: (_) {
            provider.deleteHealthRecord(record.id, widget.animalId);
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: record.isOverdue
                    ? Colors.red.shade50
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Icon(
                  _healthIcon(record.type),
                  color: record.isOverdue ? Colors.red : AppTheme.primaryColor,
                ),
              ),
              title: Text(record.title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${record.typeDisplay} - ${DateFormat('dd MMM yyyy').format(record.date)}'),
                  if (record.veterinarian != null)
                    Text('Vet: ${record.veterinarian}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  if (record.nextDueDate != null)
                    Text(
                      'Next due: ${DateFormat('dd MMM yyyy').format(record.nextDueDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: record.isOverdue
                            ? Colors.red
                            : record.isDueSoon
                                ? Colors.orange
                                : Colors.grey.shade600,
                        fontWeight: record.isOverdue ? FontWeight.bold : null,
                      ),
                    ),
                ],
              ),
              trailing: record.cost != null
                  ? Text(
                      '\$${record.cost!.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  : null,
              isThreeLine: true,
            ),
          ),
        );
      },
    );
  }

  void _showAddRecordDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final vetController = TextEditingController();
    final costController = TextEditingController();
    var selectedType = HealthRecordType.vaccination;
    DateTime selectedDate = DateTime.now();
    DateTime? nextDueDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add Health Record',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<HealthRecordType>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: HealthRecordType.values.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(HealthRecord(
                            animalId: '',
                            type: t,
                            title: '',
                            date: DateTime.now(),
                          ).typeDisplay),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setSheetState(() => selectedType = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: vetController,
                      decoration:
                          const InputDecoration(labelText: 'Veterinarian'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costController,
                      decoration: const InputDecoration(labelText: 'Cost'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text(
                        'Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) {
                          setSheetState(() => selectedDate = d);
                        }
                      },
                    ),
                    ListTile(
                      title: Text(
                        nextDueDate != null
                            ? 'Next due: ${DateFormat('dd MMM yyyy').format(nextDueDate!)}'
                            : 'Next due date (optional)',
                      ),
                      trailing: const Icon(Icons.event),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate:
                              DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (d != null) {
                          setSheetState(() => nextDueDate = d);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (titleController.text.trim().isEmpty) return;
                        final record = HealthRecord(
                          animalId: widget.animalId,
                          type: selectedType,
                          title: titleController.text.trim(),
                          description: descController.text.trim().isEmpty
                              ? null
                              : descController.text.trim(),
                          date: selectedDate,
                          nextDueDate: nextDueDate,
                          veterinarian: vetController.text.trim().isEmpty
                              ? null
                              : vetController.text.trim(),
                          cost: double.tryParse(costController.text),
                        );
                        context
                            .read<AnimalProvider>()
                            .addHealthRecord(record);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save Record'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _healthIcon(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.vaccination:
        return Icons.vaccines;
      case HealthRecordType.examination:
        return Icons.stethoscope;
      case HealthRecordType.surgery:
        return Icons.local_hospital;
      case HealthRecordType.medication:
        return Icons.medication;
      case HealthRecordType.labTest:
        return Icons.science;
      case HealthRecordType.deworming:
        return Icons.bug_report;
      case HealthRecordType.dental:
        return Icons.mood;
      case HealthRecordType.other:
        return Icons.medical_services;
    }
  }
}
