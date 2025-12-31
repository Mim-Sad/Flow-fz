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

    // First request permissions
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('Notification permissions not granted. Cannot schedule reminder.');
      return;
    }

    DateTime reminderTime = task.reminderDateTime!;
    final now = DateTime.now();

    // If it's a recurring task and the reminder is in the past,
    // find the next occurrence's reminder time.
    if (task.recurrence != null && task.recurrence!.type != RecurrenceType.none) {
      // Start searching from today
      DateTime searchDate = DateTime(now.year, now.month, now.day);
      
      // We look ahead up to 366 days to find the next occurrence
      for (int i = 0; i <= 366; i++) {
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
            reminderTime = candidateReminder;
            break;
          }
        }
      }
    }

    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);
    
    // If the reminder time is still in the past (e.g., non-recurring task), don't schedule it
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

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
  }

  Future<void> cancelTaskReminder(int taskId) async {
    await _notificationsPlugin.cancel(taskId);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
