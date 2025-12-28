import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import 'database_service.dart';

/// سرویس برای به‌روزرسانی خودکار تسک‌های در جریان به ناموفق در نیمه‌شب
class MidnightTaskUpdater {
  static final MidnightTaskUpdater _instance = MidnightTaskUpdater._internal();
  factory MidnightTaskUpdater() => _instance;
  MidnightTaskUpdater._internal();

  Timer? _midnightTimer;
  DatabaseService? _dbService;
  VoidCallback? _onUpdateCallback;
  static const String _lastCheckKey = 'midnight_task_updater_last_check';

  /// راه‌اندازی سرویس
  Future<void> initialize(DatabaseService dbService, {VoidCallback? onUpdate}) async {
    _dbService = dbService;
    _onUpdateCallback = onUpdate;
    
    // بررسی در هنگام راه‌اندازی (اگر از آخرین بررسی نیمه‌شب گذشته باشد)
    await _checkAndUpdateIfNeeded();
    
    // تنظیم Timer برای اجرای روزانه در نیمه‌شب
    _scheduleMidnightUpdate();
  }

  /// برنامه‌ریزی به‌روزرسانی در نیمه‌شب
  void _scheduleMidnightUpdate() {
    // لغو Timer قبلی اگر وجود داشته باشد
    _midnightTimer?.cancel();

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final midnight = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0, 0);
    
    final durationUntilMidnight = midnight.difference(now);
    
    debugPrint('⏰ MidnightTaskUpdater: تنظیم Timer برای ${durationUntilMidnight.inHours} ساعت و ${durationUntilMidnight.inMinutes % 60} دقیقه دیگر');

    _midnightTimer = Timer(durationUntilMidnight, () {
      _performMidnightUpdate();
      // برنامه‌ریزی مجدد برای شب بعد
      _scheduleMidnightUpdate();
    });
  }

  /// بررسی و به‌روزرسانی در صورت نیاز
  Future<void> _checkAndUpdateIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckStr = prefs.getString(_lastCheckKey);
      
      if (lastCheckStr != null) {
        final lastCheck = DateTime.parse(lastCheckStr);
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        final yesterdayMidnight = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
        
        // اگر آخرین بررسی قبل از نیمه‌شب دیروز بوده، باید به‌روزرسانی کنیم
        if (lastCheck.isBefore(yesterdayMidnight)) {
          debugPrint('🔄 MidnightTaskUpdater: آخرین بررسی قبل از نیمه‌شب دیروز بوده، در حال به‌روزرسانی...');
          await _updatePendingTasksToFailed(yesterday);
        }
      } else {
        // اولین بار است که اجرا می‌شود
        debugPrint('🔄 MidnightTaskUpdater: اولین اجرا، بررسی تسک‌های دیروز...');
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await _updatePendingTasksToFailed(yesterday);
      }
      
      // ذخیره زمان آخرین بررسی
      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('❌ MidnightTaskUpdater: خطا در بررسی: $e');
    }
  }

  /// اجرای به‌روزرسانی در نیمه‌شب
  Future<void> _performMidnightUpdate() async {
    debugPrint('🌙 MidnightTaskUpdater: اجرای به‌روزرسانی نیمه‌شب...');
    
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await _updatePendingTasksToFailed(yesterday);
      
      // ذخیره زمان آخرین بررسی
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
      
      debugPrint('✅ MidnightTaskUpdater: به‌روزرسانی نیمه‌شب با موفقیت انجام شد');
    } catch (e) {
      debugPrint('❌ MidnightTaskUpdater: خطا در به‌روزرسانی نیمه‌شب: $e');
    }
  }

  /// به‌روزرسانی تسک‌های در جریان (pending) به ناموفق (failed) برای تاریخ مشخص
  Future<void> _updatePendingTasksToFailed(DateTime targetDate) async {
    if (_dbService == null) {
      debugPrint('❌ MidnightTaskUpdater: DatabaseService تنظیم نشده است');
      return;
    }

    try {
      // دریافت تمام تسک‌ها (شامل حذف شده‌ها برای بررسی کامل)
      final allTasks = await _dbService!.getAllTasks(includeDeleted: true);
      
      final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final dateKey = _getDateKey(targetDateOnly);
      
      int updatedCount = 0;
      
      for (final task in allTasks) {
        // فقط تسک‌های فعال در تاریخ هدف را بررسی می‌کنیم
        if (!task.isActiveOnDate(targetDateOnly)) {
          continue;
        }
        
        // بررسی وضعیت تسک در تاریخ هدف
        final status = task.getStatusForDate(targetDateOnly);
        
        // اگر وضعیت pending است، آن را به failed تبدیل می‌کنیم
        if (status == TaskStatus.pending) {
          await _dbService!.updateTaskStatus(
            task.id!,
            TaskStatus.failed,
            dateKey: dateKey,
          );
          updatedCount++;
          
          debugPrint('📝 MidnightTaskUpdater: تسک "${task.title}" (ID: ${task.id}) برای تاریخ $dateKey به ناموفق تبدیل شد');
        }
      }
      
      debugPrint('✅ MidnightTaskUpdater: $updatedCount تسک برای تاریخ $dateKey به‌روزرسانی شد');
      
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

