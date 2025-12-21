import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';

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
      final startOfSelected = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
      final startOfNow = now.subtract(Duration(days: now.weekday % 7));
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
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
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

  Widget _buildRangePicker() {
    String label = '';
    final jalali = Jalali.fromDateTime(_selectedDate);

    if (_viewMode == 0) {
      label = _formatJalali(jalali);
    } else if (_viewMode == 1) {
      final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      final jStart = Jalali.fromDateTime(startOfWeek);
      final jEnd = Jalali.fromDateTime(endOfWeek);
      label = _toPersianDigit('${jStart.day} ${jStart.formatter.mN} - ${jEnd.day} ${jEnd.formatter.mN}');
    } else {
      label = _toPersianDigit('${jalali.formatter.mN} ${jalali.year}');
    }

    final theme = Theme.of(context);
    final navigationBarColor = theme.brightness == Brightness.light
        ? ElevationOverlay.applySurfaceTint(
            theme.colorScheme.surface,
            theme.colorScheme.surfaceTint,
            3,
          )
        : ElevationOverlay.applySurfaceTint(
            theme.colorScheme.surface,
            theme.colorScheme.surfaceTint,
            3,
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: navigationBarColor,
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
    final dailyTasks = tasks.where((t) => _isSameDay(t.dueDate, _selectedDate)).toList();
    if (dailyTasks.isEmpty) {
      return const Center(child: Text('برای امروز برنامه‌ای نداری.'));
    }

    return _buildGroupedListView(dailyTasks);
  }

  Widget _buildWeeklyView(List<Task> tasks) {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    
    final weeklyTasks = tasks.where((t) => 
      (t.dueDate.isAfter(startOfWeek) || _isSameDay(t.dueDate, startOfWeek)) && 
      t.dueDate.isBefore(endOfWeek)
    ).toList();

    if (weeklyTasks.isEmpty) {
      return const Center(child: Text('برای این هفته برنامه‌ای نداری.'));
    }

    // Group by day
    final Map<int, List<Task>> dayGroups = {};
    for (var task in weeklyTasks) {
      final day = task.dueDate.weekday;
      dayGroups.putIfAbsent(day, () => []).add(task);
    }

    final sortedDays = dayGroups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
    final monthlyTasks = tasks.where((t) => 
      t.dueDate.year == _selectedDate.year && 
      t.dueDate.month == _selectedDate.month
    ).toList();

    if (monthlyTasks.isEmpty) {
      return const Center(child: Text('برای این ماه برنامه‌ای نداری.'));
    }

    // Group by week of month
    final Map<int, List<Task>> weekGroups = {};
    for (var task in monthlyTasks) {
      final week = ((task.dueDate.day - 1) / 7).floor();
      weekGroups.putIfAbsent(week, () => []).add(task);
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
      final category = task.category ?? 'بدون دسته‌بندی';
      grouped.putIfAbsent(category, () => []).add(task);
    }

    // Sort categories: put "بدون دسته‌بندی" at the end
    final sortedKeys = grouped.keys.toList()..sort((a, b) {
      if (a == 'بدون دسته‌بندی') return 1;
      if (b == 'بدون دسته‌بندی') return -1;
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

  Widget _buildTaskGroup(String title, List<Task> tasks) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              ),
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
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 14,
                  decoration: task.status == TaskStatus.success ? TextDecoration.lineThrough : null,
                  color: task.status == TaskStatus.success 
                      ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            _buildPriorityDot(task.priority),
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
        ref.read(tasksProvider.notifier).updateStatus(
          task.id!,
          task.status == TaskStatus.success ? TaskStatus.pending : TaskStatus.success,
        );
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
        ref.read(tasksProvider.notifier).updateStatus(task.id!, status);
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

  Widget _getStatusIconSmall(TaskStatus status) {
    switch (status) {
      case TaskStatus.success:
        return Icon(Icons.check_circle_rounded, size: 18, color: Colors.green.shade400);
      case TaskStatus.failed:
        return Icon(Icons.cancel_rounded, size: 18, color: Colors.red.shade400);
      case TaskStatus.cancelled:
        return Icon(Icons.block_rounded, size: 18, color: Colors.grey.shade400);
      case TaskStatus.deferred:
        return Icon(Icons.history_rounded, size: 18, color: Colors.orange.shade400);
      case TaskStatus.pending:
        return Icon(Icons.radio_button_unchecked_rounded, 
          size: 18, 
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        );
    }
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
