import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';
import 'package:shamsi_date/shamsi_date.dart';

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  int _viewMode = 0; // 0: Daily, 1: Weekly, 2: Monthly
  DateTime _selectedDate = DateTime.now();

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
      label = '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}';
    } else if (_viewMode == 1) {
      final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      final jStart = Jalali.fromDateTime(startOfWeek);
      final jEnd = Jalali.fromDateTime(endOfWeek);
      label = '${jStart.month}/${jStart.day} - ${jEnd.month}/${jEnd.day}';
    } else {
      label = '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}';
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
            onPressed: () => _changeRange(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (!_isCurrentRange())
                TextButton(
                  onPressed: _jumpToCurrent,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _viewMode == 0 ? 'امروز' : (_viewMode == 1 ? 'هفته جاری' : 'ماه جاری'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () => _changeRange(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyView(List<Task> tasks) {
    final dailyTasks = tasks.where((t) => _isSameDay(t.dueDate, _selectedDate)).toList();

    if (dailyTasks.isEmpty) {
      return const Center(child: Text('برای این روز برنامه‌ای نداری.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTaskGroup('تسک‌های امروز', dailyTasks),
      ],
    );
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
    final Map<int, List<Task>> grouped = {};
    for (var task in weeklyTasks) {
      final day = task.dueDate.weekday;
      grouped.putIfAbsent(day, () => []).add(task);
    }

    final sortedDays = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final dayTasks = grouped[day]!;
        final dayDate = dayTasks.first.dueDate;
        final jDate = Jalali.fromDateTime(dayDate);
        final dayName = _getDayName(dayDate.weekday);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildTaskGroup('$dayName - ${jDate.day} ${jDate.formatter.mN}', dayTasks),
        );
      },
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'دوشنبه';
      case DateTime.tuesday: return 'سه‌شنبه';
      case DateTime.wednesday: return 'چهارشنبه';
      case DateTime.thursday: return 'پنج‌شنبه';
      case DateTime.friday: return 'جمعه';
      case DateTime.saturday: return 'شنبه';
      case DateTime.sunday: return 'یکشنبه';
      default: return '';
    }
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
    final Map<int, List<Task>> grouped = {};
    for (var task in monthlyTasks) {
      final week = ((task.dueDate.day - 1) / 7).floor();
      grouped.putIfAbsent(week, () => []).add(task);
    }

    final sortedWeeks = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedWeeks.length,
      itemBuilder: (context, index) {
        final week = sortedWeeks[index];
        final weekTasks = grouped[week]!;
        
        // Find date range for this week
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
          child: _buildTaskGroup(
            'هفته ${week + 1} (${jMin.day} تا ${jMax.day} ${jMin.formatter.mN})', 
            weekTasks
          ),
        );
      },
    );
  }

  Widget _buildTaskGroup(String title, List<Task> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            ),
          ),
        ),
        ...tasks.map((task) => _buildCompactTaskRow(task)),
        const SizedBox(height: 8),
      ],
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildCompactTaskRow(Task task) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _getStatusIconSmall(task.status),
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
          if (task.priority == TaskPriority.high)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
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
}
