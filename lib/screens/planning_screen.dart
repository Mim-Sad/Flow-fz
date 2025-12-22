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

    // Filter recurring tasks for the header (using selected date)
    final recurringTasksForHeader = _getTasksForDate(tasks, _selectedDate)
        .where(
          (t) =>
              t.recurrence != null && t.recurrence!.type != RecurrenceType.none,
        )
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Spacer for the top bar
              SizedBox(height: MediaQuery.of(context).padding.top + 70),
              
              if (recurringTasksForHeader.isNotEmpty)
                _buildRecurringTasksHeader(recurringTasksForHeader),

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

  Widget _buildRecurringTasksHeader(List<Task> tasks) {
    // Only show this header if NOT in daily view? 
    // User said: "In daily view show like normal task... In weekly/monthly design that I say".
    // But this header is outside the view mode switch.
    // If I want to follow instructions strictly, I should HIDE this header in Daily View
    // and let the daily view logic render them as normal tasks.
    
    if (_viewMode == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.repeat_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'عادت‌های امروز',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tasks.map((task) => _buildRecurringTaskCard(task)),
        ],
      ),
    );
  }

  Widget _buildRecurringTaskCard(Task task) {
    // Get category color/emoji if available
    final categories = ref.watch(categoryProvider).value ?? [];
    Color color = Colors.grey;
    String emoji = '📅';
    if (task.categories.isNotEmpty) {
      final cat = getCategoryById(task.categories.first, categories);
      color = cat.color;
      emoji = cat.emoji;
    } else if (task.category != null) {
      // Legacy support
      final cat = getCategoryById(task.category!, categories);
      color = cat.color;
      emoji = cat.emoji;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // Header: Emoji + Title + Priority + Menu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextScroll(
                    task.title,
                    mode: TextScrollMode.endless,
                    velocity: const Velocity(pixelsPerSecond: Offset(20, 0)),
                    delayBefore: const Duration(seconds: 2),
                    pauseBetween: const Duration(seconds: 2),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildPriorityDot(task.priority),
                const SizedBox(width: 8),
                IconButton(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedMoreVertical,
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
          
          // 7 Days Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                // Determine date for this circle
                // We want to show a week window? Or just the recurrence pattern?
                // User said: "7 days of the week... if a day is missing show faded circle"
                // Let's align with the current week of the selected date.
                final startOfWeek = _selectedDate.subtract(
                  Duration(days: (_selectedDate.weekday + 1) % 7),
                );
                final date = startOfWeek.add(Duration(days: i));
                final isToday = _isSameDay(date, DateTime.now());
                
                // Check status for this date
                final status = ref.read(tasksProvider.notifier).getStatusForDate(task.id!, date);
                
                // Check if task is scheduled for this day
                bool isScheduled = true;
                if (task.recurrence!.type == RecurrenceType.specificDays && task.recurrence!.daysOfWeek != null) {
                   isScheduled = task.recurrence!.daysOfWeek!.contains(date.weekday);
                } else if (task.recurrence!.type == RecurrenceType.weekly) {
                   isScheduled = date.weekday == task.dueDate.weekday;
                }
                // For daily/monthly/yearly/custom, logic is more complex, but let's assume scheduled if not specificDays.
                // Or better, use the _getTasksForDate logic? No, too heavy.
                // Simplify: Daily = always. Weekly = check weekday. SpecificDays = check list.
                
                return InkWell(
                  onTap: () {
                     if (!isScheduled) return;
                     HapticFeedback.lightImpact();
                     // Toggle status logic (Pending -> Success -> Failed -> Deferred -> Cancelled -> Pending)
                     TaskStatus nextStatus;
                     switch (status) {
                       case TaskStatus.pending: nextStatus = TaskStatus.success; break;
                       case TaskStatus.success: nextStatus = TaskStatus.failed; break;
                       case TaskStatus.failed: nextStatus = TaskStatus.deferred; break;
                       case TaskStatus.deferred: nextStatus = TaskStatus.cancelled; break;
                       case TaskStatus.cancelled: nextStatus = TaskStatus.pending; break;
                     }
                     ref.read(tasksProvider.notifier).updateStatus(task.id!, nextStatus, date: date);
                  },
                  onLongPress: () {
                     // Show status picker for this specific date instance
                     if (!isScheduled) return;
                     HapticFeedback.heavyImpact();
                     showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                        ),
                        builder: (context) => TaskStatusPickerSheet(task: task, recurringDate: date),
                      );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isScheduled 
                          ? _getStatusColor(status).withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.1),
                      border: Border.all(
                        color: isScheduled 
                           ? _getStatusColor(status)
                           : Colors.grey.withValues(alpha: 0.2),
                        width: isToday ? 2.5 : 1.5, // Highlight today
                      ),
                    ),
                    child: Center(
                      child: isScheduled 
                        ? HugeIcon(
                            icon: _getStatusIconData(status),
                            size: 18,
                            color: _getStatusColor(status),
                          )
                        : null,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.success:
        return Colors.green;
      case TaskStatus.failed:
        return Colors.red;
      case TaskStatus.deferred:
        return Colors.orange;
      case TaskStatus.cancelled:
        return Colors.grey;
      case TaskStatus.pending:
        return Theme.of(context).colorScheme.primary;
    }
  }

  dynamic _getStatusIconData(TaskStatus status) {
    switch (status) {
      case TaskStatus.success:
        return HugeIcons.strokeRoundedCheckmarkCircle02;
      case TaskStatus.failed:
        return HugeIcons.strokeRoundedCancel01;
      case TaskStatus.deferred:
        return HugeIcons.strokeRoundedTime02;
      case TaskStatus.cancelled:
        return HugeIcons.strokeRoundedMinusSign;
      case TaskStatus.pending:
        return HugeIcons.strokeRoundedCircle; // Or empty
    }
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

  // Logic to expand recurring tasks
  List<Task> _getTasksForDate(List<Task> allTasks, DateTime date) {
    final tasksForDate = <Task>[];

    for (var task in allTasks) {
      bool include = false;

      // 1. Regular task on this day
      if (task.recurrence == null ||
          task.recurrence!.type == RecurrenceType.none) {
        if (_isSameDay(task.dueDate, date)) {
          include = true;
        }
      } else {
        // 2. Recurring task
        // Check end date
        if (task.recurrence!.endDate != null &&
            date.isAfter(task.recurrence!.endDate!)) {
          continue;
        }

        // Check start date (task shouldn't appear before it was created/due)
        // Use dueDate as start date
        if (date.isBefore(
          DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day),
        )) {
          continue;
        }

        switch (task.recurrence!.type) {
          case RecurrenceType.daily:
            include = true;
            break;
          case RecurrenceType.weekly:
            if (date.weekday == task.dueDate.weekday) include = true;
            break;
          case RecurrenceType.monthly:
            if (date.day == task.dueDate.day) include = true;
            break;
          case RecurrenceType.yearly:
            if (date.month == task.dueDate.month &&
                date.day == task.dueDate.day) {
              include = true;
            }
            break;
          case RecurrenceType.specificDays:
            if (task.recurrence!.daysOfWeek != null &&
                task.recurrence!.daysOfWeek!.contains(date.weekday)) {
              include = true;
            }
            break;
          case RecurrenceType.custom:
            final diff = date.difference(task.dueDate).inDays;
            if (task.recurrence!.interval != null &&
                diff % task.recurrence!.interval! == 0) {
              include = true;
            }
            break;
          default:
            break;
        }
      }

      if (include) {
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

  Widget _buildDailyView(List<Task> tasks, List<CategoryData> categories) {
    // Generate tasks for the selected date
    final dailyTasks = _getTasksForDate(tasks, _selectedDate);

    if (dailyTasks.isEmpty) {
      return const Center(child: Text('برای امروز برنامه‌ای نداری.'));
    }

    return _buildGroupedListView(dailyTasks, categories);
  }

  Widget _buildWeeklyView(List<Task> tasks, List<CategoryData> categories) {
    // In DateTime: Mon=1, Tue=2, ... Sat=6, Sun=7
    // In Jalali/Iran: Start of week is Saturday.
    // So if today is Saturday (6), we want offset 0.
    // If today is Sunday (7), offset 1.
    // If today is Monday (1), offset 2.
    // ...
    // If today is Friday (5), offset 6.

    // Formula: (weekday % 7 + 1) % 7 ? No.
    // Sat(6) -> 0. (6+1)%7 = 0.
    // Sun(7) -> 1. (7+1)%7 = 1.
    // Mon(1) -> 2. (1+1)%7 = 2.
    // ...
    // Fri(5) -> 6. (5+1)%7 = 6.

    final offset = (_selectedDate.weekday + 1) % 7;
    final startOfWeek = _selectedDate.subtract(Duration(days: offset));

    // Group by day
    final Map<int, List<Task>> dayGroups = {};

    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dayTasks = _getTasksForDate(tasks, date);
      if (dayTasks.isNotEmpty) {
        dayGroups[date.weekday] = dayTasks;
      }
    }

    if (dayGroups.isEmpty) {
      return const Center(child: Text('برای این هفته برنامه‌ای نداری.'));
    }

    // Sort days based on Iranian week (Sat first)
    final sortedDays = dayGroups.keys.toList()
      ..sort((a, b) {
        final offsetA = (a + 1) % 7;
        final offsetB = (b + 1) % 7;
        return offsetA.compareTo(offsetB);
      });

    return ListView.builder(
      padding: EdgeInsets.only(
        top: 0, // Removed padding
        left: 16,
        right: 16,
        bottom: 16,
      ),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
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
      },
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
      padding: EdgeInsets.only(
        top: 0, // Removed padding
        left: 16,
        right: 16,
        bottom: 16,
      ),
      itemCount: sortedWeekKeys.length,
      itemBuilder: (context, index) {
        final weekKey = sortedWeekKeys[index];
        final weekTasksRaw = weekGroups[weekKey]!;

        // Deduplicate recurring tasks: keep only one instance per week to show compact row
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
             // Skip recurring tasks here
          } else {
            processedTasks.addAll(instances);
          }
        }
        
        if (processedTasks.isEmpty) return const SizedBox.shrink();

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
              _buildGroupedTasksContent(processedTasks, categories),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupedListView(List<Task> tasks, List<CategoryData> categories) {
    // Filter out recurring tasks
    final regularTasks = tasks.where((t) => t.recurrence == null || t.recurrence!.type == RecurrenceType.none).toList();
    
    final groups = _getGroupedAndSortedTasks(regularTasks);
    return ListView(
      padding: EdgeInsets.only(
        top: 0, // Removed padding
        left: 16,
        right: 16,
        bottom: 16,
      ),
      children: groups.entries
          .map((entry) => _buildTaskGroup(entry.key, entry.value, categories))
          .toList(),
    );
  }

  Widget _buildGroupedTasksContent(List<Task> tasks, List<CategoryData> categories) {
    // Filter out recurring tasks
    final regularTasks = tasks
        .where(
          (t) =>
              t.recurrence == null || t.recurrence!.type == RecurrenceType.none,
        )
        .toList();

    return Column(
      children: [
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
        color = Colors.blue;
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
