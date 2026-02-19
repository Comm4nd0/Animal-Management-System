import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/animal_provider.dart';
import '../../services/import_export_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/file_helper.dart' as file_helper;

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _importService = ImportExportService();

  // We store raw bytes for Excel, or text content for CSV/JSON
  String? _textContent;
  Uint8List? _excelBytes;
  String? _selectedFileName;
  int? _fileSize;
  bool _isImporting = false;
  int _processed = 0;
  int _total = 0;
  ImportResult? _result;
  bool _showAllColumns = false;

  bool get _hasFile => _textContent != null || _excelBytes != null;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json', 'xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final pickedFile = result.files.single;
    final name = pickedFile.name.toLowerCase();

    if (name.endsWith('.xlsx') || name.endsWith('.xls')) {
      // Excel file — store raw bytes
      if (pickedFile.bytes == null) return;
      setState(() {
        _excelBytes = pickedFile.bytes;
        _textContent = null;
        _selectedFileName = pickedFile.name;
        _fileSize = pickedFile.size;
        _result = null;
      });
    } else {
      // CSV / JSON — convert bytes to text
      String content;
      if (pickedFile.bytes != null) {
        content = file_helper.bytesToString(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        content = await file_helper.readFileContent(pickedFile.path!);
      } else {
        return;
      }
      setState(() {
        _textContent = content;
        _excelBytes = null;
        _selectedFileName = pickedFile.name;
        _fileSize = pickedFile.size;
        _result = null;
      });
    }
  }

  Future<void> _startImport() async {
    if (!_hasFile || _selectedFileName == null) return;

    setState(() {
      _isImporting = true;
      _processed = 0;
      _total = 0;
      _result = null;
    });

    void onProgress(int p, int t) {
      if (mounted) setState(() { _processed = p; _total = t; });
    }

    final name = _selectedFileName!.toLowerCase();
    ImportResult result;

    if (_excelBytes != null) {
      result = await _importService.importExcelFromBytes(
        _excelBytes!,
        onProgress: onProgress,
      );
      _excelBytes = null;
    } else if (name.endsWith('.json')) {
      result = await _importService.importJsonFromContent(
        _textContent!,
        onProgress: onProgress,
      );
      _textContent = null;
    } else {
      result = await _importService.importCsvFromContent(
        _textContent!,
        onProgress: onProgress,
      );
      _textContent = null;
    }

    if (mounted) {
      await context.read<AnimalProvider>().loadAll();
      setState(() {
        _isImporting = false;
        _result = result;
      });
    }
  }

  Future<void> _downloadTemplate() async {
    final content = _importService.generateTemplateContent();
    await file_helper.downloadFile(content, 'animal_import_template.csv');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(kIsWeb
            ? 'Template downloaded'
            : 'Template saved to documents'),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _clearFile() {
    setState(() {
      _textContent = null;
      _excelBytes = null;
      _selectedFileName = null;
      _fileSize = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Animals')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepOne(),
                const SizedBox(height: 16),
                _buildColumnReference(),
                const SizedBox(height: 16),
                _buildStepTwo(),
                if (_hasFile && !_isImporting && _result == null)
                  _buildImportButton(),
                if (_isImporting) _buildProgress(),
                if (_result != null) _buildResult(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Step 1: Prepare your file ──────────────────────────────

  Widget _buildStepOne() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader(1, 'Prepare your file'),
            const SizedBox(height: 12),
            // Supported formats
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _formatChip(Icons.table_chart, 'Excel (.xlsx)', Colors.green.shade700),
                _formatChip(Icons.description, 'CSV (.csv)', Colors.blue.shade700),
                _formatChip(Icons.data_object, 'JSON (.json)', Colors.orange.shade700),
              ],
            ),
            const SizedBox(height: 16),
            // Visual example
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _buildExampleTable(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your first row must be column headers. '
              'Headers are flexible \u2014 "Date Of Birth", '
              '"date_of_birth", or "dateOfBirth" all work.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isImporting ? null : _downloadTemplate,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download Template CSV'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleTable() {
    const headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
      color: Colors.white,
    );
    final cellStyle = TextStyle(fontSize: 12, color: Colors.grey.shade800);

    return DataTable(
      headingRowColor: WidgetStatePropertyAll(AppTheme.primaryColor),
      headingRowHeight: 36,
      dataRowMinHeight: 30,
      dataRowMaxHeight: 30,
      columnSpacing: 16,
      horizontalMargin: 10,
      columns: const [
        DataColumn(label: Text('name', style: headerStyle)),
        DataColumn(label: Text('species', style: headerStyle)),
        DataColumn(label: Text('breed', style: headerStyle)),
        DataColumn(label: Text('sex', style: headerStyle)),
        DataColumn(label: Text('date_of_birth', style: headerStyle)),
        DataColumn(label: Text('registration_number', style: headerStyle)),
        DataColumn(label: Text('sire_id', style: headerStyle)),
      ],
      rows: [
        DataRow(cells: [
          DataCell(Text('Champion Rex', style: cellStyle)),
          DataCell(Text('Dog', style: cellStyle)),
          DataCell(Text('Labrador', style: cellStyle)),
          DataCell(Text('male', style: cellStyle)),
          DataCell(Text('2022-01-15', style: cellStyle)),
          DataCell(Text('REG-001', style: cellStyle)),
          DataCell(Text('', style: cellStyle)),
        ]),
        DataRow(cells: [
          DataCell(Text('Lady Belle', style: cellStyle)),
          DataCell(Text('Dog', style: cellStyle)),
          DataCell(Text('Labrador', style: cellStyle)),
          DataCell(Text('female', style: cellStyle)),
          DataCell(Text('2023-06-20', style: cellStyle)),
          DataCell(Text('REG-002', style: cellStyle)),
          DataCell(Text('abc-123...', style: cellStyle)),
        ]),
      ],
    );
  }

  // ─── Column reference ───────────────────────────────────────

  Widget _buildColumnReference() {
    const required = [
      ('name', 'Animal name', 'Champion Rex'),
      ('species', 'Species type', 'Dog'),
      ('breed', 'Breed name', 'Labrador Retriever'),
    ];
    const optional = [
      ('sex', 'male, female, or unknown', 'male'),
      ('status', 'alive, deceased, sold, transferred', 'alive'),
      ('date_of_birth', 'Date (YYYY-MM-DD)', '2022-01-15'),
      ('date_of_death', 'Date (YYYY-MM-DD)', ''),
      ('color', 'Coat colour', 'Black'),
      ('markings', 'Distinguishing marks', 'White chest'),
      ('registration_number', 'Registry ID', 'REG-12345'),
      ('microchip_number', 'Microchip ID', '123456789012345'),
      ('sire_id', 'Father\u2019s UUID or ID', ''),
      ('dam_id', 'Mother\u2019s UUID or ID', ''),
      ('weight', 'Weight in kg', '25.5'),
      ('height', 'Height in cm', '58.0'),
      ('notes', 'Free-text notes', ''),
      ('id', 'UUID (auto-generated if blank)', ''),
      ('dna_profile_id', 'DNA test ID', ''),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.view_column, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Column Reference',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Required columns
            Text(
              'REQUIRED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.errorColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            ...required.map((c) => _columnRow(c.$1, c.$2, c.$3, true)),
            const Divider(height: 16),
            // Optional columns
            Row(
              children: [
                Text(
                  'OPTIONAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      setState(() => _showAllColumns = !_showAllColumns),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    _showAllColumns
                        ? 'Show less'
                        : 'Show all ${optional.length} columns',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...(_showAllColumns ? optional : optional.take(5))
                .map((c) => _columnRow(c.$1, c.$2, c.$3, false)),
            if (!_showAllColumns)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${optional.length - 5} more optional columns...',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _columnRow(String name, String description, String example, bool required) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: required
                  ? AppTheme.errorColor.withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: required ? AppTheme.errorColor : Colors.grey.shade800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          if (example.isNotEmpty)
            Text(
              'e.g. $example',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  // ─── Step 2: Upload ─────────────────────────────────────────

  Widget _buildStepTwo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader(2, 'Upload your file'),
            const SizedBox(height: 12),
            if (!_hasFile)
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
                        kIsWeb
                            ? 'Click to choose .xlsx, .csv, or .json file'
                            : 'Tap to choose .xlsx, .csv, or .json file',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Excel, CSV, and JSON are all supported',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: Icon(
                    _fileIcon(),
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
                        onPressed: _clearFile,
                      ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _fileIcon() {
    final name = _selectedFileName?.toLowerCase() ?? '';
    if (name.endsWith('.json')) return Icons.data_object;
    if (name.endsWith('.xlsx') || name.endsWith('.xls')) return Icons.grid_on;
    return Icons.table_chart;
  }

  Widget _stepHeader(int number, String title) {
    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: AppTheme.primaryColor,
          child: Text(
            '$number',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _formatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  // ─── Step 3: Import ─────────────────────────────────────────

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
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
                      Expanded(
                        child: Text(
                          success
                              ? 'Import Complete'
                              : 'Import Finished with Issues',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
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
                    result.elapsed.inSeconds > 0
                        ? '${result.elapsed.inSeconds}s'
                        : '${result.elapsed.inMilliseconds}ms',
                  ),
                  if (result.imported > 0) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/data-audit'),
                      icon: const Icon(Icons.health_and_safety, size: 18),
                      label: const Text('Run Data Audit'),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
                        backgroundColor:
                            AppTheme.errorColor.withValues(alpha: 0.15),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearFile,
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
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
