import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/animal_provider.dart';
import '../../models/models.dart';
import '../../utils/constants.dart';
import '../../utils/app_theme.dart';
import '../../widgets/demo_write_guard.dart';

class AnimalFormScreen extends StatefulWidget {
  final String? animalId;

  const AnimalFormScreen({super.key, this.animalId});

  @override
  State<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends State<AnimalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _colorController = TextEditingController();
  final _markingsController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _microchipController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedSpecies = Species.horse;
  Sex _selectedSex = Sex.male;
  DateTime? _dateOfBirth;
  String? _selectedSireId;
  String? _selectedDamId;
  String? _selectedBreederId;
  String? _selectedOwnerId;
  bool _isEditing = false;
  File? _pickedImageFile;
  final Map<String, dynamic> _customFieldValues = {};
  final Map<String, TextEditingController> _customFieldControllers = {};

  @override
  void initState() {
    super.initState();
    if (widget.animalId != null) {
      _isEditing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAnimal();
      });
    }
  }

  void _loadAnimal() {
    final provider = context.read<AnimalProvider>();
    final animal = provider.getAnimalById(widget.animalId!);
    if (animal == null) return;

    _nameController.text = animal.name;
    _selectedSpecies = animal.species;
    _breedController.text = animal.breed;
    _selectedSex = animal.sex;
    _dateOfBirth = animal.dateOfBirth;
    _colorController.text = animal.color ?? '';
    _markingsController.text = animal.markings ?? '';
    _regNumberController.text = animal.registrationNumber ?? '';
    _microchipController.text = animal.microchipNumber ?? '';
    _selectedBreederId = animal.breederId;
    _selectedOwnerId = animal.currentOwnerId;
    _weightController.text = animal.weight?.toString() ?? '';
    _heightController.text = animal.height?.toString() ?? '';
    _notesController.text = animal.notes ?? '';
    _selectedSireId = animal.sireId;
    _selectedDamId = animal.damId;
    // Load custom field values
    _customFieldValues.addAll(animal.customFields);
    for (final entry in animal.customFields.entries) {
      if (entry.value is! bool) {
        _getOrCreateController(entry.key).text = entry.value.toString();
      }
    }
    setState(() {});
  }

  TextEditingController _getOrCreateController(String key) {
    return _customFieldControllers.putIfAbsent(
      key,
      () => TextEditingController(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _colorController.dispose();
    _markingsController.dispose();
    _regNumberController.dispose();
    _microchipController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _notesController.dispose();
    for (final c in _customFieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Animal' : 'Add Animal'),
      ),
      body: Consumer<AnimalProvider>(
        builder: (context, provider, _) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Breed restriction banner for non-Enterprise users
                if (!_isEditing && provider.isBreedLocked)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Single breed account: '
                            '${provider.registeredSpecies} - ${provider.registeredBreed}',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildSectionTitle('Basic Information'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    prefixIcon: Icon(Icons.pets),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedSpecies,
                  decoration: const InputDecoration(
                    labelText: 'Species *',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: Species.all
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSpecies = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _breedController,
                  decoration: InputDecoration(
                    labelText: 'Breed *',
                    prefixIcon: const Icon(Icons.label),
                    suffixIcon: breedsForSpecies(_selectedSpecies).isNotEmpty
                        ? PopupMenuButton<String>(
                            icon: const Icon(Icons.arrow_drop_down),
                            onSelected: (v) =>
                                setState(() => _breedController.text = v),
                            itemBuilder: (_) => breedsForSpecies(_selectedSpecies)
                                .map((b) =>
                                    PopupMenuItem(value: b, child: Text(b)))
                                .toList(),
                          )
                        : null,
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Breed is required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Sex>(
                  value: _selectedSex,
                  decoration: const InputDecoration(
                    labelText: 'Sex *',
                    prefixIcon: Icon(Icons.wc),
                  ),
                  items: const [
                    DropdownMenuItem(value: Sex.male, child: Text('Male')),
                    DropdownMenuItem(value: Sex.female, child: Text('Female')),
                    DropdownMenuItem(value: Sex.unknown, child: Text('Unknown')),
                  ],
                  onChanged: (v) => setState(() => _selectedSex = v!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(_dateOfBirth != null
                      ? DateFormat('dd MMM yyyy').format(_dateOfBirth!)
                      : 'Date of Birth'),
                  subtitle:
                      _dateOfBirth == null ? const Text('Tap to select') : null,
                  trailing: _dateOfBirth != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _dateOfBirth = null),
                        )
                      : null,
                  onTap: _pickDateOfBirth,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Parentage'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedSireId,
                  decoration: const InputDecoration(
                    labelText: 'Sire (Father)',
                    prefixIcon: Icon(Icons.male),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Unknown')),
                    ...provider.maleAnimals
                        .where((a) => a.id != widget.animalId)
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text('${a.name} (${a.breed})'),
                            )),
                  ],
                  onChanged: (v) => setState(() => _selectedSireId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedDamId,
                  decoration: const InputDecoration(
                    labelText: 'Dam (Mother)',
                    prefixIcon: Icon(Icons.female),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Unknown')),
                    ...provider.femaleAnimals
                        .where((a) => a.id != widget.animalId)
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text('${a.name} (${a.breed})'),
                            )),
                  ],
                  onChanged: (v) => setState(() => _selectedDamId = v),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Physical Traits'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        decoration: const InputDecoration(
                          labelText: 'Color',
                          prefixIcon: Icon(Icons.palette),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _markingsController,
                        decoration: const InputDecoration(
                          labelText: 'Markings',
                          prefixIcon: Icon(Icons.texture),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg)',
                          prefixIcon: Icon(Icons.monitor_weight),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _heightController,
                        decoration: const InputDecoration(
                          labelText: 'Height (cm)',
                          prefixIcon: Icon(Icons.height),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Registration'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _regNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Registration Number',
                    prefixIcon: Icon(Icons.verified),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _microchipController,
                  decoration: const InputDecoration(
                    labelText: 'Microchip Number',
                    prefixIcon: Icon(Icons.memory),
                  ),
                ),


                const SizedBox(height: 24),
                _buildSectionTitle('Breeder & Owner'),
                const SizedBox(height: 8),
                _buildContactDropdown(
                  label: 'Breeder',
                  icon: Icons.person,
                  value: _selectedBreederId,
                  contacts: provider.contacts,
                  onChanged: (v) => setState(() => _selectedBreederId = v),
                  onAddNew: () => _showAddContactDialog(
                    onCreated: (c) => setState(() => _selectedBreederId = c.id),
                  ),
                ),
                const SizedBox(height: 12),
                _buildContactDropdown(
                  label: 'Current Owner',
                  icon: Icons.home,
                  value: _selectedOwnerId,
                  contacts: provider.contacts,
                  onChanged: (v) => setState(() => _selectedOwnerId = v),
                  onAddNew: () => _showAddContactDialog(
                    onCreated: (c) => setState(() => _selectedOwnerId = c.id),
                  ),
                ),

                // Custom Fields section
                if (provider.customFieldDefinitions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Custom Fields'),
                      TextButton.icon(
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('Manage'),
                        onPressed: () =>
                            Navigator.pushNamed(context, '/custom-fields'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...provider.customFieldDefinitions.map(
                    (field) => _buildCustomField(field),
                  ),
                ],

                const SizedBox(height: 24),
                _buildSectionTitle('Profile Photo'),
                const SizedBox(height: 8),
                _buildImagePicker(provider),

                const SizedBox(height: 24),
                _buildSectionTitle('Notes'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                ),

                const SizedBox(height: 32),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!await guardWriteAction(context)) return;
                      _saveAnimal();
                    },
                    child: Text(_isEditing ? 'Update Animal' : 'Add Animal'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildCustomField(CustomFieldDefinition field) {
    final key = field.fieldKey;

    switch (field.fieldType) {
      case CustomFieldType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: _getOrCreateController(key),
            decoration: InputDecoration(
              labelText: '${field.name}${field.required ? ' *' : ''}',
              prefixIcon: const Icon(Icons.text_fields),
            ),
            validator: field.required
                ? (v) => v == null || v.isEmpty
                    ? '${field.name} is required'
                    : null
                : null,
            onChanged: (v) => _customFieldValues[key] = v,
          ),
        );

      case CustomFieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: _getOrCreateController(key),
            decoration: InputDecoration(
              labelText: '${field.name}${field.required ? ' *' : ''}',
              prefixIcon: const Icon(Icons.tag),
            ),
            keyboardType: TextInputType.number,
            validator: field.required
                ? (v) => v == null || v.isEmpty
                    ? '${field.name} is required'
                    : null
                : null,
            onChanged: (v) {
              final num? parsed = num.tryParse(v);
              _customFieldValues[key] = parsed ?? v;
            },
          ),
        );

      case CustomFieldType.date:
        final dateValue = _customFieldValues[key] as String?;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(
              dateValue != null && dateValue.isNotEmpty
                  ? dateValue
                  : '${field.name}${field.required ? ' *' : ''}',
            ),
            subtitle: dateValue == null || dateValue.isEmpty
                ? const Text('Tap to select')
                : null,
            trailing: dateValue != null && dateValue.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _customFieldValues.remove(key);
                      });
                    },
                  )
                : null,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1980),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() {
                  _customFieldValues[key] =
                      DateFormat('yyyy-MM-dd').format(picked);
                });
              }
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        );

      case CustomFieldType.boolean:
        final boolValue = _customFieldValues[key] as bool? ?? false;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SwitchListTile(
            title: Text(field.name),
            value: boolValue,
            onChanged: (v) {
              setState(() {
                _customFieldValues[key] = v;
              });
            },
            secondary: const Icon(Icons.check_box),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        );

      case CustomFieldType.dropdown:
        final currentValue = _customFieldValues[key] as String?;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: field.options.contains(currentValue) ? currentValue : null,
            decoration: InputDecoration(
              labelText: '${field.name}${field.required ? ' *' : ''}',
              prefixIcon: const Icon(Icons.arrow_drop_down_circle),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('-- Select --')),
              ...field.options.map(
                (o) => DropdownMenuItem(value: o, child: Text(o)),
              ),
            ],
            onChanged: (v) {
              setState(() {
                if (v == null) {
                  _customFieldValues.remove(key);
                } else {
                  _customFieldValues[key] = v;
                }
              });
            },
            validator: field.required
                ? (v) =>
                    v == null || v.isEmpty ? '${field.name} is required' : null
                : null,
          ),
        );
    }
  }

  Widget _buildImagePicker(AnimalProvider provider) {
    // Show existing profile image for editing, or picked image for new
    String? existingProfilePath;
    if (_isEditing && widget.animalId != null) {
      existingProfilePath = provider.getProfileImagePath(widget.animalId!);
    }
    final hasImage = _pickedImageFile != null || existingProfilePath != null;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: CircleAvatar(
              radius: 56,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: _pickedImageFile != null
                  ? FileImage(_pickedImageFile!)
                  : existingProfilePath != null
                      ? FileImage(File(existingProfilePath))
                      : null,
              child: hasImage
                  ? null
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo,
                            size: 32, color: Colors.grey.shade500),
                        const SizedBox(height: 4),
                        Text('Add Photo',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library, size: 18),
                label: Text(hasImage ? 'Change' : 'Gallery'),
              ),
              TextButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Camera'),
              ),
              if (hasImage)
                TextButton.icon(
                  onPressed: () => setState(() => _pickedImageFile = null),
                  icon: Icon(Icons.clear, size: 18, color: Colors.red.shade400),
                  label: Text('Remove',
                      style: TextStyle(color: Colors.red.shade400)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _pickedImageFile = File(picked.path));
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _pickedImageFile = File(picked.path));
    }
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Widget _buildContactDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<Contact> contacts,
    required ValueChanged<String?> onChanged,
    required VoidCallback onAddNew,
  }) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: contacts.any((c) => c.id == value) ? value : null,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Not set')),
              ...contacts.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.displayName),
                  )),
            ],
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.person_add),
          tooltip: 'Add new contact',
          onPressed: onAddNew,
        ),
      ],
    );
  }

  void _showAddContactDialog({required ValueChanged<Contact> onCreated}) {
    final nameCtrl = TextEditingController();
    final farmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: farmCtrl,
              decoration: const InputDecoration(labelText: 'Farm / Stud Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final contact = Contact(name: name, farmName: farmCtrl.text.trim());
              context.read<AnimalProvider>().addContact(contact);
              Navigator.pop(ctx);
              onCreated(contact);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAnimal() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AnimalProvider>();

    // Tier-based validation (only for new animals, not edits)
    if (!_isEditing) {
      final tierError = provider.validateAnimalAddition(
        _selectedSpecies,
        _breedController.text.trim(),
      );
      if (tierError != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cannot Add Animal'),
            content: Text(tierError),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    // Collect custom field values from controllers
    final customFields = <String, dynamic>{};
    for (final fieldDef in provider.customFieldDefinitions) {
      final key = fieldDef.fieldKey;
      if (fieldDef.fieldType == CustomFieldType.text ||
          fieldDef.fieldType == CustomFieldType.number) {
        final controller = _customFieldControllers[key];
        if (controller != null && controller.text.trim().isNotEmpty) {
          if (fieldDef.fieldType == CustomFieldType.number) {
            customFields[key] =
                num.tryParse(controller.text.trim()) ?? controller.text.trim();
          } else {
            customFields[key] = controller.text.trim();
          }
        }
      } else if (_customFieldValues.containsKey(key)) {
        final val = _customFieldValues[key];
        if (val != null && val.toString().isNotEmpty) {
          customFields[key] = val;
        }
      }
    }

    final animal = Animal(
      id: widget.animalId,
      name: _nameController.text.trim(),
      species: _selectedSpecies,
      breed: _breedController.text.trim(),
      sex: _selectedSex,
      dateOfBirth: _dateOfBirth,
      color: _colorController.text.trim().isEmpty
          ? null
          : _colorController.text.trim(),
      markings: _markingsController.text.trim().isEmpty
          ? null
          : _markingsController.text.trim(),
      registrationNumber: _regNumberController.text.trim().isEmpty
          ? null
          : _regNumberController.text.trim(),
      microchipNumber: _microchipController.text.trim().isEmpty
          ? null
          : _microchipController.text.trim(),
      breederId: _selectedBreederId,
      currentOwnerId: _selectedOwnerId,
      weight: double.tryParse(_weightController.text),
      height: double.tryParse(_heightController.text),
      sireId: _selectedSireId,
      damId: _selectedDamId,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      customFields: customFields,
    );

    String? validationError;
    if (_isEditing) {
      validationError = await provider.updateAnimal(animal);
    } else {
      validationError = await provider.addAnimal(animal);
    }

    if (validationError != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pedigree Error'),
          content: Text(validationError!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Save profile image if one was picked
    if (_pickedImageFile != null) {
      await provider.addAnimalImage(
        animal.id,
        _pickedImageFile!,
        isProfile: true,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Animal updated' : 'Animal added'),
      ),
    );
  }
}
