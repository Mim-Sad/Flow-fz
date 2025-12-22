import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:hugeicons/hugeicons.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';

class PostponeDialog extends ConsumerWidget {
  final Task task;
  final DateTime? targetDate;

  const PostponeDialog({
    super.key,
    required this.task,
    this.targetDate,
  });

  static Future<void> show(BuildContext context, WidgetRef ref, Task task, {DateTime? targetDate}) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => PostponeDialog(task: task, targetDate: targetDate),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deferCount = task.deferCount;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.primaryContainer,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      title: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar01,
              color: colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'تعویق تسک',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: colorScheme.onSurface,
            ),
            textDirection: TextDirection.rtl,
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'این تسک تاکنون $deferCount بار به تعویق افتاده است.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 16),
          Text(
            'آیا مایلید زمان جدیدی برای انجام این تسک تنظیم کنید؟ (یک نسخه جدید ایجاد خواهد شد)',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () async {
                  // 1. Mark current as deferred and update its defer count
                  final updatedMetadata = Map<String, dynamic>.from(task.metadata);
                  updatedMetadata['deferCount'] = (updatedMetadata['deferCount'] ?? 0) + 1;
                  final updatedTask = task.copyWith(
                    status: TaskStatus.deferred,
                    metadata: updatedMetadata,
                  );

                  if (targetDate != null) {
                    // If it's a recurring instance, we update via completion
                    await ref.read(tasksProvider.notifier).updateStatus(
                      task.id!,
                      TaskStatus.deferred,
                      date: targetDate,
                    );
                    // Note: completions don't store metadata yet, but the task event will log the change
                  } else {
                    await ref.read(tasksProvider.notifier).updateTask(updatedTask);
                  }
                  
                  if (context.mounted) Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'فقط تعویق',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  final initialDate = targetDate ?? task.dueDate;
                  final Jalali? picked = await showPersianDatePicker(
                    context: context,
                    initialDate: Jalali.fromDateTime(initialDate.add(const Duration(days: 1))),
                    firstDate: Jalali.fromDateTime(DateTime.now().subtract(const Duration(days: 365))),
                    lastDate: Jalali.fromDateTime(DateTime.now().add(const Duration(days: 365))),
                    helpText: 'انتخاب تاریخ جدید',
                  );

                  if (picked != null && context.mounted) {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(initialDate),
                    );

                    if (pickedTime != null && context.mounted) {
                      final dt = picked.toDateTime();
                      final newDate = DateTime(dt.year, dt.month, dt.day, pickedTime.hour, pickedTime.minute);

                      // 1. Update status and metadata of current task to deferred
                      final currentMetadata = Map<String, dynamic>.from(task.metadata);
                      currentMetadata['deferCount'] = (currentMetadata['deferCount'] ?? 0) + 1;
                      
                      if (targetDate != null) {
                        await ref.read(tasksProvider.notifier).updateStatus(
                          task.id!,
                          TaskStatus.deferred,
                          date: targetDate,
                        );
                      } else {
                        final updatedCurrentTask = task.copyWith(
                          status: TaskStatus.deferred,
                          metadata: currentMetadata,
                        );
                        await ref.read(tasksProvider.notifier).updateTask(updatedCurrentTask);
                      }

                      // 2. Create a new task copy with the same incremented deferCount
                      final newTask = task.copyWith(
                        id: null,
                        rootId: task.rootId ?? task.id,
                        dueDate: newDate,
                        status: TaskStatus.pending,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                        metadata: currentMetadata,
                        recurrence: null, // Defer creates a one-off instance
                      );
                      
                      await ref.read(tasksProvider.notifier).addTask(newTask);
                      
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('انتخاب تاریخ'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
