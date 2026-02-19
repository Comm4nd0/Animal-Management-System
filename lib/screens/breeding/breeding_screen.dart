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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedAnimalId = widget.selectedAnimalId;
    if (_selectedAnimalId != null) {
      _tabController.index = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSuggestions();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    if (_selectedAnimalId == null) return;
    setState(() => _isLoadingSuggestions = true);
    final provider = context.read<AnimalProvider>();
    final suggestions =
        await provider.getBreedingSuggestions(_selectedAnimalId!);
    setState(() {
      _suggestions = suggestions;
      _isLoadingSuggestions = false;
    });
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
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                value: _selectedAnimalId,
                decoration: const InputDecoration(
                  labelText: 'Select Animal for Breeding Suggestions',
                  prefixIcon: Icon(Icons.pets),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Choose an animal...')),
                  ...provider.allAnimals
                      .where((a) => a.status == AnimalStatus.alive)
                      .map((a) => DropdownMenuItem(
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
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedAnimalId == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.science,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('Select an animal to get suggestions'),
                            ],
                          ),
                        )
                      : _suggestions.isEmpty
                          ? const Center(
                              child: Text('No compatible mates found'))
                          : _buildSuggestionsList(),
            ),
          ],
        );
      },
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
                color: _coiColor(suggestion.estimatedCoi).withValues(alpha: 0.15),
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
                            Expanded(child: Text(p, style: const TextStyle(fontSize: 13))),
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
                            Expanded(child: Text(c, style: const TextStyle(fontSize: 13))),
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
                            Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
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
