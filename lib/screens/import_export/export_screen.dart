import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/animal_provider.dart';
import '../../services/import_export_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/file_helper.dart' as file_helper;

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _exportService = ImportExportService();

  String _format = 'csv';
  String _scope = 'all'; // 'all' or 'filtered'
  bool _isExporting = false;
  int _written = 0;
  int _total = 0;
  bool _exportDone = false;
  int? _exportedCount;
  String? _savedPath; // Only set on native after save

  Future<void> _startExport() async {
    final provider = context.read<AnimalProvider>();
    final List<Animal>? animals =
        _scope == 'filtered' ? provider.animals : null;

    setState(() {
      _isExporting = true;
      _written = 0;
      _total = 0;
      _exportDone = false;
      _savedPath = null;
    });

    // Generate content as a string (platform-agnostic)
    String content;
    if (_format == 'json') {
      content = await _exportService.exportJsonContent(
        animals: animals,
        onProgress: (w, t) {
          if (mounted) setState(() { _written = w; _total = t; });
        },
      );
    } else {
      content = await _exportService.exportCsvContent(
        animals: animals,
        onProgress: (w, t) {
          if (mounted) setState(() { _written = w; _total = t; });
        },
      );
    }

    // Save / download the file
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final ext = _format == 'json' ? 'json' : 'csv';
    final filename = 'animals_export_$timestamp.$ext';

    final path = await file_helper.downloadFile(content, filename);

    if (mounted) {
      setState(() {
        _isExporting = false;
        _exportDone = true;
        _exportedCount = _total;
        _savedPath = path;
      });
    }
  }

  Future<void> _shareFile() async {
    if (_savedPath == null) return;
    await file_helper.shareFile(_savedPath!, subject: 'Animal Data Export');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnimalProvider>();
    final allCount = provider.allAnimals.length;
    final filteredCount = provider.animals.length;
    final hasFilters = provider.hasActiveFilters;

    return Scaffold(
      appBar: AppBar(title: const Text('Export Animals')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Format selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Format',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _FormatOption(
                          icon: Icons.table_chart,
                          title: 'CSV',
                          subtitle:
                              'Comma-separated values. Compatible with Excel, '
                              'Google Sheets, and most data tools.',
                          selected: _format == 'csv',
                          onTap: () => setState(() => _format = 'csv'),
                        ),
                        const SizedBox(height: 8),
                        _FormatOption(
                          icon: Icons.data_object,
                          title: 'JSON',
                          subtitle:
                              'Structured data format. Best for re-importing '
                              'or integration with other software.',
                          selected: _format == 'json',
                          onTap: () => setState(() => _format = 'json'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Scope selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data Scope',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        RadioListTile<String>(
                          title: Text('All animals ($allCount)'),
                          value: 'all',
                          groupValue: _scope,
                          onChanged: (v) => setState(() => _scope = v!),
                          dense: true,
                          activeColor: AppTheme.primaryColor,
                        ),
                        RadioListTile<String>(
                          title: Text(
                            'Current filter ($filteredCount)',
                            style: TextStyle(
                              color: hasFilters ? null : Colors.grey,
                            ),
                          ),
                          subtitle: hasFilters
                              ? const Text('Uses your active search/filter')
                              : const Text(
                                  'No filters active \u2014 same as all'),
                          value: 'filtered',
                          groupValue: _scope,
                          onChanged: (v) => setState(() => _scope = v!),
                          dense: true,
                          activeColor: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Export button
                if (!_isExporting && !_exportDone)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: allCount > 0 ? _startExport : null,
                      icon: const Icon(Icons.download, size: 20),
                      label: const Text('Export'),
                    ),
                  ),

                // Progress
                if (_isExporting)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _total > 0 ? _written / _total : null,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation(
                                AppTheme.primaryColor),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _total > 0
                                ? 'Writing record $_written of $_total...'
                                : 'Preparing export...',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Result
                if (_exportDone) _buildResult(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Export Complete',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$_exportedCount animals exported to ${_format.toUpperCase()}.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (!kIsWeb && _savedPath != null) ...[
              const SizedBox(height: 4),
              Text(
                _savedPath!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
            if (kIsWeb) ...[
              const SizedBox(height: 4),
              Text(
                'File downloaded to your browser\'s downloads folder.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (!kIsWeb)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareFile,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                if (!kIsWeb) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _exportDone = false;
                      _savedPath = null;
                      _exportedCount = null;
                    }),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Export Again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _FormatOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.06)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected
                    ? AppTheme.primaryColor
                    : Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? AppTheme.primaryColor : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppTheme.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
