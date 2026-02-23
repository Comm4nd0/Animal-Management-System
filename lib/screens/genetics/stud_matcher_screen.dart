import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
import '../../services/background_task_service.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';

class StudMatcherScreen extends StatefulWidget {
  final String? preselectedStudId;

  const StudMatcherScreen({super.key, this.preselectedStudId});

  @override
  State<StudMatcherScreen> createState() => _StudMatcherScreenState();
}

class _StudMatcherScreenState extends State<StudMatcherScreen> {
  String? _selectedStudId;
  List<BreedingSuggestion> _matches = [];
  bool _isLoading = false;
  bool _filterSameBreedOnly = false;
  BackgroundTaskStatus? _taskStatus;
  String? _errorMessage;

  // Stud typeahead state
  final _studSearchController = TextEditingController();
  final _studFocusNode = FocusNode();
  bool _studShowSuggestions = false;
  List<Animal> _studSuggestions = [];
  Timer? _studDebounce;
  bool _studSearchLoading = false;

  @override
  void initState() {
    super.initState();
    _studFocusNode.addListener(() {
      if (_studFocusNode.hasFocus) {
        setState(() => _studShowSuggestions = true);
        if (_selectedStudId == null) {
          _searchStudCandidates();
        }
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _studShowSuggestions = false);
        });
      }
    });
    _studSearchController.addListener(() {
      _studDebounce?.cancel();
      _studDebounce = Timer(const Duration(milliseconds: 300), () {
        if (_selectedStudId == null) {
          _searchStudCandidates();
        }
      });
    });
    if (widget.preselectedStudId != null) {
      _selectedStudId = widget.preselectedStudId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPreselectedStudDisplay();
        _loadMatches();
      });
    }
  }

  @override
  void dispose() {
    _studDebounce?.cancel();
    _studSearchController.dispose();
    _studFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPreselectedStudDisplay() async {
    if (_selectedStudId == null) return;
    final provider = context.read<AnimalProvider>();
    var stud = provider.getAnimalById(_selectedStudId!);
    stud ??= await provider.fetchAnimalById(_selectedStudId!);
    if (stud != null && mounted) {
      _studSearchController.text = _formatAnimalDisplay(stud);
    }
  }

  Future<void> _searchStudCandidates() async {
    final provider = context.read<AnimalProvider>();
    final query = _studSearchController.text.trim();
    if (_selectedStudId != null) return;

    setState(() => _studSearchLoading = true);

    try {
      final results = await provider.searchParentCandidates(
        sex: Sex.male,
        query: query,
        aliveOnly: true,
      );
      if (!mounted) return;
      setState(() {
        _studSuggestions = results;
        _studSearchLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _studSearchLoading = false);
    }
  }

  String _formatAnimalDisplay(Animal a) {
    final reg = a.registrationNumber;
    if (reg != null && reg.isNotEmpty) {
      return '${a.name} - $reg (${a.breed})';
    }
    return '${a.name} (${a.breed})';
  }

  Future<void> _loadMatches() async {
    if (_selectedStudId == null) return;
    setState(() {
      _isLoading = true;
      _matches = [];
      _errorMessage = null;
      _taskStatus = null;
    });

    final provider = context.read<AnimalProvider>();

    if (kIsWeb || provider.isDemoMode) {
      // Use background task via API to avoid blocking
      await _loadMatchesViaBackgroundTask();
    } else {
      // Mobile with local SQLite - use direct computation
      final suggestions = await provider.geneticsService.generateBreedingSuggestions(
        _selectedStudId!,
        maxResults: 100,
        maxCoiThreshold: 100.0,
      );
      if (mounted) {
        setState(() {
          _matches = suggestions;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMatchesViaBackgroundTask() async {
    final taskService = BackgroundTaskService();
    final result = await taskService.computeBreedingSuggestions(
      _selectedStudId!,
      maxResults: 100,
      maxCoi: 100.0,
      onProgress: (status) {
        if (mounted) {
          setState(() => _taskStatus = status);
        }
      },
    );

    if (!mounted) return;

    if (result == null || result.isFailed) {
      setState(() {
        _isLoading = false;
        _errorMessage = result?.error ?? 'Failed to compute breeding suggestions';
      });
      return;
    }

    if (result.result != null) {
      final suggestions = _parseSuggestionsResult(result.result!);
      setState(() {
        _matches = suggestions;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No result data returned';
      });
    }
  }

  List<BreedingSuggestion> _parseSuggestionsResult(Map<String, dynamic> data) {
    final list = data['suggestions'] as List? ?? [];
    return list.map((s) {
      final m = Map<String, dynamic>.from(s as Map);
      return BreedingSuggestion(
        sire: _animalFromApiData(Map<String, dynamic>.from(m['sire'] as Map)),
        dam: _animalFromApiData(Map<String, dynamic>.from(m['dam'] as Map)),
        compatibilityScore: (m['compatibility_score'] as num).toDouble(),
        estimatedCoi: (m['estimated_coi'] as num).toDouble(),
        pros: List<String>.from(m['pros'] as List? ?? []),
        cons: List<String>.from(m['cons'] as List? ?? []),
        geneticRisks: List<String>.from(m['genetic_risks'] as List? ?? []),
        traitPredictions: Map<String, double>.from(
          (m['trait_predictions'] as Map? ?? {}).map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ),
        ),
      );
    }).toList();
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

  List<BreedingSuggestion> get _filteredMatches {
    if (!_filterSameBreedOnly) return _matches;
    final provider = context.read<AnimalProvider>();
    final stud = provider.getAnimalById(_selectedStudId!);
    if (stud == null) return _matches;
    return _matches.where((s) => s.dam.breed == stud.breed).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stud Matcher'),
      ),
      body: Consumer<AnimalProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Stud selection + filter
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAnimalTypeahead(
                      label: 'Select Stud (Male)',
                      icon: Icons.male,
                      iconColor: AppTheme.maleColor,
                      selectedId: _selectedStudId,
                      suggestions: _studSuggestions,
                      isLoading: _studSearchLoading,
                      controller: _studSearchController,
                      focusNode: _studFocusNode,
                      showSuggestions: _studShowSuggestions,
                      onSelected: (animal) {
                        setState(() {
                          _selectedStudId = animal.id;
                          _studSearchController.text =
                              _formatAnimalDisplay(animal);
                          _studShowSuggestions = false;
                          _studFocusNode.unfocus();
                          _matches = [];
                        });
                        _loadMatches();
                      },
                      onCleared: () {
                        setState(() {
                          _selectedStudId = null;
                          _studSearchController.clear();
                          _studSuggestions = [];
                          _matches = [];
                        });
                      },
                      onSelectionInvalidated: () {
                        setState(() {
                          _selectedStudId = null;
                          _studShowSuggestions = true;
                          _matches = [];
                        });
                        _searchStudCandidates();
                      },
                    ),
                    if (_selectedStudId != null && _matches.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('Same breed only'),
                              selected: _filterSameBreedOnly,
                              onSelected: (v) =>
                                  setState(() => _filterSameBreedOnly = v),
                              selectedColor:
                                  AppTheme.primaryColor.withValues(alpha: 0.2),
                              checkmarkColor: AppTheme.primaryColor,
                            ),
                            const Spacer(),
                            _buildTrafficLightLegend(),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Results
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _selectedStudId == null
                            ? _buildEmptyState()
                            : _filteredMatches.isEmpty && !_isLoading
                                ? _buildNoMatchesState()
                                : _buildMatchesList(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnimalTypeahead({
    required String label,
    required IconData icon,
    required Color iconColor,
    required String? selectedId,
    required List<Animal> suggestions,
    required bool isLoading,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool showSuggestions,
    required ValueChanged<Animal> onSelected,
    required VoidCallback onCleared,
    required VoidCallback onSelectionInvalidated,
  }) {
    final shouldShow = showSuggestions && selectedId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: iconColor),
            hintText: 'Type name or reg number to search...',
            suffixIcon: selectedId != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear selection',
                    onPressed: onCleared,
                  )
                : isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
          ),
          onChanged: (value) {
            if (selectedId != null) {
              onSelectionInvalidated();
            }
          },
        ),
        if (shouldShow && suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final animal = suggestions[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    icon,
                    size: 20,
                    color: iconColor,
                  ),
                  title: Text(
                    animal.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      if (animal.registrationNumber != null &&
                          animal.registrationNumber!.isNotEmpty)
                        'Reg: ${animal.registrationNumber}',
                      animal.breed,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  onTap: () => onSelected(animal),
                );
              },
            ),
          ),
        if (shouldShow &&
            suggestions.isEmpty &&
            !isLoading &&
            controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No matching males found',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    final status = _taskStatus;
    final progress = status?.progress ?? 0;
    final fraction = (progress / 100).clamp(0.0, 1.0);
    final hasProgress = progress > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header icon and title
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.biotech,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Analysing Compatibility',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Computing COI for all potential mates',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 12,
                    child: Stack(
                      children: [
                        // Background
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        // Progress fill
                        if (hasProgress)
                          FractionallySizedBox(
                            widthFactor: fraction,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.secondaryColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          )
                        else
                          // Indeterminate shimmer for pre-progress phase
                          const LinearProgressIndicator(
                            minHeight: 12,
                            backgroundColor: Colors.transparent,
                            color: AppTheme.primaryColor,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Percentage and status row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hasProgress ? '$progress%' : 'Starting...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hasProgress
                            ? AppTheme.primaryColor
                            : Colors.grey.shade500,
                      ),
                    ),
                    if (status != null && status.etaDisplay.isNotEmpty)
                      Text(
                        status.etaDisplay,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),

                // Status message
                if (status != null &&
                    status.statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      status.statusMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],

                // Items processed stats
                if (status != null && status.totalItems > 0) ...[
                  const SizedBox(height: 12),
                  _buildProgressStat(
                    icon: Icons.pets,
                    label: 'Females analysed',
                    value: '${status.processedItems} / ${status.totalItems}',
                  ),
                ],

                // Stage indicator
                const SizedBox(height: 16),
                _buildProgressStages(progress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressStages(int progress) {
    final stages = [
      _ProgressStage('Fetching pedigrees', 0, 25),
      _ProgressStage('Computing COI', 25, 70),
      _ProgressStage('Scoring compatibility', 70, 90),
      _ProgressStage('Ranking results', 90, 100),
    ];

    return Column(
      children: [
        Row(
          children: stages.asMap().entries.map((entry) {
            final index = entry.key;
            final stage = entry.value;
            final isActive =
                progress >= stage.startPercent && progress < stage.endPercent;
            final isComplete = progress >= stage.endPercent;

            return Expanded(
              child: Row(
                children: [
                  if (index > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isComplete || isActive
                            ? AppTheme.primaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isComplete
                          ? AppTheme.primaryColor
                          : isActive
                              ? AppTheme.primaryColor.withValues(alpha: 0.2)
                              : Colors.grey.shade200,
                      border: Border.all(
                        color: isComplete || isActive
                            ? AppTheme.primaryColor
                            : Colors.grey.shade400,
                        width: 1.5,
                      ),
                    ),
                    child: isComplete
                        ? const Icon(Icons.check,
                            size: 12, color: Colors.white)
                        : isActive
                            ? const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppTheme.primaryColor,
                                ),
                              )
                            : null,
                  ),
                  if (index < stages.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isComplete
                            ? AppTheme.primaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Row(
          children: stages.map((stage) {
            final isActive = progress >= stage.startPercent &&
                progress < stage.endPercent;
            final isComplete = progress >= stage.endPercent;
            return Expanded(
              child: Text(
                stage.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isComplete
                      ? AppTheme.primaryColor
                      : isActive
                          ? Colors.grey.shade800
                          : Colors.grey.shade500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
            onPressed: _loadMatches,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.male, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Select a stud to find matches',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The system will analyse all available females\n'
            'and rank them by genetic compatibility.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatchesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No compatible females found'),
          if (_filterSameBreedOnly)
            TextButton(
              onPressed: () => setState(() => _filterSameBreedOnly = false),
              child: const Text('Show all breeds'),
            ),
        ],
      ),
    );
  }

  Widget _buildTrafficLightLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendDot(AppTheme.primaryColor, 'Best'),
        const SizedBox(width: 6),
        _legendDot(Colors.orange, 'OK'),
        const SizedBox(width: 6),
        _legendDot(AppTheme.errorColor, 'Avoid'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildMatchesList(AnimalProvider provider) {
    final matches = _filteredMatches;
    final stud = provider.getAnimalById(_selectedStudId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '${matches.length} potential match${matches.length == 1 ? "" : "es"} '
            'for ${stud?.name ?? "selected stud"}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final suggestion = matches[index];
              return _MatchCard(
                suggestion: suggestion,
                rank: index + 1,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProgressStage {
  final String label;
  final int startPercent;
  final int endPercent;

  const _ProgressStage(this.label, this.startPercent, this.endPercent);
}

/// Traffic-light colour for a COI value.
Color _trafficLightColor(double coi) {
  if (coi < 6.25) return AppTheme.primaryColor;
  if (coi < 12.5) return Colors.orange;
  return AppTheme.errorColor;
}

/// Traffic-light colour for compatibility score.
Color _scoreTrafficLight(double score) {
  if (score >= 70) return AppTheme.primaryColor;
  if (score >= 50) return Colors.orange;
  return AppTheme.errorColor;
}

class _MatchCard extends StatelessWidget {
  final BreedingSuggestion suggestion;
  final int rank;

  const _MatchCard({required this.suggestion, required this.rank});

  @override
  Widget build(BuildContext context) {
    final dam = suggestion.dam;
    final coi = suggestion.estimatedCoi;
    final score = suggestion.compatibilityScore;
    final trafficColor = _scoreTrafficLight(score);
    final coiColor = _trafficLightColor(coi);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: _buildTrafficIndicator(trafficColor, score),
        title: Row(
          children: [
            Expanded(
              child: Text(
                dam.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${dam.breed}${dam.ageDisplay != null ? " - ${dam.ageDisplay}" : ""}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildCoiBadge(coi, coiColor),
                const SizedBox(width: 8),
                _buildGradeBadge(suggestion.scoreGrade, trafficColor),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // COI bar
                _buildCoiBar(coi),
                const SizedBox(height: 12),
                // Pros
                if (suggestion.pros.isNotEmpty) ...[
                  const Text('Positives',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      )),
                  const SizedBox(height: 4),
                  ...suggestion.pros.map((p) => _buildBullet(
                        p,
                        Icons.check_circle,
                        AppTheme.primaryColor,
                      )),
                ],
                // Cons
                if (suggestion.cons.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Concerns',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      )),
                  const SizedBox(height: 4),
                  ...suggestion.cons.map((c) => _buildBullet(
                        c,
                        Icons.warning_amber,
                        Colors.orange,
                      )),
                ],
                // Risks
                if (suggestion.geneticRisks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Genetic Risks',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.errorColor,
                        fontSize: 13,
                      )),
                  const SizedBox(height: 4),
                  ...suggestion.geneticRisks.map((r) => _buildBullet(
                        r,
                        Icons.error_outline,
                        AppTheme.errorColor,
                      )),
                ],
                const SizedBox(height: 12),
                // Quick actions
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/animals/${dam.id}',
                      ),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Female'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficIndicator(Color color, double score) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 2.5),
      ),
      child: Center(
        child: Text(
          '${score.round()}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildCoiBadge(double coi, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        'COI: ${coi.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildGradeBadge(String grade, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        grade,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCoiBar(double coi) {
    final fraction = (coi / 50.0).clamp(0.0, 1.0);
    final color = _trafficLightColor(coi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Inbreeding Coefficient',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const Spacer(),
            Text(
              '${coi.toStringAsFixed(2)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBullet(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
