import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/animal_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/demo_write_guard.dart';

/// Screen for managing custom field definitions.
/// Users can create, edit, reorder, and delete custom fields
/// that appear on their animal records or contacts.
class CustomFieldsScreen extends StatefulWidget {
  const CustomFieldsScreen({super.key});

  @override
  State<CustomFieldsScreen> createState() => _CustomFieldsScreenState();
}

class _CustomFieldsScreenState extends State<CustomFieldsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _entityTypes = [
    CustomFieldEntityType.animal,
    CustomFieldEntityType.contact,
  ];

  static const _entityLabels = ['Animals', 'Contacts'];

  static const _entityIcons = [
    Icons.pets,
    Icons.people,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _entityTypes.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  CustomFieldEntityType get _currentEntityType =>
      _entityTypes[_tabController.index];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Fields'),
        bottom: TabBar(
          controller: _tabController,
          tabs: List.generate(_entityTypes.length, (i) {
            return Tab(
              icon: Icon(_entityIcons[i]),
              text: _entityLabels[i],
            );
          }),
          onTap: (_) => setState(() {}),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _entityTypes.map((entityType) {
          return Consumer<AnimalProvider>(
            builder: (context, provider, _) {
              final fields =
                  provider.customFieldDefinitionsFor(entityType);

              if (fields.isEmpty) {
                return _buildEmptyState(context, entityType);
              }

              return ReorderableListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: fields.length,
                onReorder: (oldIndex, newIndex) => _reorderFields(
                    context, provider, fields, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final field = fields[index];
                  return _CustomFieldCard(
                    key: ValueKey(field.id),
                    field: field,
                    onEdit: () async {
                      if (!await guardWriteAction(context)) return;
                      _showFieldDialog(context, provider,
                          field: field, entityType: entityType);
                    },
                    onDelete: () async {
                      if (!await guardWriteAction(context)) return;
                      _confirmDelete(context, provider, field);
                    },
                  );
                },
              );
            },
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (!await guardWriteAction(context)) return;
          _showFieldDialog(
            context,
            context.read<AnimalProvider>(),
            entityType: _currentEntityType,
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, CustomFieldEntityType entityType) {
    final label = _entityLabels[entityType.index].toLowerCase();
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
              'for your $label. Fields can be text, numbers, dates, '
              'yes/no, or dropdown selections.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                if (!await guardWriteAction(context)) return;
                _showFieldDialog(
                  context,
                  context.read<AnimalProvider>(),
                  entityType: entityType,
                );
              },
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
    final targetLabel = field.entityTypeDisplay.toLowerCase();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Custom Field'),
        content: Text(
          'Are you sure you want to delete "${field.name}"? '
          'This will remove the field and its values from all ${targetLabel}s.',
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
    required CustomFieldEntityType entityType,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => _CustomFieldDialog(
        field: field,
        entityType: entityType,
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
            if (field.showInPedigree &&
                field.entityType == CustomFieldEntityType.animal) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Pedigree',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.indigo.shade800,
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
  final CustomFieldEntityType entityType;
  final ValueChanged<CustomFieldDefinition> onSave;

  const _CustomFieldDialog({
    this.field,
    required this.entityType,
    required this.onSave,
  });

  @override
  State<_CustomFieldDialog> createState() => _CustomFieldDialogState();
}

class _CustomFieldDialogState extends State<_CustomFieldDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _optionController = TextEditingController();
  CustomFieldType _selectedType = CustomFieldType.text;
  bool _required = false;
  bool _showInPedigree = false;
  List<String> _options = [];

  @override
  void initState() {
    super.initState();
    if (widget.field != null) {
      _nameController.text = widget.field!.name;
      _selectedType = widget.field!.fieldType;
      _required = widget.field!.required;
      _showInPedigree = widget.field!.showInPedigree;
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
    final entityLabel = _entityLabel(widget.entityType);

    return AlertDialog(
      title: Text(isEditing ? 'Edit Custom Field' : 'New $entityLabel Field'),
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
                  decoration: InputDecoration(
                    labelText: 'Field Name *',
                    hintText: _hintForEntityType(widget.entityType),
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
                  subtitle: Text(
                      'Must be filled when adding ${entityLabel.toLowerCase()}s'),
                  value: _required,
                  onChanged: (v) => setState(() => _required = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (widget.entityType == CustomFieldEntityType.animal)
                  SwitchListTile(
                    title: const Text('Show in Pedigree'),
                    subtitle: const Text(
                        'Display this field on pedigree tree cards'),
                    value: _showInPedigree,
                    onChanged: (v) => setState(() => _showInPedigree = v),
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
            showInPedigree: _showInPedigree,
            options: _options,
          )
        : CustomFieldDefinition(
            name: _nameController.text.trim(),
            fieldType: _selectedType,
            entityType: widget.entityType,
            required: _required,
            showInPedigree: _showInPedigree,
            options: _options,
          );

    widget.onSave(field);
    Navigator.pop(context);
  }

  String _entityLabel(CustomFieldEntityType type) {
    switch (type) {
      case CustomFieldEntityType.animal:
        return 'Animal';
      case CustomFieldEntityType.contact:
        return 'Contact';
    }
  }

  String _hintForEntityType(CustomFieldEntityType type) {
    switch (type) {
      case CustomFieldEntityType.animal:
        return 'e.g., Ear Tag, Horn Status, Fleece Weight';
      case CustomFieldEntityType.contact:
        return 'e.g., Membership ID, Region, Licence Number';
    }
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
