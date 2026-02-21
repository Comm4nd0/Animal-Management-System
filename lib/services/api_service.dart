import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../utils/constants.dart';

/// REST API client for the Django backend.
///
/// When running on the web and served by Django, auto-detects the API URL
/// from the browser origin. For mobile or when API_BASE_URL is set explicitly,
/// uses the provided value.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Base URL for the Django REST API.
  /// On web builds served by Django, defaults to same-origin /api/v1.
  /// On mobile, defaults to the Android emulator loopback.
  static String _defaultBaseUrl() {
    const env = String.fromEnvironment('API_BASE_URL');
    if (env.isNotEmpty) return env;
    return kIsWeb ? '/api/v1' : 'http://10.0.2.2:8000/api/v1';
  }

  String baseUrl = _defaultBaseUrl();

  String? authToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Token $authToken',
      };

  // ─── HTTP Helpers ─────────────────────────────────────────────

  Future<dynamic> _get(String path, {Map<String, String>? queryParams}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl$path');
    final response =
        await http.post(uri, headers: _headers, body: jsonEncode(data));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl$path');
    final response =
        await http.put(uri, headers: _headers, body: jsonEncode(data));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<void> _delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.delete(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'Delete failed');
    }
  }

  // ─── Animals ──────────────────────────────────────────────────

  Future<List<Animal>> getAnimals({
    String? species,
    String? breed,
    String? search,
  }) async {
    final params = <String, String>{};
    if (species != null) params['species'] = species;
    if (breed != null) params['breed'] = breed;
    if (search != null) params['search'] = search;

    final data = await _get('/animals/', queryParams: params.isEmpty ? null : params);
    final results = data['results'] as List? ?? data as List;
    return results.map((m) => _animalFromApi(m)).toList();
  }

  /// Fetch ALL animals across all pages of paginated results.
  Future<List<Animal>> getAllAnimals() async {
    final all = <Animal>[];
    String? nextUrl = '$baseUrl/animals/?page_size=5000';

    while (nextUrl != null) {
      final uri = Uri.parse(nextUrl);
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(response.statusCode, response.body);
      }
      final data = jsonDecode(response.body);
      if (data is Map) {
        final results = data['results'] as List? ?? [];
        all.addAll(results.map((m) => _animalFromApi(m)));
        nextUrl = data['next'] as String?;
      } else if (data is List) {
        all.addAll((data).map((m) => _animalFromApi(m)));
        nextUrl = null;
      } else {
        nextUrl = null;
      }
    }
    return all;
  }

  Future<Animal> getAnimal(String id) async {
    final data = await _get('/animals/$id/');
    return _animalFromApi(data);
  }

  Future<Animal> createAnimal(Animal animal) async {
    final data = await _post('/animals/', _animalToApi(animal));
    return _animalFromApi(data);
  }

  Future<Animal> updateAnimal(Animal animal) async {
    final data = await _put('/animals/${animal.id}/', _animalToApi(animal));
    return _animalFromApi(data);
  }

  Future<void> deleteAnimal(String id) async {
    await _delete('/animals/$id/');
  }

  Future<Map<String, int>> getAnimalStats() async {
    final data = await _get('/animals/stats/');
    return Map<String, int>.from(
      data.map((k, v) => MapEntry(k as String, v as int)),
    );
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final data = await _get('/animals/dashboard-stats/');
    return Map<String, dynamic>.from(data);
  }

  // ─── Service Tiers ─────────────────────────────────────────

  /// Fetch the list of service tiers from the backend.
  /// Returns tier info as configured in Django Admin (or hard-coded defaults).
  Future<List<ServiceTierInfo>> getTiers() async {
    final data = await _get('/accounts/tiers/');
    final results = data is List ? data : (data['results'] as List? ?? []);
    return results.map((m) {
      final tierIndex = m['tier_id'] as int;
      return ServiceTierInfo(
        tier: ServiceTier.values[tierIndex],
        label: m['label'] as String,
        description: m['description'] as String? ?? '',
        maxAnimals: m['max_animals'] as int?,
        allowsMultiBreed: m['allows_multi_breed'] as bool? ?? false,
        maxUsers: m['max_users'] as int?,
      );
    }).toList();
  }

  // ─── Authentication ─────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _post('/accounts/login/', {
      'username': email,
      'password': password,
    });
    return Map<String, dynamic>.from(data);
  }

  /// Log in as the demo user (read-only, no credentials needed).
  /// Returns {token, user, is_demo: true} or throws.
  Future<Map<String, dynamic>> demoLogin() async {
    final data = await _post('/accounts/demo-login/', {});
    return Map<String, dynamic>.from(data);
  }

  // ─── Health Records ───────────────────────────────────────────

  Future<List<HealthRecord>> getHealthRecords(String animalId) async {
    final data = await _get('/health-records/', queryParams: {'animal': animalId});
    final results = data['results'] as List? ?? data as List;
    return results.map((m) => _healthRecordFromApi(m)).toList();
  }

  Future<HealthRecord> createHealthRecord(HealthRecord record) async {
    final data = await _post('/health-records/', _healthRecordToApi(record));
    return _healthRecordFromApi(data);
  }

  Future<void> deleteHealthRecord(String id) async {
    await _delete('/health-records/$id/');
  }

  // ─── Breeding Records ────────────────────────────────────────

  Future<List<BreedingRecord>> getBreedingRecords() async {
    final data = await _get('/breeding-records/');
    final results = data['results'] as List? ?? data as List;
    return results.map((m) => _breedingRecordFromApi(m)).toList();
  }

  Future<List<BreedingRecord>> getActiveBreedings() async {
    final data = await _get('/breeding-records/active/');
    final results = data is List ? data : (data['results'] as List? ?? []);
    return results.map((m) => _breedingRecordFromApi(m)).toList();
  }

  Future<BreedingRecord> createBreedingRecord(BreedingRecord record) async {
    final data = await _post('/breeding-records/', _breedingRecordToApi(record));
    return _breedingRecordFromApi(data);
  }

  // ─── Litters ──────────────────────────────────────────────────

  Future<List<Litter>> getLitters() async {
    final data = await _get('/litters/');
    final results = data['results'] as List? ?? data as List;
    return results.map((m) => _litterFromApi(m)).toList();
  }

  Future<Litter> createLitter(Litter litter) async {
    final data = await _post('/litters/', _litterToApi(litter));
    return _litterFromApi(data);
  }

  // ─── Genetics ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPedigree(String animalId, {int generations = 5}) async {
    final data = await _get(
      '/genetics/$animalId/pedigree/',
      queryParams: {'generations': '$generations'},
    );
    return data as Map<String, dynamic>;
  }

  Future<double> calculateCOI(String sireId, String damId) async {
    final data = await _get(
      '/genetics/coi/',
      queryParams: {'sire': sireId, 'dam': damId},
    );
    return (data['coi_percentage'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getBreedingSuggestions(String animalId) async {
    final data = await _get('/genetics/$animalId/suggestions/');
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  // ─── Contacts ───────────────────────────────────────────────

  Future<List<Contact>> getContacts() async {
    final data = await _get('/contacts/');
    final results = data['results'] as List? ?? data as List;
    return results
        .map((m) => Contact.fromApi(m as Map<String, dynamic>))
        .toList();
  }

  Future<Contact> createContact(Contact contact) async {
    final data = await _post('/contacts/', contact.toApi());
    return Contact.fromApi(data);
  }

  Future<Contact> updateContact(Contact contact) async {
    final data = await _put('/contacts/${contact.id}/', contact.toApi());
    return Contact.fromApi(data);
  }

  Future<void> deleteContact(String id) async {
    await _delete('/contacts/$id/');
  }

  // ─── Custom Field Definitions ────────────────────────────────

  Future<List<CustomFieldDefinition>> getCustomFieldDefinitions() async {
    final data = await _get('/custom-fields/');
    final results = data['results'] as List? ?? data as List;
    return results
        .map((m) => CustomFieldDefinition.fromApi(m as Map<String, dynamic>))
        .toList();
  }

  Future<CustomFieldDefinition> createCustomFieldDefinition(
      CustomFieldDefinition field) async {
    final data = await _post('/custom-fields/', field.toApi());
    return CustomFieldDefinition.fromApi(data);
  }

  Future<CustomFieldDefinition> updateCustomFieldDefinition(
      CustomFieldDefinition field) async {
    final data = await _put('/custom-fields/${field.id}/', field.toApi());
    return CustomFieldDefinition.fromApi(data);
  }

  Future<void> deleteCustomFieldDefinition(String id) async {
    await _delete('/custom-fields/$id/');
  }

  // ─── Serialization Helpers ────────────────────────────────────

  Animal _animalFromApi(Map<String, dynamic> m) {
    return Animal(
      id: m['id'] as String,
      name: m['name'] as String,
      species: m['species'] as String,
      breed: m['breed'] as String,
      sex: Sex.values[m['sex'] as int],
      dateOfBirth: m['date_of_birth'] != null
          ? DateTime.parse(m['date_of_birth'] as String)
          : null,
      dateOfDeath: m['date_of_death'] != null
          ? DateTime.parse(m['date_of_death'] as String)
          : null,
      color: m['color'] as String?,
      markings: m['markings'] as String?,
      registrationNumber: m['registration_number'] as String?,
      microchipNumber: m['microchip_number'] as String?,
      dnaProfileId: m['dna_profile_id'] as String?,
      sireId: m['sire'] as String?,
      damId: m['dam'] as String?,
      breederId: m['breeder'] as String?,
      currentOwnerId: m['current_owner'] as String?,
      weight: m['weight'] != null ? double.tryParse(m['weight'].toString()) : null,
      height: m['height'] != null ? double.tryParse(m['height'].toString()) : null,
      status: AnimalStatus.values[m['status'] as int? ?? 0],
      geneticTraits: Map<String, dynamic>.from(m['genetic_traits'] ?? {}),
      customFields: Map<String, dynamic>.from(m['custom_fields'] ?? {}),
      notes: m['notes'] as String?,
    );
  }

  Map<String, dynamic> _animalToApi(Animal a) {
    return {
      'name': a.name,
      'species': a.species,
      'breed': a.breed,
      'sex': a.sex.index,
      'date_of_birth': a.dateOfBirth?.toIso8601String().split('T').first,
      'date_of_death': a.dateOfDeath?.toIso8601String().split('T').first,
      'color': a.color ?? '',
      'markings': a.markings ?? '',
      'registration_number': a.registrationNumber ?? '',
      'microchip_number': a.microchipNumber ?? '',
      'dna_profile_id': a.dnaProfileId ?? '',
      'sire': a.sireId,
      'dam': a.damId,
      'breeder': a.breederId,
      'current_owner': a.currentOwnerId,
      'weight': a.weight,
      'height': a.height,
      'status': a.status.index,
      'genetic_traits': a.geneticTraits,
      'custom_fields': a.customFields,
      'notes': a.notes ?? '',
    };
  }

  HealthRecord _healthRecordFromApi(Map<String, dynamic> m) {
    return HealthRecord(
      id: m['id'] as String,
      animalId: m['animal'] as String,
      type: HealthRecordType.values[m['type'] as int],
      title: m['title'] as String,
      description: m['description'] as String?,
      date: DateTime.parse(m['date'] as String),
      nextDueDate: m['next_due_date'] != null
          ? DateTime.parse(m['next_due_date'] as String)
          : null,
      veterinarian: m['veterinarian'] as String?,
      clinic: m['clinic'] as String?,
      cost: m['cost'] != null ? double.tryParse(m['cost'].toString()) : null,
    );
  }

  Map<String, dynamic> _healthRecordToApi(HealthRecord r) {
    return {
      'animal': r.animalId,
      'type': r.type.index,
      'title': r.title,
      'description': r.description ?? '',
      'date': r.date.toIso8601String().split('T').first,
      'next_due_date': r.nextDueDate?.toIso8601String().split('T').first,
      'veterinarian': r.veterinarian ?? '',
      'clinic': r.clinic ?? '',
      'cost': r.cost,
    };
  }

  BreedingRecord _breedingRecordFromApi(Map<String, dynamic> m) {
    return BreedingRecord(
      id: m['id'] as String,
      sireId: m['sire'] as String,
      damId: m['dam'] as String,
      breedingDate: DateTime.parse(m['breeding_date'] as String),
      expectedDueDate: m['expected_due_date'] != null
          ? DateTime.parse(m['expected_due_date'] as String)
          : null,
      status: BreedingStatus.values[m['status'] as int? ?? 0],
      method: m['method'] as String?,
      expectedOffspringCoi: m['expected_offspring_coi'] as double?,
    );
  }

  Map<String, dynamic> _breedingRecordToApi(BreedingRecord r) {
    return {
      'sire': r.sireId,
      'dam': r.damId,
      'breeding_date': r.breedingDate.toIso8601String().split('T').first,
      'expected_due_date': r.expectedDueDate?.toIso8601String().split('T').first,
      'status': r.status.index,
      'method': r.method ?? '',
      'expected_offspring_coi': r.expectedOffspringCoi,
    };
  }

  Litter _litterFromApi(Map<String, dynamic> m) {
    return Litter(
      id: m['id'] as String,
      sireId: m['sire'] as String,
      damId: m['dam'] as String,
      dateOfBirth: DateTime.parse(m['date_of_birth'] as String),
      totalPuppies: m['total_puppies'] as int? ?? 0,
      maleCount: m['male_count'] as int? ?? 0,
      femaleCount: m['female_count'] as int? ?? 0,
      stillborn: m['stillborn'] as int? ?? 0,
      registrationNumber: m['registration_number'] as String?,
      notes: m['notes'] as String?,
    );
  }

  Map<String, dynamic> _litterToApi(Litter l) {
    return {
      'sire': l.sireId,
      'dam': l.damId,
      'date_of_birth': l.dateOfBirth.toIso8601String().split('T').first,
      'total_puppies': l.totalPuppies,
      'male_count': l.maleCount,
      'female_count': l.femaleCount,
      'stillborn': l.stillborn,
      'registration_number': l.registrationNumber ?? '',
      'notes': l.notes ?? '',
    };
  }

  // ─── Background Tasks ─────────────────────────────────────

  Future<Map<String, dynamic>> createPedigreeTask(String animalId, {int generations = 5}) async {
    final data = await _post('/tasks/pedigree/', {
      'animal_id': animalId,
      'generations': generations,
    });
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> createBreedingSuggestionsTask(
    String animalId, {
    int maxResults = 10,
    double maxCoi = 12.5,
  }) async {
    final data = await _post('/tasks/breeding-suggestions/', {
      'animal_id': animalId,
      'max_results': maxResults,
      'max_coi': maxCoi,
    });
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getTaskStatus(String taskId) async {
    final data = await _get('/tasks/$taskId/');
    return Map<String, dynamic>.from(data);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
