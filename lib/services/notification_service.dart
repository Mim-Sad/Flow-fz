import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
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
      
      // Request notification permission (Android 13+)
      final bool? grantedNotification = await androidImplementation?.requestNotificationsPermission();
      
      // Exact alarm permission is requested but we don't block if it's not granted
      // We will handle it by falling back to inexact scheduling
      try {
        await androidImplementation?.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('⚠️ Error requesting exact alarm permission: $e');
      }
      
      return grantedNotification ?? true;
    }
    return false;
  }

  Future<void> scheduleTaskReminder(Task task) async {
    if (task.reminderDateTime == null || task.id == null) return;
    
    try {
      // CRITICAL: Cancel any existing reminders for this task before scheduling new ones
      await cancelTaskReminder(task.id!);
      
      debugPrint('🔔 Scheduling reminder for task: ${task.title} (ID: ${task.id})');

      // First check permissions
      final hasNotificationPermission = await requestPermissions();
      if (!hasNotificationPermission) {
        debugPrint('❌ Notification permissions not granted. Cannot schedule reminder.');
        return;
      }

      // Use permission_handler to check exact alarm permission on Android
      bool canScheduleExact = true;
      if (defaultTargetPlatform == TargetPlatform.android) {
        canScheduleExact = await Permission.scheduleExactAlarm.isGranted;
      }
      
      final scheduleMode = canScheduleExact 
          ? AndroidScheduleMode.exactAllowWhileIdle 
          : AndroidScheduleMode.inexactAllowWhileIdle;

      DateTime reminderTime = task.reminderDateTime!;
      final now = DateTime.now();

      // If it's a recurring task, schedule multiple future reminders
      if (task.recurrence != null && task.recurrence!.type != RecurrenceType.none) {
        debugPrint('🔄 Recurring task detected. Scheduling multiple reminders...');
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
              // Safer ID generation: taskId * 10 + count
              // We use an offset of 100,000 to keep it within safe 32-bit range
              final notificationId = 100000 + (task.id! * 10) + scheduledCount;
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

              try {
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
                  androidScheduleMode: scheduleMode,
                  payload: task.id.toString(),
                );
              } catch (e) {
                debugPrint('❌ Error in zonedSchedule for recurring task: $e');
                // Fallback to allowWhileIdle if exact scheduling failed
                if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
                  debugPrint('🔄 Attempting fallback to inexact scheduling for recurring task...');
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
                    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                    payload: task.id.toString(),
                  );
                }
              }
              scheduledCount++;
            }
          }
        }
        debugPrint('✅ Scheduled $scheduledCount reminders for recurring task.');
        return;
      }

      // Non-recurring task logic
      final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);
      
      // Allow a small buffer (1 minute) for "past" reminders to account for slight delays
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local).subtract(const Duration(minutes: 1)))) {
        debugPrint('⚠️ Reminder time is in the past: $reminderTime. Skipping.');
        return;
      }

      final notificationId = task.id!;
      debugPrint('📅 Scheduling single reminder at $reminderTime (ID: $notificationId) in timezone: ${tz.local.name}');
      
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
          summaryText: 'یادآور تسک',
        ),
        category: AndroidNotificationCategory.reminder,
        // REMOVED: fullScreenIntent: true (Requires extra permission not in manifest)
      );

      try {
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
          androidScheduleMode: scheduleMode,
          payload: task.id.toString(),
        );
        debugPrint('✅ Single reminder scheduled successfully at $scheduledDate.');
      } catch (e) {
        debugPrint('❌ Error in zonedSchedule for single reminder: $e');
        // Fallback to allowWhileIdle if exact scheduling failed
        if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
          debugPrint('🔄 Attempting fallback to inexact scheduling...');
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
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: task.id.toString(),
          );
          debugPrint('✅ Single reminder scheduled successfully with fallback.');
        } else {
          rethrow;
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Error scheduling notification: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> cancelTaskReminder(int taskId) async {
    try {
      debugPrint('🔕 Cancelling reminders for task ID: $taskId');
      
      // Create a list of all possible notification IDs to cancel
      final List<int> idsToCancel = [
        taskId, // Primary ID
      ];
      
      // Old recurring range (backward compatibility)
      for (int i = 0; i < 7; i++) {
        idsToCancel.add(taskId * 100 + i);
      }
      
      // Range from previous failed update
      for (int i = 0; i < 10; i++) {
        idsToCancel.add(1000000000 + (taskId * 10) + i);
      }
      
      // New recurring range
      for (int i = 0; i < 10; i++) {
        idsToCancel.add(100000 + (taskId * 10) + i);
      }
      
      // Cancel all in parallel for performance
      await Future.wait(idsToCancel.map((id) => _notificationsPlugin.cancel(id)));
      
      debugPrint('✅ All reminders for task ID $taskId cancelled.');
    } catch (e) {
      debugPrint('⚠️ Error cancelling reminders: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
