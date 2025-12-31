import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize timezone
    tz_data.initializeTimeZones();
    String timeZoneName;
    try {
      final String? result = await FlutterTimezone.getLocalTimezone().then((info) => info.identifier);
      timeZoneName = result ?? 'UTC';
    } catch (e) {
      timeZoneName = 'UTC';
    }
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );
  }

  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final bool? result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      final bool? grantedNotification = await androidImplementation?.requestNotificationsPermission();
      final bool? grantedExactAlarm = await androidImplementation?.requestExactAlarmsPermission();
      
      return (grantedNotification ?? false) && (grantedExactAlarm ?? true);
    }
    return false;
  }

  Future<void> scheduleTaskReminder(Task task) async {
    if (task.reminderDateTime == null || task.id == null) return;
    debugPrint('🔔 Scheduling reminder for task: ${task.title} (ID: ${task.id})');

    // First request permissions
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('❌ Notification permissions not granted. Cannot schedule reminder.');
      return;
    }

    DateTime reminderTime = task.reminderDateTime!;
    final now = DateTime.now();

    // If it's a recurring task, schedule multiple future reminders
    if (task.recurrence != null && task.recurrence!.type != RecurrenceType.none) {
      debugPrint('🔄 Recurring task detected. Scheduling multiple reminders...');
      // Start searching from today
      DateTime searchDate = DateTime(now.year, now.month, now.day);
      
      int scheduledCount = 0;
      // Schedule up to 7 future occurrences
      for (int i = 0; i <= 366 && scheduledCount < 7; i++) {
        final candidateDate = searchDate.add(Duration(days: i));
        if (task.isActiveOnDate(candidateDate)) {
          final candidateReminder = DateTime(
            candidateDate.year,
            candidateDate.month,
            candidateDate.day,
            reminderTime.hour,
            reminderTime.minute,
          );
          
          if (candidateReminder.isAfter(now)) {
            final notificationId = task.id! * 100 + scheduledCount;
            final scheduledDate = tz.TZDateTime.from(candidateReminder, tz.local);
            
            debugPrint('📅 Scheduling occurrence $scheduledCount at $candidateReminder (ID: $notificationId)');
            
            await _notificationsPlugin.zonedSchedule(
              notificationId,
              task.title,
              task.description ?? 'یادآور تسک',
              scheduledDate,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'task_reminders',
                  'یادآور تسک‌ها',
                  channelDescription: 'اعلان‌های مربوط به یادآور تسک‌ها',
                  importance: Importance.max,
                  priority: Priority.high,
                  showWhen: true,
                ),
                iOS: DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                  payload: task.id.toString(),
                );
            scheduledCount++;
          }
        }
      }
      debugPrint('✅ Scheduled $scheduledCount reminders for recurring task.');
      return;
    }

    // Non-recurring task logic
    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);
    
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      debugPrint('⚠️ Reminder time is in the past: $reminderTime. Skipping.');
      return;
    }

    debugPrint('📅 Scheduling single reminder at $reminderTime (ID: ${task.id})');
    await _notificationsPlugin.zonedSchedule(
      task.id!,
      task.title,
      task.description ?? 'یادآور تسک',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'یادآور تسک‌ها',
          channelDescription: 'اعلان‌های مربوط به یادآور تسک‌ها',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: task.id.toString(),
    );
    debugPrint('✅ Single reminder scheduled successfully.');
  }

  Future<void> cancelTaskReminder(int taskId) async {
    debugPrint('🔕 Cancelling reminders for task ID: $taskId');
    await _notificationsPlugin.cancel(taskId);
    // Also cancel recurring occurrences
    for (int i = 0; i < 7; i++) {
      await _notificationsPlugin.cancel(taskId * 100 + i);
    }
    debugPrint('✅ All reminders for task ID $taskId cancelled.');
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
