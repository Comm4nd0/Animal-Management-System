import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';

class CoiCalculatorScreen extends StatefulWidget {
  const CoiCalculatorScreen({super.key});

  @override
  State<CoiCalculatorScreen> createState() => _CoiCalculatorScreenState();
}

class _CoiCalculatorScreenState extends State<CoiCalculatorScreen> {
  String? _selectedSireId;
  String? _selectedDamId;
  double? _calculatedCoi;
  List<Animal> _commonAncestors = [];
  bool _isCalculating = false;
  String? _error;

  Future<void> _calculate() async {
    if (_selectedSireId == null || _selectedDamId == null) return;

    setState(() {
      _isCalculating = true;
      _error = null;
      _calculatedCoi = null;
      _commonAncestors = [];
    });

    try {
      final provider = context.read<AnimalProvider>();
      final coi = await provider.calculateCOI(_selectedSireId!, _selectedDamId!);
      final ancestors = await provider.geneticsService.findCommonAncestors(
        _selectedSireId!,
        _selectedDamId!,
      );

      setState(() {
        _calculatedCoi = coi;
        _commonAncestors = ancestors;
        _isCalculating = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to calculate: $e';
        _isCalculating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbreeding Calculator'),
      ),
      body: Consumer<AnimalProvider>(
        builder: (context, provider, _) {
          final males = provider.allAnimals
              .where((a) => a.sex == Sex.male && a.status == AnimalStatus.alive)
              .toList();
          final females = provider.allAnimals
              .where((a) => a.sex == Sex.female && a.status == AnimalStatus.alive)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildInfoCard(),
              const SizedBox(height: 16),
              _buildParentSelection(males, females),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedSireId != null && _selectedDamId != null && !_isCalculating
                      ? _calculate
                      : null,
                  icon: _isCalculating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.calculate),
                  label: Text(_isCalculating ? 'Calculating...' : 'Calculate COI'),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
                ),
              if (_calculatedCoi != null) ...[
                const SizedBox(height: 24),
                _buildResultCard(provider),
                if (_commonAncestors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildCommonAncestorsCard(),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.08),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Select a sire and dam to calculate Wright's Coefficient of "
                "Inbreeding (COI) for their hypothetical offspring. Lower COI "
                "values indicate greater genetic diversity.",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentSelection(List<Animal> males, List<Animal> females) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Parents',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedSireId,
              decoration: const InputDecoration(
                labelText: 'Sire (Father)',
                prefixIcon: Icon(Icons.male, color: AppTheme.maleColor),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Select sire...')),
                ...males.map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name} (${a.breed})'),
                    )),
              ],
              onChanged: (v) => setState(() {
                _selectedSireId = v;
                _calculatedCoi = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedDamId,
              decoration: const InputDecoration(
                labelText: 'Dam (Mother)',
                prefixIcon: Icon(Icons.female, color: AppTheme.femaleColor),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Select dam...')),
                ...females.map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name} (${a.breed})'),
                    )),
              ],
              onChanged: (v) => setState(() {
                _selectedDamId = v;
                _calculatedCoi = null;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(AnimalProvider provider) {
    final coi = _calculatedCoi!;
    final sire = provider.getAnimalById(_selectedSireId!);
    final dam = provider.getAnimalById(_selectedDamId!);

    // Traffic light rating
    final Color ratingColor;
    final String ratingLabel;
    final String ratingDescription;
    final IconData ratingIcon;

    if (coi < 3.0) {
      ratingColor = AppTheme.primaryColor;
      ratingLabel = 'Excellent';
      ratingDescription = 'Very low inbreeding. This pairing has excellent genetic diversity.';
      ratingIcon = Icons.check_circle;
    } else if (coi < 6.25) {
      ratingColor = const Color(0xFF4CAF50);
      ratingLabel = 'Good';
      ratingDescription = 'Acceptable level of inbreeding within safe breeding guidelines.';
      ratingIcon = Icons.check_circle_outline;
    } else if (coi < 12.5) {
      ratingColor = Colors.orange;
      ratingLabel = 'Caution';
      ratingDescription = 'Elevated inbreeding. Consider alternative pairings if possible.';
      ratingIcon = Icons.warning;
    } else if (coi < 25.0) {
      ratingColor = AppTheme.errorColor;
      ratingLabel = 'High Risk';
      ratingDescription = 'High inbreeding coefficient. Significant risk of genetic issues.';
      ratingIcon = Icons.error;
    } else {
      ratingColor = const Color(0xFF880E4F);
      ratingLabel = 'Critical';
      ratingDescription = 'Extremely high inbreeding. This pairing is strongly discouraged.';
      ratingIcon = Icons.dangerous;
    }

    return Card(
      child: Column(
        children: [
          // Header with COI gauge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ratingColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                Text(
                  '${sire?.name ?? "?"} x ${dam?.name ?? "?"}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                // Large COI display
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: ratingColor, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: ratingColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        coi.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: ratingColor,
                        ),
                      ),
                      Text(
                        '%',
                        style: TextStyle(
                          fontSize: 14,
                          color: ratingColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Rating badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ratingColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(ratingIcon, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        ratingLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ratingDescription,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildCoiScale(coi),
                const SizedBox(height: 12),
                Text(
                  'COI Reference Guide',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                _buildReferenceRow('< 3%', 'Excellent', AppTheme.primaryColor),
                _buildReferenceRow('3% - 6.25%', 'Good', const Color(0xFF4CAF50)),
                _buildReferenceRow('6.25% - 12.5%', 'Caution', Colors.orange),
                _buildReferenceRow('12.5% - 25%', 'High Risk', AppTheme.errorColor),
                _buildReferenceRow('> 25%', 'Critical', const Color(0xFF880E4F)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoiScale(double coi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 12,
            child: Stack(
              children: [
                // Gradient background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        Color(0xFF4CAF50),
                        Colors.orange,
                        AppTheme.errorColor,
                        Color(0xFF880E4F),
                      ],
                      stops: [0.0, 0.12, 0.25, 0.5, 1.0],
                    ),
                  ),
                ),
                // Marker
                Positioned(
                  left: (coi / 50.0).clamp(0.0, 1.0) *
                      (MediaQuery.of(context).size.width - 64),
                  child: Container(
                    width: 4,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black54),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0%', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            Text('25%', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            Text('50%', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  Widget _buildReferenceRow(String range, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(range, style: const TextStyle(fontSize: 12)),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildCommonAncestorsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree, size: 20, color: AppTheme.accentColor),
                const SizedBox(width: 8),
                Text(
                  'Common Ancestors (${_commonAncestors.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'These ancestors appear in both the sire\'s and dam\'s pedigree, '
              'contributing to the inbreeding coefficient.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ..._commonAncestors.map((ancestor) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: ancestor.sex == Sex.male
                        ? AppTheme.maleColor.withValues(alpha: 0.2)
                        : AppTheme.femaleColor.withValues(alpha: 0.2),
                    child: Icon(
                      ancestor.sex == Sex.male ? Icons.male : Icons.female,
                      size: 16,
                      color: ancestor.sex == Sex.male
                          ? AppTheme.maleColor
                          : AppTheme.femaleColor,
                    ),
                  ),
                  title: Text(ancestor.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '${ancestor.breed}${ancestor.ageDisplay != null ? " - ${ancestor.ageDisplay}" : ""}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/animals/${ancestor.id}',
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                )),
          ],
        ),
      ),
    );
  }
}
