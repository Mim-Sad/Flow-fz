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
          Row(
            children: [
              Expanded(
                child: _buildStatusAction(
                  context,
                  ref,
                  TaskStatus.success,
                  'انجام شده',
                  HugeIcons.strokeRoundedCheckmarkCircle03,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusAction(
                  context,
                  ref,
                  TaskStatus.pending,
                  'در جریان',
                  HugeIcons.strokeRoundedCircle,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusAction(
                  context,
                  ref,
                  TaskStatus.failed,
                  'انجام نشده',
                  HugeIcons.strokeRoundedCancelCircle,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatusAction(
                  context,
                  ref,
                  TaskStatus.cancelled,
                  'لغو شده',
                  HugeIcons.strokeRoundedMinusSignCircle,
                  Colors.grey,
                  horizontal: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusAction(
                  context,
                  ref,
                  TaskStatus.deferred,
                  'تعویق شده',
                  HugeIcons.strokeRoundedClock01,
                  Colors.orange,
                  horizontal: true,
                ),
              ),
            ],
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
    Color color, {
    bool horizontal = false,
  }) {
    // Determine the target date for this status change
    // If recurringDate is provided (e.g., from Planning screen), use it.
    // Otherwise, if it's a recurring task (e.g., from Home screen), use task.dueDate as the target date.
    final targetDate = recurringDate ??
        (task.recurrence != null && task.recurrence!.type != RecurrenceType.none
            ? task.dueDate
            : null);

    // Determine current status (check specific date if it's a date-specific instance)
    TaskStatus currentStatus;
    if (targetDate != null) {
      currentStatus = ref
          .read(tasksProvider.notifier)
          .getStatusForDate(task.id!, targetDate);
    } else {
      currentStatus = task.status;
    }

    final isSelected = currentStatus == status;

    return InkWell(
      onTap: () async {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);

        if (status == TaskStatus.deferred) {
          final initialDate = targetDate ?? task.dueDate;
          
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
              builder: (context, child) {
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                );
              },
            );

            if (pickedTime != null) {
               final dt = picked.toDateTime();
               final newDate = DateTime(dt.year, dt.month, dt.day, pickedTime.hour, pickedTime.minute);

              if (targetDate != null) {
                ref.read(tasksProvider.notifier).updateStatus(
                      task.id!,
                      TaskStatus.deferred,
                      date: targetDate,
                    );
              } else {
                await ref
                    .read(tasksProvider.notifier)
                    .updateStatus(task.id!, TaskStatus.deferred);
              }

              // Create new task
              final newTask = Task(
                rootId: task.rootId ?? task.id,
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
          if (targetDate != null) {
            ref
                .read(tasksProvider.notifier)
                .updateStatus(task.id!, status, date: targetDate);
          } else {
            ref.read(tasksProvider.notifier).updateStatus(task.id!, status);
          }
        }
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? color
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: horizontal
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: icon,
                    size: 20,
                    color: isSelected
                        ? color
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? color
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
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
                      fontSize: 11,
                      color: isSelected
                          ? color
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
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
