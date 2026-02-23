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

  int get _progressPercent {
    if (_total <= 0) return 0;
    return ((_processed / _total) * 100).round().clamp(0, 100);
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
          if (_issues != null && !_isRunning) _buildFilterBar(),
          Expanded(
            child: _isRunning
                ? _buildProgressCard()
                : _issues == null
                    ? _buildStartState()
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

  // ─── Professional progress card ───────────────────────────────

  Widget _buildProgressCard() {
    final progress = _progressPercent;
    final fraction = (progress / 100).clamp(0.0, 1.0);
    final hasProgress = progress > 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                    Icons.health_and_safety,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Auditing Pedigree Data',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scanning all animals for integrity issues',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),

                // Gradient progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 12,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
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

                // Percentage + animals scanned row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hasProgress ? '$progress%' : 'Loading...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hasProgress
                            ? AppTheme.primaryColor
                            : Colors.grey.shade500,
                      ),
                    ),
                    if (_total > 0)
                      Text(
                        '$_processed of $_total animals',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Checklist of audit checks
                _buildCheckList(progress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckList(int progress) {
    final checks = [
      _AuditCheck(
        icon: Icons.person_off,
        label: 'Self-reference checks',
        description: 'Sire/dam cannot reference self',
        startPercent: 0,
        endPercent: 12,
      ),
      _AuditCheck(
        icon: Icons.people_outline,
        label: 'Same parent detection',
        description: 'Sire and dam must be different animals',
        startPercent: 12,
        endPercent: 24,
      ),
      _AuditCheck(
        icon: Icons.link_off,
        label: 'Orphan reference checks',
        description: 'Parent records must exist in database',
        startPercent: 24,
        endPercent: 38,
      ),
      _AuditCheck(
        icon: Icons.swap_horiz,
        label: 'Sex mismatch validation',
        description: 'Sires must be male, dams must be female',
        startPercent: 38,
        endPercent: 52,
      ),
      _AuditCheck(
        icon: Icons.calendar_month,
        label: 'Date consistency checks',
        description: 'Parents born before offspring, death after birth',
        startPercent: 52,
        endPercent: 68,
      ),
      _AuditCheck(
        icon: Icons.loop,
        label: 'Circular pedigree detection',
        description: 'No loops in ancestry chain',
        startPercent: 68,
        endPercent: 85,
      ),
      _AuditCheck(
        icon: Icons.copy,
        label: 'Duplicate registrations',
        description: 'Registration numbers must be unique',
        startPercent: 85,
        endPercent: 100,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Checks being performed',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 10),
        ...checks.map((check) => _buildCheckRow(check, progress)),
      ],
    );
  }

  Widget _buildCheckRow(_AuditCheck check, int progress) {
    final isComplete = progress >= check.endPercent;
    final isActive =
        progress >= check.startPercent && progress < check.endPercent;

    final Color iconBgColor;
    final Widget statusWidget;

    if (isComplete) {
      iconBgColor = AppTheme.primaryColor;
      statusWidget = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (isActive) {
      iconBgColor = AppTheme.primaryColor.withValues(alpha: 0.15);
      statusWidget = const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.primaryColor,
        ),
      );
    } else {
      iconBgColor = Colors.grey.shade200;
      statusWidget = const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Status circle
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBgColor,
              border: Border.all(
                color: isComplete || isActive
                    ? AppTheme.primaryColor
                    : Colors.grey.shade400,
                width: 1.5,
              ),
            ),
            child: Center(child: statusWidget),
          ),
          const SizedBox(width: 12),
          // Check icon
          Icon(
            check.icon,
            size: 18,
            color: isComplete
                ? AppTheme.primaryColor
                : isActive
                    ? Colors.grey.shade800
                    : Colors.grey.shade400,
          ),
          const SizedBox(width: 10),
          // Label + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isComplete
                        ? AppTheme.primaryColor
                        : isActive
                            ? Colors.grey.shade900
                            : Colors.grey.shade500,
                  ),
                ),
                Text(
                  check.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: isComplete || isActive
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Summary + filter ─────────────────────────────────────────

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

  // ─── Empty / clean / issues states ────────────────────────────

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

// ─── Helper models ────────────────────────────────────────────

class _AuditCheck {
  final IconData icon;
  final String label;
  final String description;
  final int startPercent;
  final int endPercent;

  const _AuditCheck({
    required this.icon,
    required this.label,
    required this.description,
    required this.startPercent,
    required this.endPercent,
  });
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
