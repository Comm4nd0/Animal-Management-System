import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'genetics_service.dart';
import 'notification_service.dart';
import 'pedigree_validator.dart';
import 'api_service.dart';
import 'sync_service.dart';

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
  DashboardStats? _dashboardStats;
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedSpeciesFilter;
  String? _selectedBreedFilter;
  Map<String, String> _customFieldFilters = {};
  List<AnimalImage> _animalImages = [];
  // Cache of profile image paths keyed by animal ID
  final Map<String, String?> _profileImageCache = {};

  // ─── Theme Mode ─────────────────────────────────────────────
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  // ─── Auth State ─────────────────────────────────────────────
  String? _authToken;
  String? get authToken => _authToken;
  bool get isLoggedIn => _authToken != null;

  void setAuthToken(String? token) {
    _authToken = token;
    notifyListeners();
  }

  // ─── Demo Mode ────────────────────────────────────────────
  bool _isDemoMode = false;
  bool get isDemoMode => _isDemoMode;

  /// Whether the current session can create/edit/delete data.
  /// Returns false in demo mode OR for read-only users.
  bool get canWrite => !_isDemoMode && canWriteData;

  void setDemoMode(bool value) {
    _isDemoMode = value;
    notifyListeners();
  }

  // ─── Account / Tier / Roles ──────────────────────────────────
  UserProfile? _userProfile;
  List<TeamMember> _teamMembers = [];

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
  Map<String, int> get stats => _dashboardStats?.counts ?? _stats;
  DashboardStats? get dashboardStats => _dashboardStats;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedSpeciesFilter => _selectedSpeciesFilter;
  String? get selectedBreedFilter => _selectedBreedFilter;
  Map<String, String> get customFieldFilters => _customFieldFilters;
  GeneticsService get geneticsService => _genetics;
  List<AnimalImage> get animalImages => _animalImages;
  UserProfile? get userProfile => _userProfile;
  List<TeamMember> get teamMembers => _teamMembers;

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

  void setUserProfile(UserProfile? profile) {
    _userProfile = profile;
    notifyListeners();
  }

  // ─── Role Helpers ───────────────────────────────────────────────

  /// Whether the current user can create/edit/delete data.
  bool get canWriteData => _userProfile?.canWriteData ?? true;

  /// Whether the current user can manage team members.
  bool get canManageUsers => _userProfile?.canManageUsers ?? false;

  /// Whether the current user is the account owner.
  bool get isOwner => _userProfile?.isOwner ?? true;

  /// Whether the current user is read-only.
  bool get isReadOnly => _userProfile?.isReadOnly ?? false;

  // ─── Team Management ───────────────────────────────────────────

  Future<void> loadTeamMembers() async {
    _teamMembers = await _db.getAllTeamMembers();
    notifyListeners();
  }

  Future<void> addTeamMember(TeamMember member) async {
    if (!canWrite) return;
    await _db.insertTeamMember(member);
    _teamMembers = await _db.getAllTeamMembers();
    notifyListeners();
  }

  Future<void> updateTeamMemberRole(String memberId, int role) async {
    if (!canWrite) return;
    await _db.updateTeamMemberRole(memberId, role);
    _teamMembers = await _db.getAllTeamMembers();
    notifyListeners();
  }

  Future<void> removeTeamMember(String memberId) async {
    if (!canWrite) return;
    await _db.deleteTeamMember(memberId);
    _teamMembers = await _db.getAllTeamMembers();
    notifyListeners();
  }

  Future<void> replaceAllTeamMembers(List<TeamMember> members) async {
    if (!canWrite) return;
    await _db.replaceAllTeamMembers(members);
    _teamMembers = members;
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

      // Schedule health reminder notifications
      try {
        await NotificationService().scheduleHealthReminders();
      } catch (_) {
        // Notifications not available on this platform
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads all data directly from the API into memory, bypassing SQLite.
  /// Used for web demo mode where sqflite is not available.
  ///
  /// Fetches pre-aggregated dashboard stats from the API instead of loading
  /// every animal record. Only recent animals (5) are loaded for display.
  Future<void> loadAllFromApi() async {
    _isLoading = true;
    notifyListeners();

    try {
      final api = ApiService();

      // Fetch pre-aggregated dashboard stats in a single request.
      // This replaces loading ALL animals just to compute totals and charts.
      final dashboardData = await api.getDashboardStats();
      _dashboardStats = DashboardStats.fromApi(dashboardData);

      // Build a minimal animal list from the recent animals in dashboard stats
      // so the rest of the UI still works (recent animals, breeding records, etc.)
      _animals = _dashboardStats!.recentAnimals.map((m) {
        return Animal(
          id: m['id'] as String,
          name: m['name'] as String,
          species: m['species'] as String,
          breed: m['breed'] as String,
          sex: Sex.values[m['sex'] as int? ?? 0],
          dateOfBirth: m['date_of_birth'] != null
              ? DateTime.tryParse(m['date_of_birth'] as String)
              : null,
          color: m['color'] as String?,
          registrationNumber: m['registration_number'] as String?,
          status: AnimalStatus.values[m['status'] as int? ?? 0],
          geneticTraits: {},
          customFields: {},
        );
      }).toList();

      // Build breeding records from dashboard stats
      _breedingRecords = _dashboardStats!.activeBreedings.map((m) {
        return BreedingRecord(
          id: m['id'] as String? ?? '',
          sireId: m['sire'] as String? ?? '',
          damId: m['dam'] as String? ?? '',
          breedingDate: m['breeding_date'] != null
              ? DateTime.parse(m['breeding_date'] as String)
              : DateTime.now(),
          expectedDueDate: m['expected_due_date'] != null
              ? DateTime.tryParse(m['expected_due_date'] as String)
              : null,
          status: BreedingStatus.values[m['status'] as int? ?? 0],
        );
      }).toList();

      try {
        _contacts = await api.getContacts();
      } catch (_) {
        _contacts = [];
      }

      try {
        _litters = await api.getLitters();
      } catch (_) {
        _litters = [];
      }

      try {
        _customFieldDefinitions = await api.getCustomFieldDefinitions();
      } catch (_) {
        _customFieldDefinitions = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Sync ──────────────────────────────────────────────────────

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Syncs local data with the remote API, then reloads all data.
  Future<SyncResult> syncWithApi() async {
    _isSyncing = true;
    notifyListeners();
    try {
      final syncService = SyncService();
      final result = await syncService.syncAll();
      if (result.isSuccess) {
        _lastSyncTime = DateTime.now();
        await loadAll();
      }
      return result;
    } finally {
      _isSyncing = false;
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
    if (!canWrite) return 'Demo mode: write operations are disabled.';
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
    if (!canWrite) return 'Demo mode: write operations are disabled.';
    final error = await validateAnimalParentage(animal);
    if (error != null) return error;

    await _db.updateAnimal(animal);
    _animals = await _db.getAllAnimals();
    notifyListeners();
    return null;
  }

  Future<void> deleteAnimal(String id) async {
    if (!canWrite) return;
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
    if (!canWrite) return;
    await _db.insertContact(contact);
    _contacts = await _db.getAllContacts();
    notifyListeners();
  }

  Future<void> updateContact(Contact contact) async {
    if (!canWrite) return;
    await _db.updateContact(contact);
    _contacts = await _db.getAllContacts();
    notifyListeners();
  }

  Future<void> deleteContact(String id) async {
    if (!canWrite) return;
    await _db.deleteContact(id);
    _contacts = await _db.getAllContacts();
    notifyListeners();
  }

  // ─── Health Records ───────────────────────────────────────────

  Future<void> addHealthRecord(HealthRecord record) async {
    if (!canWrite) return;
    await _db.insertHealthRecord(record);
    _healthRecords = await _db.getHealthRecords(record.animalId);
    notifyListeners();
  }

  Future<void> deleteHealthRecord(String id, String animalId) async {
    if (!canWrite) return;
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
    if (!canWrite) return;
    await _db.insertBreedingRecord(record);
    _breedingRecords = await _db.getActiveBreedings();
    notifyListeners();
  }

  Future<void> updateBreedingRecord(BreedingRecord record) async {
    if (!canWrite) return;
    await _db.updateBreedingRecord(record);
    _breedingRecords = await _db.getActiveBreedings();
    notifyListeners();
  }

  // ─── Litters ──────────────────────────────────────────────────

  Future<void> addLitter(Litter litter) async {
    if (!canWrite) return;
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
    if (!canWrite) return;
    await _db.insertCustomFieldDefinition(field);
    _customFieldDefinitions = await _db.getCustomFieldDefinitions();
    notifyListeners();
  }

  Future<void> updateCustomFieldDefinition(CustomFieldDefinition field) async {
    if (!canWrite) return;
    await _db.updateCustomFieldDefinition(field);
    _customFieldDefinitions = await _db.getCustomFieldDefinitions();
    notifyListeners();
  }

  Future<void> deleteCustomFieldDefinition(String id) async {
    if (!canWrite) return;
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

  // ─── Weight Records ────────────────────────────────────────────

  List<WeightRecord> _weightRecords = [];
  List<WeightRecord> get weightRecords => _weightRecords;

  Future<void> loadWeightRecords(String animalId) async {
    _weightRecords = await _db.getWeightRecords(animalId);
    notifyListeners();
  }

  Future<void> addWeightRecord(WeightRecord record) async {
    if (!canWrite) return;
    await _db.insertWeightRecord(record);
    _weightRecords = await _db.getWeightRecords(record.animalId);
    notifyListeners();
  }

  Future<void> deleteWeightRecord(String id, String animalId) async {
    if (!canWrite) return;
    await _db.deleteWeightRecord(id);
    _weightRecords = await _db.getWeightRecords(animalId);
    notifyListeners();
  }

  // ─── Show Results ─────────────────────────────────────────────

  List<ShowResult> _showResults = [];
  List<ShowResult> get showResults => _showResults;

  Future<void> loadShowResults(String animalId) async {
    _showResults = await _db.getShowResults(animalId);
    notifyListeners();
  }

  Future<void> addShowResult(ShowResult result) async {
    if (!canWrite) return;
    await _db.insertShowResult(result);
    _showResults = await _db.getShowResults(result.animalId);
    notifyListeners();
  }

  Future<void> deleteShowResult(String id, String animalId) async {
    if (!canWrite) return;
    await _db.deleteShowResult(id);
    _showResults = await _db.getShowResults(animalId);
    notifyListeners();
  }

  // ─── Financial Records ────────────────────────────────────────

  List<FinancialRecord> _financialRecords = [];
  List<FinancialRecord> get financialRecords => _financialRecords;

  Future<void> loadFinancialRecords(String animalId) async {
    _financialRecords = await _db.getFinancialRecords(animalId);
    notifyListeners();
  }

  Future<void> addFinancialRecord(FinancialRecord record) async {
    if (!canWrite) return;
    await _db.insertFinancialRecord(record);
    _financialRecords = await _db.getFinancialRecords(record.animalId);
    notifyListeners();
  }

  Future<void> deleteFinancialRecord(String id, String animalId) async {
    if (!canWrite) return;
    await _db.deleteFinancialRecord(id);
    _financialRecords = await _db.getFinancialRecords(animalId);
    notifyListeners();
  }

  // ─── Document Attachments ────────────────────────────────────

  List<DocumentAttachment> _documentAttachments = [];
  List<DocumentAttachment> get documentAttachments => _documentAttachments;

  Future<void> loadDocumentAttachments(String animalId) async {
    _documentAttachments = await _db.getDocumentAttachments(animalId);
    notifyListeners();
  }

  Future<void> addDocumentAttachment(DocumentAttachment doc) async {
    if (!canWrite) return;
    await _db.insertDocumentAttachment(doc);
    _documentAttachments = await _db.getDocumentAttachments(doc.animalId);
    notifyListeners();
  }

  Future<void> deleteDocumentAttachment(String id, String animalId) async {
    if (!canWrite) return;
    await _db.deleteDocumentAttachment(id);
    _documentAttachments = await _db.getDocumentAttachments(animalId);
    notifyListeners();
  }

  // ─── Support Messaging ──────────────────────────────────────

  final ApiService _api = ApiService();
  List<SupportTicket> _supportTickets = [];
  int _supportUnreadCount = 0;

  List<SupportTicket> get supportTickets => _supportTickets;
  int get supportUnreadCount => _supportUnreadCount;

  Future<void> loadSupportTickets() async {
    if (!isLoggedIn) return;
    try {
      _supportTickets = await _api.getSupportTickets();
      notifyListeners();
    } catch (_) {
      // Silently fail — support is non-critical
    }
  }

  Future<SupportTicket> loadSupportTicketDetail(String ticketId) async {
    return await _api.getSupportTicket(ticketId);
  }

  Future<SupportTicket> createSupportTicket({
    required String subject,
    required String message,
    String guestName = '',
    String guestEmail = '',
    String guestPhone = '',
  }) async {
    final ticket = await _api.createSupportTicket(
      subject: subject,
      message: message,
      guestName: guestName,
      guestEmail: guestEmail,
      guestPhone: guestPhone,
    );
    if (isLoggedIn) {
      await loadSupportTickets();
    }
    return ticket;
  }

  Future<SupportTicket> replySupportTicket(String ticketId, String message) async {
    final ticket = await _api.replySupportTicket(ticketId, message);
    await loadSupportTickets();
    return ticket;
  }

  Future<void> markSupportTicketRead(String ticketId) async {
    await _api.markSupportTicketRead(ticketId);
    await loadSupportUnreadCount();
  }

  Future<void> closeSupportTicket(String ticketId) async {
    await _api.closeSupportTicket(ticketId);
    await loadSupportTickets();
  }

  Future<void> loadSupportUnreadCount() async {
    if (!isLoggedIn) {
      _supportUnreadCount = 0;
      return;
    }
    try {
      final previousCount = _supportUnreadCount;
      _supportUnreadCount = await _api.getSupportUnreadCount();
      notifyListeners();

      // Trigger a push notification when new unread messages arrive
      if (_supportUnreadCount > previousCount && _supportUnreadCount > 0) {
        NotificationService().notifySupportUnread(_supportUnreadCount);
      }
    } catch (_) {
      _supportUnreadCount = 0;
    }
  }

  // Guest support helpers (ticket ID stored locally by the UI)

  Future<SupportTicket> loadGuestSupportTicket(String ticketId) async {
    return await _api.getGuestSupportTicket(ticketId);
  }

  Future<SupportTicket> replyGuestSupportTicket(String ticketId, String message) async {
    return await _api.replyGuestSupportTicket(ticketId, message);
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
