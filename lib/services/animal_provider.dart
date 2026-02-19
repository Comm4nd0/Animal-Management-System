import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';
import 'database_service.dart';
import 'genetics_service.dart';
import 'pedigree_validator.dart';

/// Central state management provider for all animal-related data.
class AnimalProvider extends ChangeNotifier {
  final DatabaseService _db;
  final GeneticsService _genetics;
  final PedigreeValidator _validator;

  List<Animal> _animals = [];
  List<Contact> _contacts = [];
  List<HealthRecord> _healthRecords = [];
  List<BreedingRecord> _breedingRecords = [];
  List<Litter> _litters = [];
  List<CustomFieldDefinition> _customFieldDefinitions = [];
  Map<String, int> _stats = {};
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedSpeciesFilter;
  String? _selectedBreedFilter;
  Map<String, String> _customFieldFilters = {};
  List<AnimalImage> _animalImages = [];
  // Cache of profile image paths keyed by animal ID
  final Map<String, String?> _profileImageCache = {};

  // ─── Account / Tier ────────────────────────────────────────────
  UserProfile? _userProfile;

  AnimalProvider({DatabaseService? db, GeneticsService? genetics, PedigreeValidator? validator})
      : _db = db ?? DatabaseService(),
        _genetics = genetics ?? GeneticsService(),
        _validator = validator ?? PedigreeValidator();

  // ─── Getters ───────────────────────────────────────────────────

  List<Animal> get animals => _filteredAnimals;
  List<Animal> get allAnimals => _animals;
  List<Contact> get contacts => _contacts;
  List<HealthRecord> get healthRecords => _healthRecords;
  List<BreedingRecord> get breedingRecords => _breedingRecords;
  List<Litter> get litters => _litters;
  List<CustomFieldDefinition> get customFieldDefinitions =>
      _customFieldDefinitions;
  Map<String, int> get stats => _stats;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedSpeciesFilter => _selectedSpeciesFilter;
  String? get selectedBreedFilter => _selectedBreedFilter;
  Map<String, String> get customFieldFilters => _customFieldFilters;
  GeneticsService get geneticsService => _genetics;
  List<AnimalImage> get animalImages => _animalImages;
  UserProfile? get userProfile => _userProfile;

  // ─── Tier Helpers ──────────────────────────────────────────────

  bool get isBreedLocked =>
      _userProfile != null && _userProfile!.isBreedLocked;

  bool get allowsMultiBreed =>
      _userProfile == null || _userProfile!.allowsMultiBreed;

  String? get registeredSpecies => _userProfile?.registeredSpecies;
  String? get registeredBreed => _userProfile?.registeredBreed;

  /// Validate whether a new animal with the given species/breed can be added.
  /// Returns null if valid, or an error message string.
  String? validateAnimalAddition(String species, String breed) {
    if (_userProfile == null) return null;
    return _userProfile!.validateAnimalAddition(species, breed);
  }

  void setUserProfile(UserProfile profile) {
    _userProfile = profile;
    notifyListeners();
  }

  List<Animal> get _filteredAnimals {
    var result = _animals;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((a) =>
          a.name.toLowerCase().contains(q) ||
          a.breed.toLowerCase().contains(q) ||
          (a.registrationNumber?.toLowerCase().contains(q) ?? false) ||
          a.customFields.values.any(
            (v) => v.toString().toLowerCase().contains(q),
          )).toList();
    }
    if (_selectedSpeciesFilter != null) {
      result = result.where((a) => a.species == _selectedSpeciesFilter).toList();
    }
    if (_selectedBreedFilter != null) {
      result = result.where((a) => a.breed == _selectedBreedFilter).toList();
    }
    // Apply custom field filters
    for (final entry in _customFieldFilters.entries) {
      final key = entry.key;
      final value = entry.value.toLowerCase();
      result = result.where((a) {
        final fieldValue = a.customFields[key];
        if (fieldValue == null) return false;
        return fieldValue.toString().toLowerCase().contains(value);
      }).toList();
    }
    return result;
  }

  List<String> get availableSpecies =>
      _animals.map((a) => a.species).toSet().toList()..sort();

  List<String> get availableBreeds =>
      _animals.map((a) => a.breed).toSet().toList()..sort();

  List<Animal> get maleAnimals =>
      _animals.where((a) => a.sex == Sex.male && a.status == AnimalStatus.alive).toList();

  List<Animal> get femaleAnimals =>
      _animals.where((a) => a.sex == Sex.female && a.status == AnimalStatus.alive).toList();

  // ─── Loading ───────────────────────────────────────────────────

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      _animals = await _db.getAllAnimals();
      _contacts = await _db.getAllContacts();
      _breedingRecords = await _db.getActiveBreedings();
      _litters = await _db.getAllLitters();
      _stats = await _db.getAnimalStats();
      _customFieldDefinitions = await _db.getCustomFieldDefinitions();
      await loadProfileImageCache();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHealthRecords(String animalId) async {
    _healthRecords = await _db.getHealthRecords(animalId);
    notifyListeners();
  }

  // ─── Pedigree Validation ────────────────────────────────────

  /// Validates that the given animal's parentage is valid (no cycles,
  /// sex mismatches, date issues, etc.). Returns null if valid, or
  /// an error message string.
  Future<String?> validateAnimalParentage(Animal animal) async {
    return _validator.validateParentage(
      animalId: animal.id,
      sireId: animal.sireId,
      damId: animal.damId,
      dateOfBirth: animal.dateOfBirth,
      allAnimals: _animals,
    );
  }

  /// Runs a full data audit on all animals. Returns a list of issues.
  Future<List<DataIssue>> auditData({
    void Function(int processed, int total)? onProgress,
  }) async {
    return _validator.auditAll(onProgress: onProgress);
  }

  // ─── Animal Operations ────────────────────────────────────────

  /// Adds an animal after validating pedigree integrity.
  /// Returns null on success, or an error message string.
  Future<String?> addAnimal(Animal animal) async {
    final error = await validateAnimalParentage(animal);
    if (error != null) return error;

    await _db.insertAnimal(animal);
    _animals = await _db.getAllAnimals();
    _stats = await _db.getAnimalStats();
    notifyListeners();
    return null;
  }

  /// Updates an animal after validating pedigree integrity.
  /// Returns null on success, or an error message string.
  Future<String?> updateAnimal(Animal animal) async {
    final error = await validateAnimalParentage(animal);
    if (error != null) return error;

    await _db.updateAnimal(animal);
    _animals = await _db.getAllAnimals();
    notifyListeners();
    return null;
  }

  Future<void> deleteAnimal(String id) async {
    await _db.deleteAnimal(id);
    _animals = await _db.getAllAnimals();
    _stats = await _db.getAnimalStats();
    notifyListeners();
  }

  Animal? getAnimalById(String id) {
    try {
      return _animals.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── Contacts ───────────────────────────────────────────────

  Contact? getContactById(String? id) {
    if (id == null) return null;
    try {
      return _contacts.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addContact(Contact contact) async {
    await _db.insertContact(contact);
    _contacts = await _db.getAllContacts();
    notifyListeners();
  }

  Future<void> updateContact(Contact contact) async {
    await _db.updateContact(contact);
    _contacts = await _db.getAllContacts();
    notifyListeners();
  }

  Future<void> deleteContact(String id) async {
    await _db.deleteContact(id);
    _contacts = await _db.getAllContacts();
    notifyListeners();
  }

  // ─── Health Records ───────────────────────────────────────────

  Future<void> addHealthRecord(HealthRecord record) async {
    await _db.insertHealthRecord(record);
    _healthRecords = await _db.getHealthRecords(record.animalId);
    notifyListeners();
  }

  Future<void> deleteHealthRecord(String id, String animalId) async {
    await _db.deleteHealthRecord(id);
    _healthRecords = await _db.getHealthRecords(animalId);
    notifyListeners();
  }

  Future<List<HealthRecord>> getUpcomingHealthReminders() async {
    return await _db.getUpcomingHealthRecords();
  }

  // ─── Animal Images ──────────────────────────────────────────

  Future<void> loadAnimalImages(String animalId) async {
    _animalImages = await _db.getAnimalImages(animalId);
    notifyListeners();
  }

  /// Returns the cached profile image path for an animal, or null.
  /// Call [loadProfileImageCache] first to populate.
  String? getProfileImagePath(String animalId) {
    return _profileImageCache[animalId];
  }

  /// Pre-loads profile image paths for all loaded animals.
  Future<void> loadProfileImageCache() async {
    for (final animal in _animals) {
      if (!_profileImageCache.containsKey(animal.id)) {
        final img = await _db.getProfileImage(animal.id);
        _profileImageCache[animal.id] = img?.imagePath;
      }
    }
    notifyListeners();
  }

  /// Picks an image file, copies it to app storage, and saves the record.
  /// Returns the created [AnimalImage], or null if no file was copied.
  Future<AnimalImage?> addAnimalImage(
    String animalId,
    File sourceFile, {
    bool isProfile = false,
    String caption = '',
  }) async {
    // Copy to app documents directory for persistence
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'animal_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final ext = p.extension(sourceFile.path);
    final fileName =
        '${animalId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final savedFile = await sourceFile.copy(p.join(imagesDir.path, fileName));

    // If no images exist yet, make this the profile
    final existing = await _db.getAnimalImages(animalId);
    final shouldBeProfile = isProfile || existing.isEmpty;

    final image = AnimalImage(
      animalId: animalId,
      imagePath: savedFile.path,
      caption: caption,
      isProfile: shouldBeProfile,
    );
    await _db.insertAnimalImage(image);

    // Update caches
    _animalImages = await _db.getAnimalImages(animalId);
    if (shouldBeProfile) {
      _profileImageCache[animalId] = savedFile.path;
    }
    notifyListeners();
    return image;
  }

  Future<void> deleteAnimalImage(String imageId, String animalId) async {
    // Find the image to delete the file
    final image = _animalImages.firstWhere(
      (i) => i.id == imageId,
      orElse: () => AnimalImage(animalId: animalId, imagePath: ''),
    );
    // Delete the file from disk
    if (image.imagePath.isNotEmpty) {
      final file = File(image.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _db.deleteAnimalImage(imageId);
    _animalImages = await _db.getAnimalImages(animalId);

    // Update profile cache
    final profile = _animalImages.where((i) => i.isProfile).toList();
    _profileImageCache[animalId] =
        profile.isNotEmpty ? profile.first.imagePath : null;
    notifyListeners();
  }

  Future<void> setProfileImage(String animalId, String imageId) async {
    await _db.setProfileImage(animalId, imageId);
    _animalImages = await _db.getAnimalImages(animalId);

    final profile = _animalImages.where((i) => i.isProfile).toList();
    _profileImageCache[animalId] =
        profile.isNotEmpty ? profile.first.imagePath : null;
    notifyListeners();
  }

  // ─── Breeding Records ────────────────────────────────────────

  Future<void> addBreedingRecord(BreedingRecord record) async {
    await _db.insertBreedingRecord(record);
    _breedingRecords = await _db.getActiveBreedings();
    notifyListeners();
  }

  Future<void> updateBreedingRecord(BreedingRecord record) async {
    await _db.updateBreedingRecord(record);
    _breedingRecords = await _db.getActiveBreedings();
    notifyListeners();
  }

  // ─── Litters ──────────────────────────────────────────────────

  Future<void> addLitter(Litter litter) async {
    await _db.insertLitter(litter);
    _litters = await _db.getAllLitters();
    notifyListeners();
  }

  // ─── Genetics ─────────────────────────────────────────────────

  Future<PedigreeNode?> buildPedigreeTree(String animalId) async {
    return await _genetics.buildPedigreeTree(animalId);
  }

  Future<List<BreedingSuggestion>> getBreedingSuggestions(
    String animalId,
  ) async {
    return await _genetics.generateBreedingSuggestions(animalId);
  }

  Future<double> calculateCOI(String sireId, String damId) async {
    return await _genetics.calculateCOI(sireId: sireId, damId: damId);
  }

  // ─── Custom Field Definitions ────────────────────────────────

  Future<void> loadCustomFieldDefinitions() async {
    _customFieldDefinitions = await _db.getCustomFieldDefinitions();
    notifyListeners();
  }

  Future<void> addCustomFieldDefinition(CustomFieldDefinition field) async {
    await _db.insertCustomFieldDefinition(field);
    _customFieldDefinitions = await _db.getCustomFieldDefinitions();
    notifyListeners();
  }

  Future<void> updateCustomFieldDefinition(CustomFieldDefinition field) async {
    await _db.updateCustomFieldDefinition(field);
    _customFieldDefinitions = await _db.getCustomFieldDefinitions();
    notifyListeners();
  }

  Future<void> deleteCustomFieldDefinition(String id) async {
    // Find the field key to remove values from all animals
    final field = _customFieldDefinitions.firstWhere(
      (f) => f.id == id,
      orElse: () => CustomFieldDefinition(name: '', fieldKey: ''),
    );

    await _db.deleteCustomFieldDefinition(id);
    _customFieldDefinitions = await _db.getCustomFieldDefinitions();

    // Remove the field value from all animals that have it
    if (field.fieldKey.isNotEmpty) {
      for (final animal in _animals) {
        if (animal.customFields.containsKey(field.fieldKey)) {
          final updatedFields = Map<String, dynamic>.from(animal.customFields);
          updatedFields.remove(field.fieldKey);
          final updated = animal.copyWith(customFields: updatedFields);
          await _db.updateAnimal(updated);
        }
      }
      _animals = await _db.getAllAnimals();
    }

    notifyListeners();
  }

  // ─── Filters ──────────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSpeciesFilter(String? species) {
    _selectedSpeciesFilter = species;
    notifyListeners();
  }

  void setBreedFilter(String? breed) {
    _selectedBreedFilter = breed;
    notifyListeners();
  }

  void setCustomFieldFilter(String fieldKey, String? value) {
    if (value == null || value.isEmpty) {
      _customFieldFilters.remove(fieldKey);
    } else {
      _customFieldFilters[fieldKey] = value;
    }
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedSpeciesFilter = null;
    _selectedBreedFilter = null;
    _customFieldFilters = {};
    notifyListeners();
  }

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedSpeciesFilter != null ||
      _selectedBreedFilter != null ||
      _customFieldFilters.isNotEmpty;
}
