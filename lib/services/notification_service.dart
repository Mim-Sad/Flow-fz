import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/task.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final _onNotificationClick = StreamController<String?>.broadcast();
  Stream<String?> get onNotificationClick => _onNotificationClick.stream;

  String? _initialPayload;

  Future<void> init() async {
    // Initialize timezone
    tz_data.initializeTimeZones();
    String timeZoneName;
    try {
      final String? result = await FlutterTimezone.getLocalTimezone().then((info) => info.identifier);
      timeZoneName = result ?? 'Asia/Tehran';
    } catch (e) {
      debugPrint('Error getting timezone: $e');
      timeZoneName = 'Asia/Tehran';
    }
    debugPrint('🌍 Local Timezone: $timeZoneName');
    
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('⚠️ Error setting location for $timeZoneName, falling back to UTC');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_launcher_foreground');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 Notification clicked with payload: ${response.payload}');
        _onNotificationClick.add(response.payload);
      },
    );

    // Check if app was launched via notification
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final payload = notificationAppLaunchDetails?.notificationResponse?.payload;
      debugPrint('🔔 App launched from notification with payload: $payload');
      _initialPayload = payload;
      
      // Also add to stream with a longer delay as a fallback for early listeners
      if (payload != null) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          _onNotificationClick.add(payload);
        });
      }
    }
  }

  String? consumeInitialPayload() {
    final payload = _initialPayload;
    _initialPayload = null;
    return payload;
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
    
    // CRITICAL: Cancel any existing reminders for this task before scheduling new ones
    // This prevents duplicate notifications when a task is updated or re-scheduled
    await cancelTaskReminder(task.id!);
    
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
            // Use a deterministic ID for each occurrence to avoid duplicates
            // Base ID + (taskId * 10) + count
            final notificationId = 1000000000 + (task.id! * 10) + scheduledCount;
            final scheduledDate = tz.TZDateTime.from(candidateReminder, tz.local);
            
            debugPrint('📅 Scheduling occurrence $scheduledCount at $candidateReminder (ID: $notificationId)');
            
            final notificationEmoji = task.taskEmoji ?? '🔔';
            final androidDetails = AndroidNotificationDetails(
              'task_reminders_v3',
              'یادآور تسک‌ها',
              channelDescription: 'اعلان‌های مربوط به یادآور تسک‌ها',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
              playSound: true,
              enableVibration: true,
              styleInformation: BigTextStyleInformation(
                task.description ?? 'زمان انجام تسک فرا رسیده است.',
                contentTitle: '$notificationEmoji ${task.title}',
                summaryText: 'یادآور تسک تکرار شونده',
              ),
              category: AndroidNotificationCategory.reminder,
            );

            await _notificationsPlugin.zonedSchedule(
              notificationId,
              task.title,
              task.description ?? 'زمان انجام تسک فرا رسیده است.',
              scheduledDate,
              NotificationDetails(
                android: androidDetails,
                iOS: const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                  interruptionLevel: InterruptionLevel.timeSensitive,
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

    // Use task.id directly for non-recurring tasks as the primary ID
    final notificationId = task.id!;
    debugPrint('📅 Scheduling single reminder at $reminderTime (ID: $notificationId) in timezone: ${tz.local.name}');
    
    // Customizing the notification with better layout and details
    final notificationEmoji = task.taskEmoji ?? '🔔';
    final androidDetails = AndroidNotificationDetails(
      'task_reminders_v3', // Incremented version for new layout
      'یادآور تسک‌ها',
      channelDescription: 'اعلان‌های مربوط به یادآور تسک‌ها',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        task.description ?? 'زمان انجام تسک فرا رسیده است.',
        contentTitle: '$notificationEmoji ${task.title}',
        summaryText: 'یادآور تسک',
      ),
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: true, // For critical reminders
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      task.title,
      task.description ?? 'زمان انجام تسک فرا رسیده است.',
      scheduledDate,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: task.id.toString(),
    );
    debugPrint('✅ Single reminder scheduled successfully.');
  }

  Future<void> cancelTaskReminder(int taskId) async {
    debugPrint('🔕 Cancelling reminders for task ID: $taskId');
    
    // 1. Cancel the primary notification ID
    await _notificationsPlugin.cancel(taskId);
    
    // 2. Cancel old recurring range (backward compatibility)
    for (int i = 0; i < 7; i++) {
      await _notificationsPlugin.cancel(taskId * 100 + i);
    }
    
    // 3. Cancel new recurring range
    for (int i = 0; i < 10; i++) { // Cancel up to 10 just to be safe
      await _notificationsPlugin.cancel(1000000000 + (taskId * 10) + i);
    }
    
    debugPrint('✅ All reminders for task ID $taskId cancelled.');
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
