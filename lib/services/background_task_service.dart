import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';

/// Service for managing background tasks (pedigree trees, breeding suggestions).
///
/// Submits expensive computations to the backend's Celery task queue and polls
/// for results. The UI shows a progress indicator while the task runs and
/// renders results once completed.
class BackgroundTaskService {
  final ApiService _api;

  BackgroundTaskService({ApiService? api}) : _api = api ?? ApiService();

  /// Submit a pedigree tree computation and poll until complete.
  ///
  /// Returns the completed task status with the result, or null on failure.
  Future<BackgroundTaskStatus?> computePedigreeTree(
    String animalId, {
    int generations = 5,
    void Function(BackgroundTaskStatus)? onProgress,
  }) async {
    try {
      final data = await _api.createPedigreeTask(animalId, generations: generations);
      final taskId = data['id'] as String;
      return _pollUntilDone(taskId, onProgress: onProgress);
    } catch (e) {
      debugPrint('Failed to create pedigree task: $e');
      return null;
    }
  }

  /// Submit a breeding suggestions computation and poll until complete.
  Future<BackgroundTaskStatus?> computeBreedingSuggestions(
    String animalId, {
    int maxResults = 10,
    double maxCoi = 12.5,
    void Function(BackgroundTaskStatus)? onProgress,
  }) async {
    try {
      final data = await _api.createBreedingSuggestionsTask(
        animalId,
        maxResults: maxResults,
        maxCoi: maxCoi,
      );
      final taskId = data['id'] as String;
      return _pollUntilDone(taskId, onProgress: onProgress);
    } catch (e) {
      debugPrint('Failed to create breeding suggestions task: $e');
      return null;
    }
  }

  /// Poll the backend for a task's status until it finishes.
  Future<BackgroundTaskStatus?> _pollUntilDone(
    String taskId, {
    void Function(BackgroundTaskStatus)? onProgress,
  }) async {
    const pollInterval = Duration(seconds: 2);
    const maxAttempts = 150; // 5 minutes max

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final data = await _api.getTaskStatus(taskId);
        final status = BackgroundTaskStatus.fromJson(data);

        onProgress?.call(status);

        if (status.isFinished) {
          return status;
        }

        await Future.delayed(pollInterval);
      } catch (e) {
        debugPrint('Error polling task $taskId: $e');
        if (attempt > 3) return null;
        await Future.delayed(const Duration(seconds: 3));
      }
    }

    debugPrint('Task $taskId timed out after $maxAttempts attempts');
    return null;
  }
}
