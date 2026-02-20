import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/animal_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/demo_write_guard.dart';

class LitterListScreen extends StatelessWidget {
  const LitterListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Litters')),
      body: Consumer<AnimalProvider>(
        builder: (context, provider, _) {
          if (provider.litters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.child_friendly,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No litters recorded',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Record litters from breeding results'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: provider.litters.length,
            itemBuilder: (context, index) {
              final litter = provider.litters[index];
              final sire = provider.getAnimalById(litter.sireId);
              final dam = provider.getAnimalById(litter.damId);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.child_friendly,
                              color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${sire?.name ?? "Unknown"} x ${dam?.name ?? "Unknown"}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (litter.registrationNumber != null)
                            Chip(label: Text(litter.registrationNumber!)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Born: ${DateFormat('dd MMM yyyy').format(litter.dateOfBirth)}',
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStat(
                              'Total', '${litter.totalPuppies}', Icons.pets),
                          const SizedBox(width: 16),
                          _buildStat('Males', '${litter.maleCount}', Icons.male,
                              color: AppTheme.maleColor),
                          const SizedBox(width: 16),
                          _buildStat(
                              'Females', '${litter.femaleCount}', Icons.female,
                              color: AppTheme.femaleColor),
                          if (litter.stillborn > 0) ...[
                            const SizedBox(width: 16),
                            _buildStat(
                              'Stillborn',
                              '${litter.stillborn}',
                              Icons.heart_broken,
                              color: Colors.grey,
                            ),
                          ],
                        ],
                      ),
                      if (litter.offspringIds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${litter.offspringIds.length} registered offspring',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (litter.notes != null && litter.notes!.isNotEmpty) ...[
                        const Divider(),
                        Text(
                          litter.notes!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (!await guardWriteAction(context)) return;
          _showAddLitterDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon,
      {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 4),
        Text('$value $label',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ],
    );
  }

  void _showAddLitterDialog(BuildContext context) {
    final provider = context.read<AnimalProvider>();
    String? selectedSireId;
    String? selectedDamId;
    DateTime dateOfBirth = DateTime.now();
    final totalController = TextEditingController();
    final maleController = TextEditingController();
    final femaleController = TextEditingController();
    final stillbornController = TextEditingController(text: '0');
    final notesController = TextEditingController();

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
                      'Record New Litter',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedSireId,
                      decoration: const InputDecoration(labelText: 'Sire *'),
                      items: provider.maleAnimals
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => selectedSireId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedDamId,
                      decoration: const InputDecoration(labelText: 'Dam *'),
                      items: provider.femaleAnimals
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => selectedDamId = v),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text(
                        'Date of Birth: ${DateFormat('dd MMM yyyy').format(dateOfBirth)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: dateOfBirth,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) {
                          setSheetState(() => dateOfBirth = d);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: totalController,
                            decoration:
                                const InputDecoration(labelText: 'Total'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: maleController,
                            decoration:
                                const InputDecoration(labelText: 'Males'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: femaleController,
                            decoration:
                                const InputDecoration(labelText: 'Females'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stillbornController,
                      decoration:
                          const InputDecoration(labelText: 'Stillborn'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (selectedSireId == null || selectedDamId == null) {
                          return;
                        }
                        final litter = Litter(
                          sireId: selectedSireId!,
                          damId: selectedDamId!,
                          dateOfBirth: dateOfBirth,
                          totalPuppies:
                              int.tryParse(totalController.text) ?? 0,
                          maleCount: int.tryParse(maleController.text) ?? 0,
                          femaleCount:
                              int.tryParse(femaleController.text) ?? 0,
                          stillborn:
                              int.tryParse(stillbornController.text) ?? 0,
                          notes: notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
                        );
                        provider.addLitter(litter);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save Litter'),
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
}
