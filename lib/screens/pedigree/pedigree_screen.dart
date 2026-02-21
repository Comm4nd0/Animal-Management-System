import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../services/animal_provider.dart';
import '../../services/background_task_service.dart';
import '../../services/pedigree_pdf_service.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';

class PedigreeScreen extends StatefulWidget {
  final String animalId;

  const PedigreeScreen({super.key, required this.animalId});

  @override
  State<PedigreeScreen> createState() => _PedigreeScreenState();
}

class _PedigreeScreenState extends State<PedigreeScreen> {
  PedigreeNode? _pedigreeTree;
  bool _isLoading = true;
  int _generations = 4;
  int _taskProgress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPedigree();
  }

  Future<void> _loadPedigree() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _taskProgress = 0;
    });

    final provider = context.read<AnimalProvider>();

    if (kIsWeb || provider.isDemoMode) {
      // Use background task via API (Celery) to avoid blocking
      await _loadPedigreeViaBackgroundTask();
    } else {
      // Mobile with local SQLite – use direct computation
      final tree = await provider.buildPedigreeTree(widget.animalId);
      if (mounted) {
        setState(() {
          _pedigreeTree = tree;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPedigreeViaBackgroundTask() async {
    final taskService = BackgroundTaskService();
    final result = await taskService.computePedigreeTree(
      widget.animalId,
      generations: _generations,
      onProgress: (status) {
        if (mounted) {
          setState(() => _taskProgress = status.progress);
        }
      },
    );

    if (!mounted) return;

    if (result == null || result.isFailed) {
      setState(() {
        _isLoading = false;
        _errorMessage = result?.error ?? 'Failed to compute pedigree tree';
      });
      return;
    }

    // Build PedigreeNode tree from the API result
    if (result.result != null) {
      final tree = _parsePedigreeResult(result.result!);
      setState(() {
        _pedigreeTree = tree;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No result data returned';
      });
    }
  }

  PedigreeNode? _parsePedigreeResult(Map<String, dynamic> data) {
    final animalData = data['animal'] as Map<String, dynamic>?;
    if (animalData == null) return null;

    return PedigreeNode(
      animal: _animalFromApiData(animalData),
      sire: data['sire'] != null
          ? _parsePedigreeResult(Map<String, dynamic>.from(data['sire'] as Map))
          : null,
      dam: data['dam'] != null
          ? _parsePedigreeResult(Map<String, dynamic>.from(data['dam'] as Map))
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pedigreeTree?.animal.name ?? 'Pedigree'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF Certificate',
            onPressed: _pedigreeTree == null ? null : _exportPdf,
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.layers),
            tooltip: 'Generations',
            onSelected: (gen) {
              setState(() => _generations = gen);
              _loadPedigree();
            },
            itemBuilder: (_) => [
              for (int i = 2; i <= 6; i++)
                PopupMenuItem(
                  value: i,
                  child: Text('$i Generations${i == _generations ? " (current)" : ""}'),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _pedigreeTree == null
                  ? const Center(child: Text('Could not load pedigree'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildPedigreeTree(_pedigreeTree!, 0),
                      ),
                    ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _taskProgress > 0
                ? 'Building pedigree tree... $_taskProgress%'
                : 'Building pedigree tree...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This runs in the background and will\nupdate automatically when ready.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadPedigree,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    final provider = context.read<AnimalProvider>();
    final animal = provider.getAnimalById(widget.animalId);
    if (animal == null) return;

    final pdfBytes = await PedigreePdfService.generateCertificate(
      animal: animal,
      allAnimals: provider.allAnimals,
      generations: _generations,
    );

    await Printing.layoutPdf(
      onLayout: (_) => pdfBytes,
      name: '${animal.name}_pedigree',
    );
  }

  Widget _buildPedigreeTree(PedigreeNode node, int generation) {
    if (generation >= _generations) {
      return _buildAnimalCard(node.animal, generation);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildAnimalCard(node.animal, generation),
        if (node.sire != null || node.dam != null) ...[
          Container(
            width: 24,
            height: 2,
            color: Colors.grey.shade400,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (node.sire != null) ...[
                _buildPedigreeTree(node.sire!, generation + 1),
                const SizedBox(height: 8),
              ] else ...[
                _buildUnknownCard('Unknown Sire', generation + 1),
                const SizedBox(height: 8),
              ],
              if (node.dam != null)
                _buildPedigreeTree(node.dam!, generation + 1)
              else
                _buildUnknownCard('Unknown Dam', generation + 1),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAnimalCard(Animal animal, int generation) {
    final isMale = animal.sex == Sex.male;
    final color = isMale ? AppTheme.maleColor : AppTheme.femaleColor;
    final maxWidth = 160.0 - (generation * 10).clamp(0, 40).toDouble();

    return GestureDetector(
      onTap: () {
        if (animal.id != widget.animalId) {
          Navigator.pushNamed(context, '/animal/detail', arguments: animal.id);
        }
      },
      child: Container(
        width: maxWidth,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color, width: generation == 0 ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isMale ? Icons.male : Icons.female,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    animal.name,
                    style: TextStyle(
                      fontWeight:
                          generation == 0 ? FontWeight.bold : FontWeight.w500,
                      fontSize: generation == 0 ? 14 : 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              animal.breed,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (animal.registrationNumber != null)
              Text(
                animal.registrationNumber!,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            if (animal.color != null)
              Text(
                animal.color!,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnknownCard(String label, int generation) {
    final maxWidth = 160.0 - (generation * 10).clamp(0, 40).toDouble();
    return Container(
      width: maxWidth,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
