import 'dart:math' as math;
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

  static const _genLabels = [
    'Subject',
    'Parents',
    'Grandparents',
    'Great-GP',
    'GG-GP',
    'GGG-GP',
    'GGGG-GP',
  ];

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
      await _loadPedigreeViaBackgroundTask();
    } else {
      final tree = await provider.buildPedigreeTree(widget.animalId,
          maxGenerations: _generations);
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

  // ─── Flatten tree into generation columns ───────────────────

  /// Converts a recursive PedigreeNode into a list of lists, one per generation.
  /// Each generation list has 2^gen entries in sire-first order.
  /// Null entries represent unknown ancestors.
  List<List<PedigreeNode?>> _flattenTree(PedigreeNode root) {
    final columns = <List<PedigreeNode?>>[];
    var currentLevel = <PedigreeNode?>[root];

    for (var gen = 0; gen <= _generations; gen++) {
      columns.add(List<PedigreeNode?>.from(currentLevel));
      if (gen < _generations) {
        final nextLevel = <PedigreeNode?>[];
        for (final node in currentLevel) {
          nextLevel.add(node?.sire); // sire on top
          nextLevel.add(node?.dam); // dam on bottom
        }
        currentLevel = nextLevel;
      }
    }
    return columns;
  }

  // ─── Card dimensions ────────────────────────────────────────

  double _cardWidth(int generation) {
    if (generation == 0) return 180;
    if (generation >= 4) return 120;
    return 140;
  }

  double _cardHeight(int generation) {
    if (generation == 0) return 80;
    if (generation >= 4) return 52;
    return 64;
  }

  // ─── Build ──────────────────────────────────────────────────

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
                  child: Text(
                      '$i Generations${i == _generations ? " (current)" : ""}'),
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
                  : InteractiveViewer(
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(100),
                      minScale: 0.2,
                      maxScale: 2.0,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildPedigreeChart(_pedigreeTree!),
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
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'This runs in the background and will\nupdate automatically when ready.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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

  // ─── Column-grid pedigree chart ─────────────────────────────

  Widget _buildPedigreeChart(PedigreeNode tree) {
    final columns = _flattenTree(tree);
    // Total height based on the deepest generation's cell count
    final maxSlots = columns.last.length; // 2^_generations
    final cellH = _cardHeight(_generations) + 8; // card + spacing
    final totalHeight = math.max(maxSlots * cellH, 300.0);

    return SizedBox(
      height: totalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var gen = 0; gen < columns.length; gen++) ...[
            _buildGenerationColumn(columns[gen], gen, totalHeight),
            if (gen < columns.length - 1)
              _buildConnectorColumn(
                  columns[gen].length, columns[gen + 1].length, totalHeight),
          ],
        ],
      ),
    );
  }

  Widget _buildGenerationColumn(
      List<PedigreeNode?> nodes, int generation, double totalHeight) {
    final w = _cardWidth(generation);
    final label = generation < _genLabels.length
        ? _genLabels[generation]
        : 'Gen $generation';

    return SizedBox(
      width: w,
      child: Column(
        children: [
          // Header label
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Cards
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < nodes.length; i++)
                  nodes[i] != null
                      ? _buildAnimalCard(nodes[i]!.animal, generation)
                      : _buildUnknownCard(
                          i.isEven ? 'Unknown Sire' : 'Unknown Dam',
                          generation,
                        ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectorColumn(
      int parentCount, int childCount, double totalHeight) {
    return SizedBox(
      width: 32,
      child: Column(
        children: [
          // Offset for the header
          const SizedBox(height: 22),
          Expanded(
            child: CustomPaint(
              painter: _BracketConnectorPainter(
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

  // ─── Animal card ────────────────────────────────────────────

  Widget _buildAnimalCard(Animal animal, int generation) {
    final isMale = animal.sex == Sex.male;
    final sexColor = isMale ? AppTheme.maleColor : AppTheme.femaleColor;
    final isSubject = generation == 0;
    final w = _cardWidth(generation);
    final h = _cardHeight(generation);

    return GestureDetector(
      onTap: () {
        if (animal.id != widget.animalId) {
          Navigator.pushNamed(context, '/animals/${animal.id}');
        }
      },
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSubject ? sexColor : Colors.grey.shade300,
            width: isSubject ? 2.0 : 1.0,
          ),
          boxShadow: isSubject
              ? [
                  BoxShadow(
                    color: sexColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Row(
            children: [
              // Colored left edge indicator
              Container(width: 4, color: sexColor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isSubject ? 8 : 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isMale ? Icons.male : Icons.female,
                            size: isSubject ? 16 : 14,
                            color: sexColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              animal.name,
                              style: TextStyle(
                                fontWeight: isSubject
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: isSubject ? 13 : 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (isSubject || generation < 4) ...[
                        Text(
                          animal.breed,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (animal.registrationNumber != null && generation < 3)
                        Text(
                          animal.registrationNumber!,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
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

  Widget _buildUnknownCard(String label, int generation) {
    final w = _cardWidth(generation);
    final h = _cardHeight(generation);
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade400,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

// ─── Bracket connector painter ──────────────────────────────

/// Draws bracket-style connector lines between pedigree generation columns.
///
/// For each parent cell, it draws:
/// - A horizontal line from the parent's right edge to the midpoint
/// - A vertical line from the sire child position to the dam child position
/// - Two horizontal lines from the midpoint to each child's left edge
class _BracketConnectorPainter extends CustomPainter {
  final int parentCount;
  final int childCount;
  final Color color;

  _BracketConnectorPainter({
    required this.parentCount,
    required this.childCount,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final h = size.height;
    final w = size.width;
    final midX = w / 2;

    // Each parent occupies h/parentCount vertical space, centered.
    // Each child occupies h/childCount vertical space, centered.
    // Child i*2 (sire) and i*2+1 (dam) map to parent i.

    for (var i = 0; i < parentCount; i++) {
      final parentY = (i + 0.5) * h / parentCount;
      final sireIdx = i * 2;
      final damIdx = i * 2 + 1;

      if (sireIdx >= childCount) break;

      final sireY = (sireIdx + 0.5) * h / childCount;
      final damY = damIdx < childCount
          ? (damIdx + 0.5) * h / childCount
          : sireY;

      // Horizontal line from parent to midpoint
      canvas.drawLine(Offset(0, parentY), Offset(midX, parentY), paint);

      // Vertical bar from sire to dam
      canvas.drawLine(Offset(midX, sireY), Offset(midX, damY), paint);

      // Horizontal branches to sire and dam
      canvas.drawLine(Offset(midX, sireY), Offset(w, sireY), paint);
      if (damIdx < childCount) {
        canvas.drawLine(Offset(midX, damY), Offset(w, damY), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BracketConnectorPainter old) =>
      parentCount != old.parentCount ||
      childCount != old.childCount ||
      color != old.color;
}
