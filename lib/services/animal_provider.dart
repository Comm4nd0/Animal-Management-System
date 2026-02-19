import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'genetics_service.dart';

/// Central state management provider for all animal-related data.
class AnimalProvider extends ChangeNotifier {
  final DatabaseService _db;
  final GeneticsService _genetics;

  List<Animal> _animals = [];
  List<HealthRecord> _healthRecords = [];
  List<BreedingRecord> _breedingRecords = [];
  List<Litter> _litters = [];
  Map<String, int> _stats = {};
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedSpeciesFilter;
  String? _selectedBreedFilter;

  // ─── Account / Tier ────────────────────────────────────────────
  UserProfile? _userProfile;

  AnimalProvider({DatabaseService? db, GeneticsService? genetics})
      : _db = db ?? DatabaseService(),
        _genetics = genetics ?? GeneticsService();

  // ─── Getters ───────────────────────────────────────────────────

  List<Animal> get animals => _filteredAnimals;
  List<Animal> get allAnimals => _animals;
  List<HealthRecord> get healthRecords => _healthRecords;
  List<BreedingRecord> get breedingRecords => _breedingRecords;
  List<Litter> get litters => _litters;
  Map<String, int> get stats => _stats;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedSpeciesFilter => _selectedSpeciesFilter;
  String? get selectedBreedFilter => _selectedBreedFilter;
  GeneticsService get geneticsService => _genetics;
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
          (a.registrationNumber?.toLowerCase().contains(q) ?? false)).toList();
    }
    if (_selectedSpeciesFilter != null) {
      result = result.where((a) => a.species == _selectedSpeciesFilter).toList();
    }
    if (_selectedBreedFilter != null) {
      result = result.where((a) => a.breed == _selectedBreedFilter).toList();
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
      _breedingRecords = await _db.getActiveBreedings();
      _litters = await _db.getAllLitters();
      _stats = await _db.getAnimalStats();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHealthRecords(String animalId) async {
    _healthRecords = await _db.getHealthRecords(animalId);
    notifyListeners();
  }

  // ─── Animal Operations ────────────────────────────────────────

  Future<void> addAnimal(Animal animal) async {
    await _db.insertAnimal(animal);
    _animals = await _db.getAllAnimals();
    _stats = await _db.getAnimalStats();
    notifyListeners();
  }

  Future<void> updateAnimal(Animal animal) async {
    await _db.updateAnimal(animal);
    _animals = await _db.getAllAnimals();
    notifyListeners();
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

  void clearFilters() {
    _searchQuery = '';
    _selectedSpeciesFilter = null;
    _selectedBreedFilter = null;
    notifyListeners();
  }
}
