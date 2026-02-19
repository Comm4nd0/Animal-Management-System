import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.preselectedStudId != null) {
      _selectedStudId = widget.preselectedStudId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMatches());
    }
  }

  Future<void> _loadMatches() async {
    if (_selectedStudId == null) return;
    setState(() {
      _isLoading = true;
      _matches = [];
    });

    final provider = context.read<AnimalProvider>();
    // Use the genetics service with a high maxResults to get all females
    final suggestions = await provider.geneticsService.generateBreedingSuggestions(
      _selectedStudId!,
      maxResults: 100,
      maxCoiThreshold: 100.0, // Show all, we'll colour-code them
    );

    setState(() {
      _matches = suggestions;
      _isLoading = false;
    });
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
          final males = provider.allAnimals
              .where((a) => a.sex == Sex.male && a.status == AnimalStatus.alive)
              .toList();

          return Column(
            children: [
              // Stud selection + filter
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedStudId,
                      decoration: const InputDecoration(
                        labelText: 'Select Stud (Male)',
                        prefixIcon: Icon(Icons.male, color: AppTheme.maleColor),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Choose a stud...')),
                        ...males.map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text('${a.name} (${a.breed})'),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _selectedStudId = v;
                          _matches = [];
                        });
                        if (v != null) _loadMatches();
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
                    ? const Center(child: CircularProgressIndicator())
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
                        '/animal/detail',
                        arguments: dam.id,
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
