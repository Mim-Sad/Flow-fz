import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// پروایدری که زمان فعلی را فراهم می‌کند و هر دقیقه آپدیت می‌شود.
/// این باعث می‌شود ویجت‌هایی که به زمان وابسته هستند (مثل داشبورد) 
/// به‌صورت ریل‌تایم با تغییر زمان بروزرسانی شوند.
final currentTimeProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  
  // ارسال زمان فعلی در ابتدا
  controller.add(DateTime.now());
  
  // تنظیم تایمر برای آپدیت هر دقیقه
  final timer = Timer.periodic(const Duration(minutes: 1), (timer) {
    controller.add(DateTime.now());
  });
  
  // تمیزکاری تایمر در صورت اتمام پرووایدر
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  
  return controller.stream;
});

/// پروایدری که فقط تاریخ امروز (بدون ساعت) را فراهم می‌کند.
final todayDateProvider = Provider<DateTime>((ref) {
  final now = ref.watch(currentTimeProvider).value ?? DateTime.now();
  return DateTime(now.year, now.month, now.day);
});
