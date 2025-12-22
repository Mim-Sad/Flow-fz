import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../screens/add_task_screen.dart';

class TaskStatusPickerSheet extends ConsumerWidget {
  final Task task;
  final DateTime? recurringDate; // Specific date for recurring task instance

  const TaskStatusPickerSheet({
    super.key,
    required this.task,
    this.recurringDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'تغییر وضعیت تسک',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 16),
                _buildStatusAction(
                  context,
                  ref,
                  TaskStatus.success,
                  'انجام شده',
                  HugeIcons.strokeRoundedCheckmarkCircle03,
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildStatusAction(
                  context,
                  ref,
                  TaskStatus.failed,
                  'انجام نشده',
                  HugeIcons.strokeRoundedCancelCircle,
                  Colors.red,
                ),
                const SizedBox(width: 8),
                _buildStatusAction(
                  context,
                  ref,
                  TaskStatus.cancelled,
                  'لغو شده',
                  HugeIcons.strokeRoundedMinusSignCircle,
                  Colors.grey,
                ),
                const SizedBox(width: 8),
                _buildStatusAction(
                  context,
                  ref,
                  TaskStatus.deferred,
                  'تعویق شده',
                  HugeIcons.strokeRoundedClock01,
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildStatusAction(
                  context,
                  ref,
                  TaskStatus.pending,
                  'در جریان',
                  HugeIcons.strokeRoundedCircle,
                  Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusAction(
    BuildContext context,
    WidgetRef ref,
    TaskStatus status,
    String label,
    dynamic icon,
    Color color,
  ) {
    // Determine current status (check specific date if recurring)
    TaskStatus currentStatus;
    if (recurringDate != null &&
        task.recurrence != null &&
        task.recurrence!.type != RecurrenceType.none) {
      currentStatus = ref
          .read(tasksProvider.notifier)
          .getStatusForDate(task.id!, recurringDate!);
    } else {
      currentStatus = task.status;
    }

    final isSelected = currentStatus == status;

    return InkWell(
      onTap: () async {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);

        if (status == TaskStatus.deferred) {
          final initialDate = recurringDate ?? task.dueDate;
          
          final Jalali? picked = await showPersianDatePicker(
            context: context,
            initialDate: Jalali.fromDateTime(
              initialDate.add(const Duration(days: 1)),
            ),
            firstDate: Jalali.fromDateTime(
              DateTime.now().subtract(const Duration(days: 365)),
            ),
            lastDate: Jalali.fromDateTime(
              DateTime.now().add(const Duration(days: 365)),
            ),
            helpText: 'انتخاب تاریخ تعویق',
          );

          if (picked != null) {
            if (!context.mounted) return;
            final TimeOfDay? pickedTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(initialDate),
            );

            if (pickedTime != null) {
               final dt = picked.toDateTime();
               final newDate = DateTime(dt.year, dt.month, dt.day, pickedTime.hour, pickedTime.minute);

              if (recurringDate != null &&
                  task.recurrence != null &&
                  task.recurrence!.type != RecurrenceType.none) {
                ref.read(tasksProvider.notifier).updateStatus(
                      task.id!,
                      TaskStatus.deferred,
                      date: recurringDate,
                    );
              } else {
                await ref
                    .read(tasksProvider.notifier)
                    .updateStatus(task.id!, TaskStatus.deferred);
              }

              // Create new task
              final newTask = Task(
                title: task.title,
                description: task.description,
                dueDate: newDate,
                status: TaskStatus.pending,
                priority: task.priority,
                category: task.category,
                categories: task.categories,
                taskEmoji: task.taskEmoji,
                attachments: task.attachments,
                recurrence: null, // One-off copy
              );
              
              await ref.read(tasksProvider.notifier).addTask(newTask);
            }
          }
        } else {
          // Standard Status Update
          if (recurringDate != null &&
              task.recurrence != null &&
              task.recurrence!.type != RecurrenceType.none) {
            ref
                .read(tasksProvider.notifier)
                .updateStatus(task.id!, status, date: recurringDate);
          } else {
            ref.read(tasksProvider.notifier).updateStatus(task.id!, status);
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? color
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            HugeIcon(
              icon: icon,
              size: 28,
              color: isSelected
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? color
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskOptionsSheet extends ConsumerWidget {
  final Task task;

  const TaskOptionsSheet({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'تنظیمات تسک',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const HugeIcon(
              icon: HugeIcons.strokeRoundedEdit02,
              size: 24,
            ),
            title: const Text('ویرایش'),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (context) => AddTaskScreen(task: task),
              );
            },
          ),
          ListTile(
            leading: const HugeIcon(
              icon: HugeIcons.strokeRoundedTask01,
              size: 24,
            ),
            title: const Text('تغییر وضعیت'),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                builder: (context) => TaskStatusPickerSheet(task: task),
              );
            },
          ),
          ListTile(
            leading: const HugeIcon(
              icon: HugeIcons.strokeRoundedDelete02,
              size: 24,
              color: Colors.red,
            ),
            title: const Text('حذف', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              ref.read(tasksProvider.notifier).deleteTask(task.id!);
            },
          ),
        ],
      ),
    );
  }
}
