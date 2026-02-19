import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/animal_provider.dart';
import '../../models/models.dart';
import '../../utils/constants.dart';

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
  final _breederController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedSpecies = Species.dog;
  Sex _selectedSex = Sex.male;
  DateTime? _dateOfBirth;
  String? _selectedSireId;
  String? _selectedDamId;
  bool _isEditing = false;

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
    _breederController.text = animal.breederName ?? '';
    _weightController.text = animal.weight?.toString() ?? '';
    _heightController.text = animal.height?.toString() ?? '';
    _notesController.text = animal.notes ?? '';
    _selectedSireId = animal.sireId;
    _selectedDamId = animal.damId;
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _colorController.dispose();
    _markingsController.dispose();
    _regNumberController.dispose();
    _microchipController.dispose();
    _breederController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _notesController.dispose();
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
                    suffixIcon: _selectedSpecies == Species.dog
                        ? PopupMenuButton<String>(
                            icon: const Icon(Icons.arrow_drop_down),
                            onSelected: (v) =>
                                setState(() => _breedController.text = v),
                            itemBuilder: (_) => DogBreeds.popular
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _breederController,
                  decoration: const InputDecoration(
                    labelText: 'Breeder Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),

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
                    onPressed: _saveAnimal,
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

  void _saveAnimal() {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AnimalProvider>();
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
      breederName: _breederController.text.trim().isEmpty
          ? null
          : _breederController.text.trim(),
      weight: double.tryParse(_weightController.text),
      height: double.tryParse(_heightController.text),
      sireId: _selectedSireId,
      damId: _selectedDamId,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (_isEditing) {
      provider.updateAnimal(animal);
    } else {
      provider.addAnimal(animal);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Animal updated' : 'Animal added'),
      ),
    );
  }
}
