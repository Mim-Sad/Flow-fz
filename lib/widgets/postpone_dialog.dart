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
    final isRecurring = task.recurrence != null && task.recurrence!.type != RecurrenceType.none;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
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
          if (!isRecurring) ...[
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
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: isRecurring 
                ? ElevatedButton(
                    onPressed: () async {
                      // 1. Mark current as deferred and update its defer count
                      final updatedMetadata = Map<String, dynamic>.from(task.metadata);
                      updatedMetadata['deferCount'] = (updatedMetadata['deferCount'] ?? 0) + 1;
                      updatedMetadata['lastDeferredAt'] = DateTime.now().toIso8601String();
                      
                      if (targetDate != null) {
                        await ref.read(tasksProvider.notifier).updateStatus(
                          task.id!,
                          TaskStatus.deferred,
                          date: targetDate,
                          metadata: updatedMetadata,
                        );
                      } else {
                        final updatedHistory = Map<String, int>.from(task.statusHistory);
                        final dateStr = getDateKey(task.dueDate);
                        updatedHistory[dateStr] = TaskStatus.deferred.index;

                        final updatedTask = task.copyWith(
                          statusHistory: updatedHistory,
                          metadata: updatedMetadata,
                        );
                        await ref.read(tasksProvider.notifier).updateTask(updatedTask);
                      }
                      
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('تایید تعویق'),
                  )
                : TextButton(
                    onPressed: () async {
                      // 1. Mark current as deferred and update its defer count
                      final updatedMetadata = Map<String, dynamic>.from(task.metadata);
                      updatedMetadata['deferCount'] = (updatedMetadata['deferCount'] ?? 0) + 1;
                      updatedMetadata['lastDeferredAt'] = DateTime.now().toIso8601String();
                      
                      if (targetDate != null) {
                        await ref.read(tasksProvider.notifier).updateStatus(
                          task.id!,
                          TaskStatus.deferred,
                          date: targetDate,
                          metadata: updatedMetadata,
                        );
                      } else {
                        final updatedHistory = Map<String, int>.from(task.statusHistory);
                        final dateStr = getDateKey(task.dueDate);
                        updatedHistory[dateStr] = TaskStatus.deferred.index;

                        final updatedTask = task.copyWith(
                          statusHistory: updatedHistory,
                          metadata: updatedMetadata,
                        );
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
            if (!isRecurring) ...[
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
                      bool isNoTimeSelected = false;
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(initialDate),
                        builder: (context, child) => Directionality(
                          textDirection: TextDirection.rtl,
                          child: Stack(
                            children: [
                              child!,
                              Positioned(
                                bottom: 40, // Moved higher to avoid overlapping with system buttons
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      isNoTimeSelected = true;
                                      Navigator.pop(context);
                                    },
                                    icon: HugeIcon(
                                      icon: HugeIcons.strokeRoundedClock01,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'بدون ساعت مشخص',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25), // More rounded/pill shape
                                        side: BorderSide(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );

                      // If user cancelled the time picker and didn't click "No specific time"
                      if (pickedTime == null && !isNoTimeSelected) return;

                      final dt = picked.toDateTime();
                      final DateTime newDate;
                      final bool hasTime;

                      if (isNoTimeSelected) {
                        newDate = DateTime(dt.year, dt.month, dt.day);
                        hasTime = false;
                      } else {
                        newDate = DateTime(dt.year, dt.month, dt.day, pickedTime!.hour, pickedTime.minute);
                        hasTime = true;
                      }

                      if (context.mounted) {
                        // 1. Update status and metadata of current task to deferred
                        final currentMetadata = Map<String, dynamic>.from(task.metadata);
                        currentMetadata['deferCount'] = (currentMetadata['deferCount'] ?? 0) + 1;
                        currentMetadata['lastDeferredAt'] = DateTime.now().toIso8601String();
                        
                        if (targetDate != null) {
                          await ref.read(tasksProvider.notifier).updateStatus(
                            task.id!,
                            TaskStatus.deferred,
                            date: targetDate,
                            metadata: currentMetadata,
                          );
                        } else {
                          final updatedHistory = Map<String, int>.from(task.statusHistory);
                          final dateStr = getDateKey(task.dueDate);
                          updatedHistory[dateStr] = TaskStatus.deferred.index;

                          final updatedCurrentTask = task.copyWith(
                            statusHistory: updatedHistory,
                            metadata: currentMetadata,
                          );
                          await ref.read(tasksProvider.notifier).updateTask(updatedCurrentTask);
                        }

                        // 2. Create a new task copy with the same incremented deferCount
                        final newTaskMetadata = Map<String, dynamic>.from(currentMetadata);
                        newTaskMetadata['hasTime'] = hasTime;

                        final newTask = Task(
                          title: task.title,
                          description: task.description,
                          dueDate: newDate,
                          endTime: hasTime && task.endTime != null 
                              ? DateTime(newDate.year, newDate.month, newDate.day, task.endTime!.hour, task.endTime!.minute)
                              : null,
                          priority: task.priority,
                          categories: List.from(task.categories),
                          tags: List.from(task.tags),
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                          position: task.position,
                          taskEmoji: task.taskEmoji,
                          attachments: List.from(task.attachments),
                          recurrence: null, // One-off postponement
                          metadata: newTaskMetadata,
                          statusHistory: {
                            getDateKey(newDate): TaskStatus.pending.index,
                          },
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
          ],
        ),
      ],
    );
  }
}
