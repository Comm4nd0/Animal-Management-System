import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/animal_provider.dart';
import '../../services/import_export_service.dart';
import '../../utils/app_theme.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _importService = ImportExportService();

  String? _selectedFilePath;
  String? _selectedFileName;
  int? _fileSize;
  bool _isImporting = false;
  int _processed = 0;
  int _total = 0;
  ImportResult? _result;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() {
        _selectedFilePath = file.path;
        _selectedFileName = result.files.single.name;
        _fileSize = result.files.single.size;
        _result = null;
      });
    }
  }

  Future<void> _startImport() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isImporting = true;
      _processed = 0;
      _total = 0;
      _result = null;
    });

    final isJson = _selectedFilePath!.toLowerCase().endsWith('.json');

    ImportResult result;
    if (isJson) {
      result = await _importService.importJson(
        _selectedFilePath!,
        onProgress: (p, t) {
          if (mounted) setState(() { _processed = p; _total = t; });
        },
      );
    } else {
      result = await _importService.importCsv(
        _selectedFilePath!,
        onProgress: (p, t) {
          if (mounted) setState(() { _processed = p; _total = t; });
        },
      );
    }

    // Reload the animal list in the provider
    if (mounted) {
      await context.read<AnimalProvider>().loadAll();
      setState(() {
        _isImporting = false;
        _result = result;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Animals')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildFileSelection(),
            if (_selectedFilePath != null && !_isImporting && _result == null)
              _buildImportButton(),
            if (_isImporting) _buildProgress(),
            if (_result != null) _buildResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Import Format',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Supported formats: CSV (.csv) and JSON (.json).\n\n'
              'Required columns: name, species, breed\n\n'
              'Optional columns: id, sex, status, date_of_birth, '
              'date_of_death, color, markings, registration_number, '
              'microchip_number, sire_id, dam_id, weight, height, notes\n\n'
              'Column headers are flexible — camelCase, snake_case, '
              'and "Title Case" are all accepted. Dates should be '
              'in YYYY-MM-DD format.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isImporting ? null : _downloadTemplate,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download Template CSV'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadTemplate() async {
    final path = await _importService.generateTemplate();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Template saved to: $path')),
    );
  }

  Widget _buildFileSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select File',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (_selectedFilePath == null)
              SizedBox(
                width: double.infinity,
                height: 120,
                child: OutlinedButton(
                  onPressed: _isImporting ? null : _pickFile,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file,
                          size: 36, color: Colors.grey.shade500),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to select a CSV or JSON file',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: Icon(
                    _selectedFileName!.endsWith('.json')
                        ? Icons.data_object
                        : Icons.table_chart,
                    color: AppTheme.primaryColor,
                  ),
                ),
                title: Text(
                  _selectedFileName!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: _fileSize != null
                    ? Text(_formatFileSize(_fileSize!))
                    : null,
                trailing: _isImporting
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _selectedFilePath = null;
                          _selectedFileName = null;
                          _fileSize = null;
                          _result = null;
                        }),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _startImport,
          icon: const Icon(Icons.upload, size: 20),
          label: const Text('Start Import'),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: _total > 0 ? _processed / _total : null,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    const AlwaysStoppedAnimation(AppTheme.primaryColor),
              ),
              const SizedBox(height: 12),
              Text(
                _total > 0
                    ? 'Processing row $_processed of $_total...'
                    : 'Reading file...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                'Do not close this screen',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final result = _result!;
    final hasErrors = result.errors.isNotEmpty;
    final success = result.imported > 0 && result.errors.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Card(
            color: success
                ? AppTheme.primaryColor.withValues(alpha: 0.06)
                : hasErrors
                    ? AppTheme.errorColor.withValues(alpha: 0.06)
                    : Colors.orange.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        success
                            ? Icons.check_circle
                            : hasErrors
                                ? Icons.error
                                : Icons.warning,
                        color: success
                            ? AppTheme.primaryColor
                            : hasErrors
                                ? AppTheme.errorColor
                                : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        success ? 'Import Complete' : 'Import Finished with Issues',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _summaryRow('Total rows', result.totalRows.toString()),
                  _summaryRow('Imported', result.imported.toString()),
                  _summaryRow('Skipped', result.skipped.toString()),
                  _summaryRow('Errors', result.errors.length.toString()),
                  _summaryRow(
                    'Duration',
                    '${result.elapsed.inSeconds > 0 ? "${result.elapsed.inSeconds}s" : "${result.elapsed.inMilliseconds}ms"}',
                  ),
                  if (result.imported > 0) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/data-audit'),
                      icon: const Icon(Icons.health_and_safety, size: 18),
                      label: const Text('Run Data Audit'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Error details
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Errors (${result.errors.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ...result.errors.take(100).map(
                  (e) => Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.errorColor.withValues(alpha: 0.15),
                        child: Text(
                          '${e.row}',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.errorColor),
                        ),
                      ),
                      title: Text(
                        e.message,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
            if (result.errors.length > 100)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '... and ${result.errors.length - 100} more errors',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
          ],

          // Import another file
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _selectedFilePath = null;
                _selectedFileName = null;
                _fileSize = null;
                _result = null;
              }),
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Import Another File'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
