import 'flow_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'lottie_category_icon.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/task.dart';
import '../models/goal.dart';
import '../models/category_data.dart';
import '../providers/task_provider.dart';
import '../providers/category_provider.dart';
import '../providers/goal_provider.dart';
import '../screens/add_task_screen.dart';
import 'postpone_dialog.dart';
import 'package:go_router/go_router.dart';
import '../utils/route_builder.dart';
import 'audio_waveform_player.dart';

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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Line
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
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
    final targetDate =
        recurringDate ??
        (task.recurrence != null && task.recurrence!.type != RecurrenceType.none
            ? task.dueDate
            : null);

    // Determine current status
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
          Navigator.pop(context);
          PostponeDialog.show(context, ref, task, targetDate: targetDate);
        } else {
          if (targetDate != null) {
            ref
                .read(tasksProvider.notifier)
                .updateStatus(task.id!, status, date: targetDate);
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class BulkTaskStatusPickerSheet extends ConsumerWidget {
  final Set<int> selectedTaskIds;
  final DateTime todayDate;

  const BulkTaskStatusPickerSheet({
    super.key,
    required this.selectedTaskIds,
    required this.todayDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Line
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'تغییر وضعیت گروهی تسک‌ها',
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
    return InkWell(
      onTap: () async {
        HapticFeedback.mediumImpact();

        if (status == TaskStatus.deferred) {
          // Defer logic for bulk is tricky as it usually requires picking a date per task or a global date
          // For now, let's assume we defer all to the same date if picked, or just skip defer in bulk for now?
          // The UI shows the button, so we should support it.
          // However, the prompt focused on "status change". Deferring usually opens a dialog.
          // The user instruction: "Fix bulk status change... recurring (current day) and regular (due date)".
          // Deferring might need a date picker, but here we just update status if it's a direct status like Done/Pending.
          // If it IS deferred, we probably shouldn't show the postpone dialog for EACH task.
          // For simplicity and safety, and since the user didn't explicitly ask for bulk-defer date picking:
          // We will treat "Deferred" as just setting the status to deferred without changing the date (or using today/due date).

          final tasks = ref.read(tasksProvider);
          for (var taskId in selectedTaskIds) {
            final task = tasks.firstWhere(
              (t) => t.id == taskId,
              orElse: () => Task(title: '', dueDate: DateTime.now()),
            );
            final isRecurring =
                task.recurrence != null &&
                task.recurrence!.type != RecurrenceType.none;

            // For recurring tasks, we change status for the *current view date* (todayDate passed in).
            // For regular tasks, we change status for their *due date*.
            final targetDate = isRecurring ? todayDate : task.dueDate;

            ref
                .read(tasksProvider.notifier)
                .updateStatus(taskId, status, date: targetDate);
          }
          if (context.mounted) Navigator.pop(context);
        } else {
          final tasks = ref.read(tasksProvider);
          for (var taskId in selectedTaskIds) {
            final task = tasks.firstWhere(
              (t) => t.id == taskId,
              orElse: () => Task(title: '', dueDate: DateTime.now()),
            );
            final isRecurring =
                task.recurrence != null &&
                task.recurrence!.type != RecurrenceType.none;

            final targetDate = isRecurring ? todayDate : task.dueDate;

            ref
                .read(tasksProvider.notifier)
                .updateStatus(taskId, status, date: targetDate);
          }
          if (context.mounted) Navigator.pop(context);
        }
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.transparent, // No selection state for bulk
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.normal,
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.normal,
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
    final allCategories = ref.watch(categoryProvider).valueOrNull ?? [];
    final allGoals = ref.watch(goalsProvider);

    final taskCategories = task.categories;
    final taskGoals = task.goalIds;

    // Find the original task to get the true start date if it's a recurring task
    final allTasks = ref.watch(tasksProvider);
    final originalTask = allTasks.cast<Task?>().firstWhere(
      (t) => t?.id == task.id,
      orElse: () => task,
    );

    final displayDate = originalTask?.dueDate ?? task.dueDate;
    final occurrenceDate = date ?? task.dueDate;
    final isRecurring =
        task.recurrence != null && task.recurrence!.type != RecurrenceType.none;
    final isOccurrenceDifferent =
        isRecurring && !DateUtils.isSameDay(displayDate, occurrenceDate);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Line
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Task Info Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            if (task.taskEmoji != null) ...[
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  task.taskEmoji!,
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                              const SizedBox(width: 14),
                            ],
                            Expanded(
                              child: Text(
                                task.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textDirection: TextDirection.rtl,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildPriorityBadge(context, task.priority),
                          ],
                        ),

                        // Date and Time Info
                        const SizedBox(height: 16),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 16),

                        // Date Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          textDirection: TextDirection.rtl,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedCalendar03,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildParenthesesStyledText(
                                    "${isRecurring ? 'آغاز:' : 'تاریخ:'} ${_formatDate(displayDate)}",
                                    TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'IRANSansX',
                                    ),
                                  ),
                                  // Occurrence Date Row (if different)
                                  if (isOccurrenceDifferent) ...[
                                    const SizedBox(height: 4),
                                    _buildParenthesesStyledText(
                                      'تکرار فعلی: ${_formatDate(occurrenceDate)}',
                                      TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Time Row (New Line)
                        if (task.metadata['hasTime'] ?? true) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            textDirection: TextDirection.rtl,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedClock01,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildParenthesesStyledText(
                                  "زمان: ${_toPersianDigit(_formatTime(displayDate))}",
                                  TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Recurrence Info
                        if (task.recurrence != null &&
                            task.recurrence!.type != RecurrenceType.none) ...[
                          const SizedBox(height: 12),
                          Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedRefresh,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildParenthesesStyledText(
                                  _getRecurrenceText(task.recurrence!),
                                  TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (task.description != null &&
                            task.description!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(height: 1, thickness: 0.5),
                          const SizedBox(height: 16),
                          Text(
                            task.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              height: 1.6,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],

                        if (taskCategories.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            textDirection: TextDirection.rtl,
                            children: taskCategories.map((catId) {
                              final catData = allCategories.firstWhere(
                                (c) => c.id == catId,
                                orElse: () => defaultCategories.firstWhere(
                                  (dc) => dc.id == catId,
                                  orElse: () => defaultCategories.first,
                                ),
                              );
                              return InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push(
                                    SearchRouteBuilder.buildSearchUrl(
                                      categories: [catId],
                                      specificDate: occurrenceDate,
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: catData.color.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: catData.color.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    textDirection: TextDirection.rtl,
                                    children: [
                                      LottieCategoryIcon(
                                        assetPath: catData.emoji,
                                        width: 22,
                                        height: 22,
                                        repeat: false,
                                      ),
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
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        if (taskGoals.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            textDirection: TextDirection.rtl,
                            children: taskGoals.map((goalId) {
                              final goal = allGoals.firstWhere(
                                (g) => g.id == goalId,
                                orElse: () => Goal(id: goalId, title: 'نامشخص', emoji: '🎯', position: 0),
                              );
                              
                              return InkWell(
                                onTap: () {
                                  context.push(
                                    SearchRouteBuilder.buildSearchUrl(
                                      goals: [goalId],
                                      specificDate: date,
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    textDirection: TextDirection.rtl,
                                    children: [
                                      Text(goal.emoji, style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Text(
                                        goal.title,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          
                          // Goal Audio Players
                          ...taskGoals.map((goalId) {
                            final goal = allGoals.cast<Goal?>().firstWhere(
                              (g) => g?.id == goalId,
                              orElse: () => null,
                            );
                            
                            if (goal != null && goal.audioPath != null) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Text(
                                        'صدای هدف: ${goal.title}', 
                                        style: TextStyle(
                                          fontSize: 12, 
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    AudioWaveformPlayer(
                                      audioPath: goal.audioPath!,
                                      activeWaveColor: Theme.of(context).colorScheme.primary,
                                      waveColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }),
                        ],

                        if (task.tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            textDirection: TextDirection.rtl,
                            children: task.tags
                                .map(
                                  (tag) => InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      context.push(
                                        SearchRouteBuilder.buildSearchUrl(
                                          tags: [tag],
                                          specificDate: occurrenceDate,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        textDirection: TextDirection.rtl,
                                        children: [
                                          HugeIcon(
                                            icon: HugeIcons.strokeRoundedTag01,
                                            size: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            tag,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],

                        if (task.attachments.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(height: 1, thickness: 0.5),
                          const SizedBox(height: 16),
                          Column(
                            children: task.attachments.map((att) {
                              final name = att.split('/').last;
                              final isVoice =
                                  name.startsWith('voice_') ||
                                  att.endsWith('.m4a');
                              final isImage =
                                  name.toLowerCase().endsWith('.jpg') ||
                                  name.toLowerCase().endsWith('.jpeg') ||
                                  name.toLowerCase().endsWith('.png') ||
                                  name.toLowerCase().endsWith('.gif') ||
                                  name.toLowerCase().endsWith('.webp');

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: isVoice
                                    ? GestureDetector(
                                        onLongPress: () =>
                                            _showAttachmentOptions(
                                              context,
                                              att,
                                              name,
                                            ),
                                        child: AudioWaveformPlayer(
                                          audioPath: att,
                                        ),
                                      )
                                    : GestureDetector(
                                        onLongPress: () =>
                                            _showAttachmentOptions(
                                              context,
                                              att,
                                              name,
                                            ),
                                        child: Container(
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outlineVariant
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: InkWell(
                                            onTap: () => OpenFilex.open(att),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Row(
                                              children: [
                                                HugeIcon(
                                                  icon: isImage
                                                      ? HugeIcons
                                                            .strokeRoundedImage01
                                                      : HugeIcons
                                                            .strokeRoundedFile01,
                                                  size: 18,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    name.length > 30
                                                        ? '${name.substring(0, 30)}...'
                                                        : name,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

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
                            builder: (context) =>
                                AddTaskScreen(task: task, initialDate: date),
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
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => TaskStatusPickerSheet(
                              task: task,
                              recurringDate: occurrenceDate,
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParenthesesStyledText(
    String text,
    TextStyle baseStyle, {
    TextAlign textAlign = TextAlign.right,
    TextDirection textDirection = TextDirection.rtl,
  }) {
    final List<TextSpan> spans = [];

    // Pattern to match labels ending with colon OR text inside parentheses
    // Group 1: Label with colon (e.g., "تاریخ شروع:")
    // Group 2: Text inside parentheses (e.g., "(امروز)")
    final RegExp regExp = RegExp(r'(^.*?:)|\((.*?)\)');
    int lastIndex = 0;

    for (final Match match in regExp.allMatches(text)) {
      // Add text before the match
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final labelMatch = match.group(1);
      final parenContentMatch = match.group(2);

      if (labelMatch != null) {
        // Style for label with colon
        spans.add(
          TextSpan(
            text: labelMatch,
            style: baseStyle.copyWith(
              color: baseStyle.color?.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      } else if (match.group(0)!.startsWith('(')) {
        // Style for parentheses
        final styledParenStyle = baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 13) * 0.85,
          color: baseStyle.color?.withValues(alpha: 0.5),
          fontWeight: FontWeight.w400,
        );

        spans.add(TextSpan(text: '(', style: styledParenStyle));
        spans.add(TextSpan(text: parenContentMatch, style: styledParenStyle));
        spans.add(TextSpan(text: ')', style: styledParenStyle));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    if (spans.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        textAlign: textAlign,
        textDirection: textDirection,
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      textDirection: textDirection,
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

  String _formatJalali(Jalali j) {
    String weekday = j.formatter.wN;
    if (weekday == 'یک شنبه') weekday = 'یک‌شنبه';
    if (weekday == 'دو شنبه') weekday = 'دو‌شنبه';
    if (weekday == 'سه شنبه') weekday = 'سه‌شنبه';
    if (weekday == 'چهار شنبه') weekday = 'چهار‌شنبه';
    if (weekday == 'پنج شنبه') weekday = 'پنج‌شنبه';
    return _toPersianDigit('$weekday ${j.day} ${j.formatter.mN} ${j.year}');
  }

  String _formatDate(DateTime date) {
    final jDate = Jalali.fromDateTime(date);
    final now = Jalali.now();

    if (jDate.year == now.year &&
        jDate.month == now.month &&
        jDate.day == now.day) {
      return 'امروز (${_formatJalali(jDate)})';
    }

    final tomorrow = now.addDays(1);
    if (jDate.year == tomorrow.year &&
        jDate.month == tomorrow.month &&
        jDate.day == tomorrow.day) {
      return 'فردا (${_formatJalali(jDate)})';
    }

    return _formatJalali(jDate);
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getRecurrenceText(RecurrenceConfig recurrence) {
    String typeText = '';
    switch (recurrence.type) {
      case RecurrenceType.hourly:
        typeText = 'ساعتی';
        break;
      case RecurrenceType.daily:
        if (recurrence.interval != null && recurrence.interval! > 1) {
          typeText = 'هر ${recurrence.interval} روز';
        } else {
          typeText = 'روزانه';
        }
        break;
      case RecurrenceType.weekly:
        typeText = 'هفتگی';
        break;
      case RecurrenceType.monthly:
        typeText = 'ماهانه';
        break;
      case RecurrenceType.yearly:
        typeText = 'سالانه';
        break;
      case RecurrenceType.custom:
        typeText = 'هر ${recurrence.interval} روز';
        break;
      case RecurrenceType.specificDays:
        final days =
            recurrence.daysOfWeek?.map((d) => _getDayName(d)).join('، ') ?? '';
        typeText = 'روزهای $days';
        break;
      default:
        typeText = 'سفارشی';
    }

    if (recurrence.endDate != null) {
      final jEndDate = Jalali.fromDateTime(recurrence.endDate!);
      typeText += ' (تا ${jEndDate.year}/${jEndDate.month}/${jEndDate.day})';
    }

    return typeText;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'شنبه';
      case DateTime.sunday:
        return '۱شنبه';
      case DateTime.monday:
        return '۲شنبه';
      case DateTime.tuesday:
        return '۳شنبه';
      case DateTime.wednesday:
        return '۴شنبه';
      case DateTime.thursday:
        return '۵شنبه';
      case DateTime.friday:
        return 'جمعه';
      default:
        return '';
    }
  }

  Widget _buildPriorityBadge(BuildContext context, TaskPriority priority) {
    final colorScheme = Theme.of(context).colorScheme;
    Color color;
    String label;

    switch (priority) {
      case TaskPriority.high:
        color = Colors.red;
        label = 'فوری';
        break;
      case TaskPriority.medium:
        color = colorScheme.primary;
        label = 'عادی';
        break;
      case TaskPriority.low:
        color = Colors.green;
        label = 'فرعی';
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Container(
        padding: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: HugeIcon(icon: icon, size: 20, color: color),
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

  void _showAttachmentOptions(
    BuildContext context,
    String filePath,
    String fileName,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Line
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Download Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedDownload01,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text(
                'دانلود فایل',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                fileName,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(context);
                _downloadAttachment(context, filePath, fileName);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadAttachment(
    BuildContext context,
    String filePath,
    String fileName,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('فایل یافت نشد')));
        }
        return;
      }

      final bytes = await file.readAsBytes();

      // Get file extension
      final extension = fileName.split('.').last;

      String? savedPath;

      if (Platform.isAndroid || Platform.isIOS) {
        // On mobile, use saveFile with bytes
        savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'ذخیره فایل',
          fileName: fileName,
          bytes: bytes,
        );
      } else {
        // On desktop, use saveFile and then write the file
        savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'ذخیره فایل',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [extension],
        );

        if (savedPath != null) {
          final savedFile = File(savedPath);
          await savedFile.writeAsBytes(bytes);
        }
      }

      if (savedPath != null && context.mounted) {
        FlowToast.show(
          context,
          message: 'فایل با موفقیت ذخیره شد',
          type: FlowToastType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        FlowToast.show(
          context,
          message: 'خطا در دانلود فایل: $e',
          type: FlowToastType.error,
        );
      }
    }
  }
}
