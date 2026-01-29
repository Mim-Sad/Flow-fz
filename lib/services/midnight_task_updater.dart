import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import 'database_service.dart';

/// سرویس برای به‌روزرسانی خودکار تسک‌های در جریان به ناموفق در ساعت مشخص شده
class MidnightTaskUpdater {
  static final MidnightTaskUpdater _instance = MidnightTaskUpdater._internal();
  factory MidnightTaskUpdater() => _instance;
  MidnightTaskUpdater._internal();

  Timer? _midnightTimer;
  DatabaseService? _dbService;
  VoidCallback? _onUpdateCallback;
  static const String _lastCheckKey = 'midnight_task_updater_last_check';

  /// راه‌اندازی سرویس
  Future<void> initialize(
    DatabaseService dbService, {
    VoidCallback? onUpdate,
  }) async {
    _dbService = dbService;
    if (onUpdate != null) {
      _onUpdateCallback = onUpdate;
    }

    // بررسی در هنگام راه‌اندازی (اگر از آخرین موعد به‌روزرسانی گذشته باشد)
    await _checkAndUpdateIfNeeded();

    // تنظیم Timer برای اجرای روزانه
    await _scheduleMidnightUpdate();
  }

  /// دریافت زمان تنظیم شده برای به‌روزرسانی (ساعت و دقیقه)
  Future<TimeOfDay> _getUpdateTime() async {
    if (_dbService == null) return const TimeOfDay(hour: 4, minute: 0);
    try {
      // ابتدا سعی می‌کنیم فرمت جدید (ساعت:دقیقه) را بخوانیم
      final timeSetting = await _dbService!.getSetting(DatabaseService.settingMidnightUpdateTime);
      if (timeSetting != null && timeSetting.contains(':')) {
        final parts = timeSetting.split(':');
        return TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 4,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }

      // اگر نبود، سراغ تنظیمات قدیمی (فقط ساعت) می‌رویم
      final hourSetting = await _dbService!.getSetting(DatabaseService.settingMidnightUpdateHour);
      return TimeOfDay(hour: int.tryParse(hourSetting ?? '4') ?? 4, minute: 0);
    } catch (e) {
      debugPrint('❌ MidnightTaskUpdater: خطا در دریافت تنظیمات زمان: $e');
      return const TimeOfDay(hour: 4, minute: 0);
    }
  }

  /// برنامه‌ریزی به‌روزرسانی در ساعت و دقیقه مشخص شده
  Future<void> _scheduleMidnightUpdate() async {
    // لغو Timer قبلی اگر وجود داشته باشد
    _midnightTimer?.cancel();

    final updateTime = await _getUpdateTime();
    final now = DateTime.now();
    
    // زمان به‌روزرسانی بعدی
    DateTime nextUpdate = DateTime(now.year, now.month, now.day, updateTime.hour, updateTime.minute);
    
    // اگر از زمان به‌روزرسانی امروز گذشته است، برای فردا برنامه‌ریزی کن
    if (now.isAfter(nextUpdate) || now.isAtSameMomentAs(nextUpdate)) {
      nextUpdate = nextUpdate.add(const Duration(days: 1));
    }

    final durationUntilUpdate = nextUpdate.difference(now);

    debugPrint(
      '⏰ MidnightTaskUpdater: تنظیم Timer برای ساعت ${updateTime.hour.toString().padLeft(2, '0')}:${updateTime.minute.toString().padLeft(2, '0')} (${durationUntilUpdate.inHours} ساعت و ${durationUntilUpdate.inMinutes % 60} دقیقه دیگر)',
    );

    _midnightTimer = Timer(durationUntilUpdate, () async {
      await _performMidnightUpdate();
      // برنامه‌ریزی مجدد برای روز بعد
      _scheduleMidnightUpdate();
    });
  }

  /// بررسی و به‌روزرسانی در صورت نیاز (مثلاً اگر برنامه در زمان مقرر بسته بوده)
  Future<void> _checkAndUpdateIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckStr = prefs.getString(_lastCheckKey);
      final updateTime = await _getUpdateTime();
      final now = DateTime.now();

      // آخرین زمانِ به‌روزرسانیِ برنامه‌ریزی‌شده که باید تا الان اجرا می‌شده
      DateTime lastScheduledUpdate = DateTime(now.year, now.month, now.day, updateTime.hour, updateTime.minute);
      
      if (now.isBefore(lastScheduledUpdate)) {
        lastScheduledUpdate = lastScheduledUpdate.subtract(const Duration(days: 1));
      }

      if (lastCheckStr != null) {
        final lastCheck = DateTime.parse(lastCheckStr);

        // اگر آخرین بررسی قبل از آخرین زمانِ به‌روزرسانیِ برنامه‌ریزی‌شده بوده
        if (lastCheck.isBefore(lastScheduledUpdate)) {
          debugPrint(
            '🔄 MidnightTaskUpdater: آخرین بررسی قبل از موعد بوده ($lastCheck < $lastScheduledUpdate). بررسی روزهای از قلم افتاده...',
          );

          // زمان مبدا برای بررسی روزها: روزِ آخرین بررسی
          DateTime cursorDate = DateTime(lastCheck.year, lastCheck.month, lastCheck.day);
          
          // تا دیروزِ آخرین به‌روزرسانی برنامه‌ریزی شده
          final yesterdayOfLastScheduled = lastScheduledUpdate.subtract(const Duration(days: 1));
          final yesterdayOfLastScheduledOnlyDate = DateTime(yesterdayOfLastScheduled.year, yesterdayOfLastScheduled.month, yesterdayOfLastScheduled.day);

          while (!cursorDate.isAfter(yesterdayOfLastScheduledOnlyDate)) {
             debugPrint(
              '🔄 MidnightTaskUpdater: در حال بررسی برای تاریخ ${cursorDate.toString().split(' ')[0]}...',
            );
            await _updatePendingTasksToFailed(cursorDate);
            cursorDate = cursorDate.add(const Duration(days: 1));
          }
        }
      } else {
        // اولین بار است که اجرا می‌شود
        debugPrint(
          '🔄 MidnightTaskUpdater: اولین اجرا، بررسی تسک‌های قبل از آخرین موعد...',
        );
        final yesterdayOfLastScheduled = lastScheduledUpdate.subtract(const Duration(days: 1));
        await _updatePendingTasksToFailed(yesterdayOfLastScheduled);
      }

      // ذخیره زمان آخرین بررسی (الان)
      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('❌ MidnightTaskUpdater: خطا در بررسی: $e');
    }
  }

  /// اجرای به‌روزرسانی در ساعت مقرر
  Future<void> _performMidnightUpdate() async {
    final updateTime = await _getUpdateTime();
    debugPrint(
      '🌙 MidnightTaskUpdater: اجرای به‌روزرسانی خودکار (ساعت ${updateTime.hour.toString().padLeft(2, '0')}:${updateTime.minute.toString().padLeft(2, '0')})...',
    );

    try {
      // تسک‌های دیروز را به ناموفق تبدیل می‌کنیم
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await _updatePendingTasksToFailed(yesterday);

      // ذخیره زمان آخرین بررسی
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());

      debugPrint(
        '✅ MidnightTaskUpdater: به‌روزرسانی خودکار با موفقیت انجام شد',
      );
    } catch (e) {
      debugPrint('❌ MidnightTaskUpdater: خطا در به‌روزرسانی خودکار: $e');
    }
  }

  /// به‌روزرسانی تسک‌های در جریان (pending) به ناموفق (failed) برای تاریخ مشخص
  Future<void> _updatePendingTasksToFailed(DateTime targetDate) async {
    if (_dbService == null) {
      debugPrint('❌ MidnightTaskUpdater: DatabaseService تنظیم نشده است');
      return;
    }

    try {
      // دریافت تمام تسک‌های فعال (غیر حذفی)
      final allTasks = await _dbService!.getAllTasks(includeDeleted: false);

      final targetDateOnly = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );
      final dateKey = _getDateKey(targetDateOnly);

      int updatedCount = 0;

      for (final task in allTasks) {
        // نادیده گرفتن تسک‌های حذف شده (احتیاط بیشتر)
        if (task.isDeleted) {
          continue;
        }

        // فقط تسک‌های فعال در تاریخ هدف را بررسی می‌کنیم
        if (!task.isActiveOnDate(targetDateOnly)) {
          continue;
        }

        // بررسی وضعیت تسک در تاریخ هدف
        final status = task.getStatusForDate(targetDateOnly);

        // فقط تسک‌های "در جریان" (pending) را به "ناموفق" (failed) تبدیل می‌کنیم
        // بقیه وضعیت‌ها مثل "تعویق شده" یا "لغو شده" نباید تغییر کنند
        if (status == TaskStatus.pending) {
          // به‌روزرسانی متادیتا برای ثبت لاگ تغییر وضعیت خودکار
          final Map<String, dynamic> newMetadata = Map<String, dynamic>.from(
            task.metadata,
          );
          List<dynamic> logs = [];
          if (newMetadata['autoFailedLog'] != null &&
              newMetadata['autoFailedLog'] is List) {
            logs = List.from(newMetadata['autoFailedLog']);
          }

          logs.add({
            'targetDate': dateKey,
            'failedAt': DateTime.now().toIso8601String(),
            'reason': 'midnight_update',
          });

          newMetadata['autoFailedLog'] = logs;

          await _dbService!.updateTaskStatus(
            task.id!,
            TaskStatus.failed,
            dateKey: dateKey,
            metadata: newMetadata,
          );
          updatedCount++;

          debugPrint(
            '📝 MidnightTaskUpdater: تسک "${task.title}" (ID: ${task.id}) برای تاریخ $dateKey به ناموفق تبدیل شد',
          );
        }
      }

      debugPrint(
        '✅ MidnightTaskUpdater: $updatedCount تسک برای تاریخ $dateKey به‌روزرسانی شد',
      );

      // فراخوانی callback برای به‌روزرسانی UI
      if (updatedCount > 0 && _onUpdateCallback != null) {
        _onUpdateCallback!();
      }
    } catch (e) {
      debugPrint('❌ MidnightTaskUpdater: خطا در به‌روزرسانی تسک‌ها: $e');
      rethrow;
    }
  }

  /// تولید کلید تاریخ به فرمت YYYY-MM-DD
  String _getDateKey(DateTime date) {
    final d = date.toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// توقف سرویس
  void dispose() {
    _midnightTimer?.cancel();
    _midnightTimer = null;
    debugPrint('🛑 MidnightTaskUpdater: سرویس متوقف شد');
  }

  /// اجرای دستی به‌روزرسانی (برای تست)
  Future<void> forceUpdate() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await _updatePendingTasksToFailed(yesterday);
  }
}
