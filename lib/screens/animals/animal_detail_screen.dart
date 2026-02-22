import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/animal_provider.dart';
import '../../services/background_task_service.dart';
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
  bool _fetchingAnimal = false;
  PedigreeNode? _pedigreeTree;
  bool _pedigreeLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AnimalProvider>();
      // Always fetch the full animal from the API to ensure we have
      // complete data (including sire/dam IDs that the list endpoint
      // may not provide).
      _fetchFromApi(p).then((_) {
        if (!mounted) return;
        _ensureParentsLoaded(p);
      });
      p.loadHealthRecords(widget.animalId);
      p.loadAnimalImages(widget.animalId);
      p.loadWeightRecords(widget.animalId);
      p.loadShowResults(widget.animalId);
      p.loadFinancialRecords(widget.animalId);
      p.loadDocumentAttachments(widget.animalId);
      _loadPedigreeTree();
    });
  }

  Future<void> _loadPedigreeTree() async {
    setState(() => _pedigreeLoading = true);

    final provider = context.read<AnimalProvider>();

    PedigreeNode? tree;

    if (kIsWeb || provider.isDemoMode) {
      await _loadPedigreeViaBackgroundTask();
      tree = _pedigreeTree;
    } else {
      tree = await provider.buildPedigreeTree(widget.animalId);
    }

    // Fallback: build the tree from the in-memory animal list when the
    // primary method (SQLite query or background task) returns nothing.
    tree ??= _buildTreeFromMemory(provider, widget.animalId, 0);

    if (mounted) {
      setState(() {
        _pedigreeTree = tree;
        _pedigreeLoading = false;
      });
    }
  }

  PedigreeNode? _buildTreeFromMemory(
    AnimalProvider provider,
    String animalId,
    int generation, {
    int maxGenerations = 4,
  }) {
    final animal = provider.getAnimalById(animalId);
    if (animal == null) return null;

    PedigreeNode? sireNode;
    PedigreeNode? damNode;

    if (generation < maxGenerations) {
      if (animal.sireId != null) {
        sireNode = _buildTreeFromMemory(
            provider, animal.sireId!, generation + 1,
            maxGenerations: maxGenerations);
      }
      if (animal.damId != null) {
        damNode = _buildTreeFromMemory(
            provider, animal.damId!, generation + 1,
            maxGenerations: maxGenerations);
      }
    }

    return PedigreeNode(
      animal: animal,
      sire: sireNode,
      dam: damNode,
      generation: generation,
    );
  }

  Future<void> _loadPedigreeViaBackgroundTask() async {
    final taskService = BackgroundTaskService();
    final result = await taskService.computePedigreeTree(
      widget.animalId,
      generations: 4,
      onProgress: (_) {},
    );

    if (!mounted) return;

    if (result != null && !result.isFailed && result.result != null) {
      final tree = _parsePedigreeResult(result.result!);
      setState(() {
        _pedigreeTree = tree;
        _pedigreeLoading = false;
      });
    } else {
      setState(() => _pedigreeLoading = false);
    }
  }

  PedigreeNode? _parsePedigreeResult(Map<String, dynamic> data) {
    final animalData = data['animal'] as Map<String, dynamic>?;
    if (animalData == null) return null;

    return PedigreeNode(
      animal: _animalFromApiData(animalData),
      sire: data['sire'] != null
          ? _parsePedigreeResult(
              Map<String, dynamic>.from(data['sire'] as Map))
          : null,
      dam: data['dam'] != null
          ? _parsePedigreeResult(
              Map<String, dynamic>.from(data['dam'] as Map))
          : null,
      generation: data['generation'] as int? ?? 0,
    );
  }

  Animal _animalFromApiData(Map<String, dynamic> m) {
    return Animal(
      id: m['id'] as String? ?? '',
      name: m['name'] as String? ?? 'Unknown',
      species: m['species'] as String? ?? '',
      breed: m['breed'] as String? ?? '',
      sex: Sex.values[(m['sex'] as int?) ?? 0],
      dateOfBirth: m['date_of_birth'] != null
          ? DateTime.tryParse(m['date_of_birth'] as String)
          : null,
      color: m['color'] as String?,
      registrationNumber: m['registration_number'] as String?,
      status: AnimalStatus.values[(m['status'] as int?) ?? 0],
      geneticTraits: {},
      customFields: {},
    );
  }

  Future<void> _fetchFromApi(AnimalProvider provider) async {
    setState(() => _fetchingAnimal = true);
    await provider.fetchAnimalById(widget.animalId);
    if (mounted) setState(() => _fetchingAnimal = false);
  }

  /// Fetches the sire and dam animals from the API if they are referenced
  /// but not yet loaded into memory. This ensures parent names display
  /// correctly on the detail screen.
  Future<void> _ensureParentsLoaded(AnimalProvider provider) async {
    final animal = provider.getAnimalById(widget.animalId);
    if (animal == null) return;

    final futures = <Future>[];
    if (animal.sireId != null && provider.getAnimalById(animal.sireId!) == null) {
      futures.add(provider.fetchAnimalById(animal.sireId!));
    }
    if (animal.damId != null && provider.getAnimalById(animal.damId!) == null) {
      futures.add(provider.fetchAnimalById(animal.damId!));
    }
    if (futures.isNotEmpty) await Future.wait(futures);
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
            body: Center(
              child: _fetchingAnimal
                  ? const CircularProgressIndicator()
                  : const Text('Animal not found'),
            ),
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
                  await Navigator.pushNamed(
                    context,
                    '/animals/${animal.id}/edit',
                  );
                  // Refresh data after returning from edit.
                  if (!mounted) return;
                  final p = context.read<AnimalProvider>();
                  await p.fetchAnimalById(widget.animalId);
                  if (!mounted) return;
                  await _ensureParentsLoaded(p);
                  if (mounted) _loadPedigreeTree();
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, animal),
                itemBuilder: (_) => [
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
    final customFieldDefs = provider.customFieldDefinitionsFor(CustomFieldEntityType.animal);

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
        // Parents section
        Card(
          margin: const EdgeInsets.only(bottom: 12),
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
        // Family Tree section (4 generations deep)
        _buildFamilyTreeSection(context, animal),
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

  Widget _buildFamilyTreeSection(BuildContext context, Animal animal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Family Tree',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_pedigreeLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Loading family tree...'),
                    ],
                  ),
                ),
              )
            else if (_pedigreeTree == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No family tree data available',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildPedigreeChart(_pedigreeTree!),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Column-grid mini-pedigree ──────────────────────────────

  static const _miniGenLabels = ['Subject', 'Parents', 'Grandparents', 'Great-GP', 'GG-GP'];
  static const _miniMaxGen = 4;

  List<List<PedigreeNode?>> _flattenMiniTree(PedigreeNode root) {
    final columns = <List<PedigreeNode?>>[];
    var currentLevel = <PedigreeNode?>[root];
    for (var gen = 0; gen <= _miniMaxGen; gen++) {
      columns.add(List<PedigreeNode?>.from(currentLevel));
      if (gen < _miniMaxGen) {
        final nextLevel = <PedigreeNode?>[];
        for (final node in currentLevel) {
          nextLevel.add(node?.sire);
          nextLevel.add(node?.dam);
        }
        currentLevel = nextLevel;
      }
    }
    return columns;
  }

  double _miniCardWidth(int gen) => gen == 0 ? 150 : (gen >= 3 ? 100 : 120);
  double _miniCardHeight(int gen) => gen == 0 ? 60 : (gen >= 3 ? 40 : 50);

  Widget _buildPedigreeChart(PedigreeNode tree) {
    final columns = _flattenMiniTree(tree);
    final maxSlots = columns.last.length;
    final cellH = _miniCardHeight(_miniMaxGen) + 6;
    final totalHeight = (maxSlots * cellH).clamp(200.0, 1200.0);

    return SizedBox(
      height: totalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var gen = 0; gen < columns.length; gen++) ...[
            _buildMiniGenColumn(columns[gen], gen),
            if (gen < columns.length - 1)
              _buildMiniConnectors(columns[gen].length, columns[gen + 1].length),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniGenColumn(List<PedigreeNode?> nodes, int gen) {
    final w = _miniCardWidth(gen);
    final label = gen < _miniGenLabels.length ? _miniGenLabels[gen] : 'Gen $gen';
    return SizedBox(
      width: w,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < nodes.length; i++)
                  nodes[i] != null
                      ? _buildTreeAnimalCard(nodes[i]!.animal, gen)
                      : _buildUnknownTreeCard(i.isEven ? 'Unknown Sire' : 'Unknown Dam', gen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniConnectors(int parentCount, int childCount) {
    return SizedBox(
      width: 24,
      child: Column(
        children: [
          const SizedBox(height: 18),
          Expanded(
            child: CustomPaint(
              painter: _MiniBracketPainter(
                parentCount: parentCount,
                childCount: childCount,
                color: Colors.grey.shade400,
              ),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeAnimalCard(Animal animal, int generation) {
    final isMale = animal.sex == Sex.male;
    final sexColor = isMale ? AppTheme.maleColor : AppTheme.femaleColor;
    final isSubject = generation == 0;
    final w = _miniCardWidth(generation);
    final h = _miniCardHeight(generation);

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/animals/${animal.id}');
      },
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSubject ? sexColor : Colors.grey.shade300,
            width: isSubject ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Row(
            children: [
              Container(width: 3, color: sexColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(isMale ? Icons.male : Icons.female, size: 12, color: sexColor),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              animal.name,
                              style: TextStyle(
                                fontWeight: isSubject ? FontWeight.bold : FontWeight.w500,
                                fontSize: isSubject ? 11 : 10,
                                color: AppTheme.primaryColor,
                                decoration: TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (animal.breed.isNotEmpty && generation < 3)
                        Text(animal.breed,
                          style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnknownTreeCard(String label, int generation) {
    final w = _miniCardWidth(generation);
    final h = _miniCardHeight(generation);
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Text(label,
          style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
      ),
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

/// Bracket connector painter for the mini-pedigree in the detail screen.
class _MiniBracketPainter extends CustomPainter {
  final int parentCount;
  final int childCount;
  final Color color;

  _MiniBracketPainter({
    required this.parentCount,
    required this.childCount,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final h = size.height;
    final w = size.width;
    final midX = w / 2;

    for (var i = 0; i < parentCount; i++) {
      final parentY = (i + 0.5) * h / parentCount;
      final sireIdx = i * 2;
      final damIdx = i * 2 + 1;
      if (sireIdx >= childCount) break;

      final sireY = (sireIdx + 0.5) * h / childCount;
      final damY =
          damIdx < childCount ? (damIdx + 0.5) * h / childCount : sireY;

      canvas.drawLine(Offset(0, parentY), Offset(midX, parentY), paint);
      canvas.drawLine(Offset(midX, sireY), Offset(midX, damY), paint);
      canvas.drawLine(Offset(midX, sireY), Offset(w, sireY), paint);
      if (damIdx < childCount) {
        canvas.drawLine(Offset(midX, damY), Offset(w, damY), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniBracketPainter old) =>
      parentCount != old.parentCount ||
      childCount != old.childCount ||
      color != old.color;
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

