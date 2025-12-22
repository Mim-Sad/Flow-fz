import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
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
      return _selectedDate.year == now.year && _selectedDate.month == now.month;
    }
  }

  void _changeRange(int delta) {
    setState(() {
      if (_viewMode == 0) {
        _selectedDate = _selectedDate.add(Duration(days: delta));
      } else if (_viewMode == 1) {
        _selectedDate = _selectedDate.add(Duration(days: delta * 7));
      } else {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + delta,
          1,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
            alpha: 0.5,
          ),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
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
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // List of recurring tasks
          ...tasks.map((task) => _buildRecurringTaskRow(task)),
          const SizedBox(height: 8),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildRecurringTaskRow(Task task) {
    final isCancelled = task.status == TaskStatus.cancelled;
    
    // Determine the status icon color/icon
    // We need to show the status for the selected date? 
    // Or for the task itself? 
    // In planning screen, we usually view a specific date.
    // If we are in Daily/Weekly/Monthly, _getTasksForDate has already created virtual copies with correct status.
    // So we can use task.status.
    
    return Opacity(
      opacity: isCancelled ? 0.6 : 1.0,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Status Icon (Right side in RTL, so first child)
             _getStatusIconForTile(task),
             
             const SizedBox(width: 12),
             
             // Task Title
            Expanded(
              child: InkWell(
                onTap: () {}, // Maybe show details?
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
                    fontSize: 14,
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
            ),
            
            // Priority
            _buildPriorityDot(task.priority),
            
            const SizedBox(width: 8),
            
            // Menu
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedMoreHorizontal,
                size: 18,
                color: Colors.grey,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _showTaskOptions(context, task),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(List<Task> tasks, List<CategoryData> categories) {
    if (_viewMode == 0) {
      return _buildDailyView(tasks, categories);
    } else if (_viewMode == 1) {
      return _buildWeeklyView(tasks, categories);
    } else {
      return _buildMonthlyView(tasks, categories);
    }
  }

  bool _isTaskActiveOnDate(Task task, DateTime date) {
    if (task.recurrence == null ||
        task.recurrence!.type == RecurrenceType.none) {
      return _isSameDay(task.dueDate, date);
    }

    // Check end date
    if (task.recurrence!.endDate != null &&
        date.isAfter(task.recurrence!.endDate!)) {
      return false;
    }

    // Check start date (task shouldn't appear before it was created/due)
    if (date.isBefore(
      DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day),
    )) {
      return false;
    }

    switch (task.recurrence!.type) {
      case RecurrenceType.daily:
        return true;
      case RecurrenceType.weekly:
        return date.weekday == task.dueDate.weekday;
      case RecurrenceType.monthly:
        return date.day == task.dueDate.day;
      case RecurrenceType.yearly:
        return date.month == task.dueDate.month &&
            date.day == task.dueDate.day;
      case RecurrenceType.specificDays:
        return task.recurrence!.daysOfWeek != null &&
            task.recurrence!.daysOfWeek!.contains(date.weekday);
      case RecurrenceType.custom:
        final diff = date.difference(task.dueDate).inDays;
        return task.recurrence!.interval != null &&
            diff % task.recurrence!.interval! == 0;
      default:
        return false;
    }
  }

  // Logic to expand recurring tasks
  List<Task> _getTasksForDate(List<Task> allTasks, DateTime date) {
    final tasksForDate = <Task>[];

    for (var task in allTasks) {
      if (_isTaskActiveOnDate(task, date)) {
        TaskStatus status;
        if (task.recurrence != null &&
            task.recurrence!.type != RecurrenceType.none) {
          // Get status for this specific date for recurring tasks
          status = ref
              .read(tasksProvider.notifier)
              .getStatusForDate(task.id!, date);
        } else {
          // For regular tasks, use the actual task status
          status = task.status;
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

  Widget _buildWeeklyRecurringTaskCard(Task task, DateTime startOfWeek) {
    // startOfWeek should be the Saturday of the week
    final days = List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task Title and Menu
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedRepeat,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedMoreHorizontal,
                  size: 18,
                  color: Colors.grey,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showTaskOptions(context, task),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 7 Circles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((date) {
              final isActive = _isTaskActiveOnDate(task, date);
              final status = isActive 
                  ? ref.read(tasksProvider.notifier).getStatusForDate(task.id!, date)
                  : TaskStatus.pending;
                  
              return Column(
                children: [
                  Text(
                    _getDayName(date.weekday)[0], // First letter of day name
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: isActive ? () {
                      HapticFeedback.lightImpact();
                      final nextStatus = status == TaskStatus.success 
                          ? TaskStatus.pending 
                          : TaskStatus.success;
                      ref.read(tasksProvider.notifier).updateStatus(task.id!, nextStatus, date: date);
                    } : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? (status == TaskStatus.success
                                ? Colors.green
                                : Theme.of(context).colorScheme.surfaceContainerHighest)
                            : Colors.transparent,
                        border: isActive
                            ? Border.all(
                                color: status == TaskStatus.success
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                              )
                            : null,
                      ),
                      child: isActive && status == TaskStatus.success
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : (!isActive 
                              ? Center(
                                  child: Container(
                                    width: 4, 
                                    height: 4, 
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.outlineVariant,
                                      shape: BoxShape.circle
                                    )
                                  )
                                ) 
                              : null),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyView(List<Task> tasks, List<CategoryData> categories) {
    // Generate tasks for the selected date
    final dailyTasks = _getTasksForDate(tasks, _selectedDate);

    if (dailyTasks.isEmpty) {
      return const Center(child: Text('برای امروز برنامه‌ای نداری.'));
    }

    return _buildGroupedListView(dailyTasks, categories);
  }

  Widget _buildWeeklyView(List<Task> tasks, List<CategoryData> categories) {
    final offset = (_selectedDate.weekday + 1) % 7;
    final startOfWeek = _selectedDate.subtract(Duration(days: offset));

    // Identify recurring tasks active in this week
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

    // Group regular tasks by day
    final Map<int, List<Task>> dayGroups = {};

    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dayTasks = _getTasksForDate(tasks, date);
      final regularTasks = dayTasks
          .where(
            (t) =>
                t.recurrence == null || t.recurrence!.type == RecurrenceType.none,
          )
          .toList();

      if (regularTasks.isNotEmpty) {
        dayGroups[date.weekday] = regularTasks;
      }
    }

    if (dayGroups.isEmpty && recurringTasksForWeek.isEmpty) {
      return const Center(child: Text('برای این هفته برنامه‌ای نداری.'));
    }

    // Sort days based on Iranian week (Sat first)
    final sortedDays = dayGroups.keys.toList()
      ..sort((a, b) {
        final offsetA = (a + 1) % 7;
        final offsetB = (b + 1) % 7;
        return offsetA.compareTo(offsetB);
      });

    return ListView(
      padding: const EdgeInsets.only(
        top: 0,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      children: [
        // Recurring Tasks Section
        if (recurringTasksForWeek.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Text('🔁', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  'تسک‌های تکرار شونده',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          ...recurringTasksForWeek.map(
            (task) => _buildWeeklyRecurringTaskCard(task, startOfWeek),
          ),
          const SizedBox(height: 16),
        ],

        // Daily Lists
        ...sortedDays.map((day) {
          final dayTasks = dayGroups[day]!;
          final dayDate = dayTasks.first.dueDate;
          final jDate = Jalali.fromDateTime(dayDate);
          final dayName = _getDayName(dayDate.weekday);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: Text(
                    _toPersianDigit(
                      '$dayName - ${jDate.day} ${jDate.formatter.mN}',
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                _buildGroupedTasksContent(dayTasks, categories),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMonthlyView(List<Task> tasks, List<CategoryData> categories) {
    // We need to iterate all days in month
    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(
      _selectedDate.year,
      _selectedDate.month,
    );

    // Group by week of month
    final Map<int, List<Task>> weekGroups = {};
    bool hasAnyTask = false;

    for (int i = 0; i < daysInMonth; i++) {
      final date = startOfMonth.add(Duration(days: i));
      final dayTasks = _getTasksForDate(tasks, date);

      if (dayTasks.isNotEmpty) {
        hasAnyTask = true;
        // Group by start of the week (Saturday based)
        final offset = (date.weekday + 1) % 7;
        final startOfWeek = date.subtract(Duration(days: offset));
        final weekKey = startOfWeek.millisecondsSinceEpoch;

        weekGroups.putIfAbsent(weekKey, () => []).addAll(dayTasks);
      }
    }

    if (!hasAnyTask) {
      return const Center(child: Text('برای این ماه برنامه‌ای نداری.'));
    }

    final sortedWeekKeys = weekGroups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: 0, // Removed padding
        left: 16,
        right: 16,
        bottom: 16,
      ),
      itemCount: sortedWeekKeys.length,
      itemBuilder: (context, index) {
        final weekKey = sortedWeekKeys[index];
        final weekTasksRaw = weekGroups[weekKey]!;

        // Extract unique recurring tasks
        final recurringTasksMap = <int, Task>{};
        for (var t in weekTasksRaw) {
          if (t.recurrence != null &&
              t.recurrence!.type != RecurrenceType.none) {
            recurringTasksMap[t.id!] = t;
          }
        }
        final recurringTasksForWeek = recurringTasksMap.values.toList();

        // Deduplicate regular tasks
        final Map<int, List<Task>> uniqueTasks = {};
        for (var t in weekTasksRaw) {
          if (t.id != null) {
            uniqueTasks.putIfAbsent(t.id!, () => []).add(t);
          }
        }

        final List<Task> processedTasks = [];
        for (var entry in uniqueTasks.entries) {
          final instances = entry.value;
          final first = instances.first;
          if (first.recurrence != null &&
              first.recurrence!.type != RecurrenceType.none) {
            // Skip recurring tasks here (handled separately)
          } else {
            processedTasks.addAll(instances);
          }
        }

        if (processedTasks.isEmpty && recurringTasksForWeek.isEmpty) {
          return const SizedBox.shrink();
        }

        final weekStart = DateTime.fromMillisecondsSinceEpoch(weekKey);
        final weekEnd = weekStart.add(const Duration(days: 6));

        final jStart = Jalali.fromDateTime(weekStart);
        final jEnd = Jalali.fromDateTime(weekEnd);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: Text(
                  _toPersianDigit(
                    'هفته: ${jStart.day} ${jStart.formatter.mN} - ${jEnd.day} ${jEnd.formatter.mN}',
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              if (recurringTasksForWeek.isNotEmpty) ...[
                ...recurringTasksForWeek.map(
                  (task) => _buildWeeklyRecurringTaskCard(task, weekStart),
                ),
                const SizedBox(height: 8),
              ],
              _buildGroupedTasksContent(processedTasks, categories),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupedListView(List<Task> tasks, List<CategoryData> categories) {
    // Filter out recurring tasks
    final recurringTasks = tasks.where((t) => t.recurrence != null && t.recurrence!.type != RecurrenceType.none).toList();
    final regularTasks = tasks.where((t) => t.recurrence == null || t.recurrence!.type == RecurrenceType.none).toList();
    
    final groups = _getGroupedAndSortedTasks(regularTasks);
    
    return ListView(
      padding: EdgeInsets.only(
        top: 0, // Removed padding
        left: 16,
        right: 16,
        bottom: 16,
      ),
      children: [
        if (recurringTasks.isNotEmpty)
          _buildRecurringTaskGroup(recurringTasks),
        ...groups.entries
          .map((entry) => _buildTaskGroup(entry.key, entry.value, categories)),
      ],
    );
  }

  Widget _buildGroupedTasksContent(List<Task> tasks, List<CategoryData> categories) {
    // Filter out recurring tasks
    final recurringTasks = tasks
        .where(
          (t) =>
              t.recurrence != null && t.recurrence!.type != RecurrenceType.none,
        )
        .toList();
    final regularTasks = tasks
        .where(
          (t) =>
              t.recurrence == null || t.recurrence!.type == RecurrenceType.none,
        )
        .toList();

    return Column(
      children: [
        if (recurringTasks.isNotEmpty)
          _buildRecurringTaskGroup(recurringTasks),
        if (regularTasks.isNotEmpty)
          ..._getGroupedAndSortedTasks(
            regularTasks,
          ).entries.map((e) => _buildTaskGroup(e.key, e.value, categories)),
      ],
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
      emoji = '🧩';
      color = Colors.purple;
    } else if (key == 'uncategorized') {
      title = 'بدون دسته‌بندی';
      emoji = '📂';
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
            alpha: 0.5,
          ), // Unified border color
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
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
                      fontSize: 13,
                      color: color, // Title keeps category color
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Reorderable List of Tasks
          // We use ReorderableListView with shrinkWrap: true. 
          // Note: ReorderableListView requires a scroll controller or shrinkWrap inside ListView.
          // Since we are inside a ListView, we should use shrinkWrap.
          if (tasks.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final items = [...tasks];
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                
                // Update tasks via provider
                ref.read(tasksProvider.notifier).reorderTasks(items);
                HapticFeedback.mediumImpact();
              },
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Padding(
                  key: ValueKey(task.id),
                  padding: EdgeInsets.zero, // Padding handled inside
                  child: _buildCompactTaskRow(task),
                );
              },
            ),

          const SizedBox(height: 8),

          // Progress Bar
          if (total > 0)
            Container(
              height: 4,
              width: double.infinity,
              alignment: Alignment
                  .centerLeft, // RTL alignment for progress? No, linear progress usually LTR or RTL based on locale.
              // LinearProgressIndicator handles directionality.
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withValues(alpha: 0.1),
                color: color,
                minHeight: 4,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            _getStatusIconForTile(task),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onLongPress: () => {}, // Handled by ReorderableListView
                child: Row(
                  children: [
                    if (task.taskEmoji != null) ...[
                      Text(task.taskEmoji!),
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
                          fontSize: 14,
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
            if (task.recurrence != null &&
                task.recurrence!.type != RecurrenceType.none)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedRepeat,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _toPersianDigit(
                        task.recurrence!.type == RecurrenceType.daily
                            ? 'هر روز'
                            : 'هفتگی',
                      ),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            _buildPriorityDot(task.priority),
            const SizedBox(width: 8),
            // 3-Dots Menu
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedMoreHorizontal,
                size: 18,
                color: Colors.grey,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _showTaskOptions(context, task),
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

  Widget _getStatusIconForTile(Task task) {
    dynamic icon;
    Color color;

    switch (task.status) {
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
        color = Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
        break;
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        // If it's a recurring task (virtual instance), we must pass the date
        if (task.recurrence != null &&
            task.recurrence!.type != RecurrenceType.none) {
          final currentStatus = ref.read(tasksProvider.notifier).getStatusForDate(task.id!, task.dueDate);
          final nextStatus = currentStatus == TaskStatus.success ? TaskStatus.pending : TaskStatus.success;
          ref.read(tasksProvider.notifier).updateStatus(task.id!, nextStatus, date: task.dueDate);
        } else {
          ref.read(tasksProvider.notifier).updateStatus(
            task.id!,
            task.status == TaskStatus.success ? TaskStatus.pending : TaskStatus.success,
          );
        }
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
            recurringDate: (task.recurrence != null && task.recurrence!.type != RecurrenceType.none) ? task.dueDate : null,
          ),
        );
      },
      child: HugeIcon(icon: icon, size: 24, color: color),
    );
  }

  Widget _buildPriorityDot(TaskPriority priority) {
    Color color;
    switch (priority) {
      case TaskPriority.high:
        color = Colors.red;
        break;
      case TaskPriority.medium:
        color = Theme.of(context).colorScheme.primary;
        break;
      case TaskPriority.low:
        color = Colors.green;
        break;
    }
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
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
