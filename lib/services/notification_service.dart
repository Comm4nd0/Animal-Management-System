import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/models.dart';
import 'database_service.dart';

/// Manages local push notifications for health reminders,
/// breeding due dates, and other time-sensitive events.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification plugin. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Schedule notifications for all upcoming and overdue health records.
  Future<void> scheduleHealthReminders() async {
    if (!_initialized) return;

    // Cancel existing health notifications first
    await cancelAllNotifications();

    final db = DatabaseService();
    final upcoming = await db.getUpcomingHealthRecords();
    int id = 1000;

    for (final record in upcoming) {
      if (record.nextDueDate == null) continue;

      final isOverdue = record.nextDueDate!.isBefore(DateTime.now());
      final title = isOverdue
          ? 'OVERDUE: ${record.title}'
          : 'Upcoming: ${record.title}';
      final body = 'Due: ${record.nextDueDate!.day}/${record.nextDueDate!.month}/${record.nextDueDate!.year}';

      await _showNotification(
        id: id++,
        title: title,
        body: body,
        channel: 'health_reminders',
        channelName: 'Health Reminders',
      );
    }
  }

  /// Show a notification for a breeding due date.
  Future<void> notifyBreedingDue(BreedingRecord record, String sireName, String damName) async {
    if (!_initialized) return;
    if (record.expectedDueDate == null) return;

    final daysLeft = record.expectedDueDate!.difference(DateTime.now()).inDays;
    if (daysLeft > 7 || daysLeft < 0) return;

    await _showNotification(
      id: 2000 + record.hashCode % 1000,
      title: 'Breeding Due Soon',
      body: '$sireName x $damName - $daysLeft days remaining',
      channel: 'breeding_alerts',
      channelName: 'Breeding Alerts',
    );
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channel,
    required String channelName,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channel,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details);
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAllNotifications() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }
}
