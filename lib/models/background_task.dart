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
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isPending => status == 0;
  bool get isRunning => status == 1;
  bool get isCompleted => status == 2;
  bool get isFailed => status == 3;
  bool get isFinished => isCompleted || isFailed;
}
