/// Represents the status of a background computation task.
class BackgroundTaskStatus {
  final String id;
  final int taskType;
  final String taskTypeDisplay;
  final int status;
  final String statusDisplay;
  final Map<String, dynamic> params;
  final Map<String, dynamic>? result;
  final String error;
  final int progress;
  final String statusMessage;
  final int totalItems;
  final int processedItems;
  final DateTime? estimatedCompletion;
  final int? estimatedSecondsRemaining;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BackgroundTaskStatus({
    required this.id,
    required this.taskType,
    required this.taskTypeDisplay,
    required this.status,
    required this.statusDisplay,
    required this.params,
    this.result,
    required this.error,
    required this.progress,
    this.statusMessage = '',
    this.totalItems = 0,
    this.processedItems = 0,
    this.estimatedCompletion,
    this.estimatedSecondsRemaining,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BackgroundTaskStatus.fromJson(Map<String, dynamic> json) {
    return BackgroundTaskStatus(
      id: json['id'] as String,
      taskType: json['task_type'] as int,
      taskTypeDisplay: json['task_type_display'] as String? ?? '',
      status: json['status'] as int,
      statusDisplay: json['status_display'] as String? ?? '',
      params: Map<String, dynamic>.from(json['params'] as Map? ?? {}),
      result: json['result'] != null
          ? Map<String, dynamic>.from(json['result'] as Map)
          : null,
      error: json['error'] as String? ?? '',
      progress: json['progress'] as int? ?? 0,
      statusMessage: json['status_message'] as String? ?? '',
      totalItems: json['total_items'] as int? ?? 0,
      processedItems: json['processed_items'] as int? ?? 0,
      estimatedCompletion: json['estimated_completion'] != null
          ? DateTime.tryParse(json['estimated_completion'] as String)
          : null,
      estimatedSecondsRemaining:
          json['estimated_seconds_remaining'] as int?,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isPending => status == 0;
  bool get isRunning => status == 1;
  bool get isCompleted => status == 2;
  bool get isFailed => status == 3;
  bool get isCancelled => status == 4;
  bool get isFinished => isCompleted || isFailed || isCancelled;
  bool get isActive => isPending || isRunning;

  /// Human-readable ETA string.
  String get etaDisplay {
    if (estimatedSecondsRemaining == null || estimatedSecondsRemaining! <= 0) {
      return '';
    }
    final secs = estimatedSecondsRemaining!;
    if (secs < 60) return '${secs}s remaining';
    if (secs < 3600) return '${(secs / 60).ceil()}m remaining';
    final hours = secs ~/ 3600;
    final mins = (secs % 3600) ~/ 60;
    return '${hours}h ${mins}m remaining';
  }

  /// Progress description combining message and items count.
  String get progressDescription {
    if (statusMessage.isNotEmpty) {
      if (totalItems > 0) {
        return '$statusMessage ($processedItems / $totalItems)';
      }
      return statusMessage;
    }
    if (totalItems > 0) {
      return '$processedItems of $totalItems items processed';
    }
    return '$progress%';
  }
}

/// Task type constants matching the backend.
class TaskTypes {
  static const int pedigreeTree = 0;
  static const int breedingSuggestions = 1;
  static const int coiCalculation = 2;
  static const int bulkImport = 3;
  static const int bulkExport = 4;
  static const int dashboardStats = 5;
}
