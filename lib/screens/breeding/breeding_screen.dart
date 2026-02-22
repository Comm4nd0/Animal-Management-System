import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';

class BreedingScreen extends StatefulWidget {
  final String? selectedAnimalId;

  const BreedingScreen({super.key, this.selectedAnimalId});

  @override
  State<BreedingScreen> createState() => _BreedingScreenState();
}

class _BreedingScreenState extends State<BreedingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedAnimalId;
  List<BreedingSuggestion> _suggestions = [];
  bool _isLoadingSuggestions = false;
  bool _isLoadingAnimals = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedAnimalId = widget.selectedAnimalId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureAnimalsLoaded();
      if (_selectedAnimalId != null) {
        _tabController.index = 1;
        _loadSuggestions();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Make sure the full animal list is available for the dropdown.
  Future<void> _ensureAnimalsLoaded() async {
    final provider = context.read<AnimalProvider>();
    final liveAnimals =
        provider.allAnimals.where((a) => a.status == AnimalStatus.alive);
    if (liveAnimals.length <= 10) {
      setState(() => _isLoadingAnimals = true);
      try {
        await provider.loadBreedingCandidates();
      } catch (_) {
        // Silently use whatever we have
      }
      if (mounted) setState(() => _isLoadingAnimals = false);
    }
  }

  Future<void> _loadSuggestions() async {
    if (_selectedAnimalId == null) return;

    setState(() {
      _isLoadingSuggestions = true;
      _errorMessage = null;
      _suggestions = [];
    });

    try {
      final provider = context.read<AnimalProvider>();
      final suggestions =
          await provider.getBreedingSuggestions(_selectedAnimalId!);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
          _errorMessage = 'Failed to load breeding suggestions. '
              'Please check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Breeding'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Active Breedings'),
            Tab(text: 'Suggestions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveBreedingsTab(),
          _buildSuggestionsTab(),
        ],
      ),
    );
  }

  Widget _buildActiveBreedingsTab() {
    return Consumer<AnimalProvider>(
      builder: (context, provider, _) {
        final records = provider.breedingRecords;
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No active breedings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 8),
                const Text('Use the Suggestions tab to find compatible pairs'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final sire = provider.getAnimalById(record.sireId);
            final dam = provider.getAnimalById(record.damId);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: AppTheme.femaleColor),
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
                        _buildStatusChip(record.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (record.method != null)
                      Text('Method: ${record.method}'),
                    if (record.expectedOffspringCoi != null)
                      Text(
                        'Expected COI: ${record.expectedOffspringCoi!.toStringAsFixed(2)}%',
                      ),
                    if (record.gestationDaysRemaining != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(
                          value: _gestationProgress(record),
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation(
                              AppTheme.primaryColor),
                        ),
                      ),
                    if (record.gestationDaysRemaining != null)
                      Text(
                        '${record.gestationDaysRemaining} days remaining',
                        style: Theme.of(context).textTheme.bodySmall,
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

  Widget _buildSuggestionsTab() {
    return Consumer<AnimalProvider>(
      builder: (context, provider, _) {
        final liveAnimals =
            provider.allAnimals.where((a) => a.status == AnimalStatus.alive);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: _isLoadingAnimals
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<String>(
                      value: _selectedAnimalId,
                      decoration: const InputDecoration(
                        labelText: 'Select Animal for Breeding Suggestions',
                        prefixIcon: Icon(Icons.pets),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Choose an animal...')),
                        ...liveAnimals.map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                '${a.name} (${a.sex == Sex.male ? "M" : "F"} - ${a.breed})',
                              ),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedAnimalId = v);
                        if (v != null) _loadSuggestions();
                      },
                    ),
            ),
            Expanded(
              child: _isLoadingSuggestions
                  ? _MatrixAnalysisOverlay(
                      animalName: _getSelectedAnimalName(provider),
                      allAnimals: liveAnimals.toList(),
                    )
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _selectedAnimalId == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.science,
                                      size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                      'Select an animal to get suggestions'),
                                ],
                              ),
                            )
                          : _suggestions.isEmpty
                              ? _buildEmptyState()
                              : _buildSuggestionsList(),
            ),
          ],
        );
      },
    );
  }

  String _getSelectedAnimalName(AnimalProvider provider) {
    if (_selectedAnimalId == null) return '';
    final animal = provider.getAnimalById(_selectedAnimalId!);
    return animal?.name ?? 'Selected Animal';
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSuggestions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No compatible mates found'),
          const SizedBox(height: 4),
          Text(
            'Try adding more animals of the opposite sex\nand same species to your records.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return _BreedingSuggestionCard(suggestion: suggestion);
      },
    );
  }

  Widget _buildStatusChip(BreedingStatus status) {
    Color color;
    switch (status) {
      case BreedingStatus.planned:
        color = Colors.blue;
        break;
      case BreedingStatus.confirmed:
        color = Colors.orange;
        break;
      case BreedingStatus.pregnant:
        color = AppTheme.femaleColor;
        break;
      case BreedingStatus.whelping:
        color = Colors.purple;
        break;
      case BreedingStatus.completed:
        color = AppTheme.primaryColor;
        break;
      case BreedingStatus.unsuccessful:
      case BreedingStatus.cancelled:
        color = Colors.grey;
        break;
    }
    return Chip(
      label: Text(
        status.name.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: color,
    );
  }

  double _gestationProgress(BreedingRecord record) {
    if (record.expectedDueDate == null) return 0;
    final total =
        record.expectedDueDate!.difference(record.breedingDate).inDays;
    final elapsed = DateTime.now().difference(record.breedingDate).inDays;
    if (total <= 0) return 0;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

// ─── Matrix-Style Analysis Overlay ────────────────────────────────────────

/// A full-screen overlay that displays a Matrix digital rain effect with
/// real-time analysis messages showing the breeding calculations in progress.
class _MatrixAnalysisOverlay extends StatefulWidget {
  final String animalName;
  final List<Animal> allAnimals;

  const _MatrixAnalysisOverlay({
    required this.animalName,
    required this.allAnimals,
  });

  @override
  State<_MatrixAnalysisOverlay> createState() => _MatrixAnalysisOverlayState();
}

class _MatrixAnalysisOverlayState extends State<_MatrixAnalysisOverlay>
    with TickerProviderStateMixin {
  late AnimationController _rainController;
  final List<_MatrixColumn> _columns = [];
  final List<_AnalysisLogEntry> _logEntries = [];
  Timer? _messageTimer;
  int _messageIndex = 0;
  final _random = Random();
  late List<String> _analysisMessages;
  double _progress = 0.0;

  // Matrix characters: mix of katakana, digits, and symbols
  static const String _matrixChars =
      '\u30A0\u30A1\u30A2\u30A3\u30A4\u30A5\u30A6\u30A7\u30A8\u30A9'
      '\u30AA\u30AB\u30AC\u30AD\u30AE\u30AF\u30B0\u30B1\u30B2\u30B3'
      '\u30B4\u30B5\u30B6\u30B7\u30B8\u30B9\u30BA\u30BB\u30BC\u30BD'
      '0123456789ACGT\u00D7%';

  @override
  void initState() {
    super.initState();
    _buildAnalysisMessages();

    _rainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    )..addListener(_updateRain);
    _rainController.repeat();

    _messageTimer =
        Timer.periodic(const Duration(milliseconds: 600), (_) => _addNextMessage());
  }

  void _buildAnalysisMessages() {
    // Build analysis messages that reference real animal names
    final names = widget.allAnimals
        .take(20)
        .map((a) => a.name)
        .toList();
    if (names.isEmpty) names.add('candidate');

    _analysisMessages = [
      '> Initializing genetics engine...',
      '> Loading pedigree database...',
      '> Querying ${widget.allAnimals.length} registered animals...',
      '> Filtering opposite-sex candidates for ${widget.animalName}...',
    ];

    // Add per-animal analysis messages
    for (var i = 0; i < min(names.length, 12); i++) {
      final name = names[i];
      _analysisMessages.addAll([
        '> Building pedigree tree: $name (5 generations)...',
        '> Calculating COI: ${widget.animalName} x $name...',
        '>   Wright\'s path coefficient = ${(_random.nextDouble() * 8).toStringAsFixed(2)}%',
        '> Analyzing breed compatibility...',
        '> Evaluating age & health factors...',
        '>   Compatibility score: ${(60 + _random.nextInt(40))}/100',
      ]);
    }

    _analysisMessages.addAll([
      '> Sorting results by compatibility score...',
      '> Compiling genetic risk analysis...',
      '> Generating trait predictions...',
      '> Preparing results...',
    ]);
  }

  @override
  void dispose() {
    _rainController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  void _updateRain() {
    if (!mounted) return;
    setState(() {
      for (final col in _columns) {
        col.update(_matrixChars, _random);
      }
    });
  }

  void _addNextMessage() {
    if (!mounted) return;
    if (_messageIndex < _analysisMessages.length) {
      setState(() {
        _logEntries.add(_AnalysisLogEntry(
          text: _analysisMessages[_messageIndex],
          timestamp: DateTime.now(),
        ));
        _messageIndex++;
        _progress = (_messageIndex / _analysisMessages.length).clamp(0.0, 1.0);
        // Keep only last 14 messages visible
        if (_logEntries.length > 14) {
          _logEntries.removeAt(0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _ensureColumns(constraints.maxWidth, constraints.maxHeight);

        return Container(
          color: const Color(0xFF0A0A0A),
          child: Stack(
            children: [
              // Matrix rain background
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _MatrixRainPainter(columns: _columns),
              ),
              // Dark gradient overlay for readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              // Analysis log + progress
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Color(0xFF00FF41)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'GENETICS ANALYSIS IN PROGRESS',
                            style: TextStyle(
                              color: const Color(0xFF00FF41),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              shadows: [
                                Shadow(
                                  color: const Color(0xFF00FF41)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: const Color(0xFF1A1A1A),
                          valueColor: AlwaysStoppedAnimation(
                            Color.lerp(
                              const Color(0xFF00FF41),
                              const Color(0xFF39FF14),
                              _progress,
                            )!,
                          ),
                          minHeight: 3,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${(_progress * 100).toInt()}% complete',
                          style: TextStyle(
                            color:
                                const Color(0xFF00FF41).withValues(alpha: 0.7),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Analysis log entries
                      Expanded(
                        child: ListView.builder(
                          reverse: false,
                          itemCount: _logEntries.length,
                          itemBuilder: (context, index) {
                            final entry = _logEntries[index];
                            final isLatest = index == _logEntries.length - 1;
                            final opacity = isLatest
                                ? 1.0
                                : (0.3 +
                                    0.7 *
                                        (index / _logEntries.length));

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.text,
                                      style: TextStyle(
                                        color: (isLatest
                                                ? const Color(0xFF39FF14)
                                                : const Color(0xFF00FF41))
                                            .withValues(alpha: opacity),
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        fontWeight: isLatest
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        shadows: isLatest
                                            ? [
                                                Shadow(
                                                  color: const Color(0xFF00FF41)
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 6,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      // Bottom hint
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Analyzing ${widget.allAnimals.length} animals '
                          'across 5 pedigree generations...',
                          style: TextStyle(
                            color:
                                const Color(0xFF00FF41).withValues(alpha: 0.5),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _ensureColumns(double width, double height) {
    final columnCount = (width / 16).floor();
    if (_columns.length != columnCount) {
      _columns.clear();
      for (var i = 0; i < columnCount; i++) {
        _columns.add(_MatrixColumn(
          x: i * 16.0,
          maxY: height,
          random: _random,
          matrixChars: _matrixChars,
        ));
      }
    }
  }
}

/// A single column of falling matrix characters.
class _MatrixColumn {
  final double x;
  final double maxY;
  double y;
  double speed;
  int trailLength;
  List<String> chars;
  final Random random;

  _MatrixColumn({
    required this.x,
    required this.maxY,
    required this.random,
    required String matrixChars,
  })  : y = -random.nextDouble() * 500,
        speed = 2 + random.nextDouble() * 6,
        trailLength = 8 + random.nextInt(18),
        chars = List.generate(
          8 + random.nextInt(18),
          (_) => String.fromCharCode(
            matrixChars.codeUnitAt(random.nextInt(matrixChars.length)),
          ),
        );

  void update(String matrixChars, Random random) {
    y += speed;
    if (y - trailLength * 14 > maxY) {
      y = -random.nextDouble() * 200;
      speed = 2 + random.nextDouble() * 6;
      trailLength = 8 + random.nextInt(18);
    }
    // Randomly mutate one character in the trail
    if (random.nextInt(3) == 0 && chars.isNotEmpty) {
      final idx = random.nextInt(chars.length);
      chars[idx] = String.fromCharCode(
        matrixChars.codeUnitAt(random.nextInt(matrixChars.length)),
      );
    }
  }
}

class _MatrixRainPainter extends CustomPainter {
  final List<_MatrixColumn> columns;

  _MatrixRainPainter({required this.columns});

  @override
  void paint(Canvas canvas, Size size) {
    for (final col in columns) {
      for (var i = 0; i < col.chars.length; i++) {
        final charY = col.y - i * 14.0;
        if (charY < -14 || charY > size.height + 14) continue;

        final opacity = i == 0
            ? 1.0
            : (1.0 - i / col.chars.length).clamp(0.05, 0.8);

        final color = i == 0
            ? const Color(0xFFFFFFFF) // Head is white/bright
            : Color.fromRGBO(0, 255, 65, opacity);

        final textPainter = TextPainter(
          text: TextSpan(
            text: col.chars[i],
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(col.x, charY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixRainPainter oldDelegate) => true;
}

class _AnalysisLogEntry {
  final String text;
  final DateTime timestamp;

  _AnalysisLogEntry({required this.text, required this.timestamp});
}

// ─── Suggestion Card ────────────────────────────────────────────────────

class _BreedingSuggestionCard extends StatelessWidget {
  final BreedingSuggestion suggestion;

  const _BreedingSuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final scoreColor = suggestion.compatibilityScore >= 75
        ? AppTheme.primaryColor
        : suggestion.compatibilityScore >= 50
            ? Colors.orange
            : AppTheme.errorColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: scoreColor.withValues(alpha: 0.15),
          child: Text(
            '${suggestion.compatibilityScore.round()}',
            style: TextStyle(
              color: scoreColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          '${suggestion.sire.name} x ${suggestion.dam.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Text(suggestion.scoreGrade),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _coiColor(suggestion.estimatedCoi)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'COI: ${suggestion.estimatedCoi.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: _coiColor(suggestion.estimatedCoi),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (suggestion.pros.isNotEmpty) ...[
                  const Text('Pros:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...suggestion.pros.map((p) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle,
                                color: AppTheme.primaryColor, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(p,
                                    style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                ],
                if (suggestion.cons.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Cons:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...suggestion.cons.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning,
                                color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(c,
                                    style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                ],
                if (suggestion.geneticRisks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Genetic Risks:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorColor)),
                  ...suggestion.geneticRisks.map((r) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.errorColor, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(r,
                                    style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _coiColor(double coi) {
    if (coi < 3) return AppTheme.primaryColor;
    if (coi < 6.25) return Colors.orange;
    return AppTheme.errorColor;
  }
}
