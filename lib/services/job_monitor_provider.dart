import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'background_task_service.dart';
import 'notification_service.dart';

/// Provider that monitors active background jobs and notifies the UI.
///
/// Periodically polls for active tasks and emits updates so the UI can show
/// a global activity indicator, progress bars, and completion notifications.
class JobMonitorProvider extends ChangeNotifier {
  final BackgroundTaskService _taskService;
  final NotificationService _notifications;

  Timer? _pollTimer;
  List<BackgroundTaskStatus> _activeTasks = [];
  List<BackgroundTaskStatus> _recentTasks = [];
  final Set<String> _notifiedTaskIds = {};
  bool _isPolling = false;

  JobMonitorProvider({
    BackgroundTaskService? taskService,
    NotificationService? notifications,
  })  : _taskService = taskService ?? BackgroundTaskService(),
        _notifications = notifications ?? NotificationService();

  /// Currently active (pending/running) tasks.
  List<BackgroundTaskStatus> get activeTasks =>
      List.unmodifiable(_activeTasks);

  /// Recently completed tasks (for showing completion notifications).
  List<BackgroundTaskStatus> get recentTasks =>
      List.unmodifiable(_recentTasks);

  /// Whether there are any active background jobs.
  bool get hasActiveTasks => _activeTasks.isNotEmpty;

  /// Total number of active tasks.
  int get activeTaskCount => _activeTasks.length;

  /// Start periodic polling for active tasks.
  void startMonitoring() {
    if (_isPolling) return;
    _isPolling = true;
    _poll(); // immediate first poll
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  /// Stop periodic polling.
  void stopMonitoring() {
    _isPolling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Force an immediate refresh of active tasks.
  Future<void> refresh() async {
    await _poll();
  }

  /// Submit a bulk import and start tracking it.
  Future<BackgroundTaskStatus?> submitBulkImport(
    List<int> fileBytes,
    String fileName, {
    void Function(BackgroundTaskStatus)? onProgress,
  }) async {
    final result = await _taskService.startBulkImport(
      fileBytes,
      fileName,
      onProgress: (status) {
        _updateTask(status);
        onProgress?.call(status);
      },
    );
    if (result != null) {
      _handleCompletion(result);
    }
    return result;
  }

  /// Submit a bulk export and start tracking it.
  Future<BackgroundTaskStatus?> submitBulkExport({
    String format = 'csv',
    void Function(BackgroundTaskStatus)? onProgress,
  }) async {
    final result = await _taskService.startBulkExport(
      format: format,
      onProgress: (status) {
        _updateTask(status);
        onProgress?.call(status);
      },
    );
    if (result != null) {
      _handleCompletion(result);
    }
    return result;
  }

  /// Submit a dashboard stats computation and track it.
  Future<BackgroundTaskStatus?> submitDashboardStats({
    void Function(BackgroundTaskStatus)? onProgress,
  }) async {
    final result = await _taskService.computeDashboardStats(
      onProgress: (status) {
        _updateTask(status);
        onProgress?.call(status);
      },
    );
    if (result != null) {
      _handleCompletion(result);
    }
    return result;
  }

  /// Cancel a task.
  Future<BackgroundTaskStatus?> cancelTask(String taskId) async {
    final result = await _taskService.cancelTask(taskId);
    if (result != null) {
      _activeTasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
    }
    return result;
  }

  /// Retry a task.
  Future<BackgroundTaskStatus?> retryTask(String taskId) async {
    final result = await _taskService.retryTask(taskId);
    if (result != null) {
      _activeTasks.add(result);
      notifyListeners();
    }
    return result;
  }

  /// Load recent task history.
  Future<void> loadRecentTasks({int limit = 20}) async {
    _recentTasks = await _taskService.listTasks(limit: limit);
    notifyListeners();
  }

  Future<void> _poll() async {
    try {
      final tasks = await _taskService.getActiveTasks();
      final previousIds = _activeTasks.map((t) => t.id).toSet();
      _activeTasks = tasks;

      // Detect newly completed tasks (were active before, no longer active)
      for (final prevId in previousIds) {
        if (!tasks.any((t) => t.id == prevId)) {
          // Task is no longer active - check if it completed
          _checkCompletedTask(prevId);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error polling active tasks: $e');
    }
  }

  Future<void> _checkCompletedTask(String taskId) async {
    if (_notifiedTaskIds.contains(taskId)) return;

    try {
      final data = await ApiService().getTaskStatus(taskId);
      final task = BackgroundTaskStatus.fromJson(data);
      _handleCompletion(task);
    } catch (e) {
      debugPrint('Error checking completed task $taskId: $e');
    }
  }

  void _handleCompletion(BackgroundTaskStatus task) {
    if (_notifiedTaskIds.contains(task.id)) return;
    if (!task.isFinished) return;

    _notifiedTaskIds.add(task.id);

    // Send local notification
    final title = task.isCompleted
        ? '${task.taskTypeDisplay} Complete'
        : '${task.taskTypeDisplay} Failed';
    final body = task.isCompleted
        ? task.statusMessage.isNotEmpty
            ? task.statusMessage
            : 'Your ${task.taskTypeDisplay.toLowerCase()} has completed successfully.'
        : task.error.isNotEmpty
            ? task.error
            : 'The task failed. You can retry it from the job history.';

    _notifications.notifyJobComplete(
      taskTypeDisplay: task.taskTypeDisplay,
      isSuccess: task.isCompleted,
      message: body,
    );

    // Add to recent tasks
    _recentTasks.insert(0, task);
    if (_recentTasks.length > 20) {
      _recentTasks = _recentTasks.sublist(0, 20);
    }

    notifyListeners();
  }

  void _updateTask(BackgroundTaskStatus task) {
    final idx = _activeTasks.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      _activeTasks[idx] = task;
    } else if (task.isActive) {
      _activeTasks.add(task);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
