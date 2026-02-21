import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
import '../../services/pedigree_validator.dart';
import '../../utils/app_theme.dart';

class DataAuditScreen extends StatefulWidget {
  const DataAuditScreen({super.key});

  @override
  State<DataAuditScreen> createState() => _DataAuditScreenState();
}

class _DataAuditScreenState extends State<DataAuditScreen> {
  List<DataIssue>? _issues;
  bool _isRunning = false;
  int _processed = 0;
  int _total = 0;
  String _filterCode = 'ALL';

  Future<void> _runAudit() async {
    setState(() {
      _isRunning = true;
      _issues = null;
      _processed = 0;
      _total = 0;
    });

    final provider = context.read<AnimalProvider>();
    final issues = await provider.auditData(
      onProgress: (processed, total) {
        if (mounted) {
          setState(() {
            _processed = processed;
            _total = total;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _issues = issues;
        _isRunning = false;
      });
    }
  }

  List<DataIssue> get _filteredIssues {
    if (_issues == null) return [];
    if (_filterCode == 'ALL') return _issues!;
    if (_filterCode == 'ERRORS') {
      return _issues!.where((i) => i.severity == IssueSeverity.error).toList();
    }
    if (_filterCode == 'WARNINGS') {
      return _issues!.where((i) => i.severity == IssueSeverity.warning).toList();
    }
    return _issues!.where((i) => i.code == _filterCode).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Audit'),
      ),
      body: Column(
        children: [
          _buildHeader(),
          if (_isRunning) _buildProgress(),
          if (_issues != null && !_isRunning) _buildFilterBar(),
          Expanded(
            child: _issues == null && !_isRunning
                ? _buildStartState()
                : _isRunning
                    ? const SizedBox.shrink()
                    : _filteredIssues.isEmpty
                        ? _buildCleanState()
                        : _buildIssuesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppTheme.primaryColor.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Pedigree Data Audit',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Scans all animals for data integrity issues including circular '
            'pedigrees, sex mismatches, date inconsistencies, orphan references, '
            'and duplicate registrations.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _isRunning ? null : _runAudit,
              icon: _isRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow, size: 18),
              label: Text(_isRunning
                  ? 'Scanning...'
                  : _issues != null
                      ? 'Re-run Audit'
                      : 'Run Audit'),
            ),
          ),
          if (_issues != null && !_isRunning) ...[
            const SizedBox(height: 8),
            _buildSummary(),
          ],
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _total > 0 ? _processed / _total : null,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            _total > 0
                ? 'Checking animal $_processed of $_total...'
                : 'Loading animals...',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final errors =
        _issues!.where((i) => i.severity == IssueSeverity.error).length;
    final warnings =
        _issues!.where((i) => i.severity == IssueSeverity.warning).length;

    return Row(
      children: [
        _SummaryChip(
          icon: Icons.error,
          label: '$errors error${errors == 1 ? "" : "s"}',
          color: errors > 0 ? AppTheme.errorColor : AppTheme.primaryColor,
        ),
        const SizedBox(width: 8),
        _SummaryChip(
          icon: Icons.warning,
          label: '$warnings warning${warnings == 1 ? "" : "s"}',
          color: warnings > 0 ? Colors.orange : AppTheme.primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          '$_total animals scanned',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    // Collect unique issue codes
    final codes = <String>{};
    for (final issue in _issues!) {
      codes.add(issue.code);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('ALL', 'All (${_issues!.length})'),
          _buildFilterChip(
            'ERRORS',
            'Errors (${_issues!.where((i) => i.severity == IssueSeverity.error).length})',
          ),
          _buildFilterChip(
            'WARNINGS',
            'Warnings (${_issues!.where((i) => i.severity == IssueSeverity.warning).length})',
          ),
          ...codes.map((code) {
            final count = _issues!.where((i) => i.code == code).length;
            return _buildFilterChip(code, '${_readableCode(code)} ($count)');
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String code, String label) {
    final selected = _filterCode == code;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _filterCode = code),
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
        checkmarkColor: AppTheme.primaryColor,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  String _readableCode(String code) {
    switch (code) {
      case 'SELF_SIRE':
        return 'Self Sire';
      case 'SELF_DAM':
        return 'Self Dam';
      case 'SAME_PARENTS':
        return 'Same Parents';
      case 'ORPHAN_SIRE':
        return 'Missing Sire';
      case 'ORPHAN_DAM':
        return 'Missing Dam';
      case 'SIRE_IS_FEMALE':
        return 'Sire Female';
      case 'DAM_IS_MALE':
        return 'Dam Male';
      case 'SIRE_BORN_AFTER':
        return 'Sire DOB';
      case 'DAM_BORN_AFTER':
        return 'Dam DOB';
      case 'DEATH_BEFORE_BIRTH':
        return 'Death < Birth';
      case 'CIRCULAR_PEDIGREE':
        return 'Circular';
      case 'DUPLICATE_REG':
        return 'Dup. Reg#';
      default:
        return code;
    }
  }

  Widget _buildStartState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.health_and_safety, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Tap "Run Audit" to scan your data',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Checks are optimised for large datasets',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 64, color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          Text(
            _filterCode == 'ALL'
                ? 'No issues found!'
                : 'No matching issues',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filterCode == 'ALL'
                ? 'Your pedigree data is clean.'
                : 'Try a different filter.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesList() {
    final issues = _filteredIssues;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: issues.length,
      itemBuilder: (context, index) {
        final issue = issues[index];
        return _IssueCard(issue: issue);
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final DataIssue issue;

  const _IssueCard({required this.issue});

  @override
  Widget build(BuildContext context) {
    final isError = issue.severity == IssueSeverity.error;
    final color = isError ? AppTheme.errorColor : Colors.orange;
    final icon = isError ? Icons.error : Icons.warning;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          issue.animalName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          issue.message,
          style: const TextStyle(fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => Navigator.pushNamed(
          context,
          '/animals/${issue.animalId}',
        ),
        isThreeLine: true,
      ),
    );
  }
}
