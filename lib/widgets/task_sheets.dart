import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/task.dart';
import '../models/category_data.dart';
import '../providers/task_provider.dart';
import '../providers/category_provider.dart';
import '../screens/add_task_screen.dart';
import 'postpone_dialog.dart';

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

        if (status == TaskStatus.deferred) {
          // Close the current sheet first
          Navigator.pop(context);
          
          // Show the new postponement dialog
          PostponeDialog.show(context, ref, task, targetDate: targetDate);
        } else {
          // Standard Status Update
          if (targetDate != null) {
            ref.read(tasksProvider.notifier).updateStatus(task.id!, status, date: targetDate);
          } else {
            ref.read(tasksProvider.notifier).updateStatus(task.id!, status);
          }
          if (context.mounted) Navigator.pop(context);
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
  final DateTime? date;

  const TaskOptionsSheet({super.key, required this.task, this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final allCategories = ref.watch(categoryProvider).valueOrNull ?? [];
    
    // Helper to get category data
    final taskCategories = task.categories.isNotEmpty 
        ? task.categories 
        : (task.category != null ? [task.category!] : <String>[]);
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Task Info Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          task.taskEmoji ?? '🫥',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          textDirection: TextDirection.rtl,
                          children: [
                            Text(
                              task.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textDirection: TextDirection.rtl,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            _buildPriorityBadge(context, task.priority),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Date and Time Info
                  const SizedBox(height: 16),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 16),
                  
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedCalendar03,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(task.dueDate),
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      ),
                      if (task.metadata['hasTime'] ?? true) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedClock01,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _toPersianDigit(_formatTime(task.dueDate)),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Recurrence Info
                  if (task.recurrence != null && task.recurrence!.type != RecurrenceType.none) ...[
                    const SizedBox(height: 12),
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        HugeIcon(
                           icon: HugeIcons.strokeRoundedRefresh,
                           size: 18,
                           color: colorScheme.secondary,
                         ),
                        const SizedBox(width: 8),
                        Text(
                          _getRecurrenceText(task.recurrence!),
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ],

                  if (task.description != null && task.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1, thickness: 0.5),
                    const SizedBox(height: 16),
                    Text(
                      task.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                  
                  if (taskCategories.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1, thickness: 0.5),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      textDirection: TextDirection.rtl,
                      children: taskCategories.map((catId) {
                        final catData = allCategories.firstWhere(
                          (c) => c.id == catId,
                          orElse: () => defaultCategories.firstWhere((dc) => dc.id == catId, orElse: () => defaultCategories.first),
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: catData.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: catData.color.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            textDirection: TextDirection.rtl,
                            children: [
                              Lottie.asset(catData.emoji, width: 22, height: 22),
                              const SizedBox(width: 8),
                              Text(
                                catData.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: catData.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Actions List
            Column(
              children: [
                _buildActionTile(
                  context,
                  icon: HugeIcons.strokeRoundedEdit02,
                  label: 'ویرایش تسک',
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AddTaskScreen(
                        task: task,
                        initialDate: date,
                      ),
                    );
                  },
                ),
                _buildActionTile(
                  context,
                  icon: HugeIcons.strokeRoundedCopy01,
                  label: 'تکثیر تسک',
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AddTaskScreen(
                        task: task.duplicate(),
                        initialDate: date,
                      ),
                    );
                  },
                ),
                _buildActionTile(
                  context,
                  icon: HugeIcons.strokeRoundedTask01,
                  label: 'تغییر وضعیت',
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                      ),
                      builder: (context) => TaskStatusPickerSheet(
                        task: task,
                        recurringDate: date,
                      ),
                    );
                  },
                ),
                _buildActionTile(
                  context,
                  icon: HugeIcons.strokeRoundedDelete02,
                  label: 'حذف تسک',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(tasksProvider.notifier).deleteTask(task.id!);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _toPersianDigit(String input) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    String result = input;
    for (int i = 0; i < englishDigits.length; i++) {
      result = result.replaceAll(englishDigits[i], persianDigits[i]);
    }
    return result;
  }

  String _formatDate(DateTime date) {
    final jDate = Jalali.fromDateTime(date);
    final now = Jalali.now();
    
    if (jDate.year == now.year && jDate.month == now.month && jDate.day == now.day) {
      return 'امروز';
    }
    
    final tomorrow = now.addDays(1);
    if (jDate.year == tomorrow.year && jDate.month == tomorrow.month && jDate.day == tomorrow.day) {
      return 'فردا';
    }

    return '${jDate.year}/${jDate.month.toString().padLeft(2, '0')}/${jDate.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getRecurrenceText(RecurrenceConfig recurrence) {
    String typeText = '';
    switch (recurrence.type) {
      case RecurrenceType.hourly: typeText = 'ساعتی'; break;
      case RecurrenceType.daily: typeText = 'روزانه'; break;
      case RecurrenceType.weekly: typeText = 'هفتگی'; break;
      case RecurrenceType.monthly: typeText = 'ماهانه'; break;
      case RecurrenceType.yearly: typeText = 'سالانه'; break;
      case RecurrenceType.custom: typeText = 'هر ${recurrence.interval} روز'; break;
      case RecurrenceType.specificDays: 
        final days = recurrence.daysOfWeek?.map((d) => _getDayName(d)).join('، ') ?? '';
        typeText = 'روزهای $days'; 
        break;
      default: typeText = 'سفارشی';
    }
    
    if (recurrence.endDate != null) {
      final jEndDate = Jalali.fromDateTime(recurrence.endDate!);
      typeText += ' (تا ${jEndDate.year}/${jEndDate.month}/${jEndDate.day})';
    }
    
    return typeText;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.saturday: return 'شنبه';
      case DateTime.sunday: return '۱شنبه';
      case DateTime.monday: return '۲شنبه';
      case DateTime.tuesday: return '۳شنبه';
      case DateTime.wednesday: return '۴شنبه';
      case DateTime.thursday: return '۵شنبه';
      case DateTime.friday: return 'جمعه';
      default: return '';
    }
  }

  Widget _buildPriorityBadge(BuildContext context, TaskPriority priority) {
    final colorScheme = Theme.of(context).colorScheme;
    Color color;
    String label;
    
    switch (priority) {
      case TaskPriority.high:
        color = Colors.red;
        label = 'بالا';
        break;
      case TaskPriority.medium:
        color = colorScheme.primary;
        label = 'متوسط';
        break;
      case TaskPriority.low:
        color = Colors.green;
        label = 'کم';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDestructive ? Colors.red : colorScheme.onSurface;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: HugeIcon(
          icon: icon,
          size: 20,
          color: color,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 18,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
