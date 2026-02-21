import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';

/// Service for managing background tasks (pedigree trees, breeding suggestions,
/// bulk import/export, dashboard stats).
///
/// Submits expensive computations to the backend's Celery task queue and polls
/// for results. The UI shows a progress indicator while the task runs and
/// renders results once completed.
class BackgroundTaskService {
  final ApiService _api;

  BackgroundTaskService({ApiService? api}) : _api = api ?? ApiService();

  /// Submit a pedigree tree computation and poll until complete.
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

  /// Submit a bulk import job and poll until complete.
  ///
  /// [fileBytes] is the raw file content.
  /// [fileName] is the original filename (used to detect csv/json).
  Future<BackgroundTaskStatus?> startBulkImport(
    List<int> fileBytes,
    String fileName, {
    void Function(BackgroundTaskStatus)? onProgress,
  }) async {
    try {
      final data = await _api.createBulkImportTask(fileBytes, fileName);
      final taskId = data['id'] as String;
      return _pollUntilDone(taskId, onProgress: onProgress);
    } catch (e) {
      debugPrint('Failed to create bulk import task: $e');
      return null;
    }
  }

  /// Submit a bulk export job and poll until complete.
  Future<BackgroundTaskStatus?> startBulkExport({
    String format = 'csv',
    void Function(BackgroundTaskStatus)? onProgress,
  }) async {
    try {
      final data = await _api.createBulkExportTask(format: format);
      final taskId = data['id'] as String;
      return _pollUntilDone(taskId, onProgress: onProgress);
    } catch (e) {
      debugPrint('Failed to create bulk export task: $e');
      return null;
    }
  }

  /// Submit a dashboard stats computation and poll until complete.
  Future<BackgroundTaskStatus?> computeDashboardStats({
    void Function(BackgroundTaskStatus)? onProgress,
  }) async {
    try {
      final data = await _api.createDashboardStatsTask();
      final taskId = data['id'] as String;
      return _pollUntilDone(taskId, onProgress: onProgress);
    } catch (e) {
      debugPrint('Failed to create dashboard stats task: $e');
      return null;
    }
  }

  /// Cancel an active task.
  Future<BackgroundTaskStatus?> cancelTask(String taskId) async {
    try {
      final data = await _api.cancelTask(taskId);
      return BackgroundTaskStatus.fromJson(data);
    } catch (e) {
      debugPrint('Failed to cancel task $taskId: $e');
      return null;
    }
  }

  /// Retry a failed or cancelled task.
  Future<BackgroundTaskStatus?> retryTask(String taskId) async {
    try {
      final data = await _api.retryTask(taskId);
      return BackgroundTaskStatus.fromJson(data);
    } catch (e) {
      debugPrint('Failed to retry task $taskId: $e');
      return null;
    }
  }

  /// Get all active tasks for the current user.
  Future<List<BackgroundTaskStatus>> getActiveTasks() async {
    try {
      final dataList = await _api.getActiveTasks();
      return dataList.map((d) => BackgroundTaskStatus.fromJson(d)).toList();
    } catch (e) {
      debugPrint('Failed to get active tasks: $e');
      return [];
    }
  }

  /// List all tasks for the current user.
  Future<List<BackgroundTaskStatus>> listTasks({
    String? statusFilter,
    int? taskType,
    int limit = 20,
  }) async {
    try {
      final dataList = await _api.listTasks(
        statusFilter: statusFilter,
        taskType: taskType,
        limit: limit,
      );
      return dataList.map((d) => BackgroundTaskStatus.fromJson(d)).toList();
    } catch (e) {
      debugPrint('Failed to list tasks: $e');
      return [];
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
