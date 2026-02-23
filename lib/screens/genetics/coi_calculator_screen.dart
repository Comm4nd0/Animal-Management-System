import 'dart:async';
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
  // Store selected animal names for the result card display
  String? _selectedSireName;
  String? _selectedDamName;
  double? _calculatedCoi;
  List<Animal> _commonAncestors = [];
  bool _isCalculating = false;
  String? _error;

  // Sire typeahead state
  final _sireSearchController = TextEditingController();
  final _sireFocusNode = FocusNode();
  bool _sireShowSuggestions = false;
  List<Animal> _sireSuggestions = [];
  Timer? _sireDebounce;
  bool _sireSearchLoading = false;

  // Dam typeahead state
  final _damSearchController = TextEditingController();
  final _damFocusNode = FocusNode();
  bool _damShowSuggestions = false;
  List<Animal> _damSuggestions = [];
  Timer? _damDebounce;
  bool _damSearchLoading = false;

  @override
  void initState() {
    super.initState();
    _sireFocusNode.addListener(() {
      if (_sireFocusNode.hasFocus) {
        setState(() => _sireShowSuggestions = true);
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _sireShowSuggestions = false);
        });
      }
    });
    _damFocusNode.addListener(() {
      if (_damFocusNode.hasFocus) {
        setState(() => _damShowSuggestions = true);
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _damShowSuggestions = false);
        });
      }
    });
    _sireSearchController.addListener(() {
      _sireDebounce?.cancel();
      _sireDebounce = Timer(const Duration(milliseconds: 300), () {
        if (_selectedSireId == null && _sireSearchController.text.trim().isNotEmpty) {
          _searchCandidates(isSire: true);
        }
      });
    });
    _damSearchController.addListener(() {
      _damDebounce?.cancel();
      _damDebounce = Timer(const Duration(milliseconds: 300), () {
        if (_selectedDamId == null && _damSearchController.text.trim().isNotEmpty) {
          _searchCandidates(isSire: false);
        }
      });
    });
  }

  @override
  void dispose() {
    _sireDebounce?.cancel();
    _damDebounce?.cancel();
    _sireSearchController.dispose();
    _damSearchController.dispose();
    _sireFocusNode.dispose();
    _damFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchCandidates({required bool isSire}) async {
    final provider = context.read<AnimalProvider>();
    final controller = isSire ? _sireSearchController : _damSearchController;
    final sex = isSire ? Sex.male : Sex.female;

    String query = controller.text.trim();
    final selectedId = isSire ? _selectedSireId : _selectedDamId;
    if (selectedId != null) return;

    setState(() {
      if (isSire) {
        _sireSearchLoading = true;
      } else {
        _damSearchLoading = true;
      }
    });

    try {
      final results = await provider.searchParentCandidates(
        sex: sex,
        query: query,
      );

      if (!mounted) return;

      setState(() {
        if (isSire) {
          _sireSuggestions = results;
          _sireSearchLoading = false;
        } else {
          _damSuggestions = results;
          _damSearchLoading = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (isSire) {
          _sireSearchLoading = false;
        } else {
          _damSearchLoading = false;
        }
      });
    }
  }

  String _formatAnimalDisplay(Animal a) {
    final reg = a.registrationNumber;
    if (reg != null && reg.isNotEmpty) {
      return '${a.name} - $reg (${a.breed})';
    }
    return '${a.name} (${a.breed})';
  }

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

      List<Animal> ancestors = [];
      try {
        ancestors = await provider.geneticsService.findCommonAncestors(
          _selectedSireId!,
          _selectedDamId!,
        );
      } catch (_) {
        // Common ancestors may not be available on web — non-critical
      }

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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildInfoCard(),
              const SizedBox(height: 16),
              _buildParentSelection(),
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

  Widget _buildParentSelection() {
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
            _buildAnimalTypeahead(
              label: 'Sire (Father)',
              icon: Icons.male,
              iconColor: AppTheme.maleColor,
              selectedId: _selectedSireId,
              suggestions: _sireSuggestions,
              isLoading: _sireSearchLoading,
              controller: _sireSearchController,
              focusNode: _sireFocusNode,
              showSuggestions: _sireShowSuggestions,
              onSelected: (animal) => setState(() {
                _selectedSireId = animal.id;
                _selectedSireName = animal.name;
                _sireSearchController.text = _formatAnimalDisplay(animal);
                _sireShowSuggestions = false;
                _sireFocusNode.unfocus();
                _calculatedCoi = null;
              }),
              onCleared: () {
                setState(() {
                  _selectedSireId = null;
                  _selectedSireName = null;
                  _sireSearchController.clear();
                  _sireSuggestions = [];
                  _calculatedCoi = null;
                });
              },
              onSelectionInvalidated: () {
                setState(() {
                  _selectedSireId = null;
                  _selectedSireName = null;
                  _sireShowSuggestions = true;
                  _calculatedCoi = null;
                });
                _searchCandidates(isSire: true);
              },
            ),
            const SizedBox(height: 12),
            _buildAnimalTypeahead(
              label: 'Dam (Mother)',
              icon: Icons.female,
              iconColor: AppTheme.femaleColor,
              selectedId: _selectedDamId,
              suggestions: _damSuggestions,
              isLoading: _damSearchLoading,
              controller: _damSearchController,
              focusNode: _damFocusNode,
              showSuggestions: _damShowSuggestions,
              onSelected: (animal) => setState(() {
                _selectedDamId = animal.id;
                _selectedDamName = animal.name;
                _damSearchController.text = _formatAnimalDisplay(animal);
                _damShowSuggestions = false;
                _damFocusNode.unfocus();
                _calculatedCoi = null;
              }),
              onCleared: () {
                setState(() {
                  _selectedDamId = null;
                  _selectedDamName = null;
                  _damSearchController.clear();
                  _damSuggestions = [];
                  _calculatedCoi = null;
                });
              },
              onSelectionInvalidated: () {
                setState(() {
                  _selectedDamId = null;
                  _selectedDamName = null;
                  _damShowSuggestions = true;
                  _calculatedCoi = null;
                });
                _searchCandidates(isSire: false);
              },
            ),
          ],
        ),
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
                  color: Colors.black.withOpacity(0.08),
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
        if (shouldShow && suggestions.isEmpty && !isLoading && controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No matching animals found',
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

  Widget _buildResultCard(AnimalProvider provider) {
    final coi = _calculatedCoi!;
    final sireName = _selectedSireName ?? provider.getAnimalById(_selectedSireId!)?.name ?? '?';
    final damName = _selectedDamName ?? provider.getAnimalById(_selectedDamId!)?.name ?? '?';

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
                  '$sireName x $damName',
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
