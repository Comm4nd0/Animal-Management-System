import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/animal_provider.dart';
import '../../utils/app_theme.dart';

/// Screen for managing custom field definitions.
/// Users can create, edit, reorder, and delete custom fields
/// that appear on all their animal records.
class CustomFieldsScreen extends StatelessWidget {
  const CustomFieldsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Fields'),
      ),
      body: Consumer<AnimalProvider>(
        builder: (context, provider, _) {
          final fields = provider.customFieldDefinitions;

          if (fields.isEmpty) {
            return _buildEmptyState(context);
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: fields.length,
            onReorder: (oldIndex, newIndex) =>
                _reorderFields(context, provider, fields, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final field = fields[index];
              return _CustomFieldCard(
                key: ValueKey(field.id),
                field: field,
                onEdit: () => _showFieldDialog(context, provider, field: field),
                onDelete: () => _confirmDelete(context, provider, field),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFieldDialog(
          context,
          context.read<AnimalProvider>(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Custom Fields',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create custom fields to track additional information '
              'for your animals. Fields can be text, numbers, dates, '
              'yes/no, or dropdown selections.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showFieldDialog(
                context,
                context.read<AnimalProvider>(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Custom Field'),
            ),
          ],
        ),
      ),
    );
  }

  void _reorderFields(
    BuildContext context,
    AnimalProvider provider,
    List<CustomFieldDefinition> fields,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) newIndex--;
    final field = fields[oldIndex];
    final updated = field.copyWith(displayOrder: newIndex);
    provider.updateCustomFieldDefinition(updated);

    // Update all other field orders
    for (int i = 0; i < fields.length; i++) {
      if (fields[i].id != field.id) {
        final order = i >= newIndex && i < oldIndex
            ? i + 1
            : i > oldIndex && i <= newIndex
                ? i - 1
                : i;
        if (order != fields[i].displayOrder) {
          provider.updateCustomFieldDefinition(
            fields[i].copyWith(displayOrder: order),
          );
        }
      }
    }
  }

  void _confirmDelete(
    BuildContext context,
    AnimalProvider provider,
    CustomFieldDefinition field,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Custom Field'),
        content: Text(
          'Are you sure you want to delete "${field.name}"? '
          'This will remove the field and its values from all animals.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteCustomFieldDefinition(field.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFieldDialog(
    BuildContext context,
    AnimalProvider provider, {
    CustomFieldDefinition? field,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => _CustomFieldDialog(
        field: field,
        onSave: (updatedField) {
          if (field != null) {
            provider.updateCustomFieldDefinition(updatedField);
          } else {
            provider.addCustomFieldDefinition(updatedField);
          }
        },
      ),
    );
  }
}

class _CustomFieldCard extends StatelessWidget {
  final CustomFieldDefinition field;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomFieldCard({
    super.key,
    required this.field,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_typeIcon(field.fieldType), color: AppTheme.primaryColor),
        title: Text(
          field.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Text(field.fieldTypeDisplay),
            if (field.required) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (field.fieldType == CustomFieldType.dropdown) ...[
              const SizedBox(width: 8),
              Text(
                '${field.options.length} options',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(Icons.delete, size: 20, color: Colors.red.shade300),
              onPressed: onDelete,
            ),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.text:
        return Icons.text_fields;
      case CustomFieldType.number:
        return Icons.tag;
      case CustomFieldType.date:
        return Icons.calendar_today;
      case CustomFieldType.boolean:
        return Icons.check_box;
      case CustomFieldType.dropdown:
        return Icons.arrow_drop_down_circle;
    }
  }
}

class _CustomFieldDialog extends StatefulWidget {
  final CustomFieldDefinition? field;
  final ValueChanged<CustomFieldDefinition> onSave;

  const _CustomFieldDialog({this.field, required this.onSave});

  @override
  State<_CustomFieldDialog> createState() => _CustomFieldDialogState();
}

class _CustomFieldDialogState extends State<_CustomFieldDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _optionController = TextEditingController();
  CustomFieldType _selectedType = CustomFieldType.text;
  bool _required = false;
  List<String> _options = [];

  @override
  void initState() {
    super.initState();
    if (widget.field != null) {
      _nameController.text = widget.field!.name;
      _selectedType = widget.field!.fieldType;
      _required = widget.field!.required;
      _options = List.from(widget.field!.options);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _optionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.field != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Custom Field' : 'New Custom Field'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Field Name *',
                    hintText: 'e.g., Ear Tag, Horn Status, Fleece Weight',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CustomFieldType>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'Field Type'),
                  items: CustomFieldType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(_typeLabel(t)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Required'),
                  subtitle: const Text('Must be filled when adding animals'),
                  value: _required,
                  onChanged: (v) => setState(() => _required = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_selectedType == CustomFieldType.dropdown) ...[
                  const Divider(),
                  Text(
                    'Dropdown Options',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionController,
                          decoration: const InputDecoration(
                            hintText: 'Add option...',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addOption(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        color: AppTheme.primaryColor,
                        onPressed: _addOption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ..._options.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 6),
                          const SizedBox(width: 8),
                          Expanded(child: Text(entry.value)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() => _options.removeAt(entry.key));
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_options.isEmpty)
                    Text(
                      'Add at least one option',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 12,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  void _addOption() {
    final text = _optionController.text.trim();
    if (text.isNotEmpty && !_options.contains(text)) {
      setState(() {
        _options.add(text);
        _optionController.clear();
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == CustomFieldType.dropdown && _options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one dropdown option')),
      );
      return;
    }

    final field = widget.field != null
        ? widget.field!.copyWith(
            name: _nameController.text.trim(),
            fieldType: _selectedType,
            required: _required,
            options: _options,
          )
        : CustomFieldDefinition(
            name: _nameController.text.trim(),
            fieldType: _selectedType,
            required: _required,
            options: _options,
          );

    widget.onSave(field);
    Navigator.pop(context);
  }

  String _typeLabel(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.text:
        return 'Text';
      case CustomFieldType.number:
        return 'Number';
      case CustomFieldType.date:
        return 'Date';
      case CustomFieldType.boolean:
        return 'Yes/No';
      case CustomFieldType.dropdown:
        return 'Dropdown';
    }
  }
}
