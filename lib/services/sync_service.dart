import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'database_service.dart';

/// Syncs local SQLite data with the remote Django API.
///
/// Strategy:
/// - On sync, pull remote data and merge with local.
/// - Remote is treated as source of truth for reads.
/// - Local changes are pushed up if the API is reachable.
/// - Falls back gracefully to local-only when offline.
class SyncService {
  final ApiService _api;
  final DatabaseService _db;

  SyncService({ApiService? api, DatabaseService? db})
      : _api = api ?? ApiService(),
        _db = db ?? DatabaseService();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Performs a full sync: pulls remote data and stores it locally.
  /// Returns a [SyncResult] with counts of what changed.
  Future<SyncResult> syncAll() async {
    if (_isSyncing) return SyncResult(status: SyncStatus.alreadyRunning);

    _isSyncing = true;
    try {
      int pulled = 0;

      // 1. Sync animals
      try {
        final remoteAnimals = await _api.getAnimals();
        for (final animal in remoteAnimals) {
          await _db.insertAnimal(animal);
        }
        pulled += remoteAnimals.length;
      } catch (e) {
        debugPrint('Sync animals failed: $e');
        return SyncResult(
          status: SyncStatus.failed,
          error: 'Failed to sync animals: $e',
        );
      }

      // 2. Sync contacts
      try {
        final remoteContacts = await _api.getContacts();
        for (final contact in remoteContacts) {
          await _db.insertContact(contact);
        }
        pulled += remoteContacts.length;
      } catch (e) {
        debugPrint('Sync contacts failed: $e');
      }

      // 3. Sync breeding records
      try {
        final remoteBreedings = await _api.getBreedingRecords();
        for (final record in remoteBreedings) {
          await _db.insertBreedingRecord(record);
        }
        pulled += remoteBreedings.length;
      } catch (e) {
        debugPrint('Sync breeding records failed: $e');
      }

      // 4. Sync litters
      try {
        final remoteLitters = await _api.getLitters();
        for (final litter in remoteLitters) {
          await _db.insertLitter(litter);
        }
        pulled += remoteLitters.length;
      } catch (e) {
        debugPrint('Sync litters failed: $e');
      }

      _lastSyncTime = DateTime.now();
      return SyncResult(
        status: SyncStatus.success,
        recordsPulled: pulled,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Push a single animal to the remote API.
  Future<bool> pushAnimal(Animal animal) async {
    try {
      await _api.createAnimal(animal);
      return true;
    } catch (e) {
      debugPrint('Push animal failed: $e');
      return false;
    }
  }

  /// Check if the API is reachable.
  Future<bool> isOnline() async {
    try {
      await _api.getAnimalStats();
      return true;
    } catch (_) {
      return false;
    }
  }
}

enum SyncStatus {
  success,
  failed,
  alreadyRunning,
}

class SyncResult {
  final SyncStatus status;
  final int recordsPulled;
  final int recordsPushed;
  final String? error;

  SyncResult({
    required this.status,
    this.recordsPulled = 0,
    this.recordsPushed = 0,
    this.error,
  });

  bool get isSuccess => status == SyncStatus.success;
}
