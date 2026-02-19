import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';

class AnimalDetailScreen extends StatefulWidget {
  final String animalId;

  const AnimalDetailScreen({super.key, required this.animalId});

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnimalProvider>().loadHealthRecords(widget.animalId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnimalProvider>(
      builder: (context, provider, _) {
        final animal = provider.getAnimalById(widget.animalId);
        if (animal == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Animal')),
            body: const Center(child: Text('Animal not found')),
          );
        }

        final sire = animal.sireId != null
            ? provider.getAnimalById(animal.sireId!)
            : null;
        final dam = animal.damId != null
            ? provider.getAnimalById(animal.damId!)
            : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(animal.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/animal/edit',
                  arguments: animal.id,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, animal),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'pedigree',
                    child: ListTile(
                      leading: Icon(Icons.account_tree),
                      title: Text('View Pedigree'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'breeding',
                    child: ListTile(
                      leading: Icon(Icons.favorite),
                      title: Text('Breeding Suggestions'),
                    ),
                  ),
                  if (animal.sex == Sex.male)
                    const PopupMenuItem(
                      value: 'stud_matcher',
                      child: ListTile(
                        leading: Icon(Icons.male),
                        title: Text('Find Female Matches'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              _buildHeader(context, animal),
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                tabs: const [
                  Tab(text: 'Info'),
                  Tab(text: 'Health'),
                  Tab(text: 'Lineage'),
                  Tab(text: 'Notes'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInfoTab(context, animal, sire, dam),
                    _buildHealthTab(context, provider),
                    _buildLineageTab(context, animal, sire, dam, provider),
                    _buildNotesTab(context, animal),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Animal animal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: animal.sex == Sex.male
          ? AppTheme.maleColor.withValues(alpha: 0.1)
          : animal.sex == Sex.female
              ? AppTheme.femaleColor.withValues(alpha: 0.1)
              : Colors.grey.shade100,
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: animal.sex == Sex.male
                ? AppTheme.maleColor.withValues(alpha: 0.2)
                : AppTheme.femaleColor.withValues(alpha: 0.2),
            child: Icon(
              animal.sex == Sex.male ? Icons.male : Icons.female,
              size: 36,
              color: animal.sex == Sex.male
                  ? AppTheme.maleColor
                  : AppTheme.femaleColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  animal.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${animal.species} - ${animal.breed}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                ),
                if (animal.ageDisplay != null)
                  Text(
                    animal.ageDisplay!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
              ],
            ),
          ),
          if (animal.status != AnimalStatus.alive)
            Chip(
              label: Text(animal.status.name.toUpperCase()),
              backgroundColor: Colors.orange.shade100,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoTab(
    BuildContext context,
    Animal animal,
    Animal? sire,
    Animal? dam,
  ) {
    final provider = context.read<AnimalProvider>();
    final customFieldDefs = provider.customFieldDefinitions;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection('Registration', [
          if (animal.registrationNumber != null)
            _buildInfoRow('Reg. Number', animal.registrationNumber!),
          if (animal.microchipNumber != null)
            _buildInfoRow('Microchip', animal.microchipNumber!),
          if (animal.dnaProfileId != null)
            _buildInfoRow('DNA Profile', animal.dnaProfileId!),
        ]),
        _buildSection('Physical', [
          if (animal.color != null) _buildInfoRow('Color', animal.color!),
          if (animal.markings != null)
            _buildInfoRow('Markings', animal.markings!),
          if (animal.weight != null)
            _buildInfoRow('Weight', '${animal.weight} kg'),
          if (animal.height != null)
            _buildInfoRow('Height', '${animal.height} cm'),
        ]),
        _buildSection('Breeder & Owner', [
          _buildContactRow('Breeder', animal.breederId, provider),
          _buildContactRow('Owner', animal.currentOwnerId, provider),
        ]),
        if (animal.inbreedingCoefficient > 0)
          _buildSection('Genetics', [
            _buildInfoRow(
              'COI',
              '${animal.inbreedingCoefficient.toStringAsFixed(2)}%',
            ),
          ]),
        // Custom Fields section
        if (animal.customFields.isNotEmpty)
          _buildSection('Custom Fields', [
            ...animal.customFields.entries.map((entry) {
              final def = customFieldDefs
                  .where((d) => d.fieldKey == entry.key)
                  .toList();
              final displayName = def.isNotEmpty ? def.first.name : entry.key;
              final value = entry.value;
              final displayValue = value is bool
                  ? (value ? 'Yes' : 'No')
                  : value.toString();
              return _buildInfoRow(displayName, displayValue);
            }),
          ]),
      ],
    );
  }

  Widget _buildHealthTab(BuildContext context, AnimalProvider provider) {
    final records = provider.healthRecords;
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No health records yet'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                '/health',
                arguments: widget.animalId,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Record'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              '/health',
              arguments: widget.animalId,
            ),
            icon: const Icon(Icons.medical_services),
            label: const Text('Manage Health Records'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    _healthIcon(record.type),
                    color: record.isOverdue ? Colors.red : AppTheme.primaryColor,
                  ),
                  title: Text(record.title),
                  subtitle: Text(record.typeDisplay),
                  trailing: record.isOverdue
                      ? const Chip(
                          label: Text('OVERDUE'),
                          backgroundColor: Colors.red,
                          labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                        )
                      : record.isDueSoon
                          ? const Chip(
                              label: Text('DUE SOON'),
                              backgroundColor: Colors.orange,
                              labelStyle:
                                  TextStyle(color: Colors.white, fontSize: 10),
                            )
                          : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLineageTab(
    BuildContext context,
    Animal animal,
    Animal? sire,
    Animal? dam,
    AnimalProvider provider,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parents',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildParentRow(context, 'Sire (Father)', sire),
                const SizedBox(height: 4),
                _buildParentRow(context, 'Dam (Mother)', dam),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () =>
              Navigator.pushNamed(context, '/pedigree', arguments: animal.id),
          icon: const Icon(Icons.account_tree),
          label: const Text('View Full Pedigree Tree'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(
            context,
            '/breeding/suggestions',
            arguments: animal.id,
          ),
          icon: const Icon(Icons.favorite),
          label: const Text('Get Breeding Suggestions'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.femaleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildParentRow(BuildContext context, String label, Animal? parent) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: parent != null
              ? InkWell(
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/animal/detail',
                    arguments: parent.id,
                  ),
                  child: Text(
                    '${parent.name} (${parent.breed})',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text('Unknown', style: TextStyle(color: Colors.grey.shade500)),
        ),
      ],
    );
  }

  Widget _buildNotesTab(BuildContext context, Animal animal) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: animal.notes != null && animal.notes!.isNotEmpty
          ? Text(animal.notes!, style: Theme.of(context).textTheme.bodyLarge)
          : Center(
              child: Text(
                'No notes for this animal',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(
    String label,
    String? contactId,
    AnimalProvider provider,
  ) {
    final contact = provider.getContactById(contactId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: contact != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (contact.phone.isNotEmpty)
                        Text(
                          contact.phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      if (contact.email.isNotEmpty)
                        Text(
                          contact.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  )
                : Text('Not set',
                    style: TextStyle(color: Colors.grey.shade500)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
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

  void _handleMenuAction(String action, Animal animal) {
    switch (action) {
      case 'pedigree':
        Navigator.pushNamed(context, '/pedigree', arguments: animal.id);
        break;
      case 'breeding':
        Navigator.pushNamed(context, '/breeding/suggestions',
            arguments: animal.id);
        break;
      case 'stud_matcher':
        Navigator.pushNamed(context, '/stud-matcher/preselected',
            arguments: animal.id);
        break;
      case 'delete':
        _confirmDelete(animal);
        break;
    }
  }

  void _confirmDelete(Animal animal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Animal'),
        content: Text('Are you sure you want to delete ${animal.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AnimalProvider>().deleteAnimal(animal.id);
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
