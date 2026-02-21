import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import '../models/models.dart';
import 'animal_provider.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';
import 'demo_data_generator.dart';

/// Orchestrates entering and exiting demo mode.
///
/// **Enter flow**:
///   1. Call `POST /api/v1/accounts/demo-login/` to get a read-only token.
///   2. Configure [ApiService] with the token.
///   3. Sync demo data from the API into local SQLite.
///   4. Set [AnimalProvider.isDemoMode] = true.
///   5. On mobile only: if the API is unreachable, fall back to
///      [DemoDataGenerator] which creates ~200 animals directly in SQLite.
///      (Web builds skip the fallback because sqflite isn't available.)
///
/// **Exit flow**:
///   1. Clear local SQLite data.
///   2. Reset [ApiService] token.
///   3. Set [AnimalProvider.isDemoMode] = false.
class DemoService {
  final ApiService _api;
  final DatabaseService _db;

  DemoService({ApiService? api, DatabaseService? db})
      : _api = api ?? ApiService(),
        _db = db ?? DatabaseService();

  /// Enter demo mode. Returns true on success.
  Future<bool> enterDemoMode(AnimalProvider provider) async {
    try {
      // Try API-backed demo
      final result = await _api.demoLogin();
      final token = result['token'] as String;
      _api.authToken = token;
      provider.setAuthToken(token);

      // Parse user profile from response
      if (result['user'] != null) {
        final profileData = result['user'] as Map<String, dynamic>;
        provider.setUserProfile(UserProfile.fromApi(profileData));
      }

      provider.setDemoMode(true);

      if (kIsWeb) {
        // On web, sqflite is not available.
        // Load data directly from the API into memory.
        await provider.loadAllFromApi();
      } else {
        // On mobile, sync data into local SQLite then load from there.
        final syncService = SyncService(api: _api, db: _db);
        await syncService.syncAll();
        await provider.loadAll();
      }

      return true;
    } catch (e, st) {
      debugPrint('Demo API login failed: $e');
      debugPrint('$st');

      // On web, sqflite isn't available so the fallback generator won't work.
      // The web app is served from Django, so the API should always be reachable.
      if (kIsWeb) {
        debugPrint('Skipping fallback on web (sqflite not supported)');
        return false;
      }

      return _enterFallbackDemo(provider);
    }
  }

  /// Fallback: generate demo data locally when the API is unreachable.
  /// Only used on mobile where sqflite is available.
  Future<bool> _enterFallbackDemo(AnimalProvider provider) async {
    try {
      final generator = DemoDataGenerator(db: _db);
      await generator.generate();

      provider.setDemoMode(true);
      await provider.loadAll();
      return true;
    } catch (e, st) {
      debugPrint('Fallback demo generation failed: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Exit demo mode: clear data and reset state.
  Future<void> exitDemoMode(AnimalProvider provider) async {
    // Clear the API token
    _api.authToken = null;
    provider.setAuthToken(null);

    // Clear all local data (skip on web where sqflite is unavailable)
    if (!kIsWeb) {
      try {
        await _clearLocalData();
      } catch (e) {
        debugPrint('Clear local data failed: $e');
      }
    }

    // Reset demo flag and user profile
    provider.setUserProfile(null);
    provider.setDemoMode(false);

    // Reload (will be empty) — skip on web since sqflite is unavailable
    if (!kIsWeb) {
      await provider.loadAll();
    }
  }

  Future<void> _clearLocalData() async {
    final db = await _db.database;
    await db.delete('animals');
    await db.delete('health_records');
    await db.delete('breeding_records');
    await db.delete('litters');
    await db.delete('contacts');
    await db.delete('custom_field_definitions');
    await db.delete('weight_records');
    await db.delete('show_results');
    await db.delete('financial_records');
    await db.delete('document_attachments');
    await db.delete('animal_images');
    await db.delete('team_members');
  }
}
