import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/animal_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/demo_write_guard.dart';
import 'weight_records_tab.dart';
import 'show_results_tab.dart';
import 'financial_records_tab.dart';
import 'documents_tab.dart';

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
    _tabController = TabController(length: 9, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AnimalProvider>();
      p.loadHealthRecords(widget.animalId);
      p.loadAnimalImages(widget.animalId);
      p.loadWeightRecords(widget.animalId);
      p.loadShowResults(widget.animalId);
      p.loadFinancialRecords(widget.animalId);
      p.loadDocumentAttachments(widget.animalId);
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
                onPressed: () async {
                  if (!await guardWriteAction(context)) return;
                  Navigator.pushNamed(
                    context,
                    '/animals/${animal.id}/edit',
                  );
                },
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
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Info'),
                  Tab(text: 'Photos'),
                  Tab(text: 'Health'),
                  Tab(text: 'Growth'),
                  Tab(text: 'Shows'),
                  Tab(text: 'Finances'),
                  Tab(text: 'Docs'),
                  Tab(text: 'Lineage'),
                  Tab(text: 'Notes'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInfoTab(context, animal, sire, dam),
                    _buildPhotosTab(context, animal, provider),
                    _buildHealthTab(context, provider),
                    WeightRecordsTab(animalId: widget.animalId),
                    ShowResultsTab(animalId: widget.animalId),
                    FinancialRecordsTab(animalId: widget.animalId),
                    DocumentsTab(animalId: widget.animalId),
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
    final provider = context.read<AnimalProvider>();
    final profilePath = provider.getProfileImagePath(animal.id);
    final hasProfileImage =
        profilePath != null && File(profilePath).existsSync();

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
          GestureDetector(
            onTap: hasProfileImage
                ? () => _showFullImage(context, profilePath!)
                : null,
            child: CircleAvatar(
              radius: 36,
              backgroundColor: animal.sex == Sex.male
                  ? AppTheme.maleColor.withValues(alpha: 0.2)
                  : AppTheme.femaleColor.withValues(alpha: 0.2),
              backgroundImage: hasProfileImage
                  ? FileImage(File(profilePath!))
                  : null,
              child: hasProfileImage
                  ? null
                  : Icon(
                      animal.sex == Sex.male ? Icons.male : Icons.female,
                      size: 36,
                      color: animal.sex == Sex.male
                          ? AppTheme.maleColor
                          : AppTheme.femaleColor,
                    ),
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
                '/health/${widget.animalId}',
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
              '/health/${widget.animalId}',
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
              Navigator.pushNamed(context, '/pedigree/${animal.id}'),
          icon: const Icon(Icons.account_tree),
          label: const Text('View Full Pedigree Tree'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(
            context,
            '/breeding/${animal.id}',
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
                    '/animals/${parent.id}',
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

  Widget _buildPhotosTab(
    BuildContext context,
    Animal animal,
    AnimalProvider provider,
  ) {
    final images = provider.animalImages;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  if (!await guardWriteAction(context)) return;
                  _addPhoto(animal.id, ImageSource.gallery);
                },
                icon: const Icon(Icons.photo_library),
                label: const Text('Add from Gallery'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  if (!await guardWriteAction(context)) return;
                  _addPhoto(animal.id, ImageSource.camera);
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
              ),
            ],
          ),
        ),
        Expanded(
          child: images.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No photos yet'),
                      const SizedBox(height: 4),
                      Text(
                        'Add photos of this animal',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final img = images[index];
                    return _PhotoTile(
                      image: img,
                      onTap: () => _showFullImage(context, img.imagePath),
                      onSetProfile: () async {
                        if (!await guardWriteAction(context)) return;
                        provider.setProfileImage(animal.id, img.id);
                      },
                      onDelete: () async {
                        if (!await guardWriteAction(context)) return;
                        _confirmDeleteImage(img.id, animal.id, provider);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _addPhoto(String animalId, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;
    final provider = context.read<AnimalProvider>();
    await provider.addAnimalImage(animalId, File(picked.path));
  }

  void _showFullImage(BuildContext context, String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(imagePath)),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteImage(
      String imageId, String animalId, AnimalProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteAnimalImage(imageId, animalId);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
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
        return Icons.medical_services;
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

  Future<void> _handleMenuAction(String action, Animal animal) async {
    switch (action) {
      case 'pedigree':
        Navigator.pushNamed(context, '/pedigree/${animal.id}');
        break;
      case 'breeding':
        Navigator.pushNamed(context, '/breeding/${animal.id}');
        break;
      case 'stud_matcher':
        Navigator.pushNamed(context, '/stud-matcher/${animal.id}');
        break;
      case 'delete':
        if (!await guardWriteAction(context)) return;
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

/// A single photo tile in the gallery grid with context menu.
class _PhotoTile extends StatelessWidget {
  final AnimalImage image;
  final VoidCallback onTap;
  final VoidCallback onSetProfile;
  final VoidCallback onDelete;

  const _PhotoTile({
    required this.image,
    required this.onTap,
    required this.onSetProfile,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(image.imagePath);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                : Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.broken_image),
                  ),
          ),
          // Profile badge
          if (image.isProfile)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Profile',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          // Action menu
          Positioned(
            top: 2,
            right: 2,
            child: PopupMenuButton<String>(
              iconSize: 20,
              icon: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.more_vert,
                    color: Colors.white, size: 16),
              ),
              onSelected: (value) {
                if (value == 'profile') onSetProfile();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                if (!image.isProfile)
                  const PopupMenuItem(
                    value: 'profile',
                    child: ListTile(
                      leading: Icon(Icons.star),
                      title: Text('Set as Profile'),
                      dense: true,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title:
                        Text('Delete', style: TextStyle(color: Colors.red)),
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
