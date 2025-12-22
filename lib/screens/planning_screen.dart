import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import '../constants/duck_emojis.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:text_scroll/text_scroll.dart';
import '../providers/task_provider.dart';
import '../providers/category_provider.dart';
import '../models/task.dart';
import '../models/category_data.dart';
import '../widgets/task_sheets.dart';
// Removed unused import: add_task_screen.dart as it is handled in TaskSheets

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  int _viewMode = 0; // 0: Daily, 1: Weekly, 2: Monthly
  DateTime _selectedDate = DateTime.now();

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
    return _toPersianDigit('${j.day} ${j.formatter.mN} ${j.year}');
  }

  String _formatMiladiSmall(DateTime dt) {
    return intl.DateFormat('d MMM yyyy').format(dt);
  }

  Future<void> _selectDate() async {
    final Jalali? picked = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(_selectedDate),
      firstDate: Jalali(1300, 1, 1),
      lastDate: Jalali(1500, 1, 1),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked.toDateTime();
      });
    }
  }

  void _jumpToCurrent() {
    setState(() {
      _selectedDate = DateTime.now();
    });
  }

  bool _isCurrentRange() {
    final now = DateTime.now();
    if (_viewMode == 0) {
      return _isSameDay(_selectedDate, now);
    } else if (_viewMode == 1) {
      final startOfSelected = _selectedDate.subtract(
        Duration(days: (_selectedDate.weekday + 1) % 7),
      );
      final startOfNow = now.subtract(Duration(days: (now.weekday + 1) % 7));
      return _isSameDay(startOfSelected, startOfNow);
    } else {
      final jSelected = Jalali.fromDateTime(_selectedDate);
      final jNow = Jalali.fromDateTime(now);
      return jSelected.year == jNow.year && jSelected.month == jNow.month;
    }
  }

  void _changeRange(int delta) {
    setState(() {
      if (_viewMode == 0) {
        _selectedDate = _selectedDate.add(Duration(days: delta));
      } else if (_viewMode == 1) {
        _selectedDate = _selectedDate.add(Duration(days: delta * 7));
      } else {
        final j = Jalali.fromDateTime(_selectedDate);
        _selectedDate = j.addMonths(delta).toDateTime();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch tasksProvider to rebuild when tasks change
    final allTasks = ref.watch(tasksProvider);
    final tasks = allTasks.where(_isTaskStructurallyValid).toList();
    
    // Also watch taskCompletionsProvider if it exists, or just rely on tasksProvider updates
    // Since we updated TasksNotifier to force state update on completion change, this should be enough.
    // However, for recurring tasks status, we might need to ensure we are reading the latest status.
    
    final categories = ref.watch(categoryProvider).value ?? [];

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Spacer for the top bar
              SizedBox(height: MediaQuery.of(context).padding.top + 70),
              
              Expanded(child: _buildMainContent(tasks, categories)),
              _buildRangePicker(),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.7),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(
                            value: 0,
                            label: Text('روزانه'),
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedCalendar03,
                              size: 18,
                            ),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text('هفتگی'),
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedCalendar02,
                              size: 18,
                            ),
                          ),
                          ButtonSegment(
                            value: 2,
                            label: Text('ماهانه'),
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedCalendar01,
                              size: 18,
                            ),
                          ),
                        ],
                        selected: {_viewMode},
                        onSelectionChanged: (Set<int> newSelection) {
                          setState(() {
                            _viewMode = newSelection.first;
                          });
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith<
                            Color?
                          >((states) {
                            if (states.contains(WidgetState.selected)) {
                              return Theme.of(
                                context,
                              ).colorScheme.secondaryContainer;
                            }
                            return Colors.transparent;
                          }),
                          side: WidgetStateProperty.all(
                            BorderSide(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          elevation: WidgetStateProperty.all(0),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringTaskGroup(List<Task> tasks) {
    // Calculate progress for recurring tasks
    int total = tasks.length;
    int completed = tasks.where((t) => t.status == TaskStatus.success).length;
    double progress = total == 0 ? 0 : completed / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
            alpha: 0.5,
          ),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Text('🔁', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تسک‌های تکرار شونده',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Thin divider line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          
          // List of recurring tasks
          ...tasks.map((task) => _buildRecurringTaskRow(task)),
          const SizedBox(height: 12),

          // Progress Bar
          if (total > 0)
            Container(
              height: 3,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                color: Theme.of(context).colorScheme.primary,
                minHeight: 3,
              ),
            ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildRecurringTaskRow(Task task) {
    final isCancelled = task.status == TaskStatus.cancelled;
    
    return Opacity(
      opacity: isCancelled ? 0.6 : 1.0,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            // Status Icon (Left side)
            _getStatusIconForTile(task),

            const SizedBox(width: 10),

            // Task Title (Right side)
            Expanded(
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _toggleTaskStatus(task, task.dueDate);
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  _showTaskOptions(context, task);
                },
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    if (task.taskEmoji != null) ...[
                      Text(task.taskEmoji!, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: TextScroll(
                        task.title,
                        mode: TextScrollMode.endless,
                        velocity: const Velocity(
                          pixelsPerSecond: Offset(30, 0),
                        ),
                        delayBefore: const Duration(seconds: 2),
                        pauseBetween: const Duration(seconds: 2),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          decoration: task.status == TaskStatus.success
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.status == TaskStatus.success
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5)
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(List<Task> tasks, List<CategoryData> categories) {
    final validTasks = tasks.where(_isTaskStructurallyValid).toList();

    if (_viewMode == 0) {
      return _buildDailyView(validTasks, categories);
    } else if (_viewMode == 1) {
      return _buildWeeklyView(validTasks, categories);
    } else {
      return _buildMonthlyView(validTasks, categories);
    }
  }

  bool _isTaskStructurallyValid(Task task) {
    if (task.title.trim().isEmpty) return false;

    final recurrence = task.recurrence;
    if (recurrence != null && recurrence.type != RecurrenceType.none) {
      // Recurring tasks MUST have an ID to track their status per date
      if (task.id == null) return false;

      if (recurrence.type == RecurrenceType.hourly) {
        return false;
      }

      if (recurrence.type == RecurrenceType.custom) {
        if (recurrence.interval == null || recurrence.interval! <= 0) {
          return false;
        }
      }

      if (recurrence.type == RecurrenceType.specificDays) {
        final days = recurrence.daysOfWeek;
        if (days == null || days.isEmpty) return false;
        if (days.any((d) => d < 1 || d > 7)) return false;
      }
    }

    return true;
  }

  bool _isTaskActiveOnDate(Task task, DateTime date) {
    if (task.recurrence == null ||
        task.recurrence!.type == RecurrenceType.none) {
      return _isSameDay(task.dueDate, date);
    }

    try {
      // Check end date
      if (task.recurrence!.endDate != null &&
          date.isAfter(task.recurrence!.endDate!)) {
        return false;
      }

      // Check start date (task shouldn't appear before it was created/due)
      final dateOnly = DateTime(date.year, date.month, date.day);
      final dueOnly =
          DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      if (dateOnly.isBefore(dueOnly)) {
        return false;
      }

      // Special check: If this task has a specific status entry for this date in task_completions,
      // it means it was interacted with on this date, so it should be active/visible.
      // This covers cases where recurrence logic might be tricky but user explicitly acted on it.
      if (task.id != null) {
          final status = ref.read(tasksProvider.notifier).getStatusForDate(task.id!, date);
          if (status != TaskStatus.pending) { // If it has a non-default status recorded
              return true;
          }
      }

      switch (task.recurrence!.type) {
        case RecurrenceType.daily:
          return true;
        case RecurrenceType.weekly:
          return date.weekday == task.dueDate.weekday;
        case RecurrenceType.monthly:
          final jDate = Jalali.fromDateTime(date);
          final jDue = Jalali.fromDateTime(task.dueDate);
          return jDate.day == jDue.day;
        case RecurrenceType.yearly:
          final jDate = Jalali.fromDateTime(date);
          final jDue = Jalali.fromDateTime(task.dueDate);
          return jDate.month == jDue.month && jDate.day == jDue.day;
        case RecurrenceType.specificDays:
          return task.recurrence!.daysOfWeek != null &&
              task.recurrence!.daysOfWeek!.contains(date.weekday);
        case RecurrenceType.custom:
          final diff = date.difference(task.dueDate).inDays;
          final interval = task.recurrence!.interval;
          return interval != null && interval > 0 && diff % interval == 0;
        default:
          return false;
      }
    } catch (e) {
      debugPrint('Error in _isTaskActiveOnDate: $e');
      return false;
    }
  }

  // Logic to expand recurring tasks
  List<Task> _getTasksForDate(List<Task> allTasks, DateTime date) {
    final tasksForDate = <Task>[];

    for (var task in allTasks) {
      if (!_isTaskStructurallyValid(task)) continue;

      if (_isTaskActiveOnDate(task, date)) {
        TaskStatus status = task.status;
        if (task.recurrence != null &&
            task.recurrence!.type != RecurrenceType.none &&
            task.id != null) {
          status = ref
              .read(tasksProvider.notifier)
              .getStatusForDate(task.id!, date);
        }

        // Create a virtual copy for display
        tasksForDate.add(task.copyWith(dueDate: date, status: status));
      }
    }
    return tasksForDate;
  }

  Widget _buildRangePicker() {
    String label = '';
    final jalali = Jalali.fromDateTime(_selectedDate);

    if (_viewMode == 0) {
      label = _formatJalali(jalali);
    } else if (_viewMode == 1) {
      final startOfWeek = _selectedDate.subtract(
        Duration(days: (_selectedDate.weekday + 1) % 7),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      final jStart = Jalali.fromDateTime(startOfWeek);
      final jEnd = Jalali.fromDateTime(endOfWeek);
      label = _toPersianDigit(
        '${jStart.day} ${jStart.formatter.mN} - ${jEnd.day} ${jEnd.formatter.mN}',
      );
    } else {
      label = _toPersianDigit('${jalali.formatter.mN} ${jalali.year}');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeRange(-1),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 24,
              color: Colors.grey,
            ),
          ),
          InkWell(
            onTap: _selectDate,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _formatMiladiSmall(_selectedDate),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                if (!_isCurrentRange())
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton(
                      onPressed: _jumpToCurrent,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _viewMode == 0
                            ? 'برو به امروز'
                            : (_viewMode == 1
                                  ? 'برو به هفته جاری'
                                  : 'برو به ماه جاری'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _changeRange(1),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              size: 24,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyRecurringTaskRow(
    Task task,
    DateTime startOfWeek, {
    int? currentMonth,
  }) {
    final days = List.generate(
      7,
      (index) => startOfWeek.add(Duration(days: index)),
    );

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          // 7 Status Icons (Left side)
          Row(
            textDirection: TextDirection.rtl,
            mainAxisSize: MainAxisSize.min,
            children: days.map((date) {
              final isCurrentMonth =
                  currentMonth == null ||
                  Jalali.fromDateTime(date).month == currentMonth;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: _buildStatusIcon(
                  task: task,
                  date: date,
                  size: 22,
                  isCurrentMonth: isCurrentMonth,
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(width: 10),

          // Task Title (Right side)
          Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                // For weekly recurring, toggle for today if in range, otherwise first day
                final today = DateTime.now();
                DateTime targetDate = days.first;
                for (var d in days) {
                  if (_isSameDay(d, today)) {
                    targetDate = d;
                    break;
                  }
                }
                _toggleTaskStatus(task, targetDate);
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showTaskOptions(context, task);
              },
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  if (task.taskEmoji != null) ...[
                    Text(task.taskEmoji!, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: TextScroll(
                      task.title,
                      mode: TextScrollMode.endless,
                      velocity: const Velocity(pixelsPerSecond: Offset(30, 0)),
                      delayBefore: const Duration(seconds: 2),
                      pauseBetween: const Duration(seconds: 2),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyRecurringTaskGroup(List<Task> tasks, DateTime startOfWeek) {
    // Calculate progress across all 7 days for all tasks
    int totalSlots = tasks.length * 7;
    int completedSlots = 0;
    
    for (var task in tasks) {
      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        final status = ref.read(tasksProvider.notifier).getStatusForDate(task.id!, date);
        if (status == TaskStatus.success) completedSlots++;
      }
    }
    double progress = totalSlots == 0 ? 0 : completedSlots / totalSlots;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Text('🔁', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تسک‌های تکرار شونده',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Thin divider line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          
          // Day initials
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(7, (index) {
                    final date = startOfWeek.add(Duration(days: index));
                    return Container(
                      width: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      alignment: Alignment.center,
                      child: Text(
                        _getDayName(date.weekday)[0],
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  }),
                ),
                const Expanded(child: SizedBox()), // Push to right
              ],
            ),
          ),
          const SizedBox(height: 2),
          
          // List of recurring tasks
          ...tasks.map((task) => _buildWeeklyRecurringTaskRow(task, startOfWeek)),
          const SizedBox(height: 12),

          // Progress Bar
          if (totalSlots > 0)
            Container(
              height: 3,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                color: Theme.of(context).colorScheme.primary,
                minHeight: 3,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDailyView(List<Task> tasks, List<CategoryData> categories) {
    // Generate tasks for the selected date
    final dailyTasks = _getTasksForDate(tasks, _selectedDate);

    if (dailyTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✨', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            Text(
              'برای این روز برنامه‌ای نداری.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }


    final recurringTasks = <Task>[];
    final regularTasks = <Task>[];

    for (var task in dailyTasks) {
      if (task.recurrence != null && task.recurrence!.type != RecurrenceType.none) {
        recurringTasks.add(task);
      } else {
        regularTasks.add(task);
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // Recurring Tasks Box
        if (recurringTasks.isNotEmpty)
          FadeInOnce(
            key: const ValueKey('daily_recurring_box'),
            delay: 100.ms,
            child: _buildRecurringTaskGroup(recurringTasks),
          ),
        
        // Regular Task Groups
        ..._getGroupedAndSortedTasks(regularTasks).entries.toList().asMap().entries.map((entry) {
             final index = entry.key;
             final group = entry.value;
             return FadeInOnce(
               key: ValueKey('daily_group_${group.key}'),
               delay: (200 + (index * 50)).ms,
               child: _buildTaskGroup(group.key, group.value, categories),
             );
        }),
      ],
    );
  }

  Widget _buildWeeklyView(List<Task> tasks, List<CategoryData> categories) {
    final offset = (_selectedDate.weekday + 1) % 7;
    final startOfWeek = _selectedDate.subtract(Duration(days: offset));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    // 1. Identify recurring tasks active in this week
    final recurringTasksForWeek = <Task>[];
    for (var task in tasks) {
      if (task.recurrence != null &&
          task.recurrence!.type != RecurrenceType.none) {
        bool isActive = false;
        for (int i = 0; i < 7; i++) {
          if (_isTaskActiveOnDate(task, startOfWeek.add(Duration(days: i)))) {
            isActive = true;
            break;
          }
        }
        if (isActive) recurringTasksForWeek.add(task);
      }
    }

    // 2. Identify all regular tasks for the week
    final regularTasksForWeek = <Task>[];
    
    // Efficient way: Check if task.dueDate is within startOfWeek and endOfWeek
    for (var task in tasks) {
      if (task.recurrence == null || task.recurrence!.type == RecurrenceType.none) {
         if ((task.dueDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && 
              task.dueDate.isBefore(endOfWeek.add(const Duration(days: 1))))) {
           regularTasksForWeek.add(task);
         }
      }
    }

    if (regularTasksForWeek.isEmpty && recurringTasksForWeek.isEmpty) {
      return const Center(child: Text('برای این هفته برنامه‌ای نداری.'));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // Recurring Tasks Section (Top)
        if (recurringTasksForWeek.isNotEmpty)
          FadeInOnce(
            key: const ValueKey('weekly_recurring_box'),
            delay: 100.ms,
            child: _buildWeeklyRecurringTaskGroup(recurringTasksForWeek, startOfWeek),
          ),
        
        // Grouped Regular Tasks (All tasks of the week grouped by category)
        if (regularTasksForWeek.isNotEmpty)
          ..._getGroupedAndSortedTasks(regularTasksForWeek)
              .entries.toList().asMap().entries
              .map((entry) {
                final index = entry.key;
                final group = entry.value;
                return FadeInOnce(
                  key: ValueKey('weekly_group_${group.key}'),
                  delay: (200 + (index * 50)).ms,
                  child: _buildTaskGroup(group.key, group.value, categories),
                );
              }),
      ],
    );
  }

  Widget _buildMonthlyView(List<Task> tasks, List<CategoryData> categories) {
    try {
      final jalaliDate = Jalali.fromDateTime(_selectedDate);
      final monthStart = Jalali(jalaliDate.year, jalaliDate.month, 1);
      final monthLength = monthStart.monthLength;
      final startOfMonth = monthStart.toDateTime();
      final endOfMonth = monthStart.copy(day: monthLength).toDateTime();

      // 1. Generate Weeks
      final weeks = <List<DateTime>>[];
      final firstDayOffset = (startOfMonth.weekday + 1) % 7;
      var weekStart = startOfMonth.subtract(Duration(days: firstDayOffset));

      // Safety check to prevent infinite loops: max 6 weeks in a month
      int weekCount = 0;
      // Continue until we have covered the entire month
      while (weekStart.isBefore(endOfMonth.add(const Duration(seconds: 1))) ||
          weekCount < 5) {
        final weekDays =
            List.generate(7, (i) => weekStart.add(Duration(days: i)));
        // Only add the week if it contains at least one day from the current month
        if (weekDays.any(
          (d) => Jalali.fromDateTime(d).month == jalaliDate.month,
        )) {
          weeks.add(weekDays);
        }

        weekStart = weekStart.add(const Duration(days: 7));
        weekCount++;

        // Safety break
        if (weekCount > 6) break;
      }

      // 2. Collect Recurring Tasks
      final Map<int, List<Task>> recurringTasksByWeek = {};
      for (int i = 0; i < weeks.length; i++) {
          final weekDays = weeks[i];
          final weekTasks = <Task>[];
          for (var task in tasks) {
            if (task.recurrence != null && task.recurrence!.type != RecurrenceType.none) {
               if (weekDays.any((d) => _isTaskActiveOnDate(task, d))) {
                  weekTasks.add(task);
               }
            }
          }
          if (weekTasks.isNotEmpty) {
              recurringTasksByWeek[i] = weekTasks;
          }
      }

      // 3. Collect Regular Tasks
      final regularTasksForMonth = <Task>[];
      for (var task in tasks) {
        if (task.recurrence == null || task.recurrence!.type == RecurrenceType.none) {
           final tJalali = Jalali.fromDateTime(task.dueDate);
           if (tJalali.year == jalaliDate.year && tJalali.month == jalaliDate.month) {
             regularTasksForMonth.add(task);
           }
        }
      }

      if (recurringTasksByWeek.isEmpty && regularTasksForMonth.isEmpty) {
        return const Center(child: Text('برای این ماه برنامه‌ای نداری.'));
      }

      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          // Consolidated Recurring Tasks Box
          if (recurringTasksByWeek.isNotEmpty)
            FadeInOnce(
              key: const ValueKey('monthly_recurring_box'),
              delay: 100.ms,
              child: _buildMonthlyRecurringTasksBox(
                recurringTasksByWeek,
                weeks,
                jalaliDate.month,
              ),
            ),
          
          if (recurringTasksByWeek.isNotEmpty && regularTasksForMonth.isNotEmpty)
             const SizedBox(height: 16),

          // Regular Tasks
          if (regularTasksForMonth.isNotEmpty)
            ..._getGroupedAndSortedTasks(regularTasksForMonth).entries.toList().asMap().entries.map((entry) {
               final index = entry.key;
               final group = entry.value;
               return FadeInOnce(
                 key: ValueKey('monthly_group_${group.key}'),
                 delay: (200 + (index * 50)).ms,
                 child: _buildTaskGroup(group.key, group.value, categories),
               );
            }),
        ],
      );
    } catch (e, stack) {
      debugPrint('Error in _buildMonthlyView: $e\n$stack');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SelectableText(
            'خطایی رخ داده است:\n$e',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  Widget _buildMonthlyRecurringTasksBox(
    Map<int, List<Task>> tasksByWeek,
    List<List<DateTime>> weeks,
    int currentMonth,
  ) {
    double progress = 0.0;
    try {
      int totalTasks = 0;
      int completedTasks = 0;
      final notifier = ref.read(tasksProvider.notifier);

      tasksByWeek.forEach((weekIndex, tasks) {
        if (weekIndex >= 0 && weekIndex < weeks.length) {
          final weekDays = weeks[weekIndex];
          for (var task in tasks) {
            if (task.id == null) continue;
            for (var date in weekDays) {
              if (_isTaskActiveOnDate(task, date)) {
                totalTasks++;
                if (notifier.getStatusForDate(task.id!, date) ==
                    TaskStatus.success) {
                  completedTasks++;
                }
              }
            }
          }
        }
      });

      progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
    } catch (e, stack) {
      debugPrint('Error in _buildMonthlyRecurringTasksBox: $e\n$stack');
      progress = 0.0;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Text('🔄', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'تسک‌های تکرار شونده ماهانه',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.5),
            ),
          ),

          const SizedBox(height: 12),

          // Weeks Sections
          ...tasksByWeek.entries.map((entry) {
            final weekIndex = entry.key;
            final tasks = entry.value;
            final isLast = entry.key == tasksByWeek.keys.last;
            final weekDays = weeks[weekIndex];
            final weekStart = weekDays.first;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Week Title (Centered Capsule)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'هفته ${_toPersianDigit((weekIndex + 1).toString())}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Day initials (Hints above each week)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      Row(
                        textDirection: TextDirection.rtl,
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(7, (index) {
                          final date = weekDays[index];
                          return Container(
                            width: 22,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            alignment: Alignment.center,
                            child: Text(
                              _getDayName(date.weekday)[0],
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          );
                        }),
                      ),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Tasks
                ...tasks.map(
                  (task) => _buildWeeklyRecurringTaskRow(
                    task,
                    weekStart,
                    currentMonth: currentMonth,
                  ),
                ),

                if (!isLast)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                  )
                else
                  const SizedBox(height: 12),
              ],
            );
          }),

          // Progress Bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            color: Theme.of(context).colorScheme.primary,
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Map<String, List<Task>> _getGroupedAndSortedTasks(List<Task> tasks) {
    final Map<String, List<Task>> grouped = {};
    for (var task in tasks) {
      String key;
      if (task.categories.length > 1) {
        key = 'combined'; // Combined Tasks
      } else if (task.categories.isNotEmpty) {
        key = task.categories.first;
      } else {
        key = 'uncategorized';
      }
      grouped.putIfAbsent(key, () => []).add(task);
    }

    // Sort categories: "combined" first, then others, "uncategorized" last
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        // 1. Uncategorized is always last (biggest)
        if (a == 'uncategorized') return 1;
        if (b == 'uncategorized') return -1;

        // 2. Combined is second to last (bigger than normal, smaller than uncategorized)
        if (a == 'combined') return 1;
        if (b == 'combined') return -1;

        // 3. Normal categories
        return a.compareTo(b);
      });

    final Map<String, List<Task>> result = {};
    for (var key in sortedKeys) {
      final list = grouped[key]!;
      // Sort tasks within category: High priority first, then move cancelled to bottom
      list.sort((a, b) {
        // Move cancelled to bottom
        if (a.status == TaskStatus.cancelled &&
            b.status != TaskStatus.cancelled) {
          return 1;
        }
        if (a.status != TaskStatus.cancelled &&
            b.status == TaskStatus.cancelled) {
          return -1;
        }

        // Priority sort
        if (a.priority != b.priority) {
          return b.priority.index.compareTo(a.priority.index);
        }
        return a.createdAt.compareTo(b.createdAt);
      });
      result[key] = list;
    }
    return result;
  }

  Widget _buildTaskGroup(String key, List<Task> tasks, List<CategoryData> categories) {
    String title;
    Color color;
    String emoji;

    if (key == 'combined') {
      title = 'کارهای ترکیبی';
      emoji = DuckEmojis.all[29];
      color = Colors.purple;
    } else if (key == 'uncategorized') {
      title = 'بدون دسته‌بندی';
      emoji = DuckEmojis.other;
      color = Colors.grey;
    } else {
      final catData = getCategoryById(key, categories);
      title = catData.label;
      emoji = catData.emoji;
      color = catData.color;
    }

    // Calculate progress
    final total = tasks.length;
    final completed = tasks.where((t) => t.status == TaskStatus.success).length;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias, // For progress bar clipping
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
            alpha: 0.5,
          ), // Unified border color
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Lottie.asset(emoji, width: 24, height: 24),
                const SizedBox(width: 6),
                Expanded(
                  child: TextScroll(
                    title,
                    mode: TextScrollMode.endless,
                    velocity: const Velocity(pixelsPerSecond: Offset(20, 0)),
                    delayBefore: const Duration(seconds: 2),
                    pauseBetween: const Duration(seconds: 2),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color, // Title keeps category color
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Thin divider line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          
          // Tasks List
          if (tasks.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Padding(
                  key: ValueKey(task.id ?? 'temp_${task.hashCode}_$index'),
                  padding: EdgeInsets.zero,
                  child: _buildCompactTaskRow(task),
                );
              },
            ),

          const SizedBox(height: 12),

          // Progress Bar
          if (total > 0)
            Container(
              height: 3,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withValues(alpha: 0.1),
                color: color,
                minHeight: 3,
              ),
            ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildCompactTaskRow(Task task) {
    final isCancelled = task.status == TaskStatus.cancelled;
    return Opacity(
      opacity: isCancelled ? 0.6 : 1.0,
      child: Container(
        // Add transparent background to catch drag gestures effectively
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            // Status Icon (Left side)
            _buildStatusIcon(task: task, date: task.dueDate, size: 22),

            const SizedBox(width: 10),

            // Task Title (Right side)
            Expanded(
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _toggleTaskStatus(task, task.dueDate);
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  _showTaskOptions(context, task);
                },
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    if (task.taskEmoji != null) ...[
                      Text(task.taskEmoji!, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: TextScroll(
                        task.title,
                        mode: TextScrollMode.endless,
                        velocity: const Velocity(
                          pixelsPerSecond: Offset(30, 0),
                        ),
                        delayBefore: const Duration(seconds: 2),
                        pauseBetween: const Duration(seconds: 2),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          decoration: task.status == TaskStatus.success
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.status == TaskStatus.success
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5)
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskOptions(BuildContext context, Task task) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => TaskOptionsSheet(task: task),
    );
  }

  void _toggleTaskStatus(Task task, DateTime date) {
    if (task.id == null) return;

    final hasRecurring =
        task.recurrence != null && task.recurrence!.type != RecurrenceType.none;
    final status = hasRecurring
        ? ref.read(tasksProvider.notifier).getStatusForDate(task.id!, date)
        : task.status;

    final nextStatus =
        status == TaskStatus.success ? TaskStatus.pending : TaskStatus.success;

    // Apply optimistic update immediately
    if (hasRecurring) {
        ref
          .read(tasksProvider.notifier)
          .updateStatus(task.id!, nextStatus, date: date);
    } else {
        ref.read(tasksProvider.notifier).updateStatus(task.id!, nextStatus);
    }

    HapticFeedback.lightImpact();
  }

  Widget _buildStatusIcon({
    required Task task,
    required DateTime date,
    double size = 24,
    bool isCurrentMonth = true,
  }) {
    final hasRecurring =
        task.recurrence != null && task.recurrence!.type != RecurrenceType.none;
    final hasId = task.id != null;
    final status = (hasRecurring && hasId)
        ? ref.read(tasksProvider.notifier).getStatusForDate(task.id!, date)
        : task.status;

    dynamic icon;
    Color color;

    switch (status) {
      case TaskStatus.success:
        icon = HugeIcons.strokeRoundedCheckmarkCircle03;
        color = Colors.green;
        break;
      case TaskStatus.failed:
        icon = HugeIcons.strokeRoundedCancelCircle;
        color = Colors.red;
        break;
      case TaskStatus.cancelled:
        icon = HugeIcons.strokeRoundedMinusSignCircle;
        color = Colors.grey;
        break;
      case TaskStatus.deferred:
        icon = HugeIcons.strokeRoundedClock01;
        color = Colors.orange;
        break;
      case TaskStatus.pending:
        icon = HugeIcons.strokeRoundedCircle;
        color = Theme.of(context)
            .colorScheme
            .onSurfaceVariant
            .withValues(alpha: 0.4);
        break;
    }

    // Apply fading for non-current month days
    if (!isCurrentMonth) {
      color = color.withValues(alpha: 0.15);
    }

    final isActive = _isTaskActiveOnDate(task, date);
    if (!isActive) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: isCurrentMonth ? 1.0 : 0.3),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _toggleTaskStatus(task, date);
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          builder: (context) => TaskStatusPickerSheet(
            task: task,
            recurringDate: (task.recurrence != null && task.recurrence!.type != RecurrenceType.none) ? date : null,
          ),
        );
      },
      child: HugeIcon(icon: icon, size: size, color: color),
    );
  }

  Widget _getStatusIconForTile(Task task) {
    return _buildStatusIcon(task: task, date: task.dueDate);
  }



  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'شنبه';
      case DateTime.sunday:
        return 'یکشنبه';
      case DateTime.monday:
        return 'دوشنبه';
      case DateTime.tuesday:
        return 'سه‌شنبه';
      case DateTime.wednesday:
        return 'چهارشنبه';
      case DateTime.thursday:
        return 'پنج‌شنبه';
      case DateTime.friday:
        return 'جمعه';
      default:
        return '';
    }
  }
}

class FadeInOnce extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const FadeInOnce({super.key, required this.child, required this.delay});

  @override
  State<FadeInOnce> createState() => _FadeInOnceState();
}

class _FadeInOnceState extends State<FadeInOnce> with AutomaticKeepAliveClientMixin {
  bool _hasAnimated = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_hasAnimated) return widget.child;

    return widget.child
        .animate(onComplete: (controller) => _hasAnimated = true)
        .fadeIn(duration: 400.ms, delay: widget.delay)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic)
        .blur(begin: const Offset(4, 4), end: Offset.zero);
  }
}
