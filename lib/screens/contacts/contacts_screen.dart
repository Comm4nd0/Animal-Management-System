import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/demo_write_guard.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
      ),
      body: Consumer<AnimalProvider>(
        builder: (context, provider, _) {
          final contacts = provider.contacts;
          if (contacts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No contacts yet'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (!await guardWriteAction(context)) return;
                      _showContactForm(context);
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Contact'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return _ContactCard(
                contact: contact,
                customFieldDefs: provider.customFieldDefinitionsFor(
                    CustomFieldEntityType.contact),
                onEdit: () async {
                  if (!await guardWriteAction(context)) return;
                  _showContactForm(context, contact: contact);
                },
                onDelete: () async {
                  if (!await guardWriteAction(context)) return;
                  _confirmDelete(context, contact);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (!await guardWriteAction(context)) return;
          _showContactForm(context);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Contact'),
      ),
    );
  }

  void _showContactForm(BuildContext context, {Contact? contact}) {
    showDialog(
      context: context,
      builder: (ctx) => _ContactFormDialog(contact: contact),
    );
  }

  void _confirmDelete(BuildContext context, Contact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
          'Are you sure you want to delete ${contact.displayName}? '
          'Animals referencing this contact will lose their breeder/owner link.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AnimalProvider>().deleteContact(contact.id);
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

/// Stateful dialog for creating/editing a contact, including custom fields.
class _ContactFormDialog extends StatefulWidget {
  final Contact? contact;

  const _ContactFormDialog({this.contact});

  @override
  State<_ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<_ContactFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _farmCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _prefixCtrl;
  late final TextEditingController _notesCtrl;
  final _formKey = GlobalKey<FormState>();

  /// Mutable copy of custom field values being edited.
  late Map<String, dynamic> _customFieldValues;

  bool get _isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.contact?.name ?? '');
    _farmCtrl = TextEditingController(text: widget.contact?.farmName ?? '');
    _emailCtrl = TextEditingController(text: widget.contact?.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.contact?.phone ?? '');
    _addressCtrl = TextEditingController(text: widget.contact?.address ?? '');
    _prefixCtrl = TextEditingController(text: widget.contact?.prefix ?? '');
    _notesCtrl = TextEditingController(text: widget.contact?.notes ?? '');
    _customFieldValues =
        Map<String, dynamic>.from(widget.contact?.customFields ?? {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _farmCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _prefixCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AnimalProvider>();
    final contactFields =
        provider.customFieldDefinitionsFor(CustomFieldEntityType.contact);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Contact' : 'New Contact'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  autofocus: true,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _farmCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Farm / Stud Name',
                    prefixIcon: Icon(Icons.home_work),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _prefixCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Breeding Prefix / Affix',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
                // ─── Custom Fields ─────────────────────────────
                if (contactFields.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Custom Fields',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...contactFields.map((def) =>
                      _buildCustomFieldInput(def)),
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
          child: Text(_isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  Widget _buildCustomFieldInput(CustomFieldDefinition def) {
    final key = def.fieldKey;
    final currentValue = _customFieldValues[key];

    switch (def.fieldType) {
      case CustomFieldType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextFormField(
            initialValue: currentValue?.toString() ?? '',
            decoration: InputDecoration(
              labelText: def.name + (def.required ? ' *' : ''),
              prefixIcon: const Icon(Icons.text_fields),
            ),
            validator: def.required
                ? (v) => (v == null || v.isEmpty) ? '${def.name} is required' : null
                : null,
            onChanged: (v) => _customFieldValues[key] = v,
          ),
        );

      case CustomFieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextFormField(
            initialValue: currentValue?.toString() ?? '',
            decoration: InputDecoration(
              labelText: def.name + (def.required ? ' *' : ''),
              prefixIcon: const Icon(Icons.tag),
            ),
            keyboardType: TextInputType.number,
            validator: def.required
                ? (v) => (v == null || v.isEmpty) ? '${def.name} is required' : null
                : null,
            onChanged: (v) {
              final n = num.tryParse(v);
              _customFieldValues[key] = n ?? v;
            },
          ),
        );

      case CustomFieldType.boolean:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SwitchListTile(
            title: Text(def.name),
            value: currentValue == true ||
                currentValue == 'true' ||
                currentValue == 1,
            onChanged: (v) => setState(() => _customFieldValues[key] = v),
            contentPadding: EdgeInsets.zero,
          ),
        );

      case CustomFieldType.dropdown:
        final strValue = currentValue?.toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DropdownButtonFormField<String>(
            value: def.options.contains(strValue) ? strValue : null,
            decoration: InputDecoration(
              labelText: def.name + (def.required ? ' *' : ''),
              prefixIcon: const Icon(Icons.arrow_drop_down_circle),
            ),
            items: def.options
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            validator: def.required
                ? (v) => (v == null || v.isEmpty) ? '${def.name} is required' : null
                : null,
            onChanged: (v) => _customFieldValues[key] = v,
          ),
        );

      case CustomFieldType.date:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextFormField(
            initialValue: currentValue?.toString() ?? '',
            decoration: InputDecoration(
              labelText: def.name + (def.required ? ' *' : ''),
              prefixIcon: const Icon(Icons.calendar_today),
              hintText: 'YYYY-MM-DD',
            ),
            validator: def.required
                ? (v) => (v == null || v.isEmpty) ? '${def.name} is required' : null
                : null,
            onChanged: (v) => _customFieldValues[key] = v,
          ),
        );
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AnimalProvider>();

    // Clean empty custom field values
    final cleanedFields = Map<String, dynamic>.from(_customFieldValues)
      ..removeWhere(
          (_, v) => v == null || v == '' || v == false);

    if (_isEditing) {
      provider.updateContact(widget.contact!.copyWith(
        name: _nameCtrl.text.trim(),
        farmName: _farmCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        prefix: _prefixCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        customFields: cleanedFields,
      ));
    } else {
      provider.addContact(Contact(
        name: _nameCtrl.text.trim(),
        farmName: _farmCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        prefix: _prefixCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        customFields: cleanedFields,
      ));
    }
    Navigator.pop(context);
  }
}

class _ContactCard extends StatelessWidget {
  final Contact contact;
  final List<CustomFieldDefinition> customFieldDefs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.contact,
    required this.customFieldDefs,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Build custom field display lines
    final customLines = <Widget>[];
    for (final def in customFieldDefs) {
      final val = contact.customFields[def.fieldKey];
      if (val != null && val.toString().isNotEmpty && val != false) {
        final display = def.fieldType == CustomFieldType.boolean
            ? (val == true || val == 'true' ? 'Yes' : 'No')
            : val.toString();
        customLines.add(
          Text(
            '${def.name}: $display',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        );
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
          child: Text(
            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        title: Text(
          contact.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contact.prefix.isNotEmpty)
              Text('Prefix: ${contact.prefix}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (contact.phone.isNotEmpty)
              Text(contact.phone,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (contact.email.isNotEmpty)
              Text(contact.email,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ...customLines,
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
        isThreeLine: contact.phone.isNotEmpty ||
            contact.email.isNotEmpty ||
            customLines.isNotEmpty,
      ),
    );
  }
}
