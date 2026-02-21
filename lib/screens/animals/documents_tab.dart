import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/animal_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/demo_write_guard.dart';

class DocumentsTab extends StatelessWidget {
  final String animalId;
  const DocumentsTab({super.key, required this.animalId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AnimalProvider>(
      builder: (context, provider, _) {
        final docs = provider.documentAttachments;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (!await guardWriteAction(context)) return;
                  _addDocument(context, provider);
                },
                icon: const Icon(Icons.attach_file),
                label: const Text('Attach Document'),
              ),
            ),
            Expanded(
              child: docs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No documents attached'),
                          const SizedBox(height: 4),
                          Text(
                            'Attach certificates, test results, and more',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              _docTypeIcon(doc.documentType),
                              color: AppTheme.primaryColor,
                            ),
                            title: Text(doc.title),
                            subtitle: Text(
                              [
                                doc.documentType.label,
                                DateFormat.yMMMd().format(doc.uploadedAt),
                              ].join(' - '),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () async {
                                if (!await guardWriteAction(context)) return;
                                _confirmDelete(context, provider, doc);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  IconData _docTypeIcon(DocumentType type) {
    return switch (type) {
      DocumentType.pedigreeCert => Icons.account_tree,
      DocumentType.registration => Icons.card_membership,
      DocumentType.dnaTest => Icons.science,
      DocumentType.healthCert => Icons.medical_services,
      DocumentType.insurance => Icons.shield,
      DocumentType.contract => Icons.description,
      DocumentType.photoId => Icons.badge,
      DocumentType.other => Icons.insert_drive_file,
    };
  }

  Future<void> _addDocument(
      BuildContext context, AnimalProvider provider) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    // Copy to app storage
    final appDir = await getApplicationDocumentsDirectory();
    final docsDir = Directory(p.join(appDir.path, 'animal_documents'));
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
    final ext = p.extension(file.path!);
    final fileName =
        '${animalId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final savedPath = p.join(docsDir.path, fileName);
    await File(file.path!).copy(savedPath);

    if (!context.mounted) return;
    _showMetadataDialog(context, provider, savedPath, file.name);
  }

  void _showMetadataDialog(BuildContext context, AnimalProvider provider,
      String filePath, String originalName) {
    final titleCtrl = TextEditingController(text: originalName);
    final notesCtrl = TextEditingController();
    DocumentType selectedType = DocumentType.other;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Document Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Title *'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<DocumentType>(
                  value: selectedType,
                  decoration:
                      const InputDecoration(labelText: 'Document Type'),
                  items: DocumentType.values
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedType = v);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.isEmpty) return;
                provider.addDocumentAttachment(DocumentAttachment(
                  animalId: animalId,
                  title: titleCtrl.text,
                  documentType: selectedType,
                  filePath: filePath,
                  notes: notesCtrl.text,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AnimalProvider provider,
      DocumentAttachment doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              provider.deleteDocumentAttachment(doc.id, animalId);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
