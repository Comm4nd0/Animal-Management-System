import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';

const _kAnalysisSteps = <_AnalysisStep>[
  _AnalysisStep(Icons.storage, 'Loading pedigree database'),
  _AnalysisStep(Icons.people_alt, 'Filtering eligible candidates'),
  _AnalysisStep(Icons.account_tree, 'Building pedigree trees (5 generations)'),
  _AnalysisStep(Icons.calculate, 'Calculating COI coefficients'),
  _AnalysisStep(Icons.compare_arrows, 'Evaluating breed compatibility'),
  _AnalysisStep(Icons.monitor_heart, 'Analysing age & health factors'),
  _AnalysisStep(Icons.sort, 'Ranking results'),
];

class BreedingScreen extends StatefulWidget {
  final String? selectedAnimalId;

  const BreedingScreen({super.key, this.selectedAnimalId});

  @override
  State<BreedingScreen> createState() => _BreedingScreenState();
}

class _BreedingScreenState extends State<BreedingScreen> {
  String? _selectedAnimalId;
  List<BreedingSuggestion> _suggestions = [];
  bool _isLoadingSuggestions = false;
  bool _isLoadingAnimals = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedAnimalId = widget.selectedAnimalId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureAnimalsLoaded();
      if (_selectedAnimalId != null) {
        _loadSuggestions();
      }
    });
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
        title: const Text('Breeding Suggestions'),
      ),
      body: _buildSuggestionsTab(),
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
                  ? _AnalysisProgressPanel(
                      animalName: _getSelectedAnimalName(provider),
                      candidateCount: liveAnimals.length,
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

}

// ─── Analysis Progress Panel ──────────────────────────────────────────────

/// Immutable description of one analysis step shown in the progress panel.
class _AnalysisStep {
  final IconData icon;
  final String label;
  const _AnalysisStep(this.icon, this.label);
}

/// A professional loading panel that walks through the analysis steps with
/// animated progress, giving the user clear feedback that work is happening.
class _AnalysisProgressPanel extends StatefulWidget {
  final String animalName;
  final int candidateCount;

  const _AnalysisProgressPanel({
    required this.animalName,
    required this.candidateCount,
  });

  @override
  State<_AnalysisProgressPanel> createState() => _AnalysisProgressPanelState();
}

class _AnalysisProgressPanelState extends State<_AnalysisProgressPanel>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  Timer? _stepTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Advance through the steps on a timer so the user sees progress
    _stepTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) return;
      if (_currentStep < _kAnalysisSteps.length - 1) {
        setState(() => _currentStep++);
      }
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        ((_currentStep + 1) / _kAnalysisSteps.length).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // ── Header card ──────────────────────────────────────────
          Card(
            elevation: 0,
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: AppTheme.primaryColor.withValues(alpha: 0.25),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.biotech,
                      color: AppTheme.primaryColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analysing genetics for ${widget.animalName}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Evaluating ${widget.candidateCount} candidates '
                          'across 5 pedigree generations',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ── Progress bar ─────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor:
                  const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(progress * 100).toInt()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // ── Step list ────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _kAnalysisSteps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final step = _kAnalysisSteps[index];
                final isDone = index < _currentStep;
                final isActive = index == _currentStep;

                return _PulsingStepTile(
                  animation: _pulseController,
                  isActive: isActive,
                  isDone: isDone,
                  step: step,
                  textColor: isDone || isActive
                      ? theme.textTheme.bodyLarge?.color
                      : Colors.grey.shade400,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A single analysis step row that pulses when active.
class _PulsingStepTile extends AnimatedWidget {
  final bool isActive;
  final bool isDone;
  final _AnalysisStep step;
  final Color? textColor;

  const _PulsingStepTile({
    required Animation<double> animation,
    required this.isActive,
    required this.isDone,
    required this.step,
    this.textColor,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final controller = listenable as Animation<double>;
    final double opacity =
        isActive ? 0.7 + 0.3 * controller.value : 1.0;

    return Opacity(
      opacity: opacity,
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        leading: isDone
            ? const Icon(Icons.check_circle,
                color: AppTheme.primaryColor, size: 22)
            : isActive
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation(AppTheme.primaryColor),
                    ),
                  )
                : Icon(step.icon, color: Colors.grey.shade400, size: 22),
        title: Text(
          step.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: textColor,
          ),
        ),
      ),
    );
  }
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
