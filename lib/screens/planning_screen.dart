import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:text_scroll/text_scroll.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../models/category_data.dart';
import 'add_task_screen.dart';

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
      final startOfSelected = _selectedDate.subtract(Duration(days: (_selectedDate.weekday + 1) % 7));
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
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta, 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when completions change
    // We listen to the notifier which updates state when completions update (via our hack)
    // Ideally we should listen to a completions provider too if separated.
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('روزانه'), icon: Icon(Icons.today)),
                ButtonSegment(value: 1, label: Text('هفتگی'), icon: Icon(Icons.view_week)),
                ButtonSegment(value: 2, label: Text('ماهانه'), icon: Icon(Icons.calendar_month)),
              ],
              selected: {_viewMode},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _viewMode = newSelection.first;
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (states) {
                    if (states.contains(WidgetState.selected)) {
                      return Theme.of(context).colorScheme.secondaryContainer;
                    }
                    return Colors.transparent;
                  },
                ),
                side: WidgetStateProperty.all(BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                )),
              ),
            ),
          ),
          Expanded(
            child: _buildMainContent(tasks),
          ),
          _buildRangePicker(),
        ],
      ),
    );
  }

  Widget _buildMainContent(List<Task> tasks) {
    if (_viewMode == 0) {
      return _buildDailyView(tasks);
    } else if (_viewMode == 1) {
      return _buildWeeklyView(tasks);
    } else {
      return _buildMonthlyView(tasks);
    }
  }
  
  // Logic to expand recurring tasks
  List<Task> _getTasksForDate(List<Task> allTasks, DateTime date) {
    final tasksForDate = <Task>[];
    
    for (var task in allTasks) {
      bool include = false;
      
      // 1. Regular task on this day
      if (task.recurrence == null || task.recurrence!.type == RecurrenceType.none) {
        if (_isSameDay(task.dueDate, date)) {
          include = true;
        }
      } else {
        // 2. Recurring task
        // Check end date
        if (task.recurrence!.endDate != null && date.isAfter(task.recurrence!.endDate!)) {
          continue;
        }
        
        // Check start date (task shouldn't appear before it was created/due)
        // Use dueDate as start date
        if (date.isBefore(DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day))) {
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
            if (date.month == task.dueDate.month && date.day == task.dueDate.day) include = true;
            break;
          case RecurrenceType.specificDays:
            if (task.recurrence!.daysOfWeek != null && 
                task.recurrence!.daysOfWeek!.contains(date.weekday)) {
              include = true;
            }
            break;
          case RecurrenceType.custom:
             final diff = date.difference(task.dueDate).inDays;
             if (task.recurrence!.interval != null && diff % task.recurrence!.interval! == 0) {
               include = true;
             }
             break;
          default:
            break;
        }
      }
      
      if (include) {
        TaskStatus status;
        if (task.recurrence != null && task.recurrence!.type != RecurrenceType.none) {
           // Get status for this specific date for recurring tasks
           status = ref.read(tasksProvider.notifier).getStatusForDate(task.id!, date);
        } else {
           // For regular tasks, use the actual task status
           status = task.status;
        }

        // Create a virtual copy for display
        tasksForDate.add(task.copyWith(
          dueDate: date,
          status: status,
        ));
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
      final startOfWeek = _selectedDate.subtract(Duration(days: (_selectedDate.weekday + 1) % 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      final jStart = Jalali.fromDateTime(startOfWeek);
      final jEnd = Jalali.fromDateTime(endOfWeek);
      label = _toPersianDigit('${jStart.day} ${jStart.formatter.mN} - ${jEnd.day} ${jEnd.formatter.mN}');
    } else {
      label = _toPersianDigit('${jalali.formatter.mN} ${jalali.year}');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _changeRange(-1);
            },
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _selectDate();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  _formatMiladiSmall(_selectedDate),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                if (!_isCurrentRange())
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _jumpToCurrent();
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _viewMode == 0 ? 'برو به امروز' : (_viewMode == 1 ? 'برو به هفته جاری' : 'برو به ماه جاری'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _changeRange(1);
            },
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyView(List<Task> tasks) {
    // Generate tasks for the selected date
    final dailyTasks = _getTasksForDate(tasks, _selectedDate);
    
    if (dailyTasks.isEmpty) {
      return const Center(child: Text('برای امروز برنامه‌ای نداری.'));
    }

    return _buildGroupedListView(dailyTasks);
  }

  Widget _buildWeeklyView(List<Task> tasks) {
    final startOfWeek = _selectedDate.subtract(Duration(days: (_selectedDate.weekday + 1) % 7));
    // final endOfWeek = startOfWeek.add(const Duration(days: 7));
    
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

    final sortedDays = dayGroups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final dayTasks = dayGroups[day]!;
        final dayDate = dayTasks.first.dueDate; // Since we forced dueDate in _getTasksForDate
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
                  _toPersianDigit('$dayName - ${jDate.day} ${jDate.formatter.mN}'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              _buildGroupedTasksContent(dayTasks),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthlyView(List<Task> tasks) {
    // We need to iterate all days in month
    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
    
    // Group by week of month
    final Map<int, List<Task>> weekGroups = {};
    bool hasAnyTask = false;
    
    for (int i = 0; i < daysInMonth; i++) {
      final date = startOfMonth.add(Duration(days: i));
      final dayTasks = _getTasksForDate(tasks, date);
      
      if (dayTasks.isNotEmpty) {
        hasAnyTask = true;
        final week = ((date.day - 1) / 7).floor();
        weekGroups.putIfAbsent(week, () => []).addAll(dayTasks);
      }
    }

    if (!hasAnyTask) {
      return const Center(child: Text('برای این ماه برنامه‌ای نداری.'));
    }

    final sortedWeeks = weekGroups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedWeeks.length,
      itemBuilder: (context, index) {
        final week = sortedWeeks[index];
        final weekTasks = weekGroups[week]!;
        
        DateTime minDate = weekTasks.first.dueDate;
        DateTime maxDate = weekTasks.first.dueDate;
        for (var t in weekTasks) {
          if (t.dueDate.isBefore(minDate)) minDate = t.dueDate;
          if (t.dueDate.isAfter(maxDate)) maxDate = t.dueDate;
        }
        final jMin = Jalali.fromDateTime(minDate);
        final jMax = Jalali.fromDateTime(maxDate);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: Text(
                  _toPersianDigit('هفته ${week + 1} (${jMin.day} تا ${jMax.day} ${jMin.formatter.mN})'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              _buildGroupedTasksContent(weekTasks),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupedListView(List<Task> tasks) {
    final groups = _getGroupedAndSortedTasks(tasks);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: groups.entries.map((entry) => _buildTaskGroup(entry.key, entry.value)).toList(),
    );
  }

  Widget _buildGroupedTasksContent(List<Task> tasks) {
    final groups = _getGroupedAndSortedTasks(tasks);
    return Column(
      children: groups.entries.map((entry) => _buildTaskGroup(entry.key, entry.value)).toList(),
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
    final sortedKeys = grouped.keys.toList()..sort((a, b) {
      if (a == 'combined') return -1;
      if (b == 'combined') return 1;
      if (a == 'uncategorized') return 1;
      if (b == 'uncategorized') return -1;
      return a.compareTo(b);
    });

    final Map<String, List<Task>> result = {};
    for (var key in sortedKeys) {
      final list = grouped[key]!;
      // Sort tasks within category: High priority first, then move cancelled to bottom
      list.sort((a, b) {
        // Move cancelled to bottom
        if (a.status == TaskStatus.cancelled && b.status != TaskStatus.cancelled) return 1;
        if (a.status != TaskStatus.cancelled && b.status == TaskStatus.cancelled) return -1;
        
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

  Widget _buildTaskGroup(String key, List<Task> tasks) {
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
      final catData = getCategoryById(key);
      title = catData.label;
      emoji = catData.emoji;
      color = catData.color;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
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
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...tasks.map((task) => _buildCompactTaskRow(task)),
          const SizedBox(height: 8),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildCompactTaskRow(Task task) {
    final isCancelled = task.status == TaskStatus.cancelled;
    return Opacity(
      opacity: isCancelled ? 0.6 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            _getStatusIconForTile(task),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onLongPress: () => _showTaskOptions(context, task),
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
                        velocity: const Velocity(pixelsPerSecond: Offset(30, 0)),
                        delayBefore: const Duration(seconds: 2),
                        pauseBetween: const Duration(seconds: 2),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 14,
                          decoration: task.status == TaskStatus.success ? TextDecoration.lineThrough : null,
                          color: task.status == TaskStatus.success 
                              ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (task.recurrence != null && task.recurrence!.type != RecurrenceType.none)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.repeat_rounded, size: 14, color: Colors.grey),
              ),
            _buildPriorityDot(task.priority),
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
      builder: (context) => Container(
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
              leading: const Icon(Icons.edit_outlined),
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
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('تغییر وضعیت'),
              onTap: () {
                Navigator.pop(context);
                _showStatusPicker(context, task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                ref.read(tasksProvider.notifier).deleteTask(task.id!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusIconForTile(Task task) {
    IconData icon;
    Color color;

    switch (task.status) {
      case TaskStatus.success: icon = Icons.check_circle_rounded; color = Colors.green; break;
      case TaskStatus.failed: icon = Icons.cancel_rounded; color = Colors.red; break;
      case TaskStatus.cancelled: icon = Icons.block_rounded; color = Colors.grey; break;
      case TaskStatus.deferred: icon = Icons.history_rounded; color = Colors.orange; break;
      case TaskStatus.pending: icon = Icons.radio_button_unchecked_rounded; color = Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4); break;
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        // If it's a recurring task (virtual instance), we must pass the date
        if (task.recurrence != null && task.recurrence!.type != RecurrenceType.none) {
           ref.read(tasksProvider.notifier).updateStatus(
            task.id!,
            task.status == TaskStatus.success ? TaskStatus.pending : TaskStatus.success,
            date: task.dueDate, // Use the virtual date
          );
        } else {
           ref.read(tasksProvider.notifier).updateStatus(
            task.id!,
            task.status == TaskStatus.success ? TaskStatus.pending : TaskStatus.success,
          );
        }
      },
      onLongPress: () => _showStatusPicker(context, task),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  void _showStatusPicker(BuildContext context, Task task) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تغییر وضعیت تسک',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statusIcon(context, task, TaskStatus.success, Icons.check_circle_rounded, 'موفق', Colors.green),
                _statusIcon(context, task, TaskStatus.failed, Icons.cancel_rounded, 'ناموفق', Colors.red),
                _statusIcon(context, task, TaskStatus.deferred, Icons.history_rounded, 'تعویق', Colors.orange),
                _statusIcon(context, task, TaskStatus.cancelled, Icons.block_rounded, 'لغو', Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(BuildContext context, Task task, TaskStatus status, IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        
        // Handle recurrence
        if (task.recurrence != null && task.recurrence!.type != RecurrenceType.none) {
           ref.read(tasksProvider.notifier).updateStatus(
             task.id!, 
             status,
             date: task.dueDate
           );
        } else {
           ref.read(tasksProvider.notifier).updateStatus(task.id!, status);
        }
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPriorityDot(TaskPriority priority) {
    Color color;
    switch (priority) {
      case TaskPriority.high: color = Colors.red; break;
      case TaskPriority.medium: color = Colors.blue; break;
      case TaskPriority.low: color = Colors.green; break;
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
