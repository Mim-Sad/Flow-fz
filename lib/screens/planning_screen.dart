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
import '../widgets/postpone_dialog.dart';
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
  final Set<String> _animatedKeys = {};

  String _toPersianDigit(String input) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    String result = input;
    for (int i = 0; i < englishDigits.length; i++) {
      result = result.replaceAll(englishDigits[i], persianDigits[i]);
    }
    return result;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'شنبه';
      case DateTime.sunday:
        return 'یک‌شنبه';
      case DateTime.monday:
        return 'دو‌شنبه';
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

  String _formatJalali(Jalali j) {
    String weekday = j.formatter.wN;
    if (weekday == 'یک شنبه') weekday = 'یک‌شنبه';
    if (weekday == 'دو شنبه') weekday = 'دو‌شنبه';
    if (weekday == 'سه شنبه') weekday = 'سه‌شنبه';
    if (weekday == 'چهار شنبه') weekday = 'چهار‌شنبه';
    if (weekday == 'پنج شنبه') weekday = 'پنج‌شنبه';
    return _toPersianDigit('$weekday ${j.day} ${j.formatter.mN} ${j.year}');
  }

  String _formatMiladi(DateTime dt, int viewMode) {
    if (viewMode == 0) {
      return intl.DateFormat('d MMMM yyyy', 'en_US').format(dt);
    } else if (viewMode == 1) {
      final startOfWeek = dt.subtract(
        Duration(days: (dt.weekday + 1) % 7),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      if (startOfWeek.year == endOfWeek.year) {
        return '${intl.DateFormat('d MMM', 'en_US').format(startOfWeek)} - ${intl.DateFormat('d MMM yyyy', 'en_US').format(endOfWeek)}';
      } else {
        return '${intl.DateFormat('d MMM yyyy', 'en_US').format(startOfWeek)} - ${intl.DateFormat('d MMM yyyy', 'en_US').format(endOfWeek)}';
      }
    } else {
      final jalali = Jalali.fromDateTime(dt);
      final jStart = jalali.copy(day: 1);
      final jEnd = jalali.copy(day: jalali.monthLength);
      final dStart = jStart.toDateTime();
      final dEnd = jEnd.toDateTime();

      if (dStart.year == dEnd.year) {
        if (dStart.month == dEnd.month) {
          return intl.DateFormat('MMMM yyyy', 'en_US').format(dStart);
        } else {
          return '${intl.DateFormat('MMM', 'en_US').format(dStart)} - ${intl.DateFormat('MMM yyyy', 'en_US').format(dEnd)}';
        }
      } else {
        return '${intl.DateFormat('MMM yyyy', 'en_US').format(dStart)} - ${intl.DateFormat('MMM yyyy', 'en_US').format(dEnd)}';
      }
    }
  }

  Future<void> _selectDate() async {
    final Jalali? picked = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(_selectedDate),
      firstDate: Jalali(1300, 1, 1),
      lastDate: Jalali(1500, 1, 1),
      helpText: 'انتخاب تاریخ برنامه‌ریزی',
    );
    if (picked != null) {
      setState(() {
        _animatedKeys.clear();
        _selectedDate = picked.toDateTime();
      });
    }
  }

  void _jumpToCurrent() {
    setState(() {
      _animatedKeys.clear();
      _selectedDate = DateTime.now();
    });
  }

  bool _isCurrentRange() {
    final now = DateTime.now();
    if (_viewMode == 0) {
      return isSameDay(_selectedDate, now);
    } else if (_viewMode == 1) {
      final startOfSelected = _selectedDate.subtract(
        Duration(days: (_selectedDate.weekday + 1) % 7),
      );
      final startOfNow = now.subtract(Duration(days: (now.weekday + 1) % 7));
      return isSameDay(startOfSelected, startOfNow);
    } else {
      final jSelected = Jalali.fromDateTime(_selectedDate);
      final jNow = Jalali.fromDateTime(now);
      return jSelected.year == jNow.year && jSelected.month == jNow.month;
    }
  }

  void _changeRange(int delta) {
    setState(() {
      _animatedKeys.clear();
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
    // Watch all tasks for weekly/monthly views
    final allTasks = ref.watch(tasksProvider);
    // Watch activeTasksProvider for the selected date (daily view)
    final dailyTasks = ref.watch(activeTasksProvider(_selectedDate));
    
    final categories = ref.watch(categoryProvider).value ?? [];

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _buildMainContent(allTasks, dailyTasks, categories),
              ),
              _buildRangePicker(),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.8),
                    Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.6, 1.0],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
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
                        _animatedKeys.clear();
                        _viewMode = newSelection.first;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  

  Widget _buildMainContent(
    List<Task> allTasks,
    List<Task> dailyTasks,
    List<CategoryData> categories,
  ) {
    if (_viewMode == 0) {
      final validTasks = dailyTasks.where(_isTaskStructurallyValid).toList();
      return _buildDailyView(validTasks, categories);
    } else if (_viewMode == 1) {
      final validTasks = allTasks.where(_isTaskStructurallyValid).toList();
      return _buildWeeklyView(validTasks, categories);
    } else {
      final validTasks = allTasks.where(_isTaskStructurallyValid).toList();
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
        // Hourly tasks are allowed but UI might need optimization
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      decoration: BoxDecoration(
        
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainer,
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
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    _formatMiladi(_selectedDate, _viewMode),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 80,
          left: 12,
          right: 12,
          bottom: 12,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/images/TheSoul/4 pls wait 3.json',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyView(List<Task> dailyTasks, List<CategoryData> categories) {
    if (dailyTasks.isEmpty) {
      return _buildEmptyState('برای این روز برنامه‌ای نداری!');
    }

    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 80,
        left: 12,
        right: 12,
        bottom: 12,
      ),
      children: [
        // Task Groups
        ..._getGroupedAndSortedTasks(dailyTasks, statusDateOverride: _selectedDate)
            .entries
            .toList()
            .asMap()
            .entries
            .map((entry) {
             final index = entry.key;
             final group = entry.value;
             final key = 'daily_group_${group.key}_${_selectedDate.toIso8601String()}';
             final shouldAnimate = !_animatedKeys.contains(key);
             if (shouldAnimate) _animatedKeys.add(key);

             return FadeInOnce(
               key: ValueKey(key),
               delay: (200 + (index * 50)).ms,
               animate: shouldAnimate,
               child: _buildTaskGroup(
                 group.key,
                 group.value,
                 categories,
                 dateOverride: _selectedDate,
               ),
             );
        }),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10.5, vertical: 3),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
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
          Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                final today = DateTime.now();
                DateTime targetDate = days.first;
                for (var d in days) {
                  if (isSameDay(d, today)) {
                    targetDate = d;
                    break;
                  }
                }
                _toggleTaskStatus(task, targetDate);
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                final today = DateTime.now();
                DateTime targetDate = days.first;
                for (var d in days) {
                  if (isSameDay(d, today)) {
                    targetDate = d;
                    break;
                  }
                }
                _showTaskOptions(context, task, date: targetDate);
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

  Widget _buildWeeklyTaskGroup(
    String key,
    List<Task> tasks,
    List<CategoryData> categories,
    DateTime startOfWeek,
  ) {
    String title;
    Color color;
    String emoji;

    if (key == 'combined') {
      title = 'کارهای ترکیبی';
      emoji = DuckEmojis.hypn;
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

    final recurringTasks = tasks
        .where((t) => t.recurrence != null && t.recurrence!.type != RecurrenceType.none)
        .toList();
    final regularTasks = tasks
        .where((t) => t.recurrence == null || t.recurrence!.type == RecurrenceType.none)
        .toList();

    final tasksNotifier = ref.read(tasksProvider.notifier);

    int total = 0;
    int completed = 0;

    for (var t in recurringTasks) {
      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        if (!t.isActiveOnDate(date)) continue;

        final status = tasksNotifier.getStatusForDate(t.id!, date);
        if (status == TaskStatus.cancelled || status == TaskStatus.deferred) continue;
        total++;
        if (status == TaskStatus.success) completed++;
      }
    }

    for (var t in regularTasks) {
      final status = tasksNotifier.getStatusForDate(t.id!, t.dueDate);
      if (status == TaskStatus.cancelled || status == TaskStatus.deferred) continue;
      total++;
      if (status == TaskStatus.success) completed++;
    }

    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                    velocity: const Velocity(pixelsPerSecond: Offset(12, 0)),
                    delayBefore: const Duration(seconds: 2),
                    pauseBetween: const Duration(seconds: 2),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.5),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          if (recurringTasks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.5),
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
            const SizedBox(height: 2),
            ...recurringTasks.map((t) => _buildWeeklyRecurringTaskRow(t, startOfWeek)),
            if (regularTasks.isNotEmpty) const SizedBox(height: 8),
          ],
          if (regularTasks.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: regularTasks.length,
              itemBuilder: (context, index) {
                final task = regularTasks[index];
                return Padding(
                  key: ValueKey(task.id ?? 'temp_${task.hashCode}_$index'),
                  padding: EdgeInsets.zero,
                  child: _buildCompactTaskRow(task),
                );
              },
            ),
          const SizedBox(height: 12),
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
    );
  }

  Widget _buildMonthlyTaskGroup(
    String key,
    List<Task> tasks,
    List<CategoryData> categories,
    List<List<DateTime>> weeks,
    int currentMonth,
  ) {
    String title;
    Color color;
    String emoji;

    if (key == 'combined') {
      title = 'کارهای ترکیبی';
      emoji = DuckEmojis.hypn;
      color = Colors.purple;
    } else if (key == 'uncategorized') {
      title = 'بدون دستهu000cبندی';
      emoji = DuckEmojis.other;
      color = Colors.grey;
    } else {
      final catData = getCategoryById(key, categories);
      title = catData.label;
      emoji = catData.emoji;
      color = catData.color;
    }

    final recurringTasks = tasks
        .where((t) => t.recurrence != null && t.recurrence!.type != RecurrenceType.none)
        .toList();
    final regularTasks = tasks
        .where((t) => t.recurrence == null || t.recurrence!.type == RecurrenceType.none)
        .toList();

    final Map<int, List<Task>> recurringByWeek = {};
    for (int i = 0; i < weeks.length; i++) {
      final weekDays = weeks[i];
      final weekTasks = <Task>[];
      for (var t in recurringTasks) {
        bool matchesWeek = false;
        for (var d in weekDays) {
          if (Jalali.fromDateTime(d).month != currentMonth) continue;
          if (t.isActiveOnDate(d) || t.statusHistory.containsKey(getDateKey(d))) {
            matchesWeek = true;
            break;
          }
        }
        if (matchesWeek) weekTasks.add(t);
      }
      if (weekTasks.isNotEmpty) recurringByWeek[i] = weekTasks;
    }

    final tasksNotifier = ref.read(tasksProvider.notifier);
    int total = 0;
    int completed = 0;

    for (var t in recurringTasks) {
      for (var week in weeks) {
        for (var d in week) {
          if (Jalali.fromDateTime(d).month != currentMonth) continue;
          if (!t.isActiveOnDate(d)) continue;
          final status = tasksNotifier.getStatusForDate(t.id!, d);
          if (status == TaskStatus.cancelled || status == TaskStatus.deferred) continue;
          total++;
          if (status == TaskStatus.success) completed++;
        }
      }
    }

    for (var t in regularTasks) {
      final status = tasksNotifier.getStatusForDate(t.id!, t.dueDate);
      if (status == TaskStatus.cancelled || status == TaskStatus.deferred) continue;
      total++;
      if (status == TaskStatus.success) completed++;
    }

    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    velocity: const Velocity(pixelsPerSecond: Offset(12, 0)),
                    delayBefore: const Duration(seconds: 2),
                    pauseBetween: const Duration(seconds: 2),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.5),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          if (recurringByWeek.isNotEmpty) ...[
            ...(recurringByWeek.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
            .map((entry) {
              final weekIndex = entry.key;
              final weekTasks = entry.value;
              final weekDays = weeks[weekIndex];
              final weekStart = weekDays.first;
              final isLast = weekIndex == (recurringByWeek.keys.isEmpty ? weekIndex : recurringByWeek.keys.reduce((a, b) => a > b ? a : b));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.5),
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
                  ...weekTasks.map(
                    (t) => _buildWeeklyRecurringTaskRow(
                      t,
                      weekStart,
                      currentMonth: currentMonth,
                    ),
                  ),
                  if (!isLast) const SizedBox(height: 12) else const SizedBox(height: 12),
                ],
              );
            }),
            if (regularTasks.isNotEmpty) const SizedBox(height: 8),
          ],
          if (regularTasks.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: regularTasks.length,
              itemBuilder: (context, index) {
                final task = regularTasks[index];
                return Padding(
                  key: ValueKey(task.id ?? 'temp_${task.hashCode}_$index'),
                  padding: EdgeInsets.zero,
                  child: _buildCompactTaskRow(task),
                );
              },
            ),
          const SizedBox(height: 12),
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
    );
  }

  Widget _buildWeeklyView(List<Task> tasks, List<CategoryData> categories) {
    final offset = (_selectedDate.weekday + 1) % 7;
    final startOfWeek = _selectedDate.subtract(Duration(days: offset));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final tasksForWeek = <Task>[];
    for (var task in tasks) {
      final hasRecurrence = task.recurrence != null && task.recurrence!.type != RecurrenceType.none;

      if (hasRecurrence) {
        bool isActiveOrHasStatus = false;
        for (int i = 0; i < 7; i++) {
          final date = startOfWeek.add(Duration(days: i));
          if (task.isActiveOnDate(date) || task.statusHistory.containsKey(getDateKey(date))) {
            isActiveOrHasStatus = true;
            break;
          }
        }
        if (isActiveOrHasStatus) tasksForWeek.add(task);
      } else {
        final isInRange = task.dueDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
            task.dueDate.isBefore(endOfWeek.add(const Duration(days: 1)));

        if (isInRange) {
          tasksForWeek.add(task);
        } else {
          bool hasStatusInWeek = false;
          for (int i = 0; i < 7; i++) {
            final date = startOfWeek.add(Duration(days: i));
            if (task.statusHistory.containsKey(getDateKey(date))) {
              hasStatusInWeek = true;
              break;
            }
          }
          if (hasStatusInWeek) tasksForWeek.add(task);
        }
      }
    }

    if (tasksForWeek.isEmpty) {
      return _buildEmptyState('برای این هفته برنامه‌ای نداری!');
    }

    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 80,
        left: 12,
        right: 12,
        bottom: 12,
      ),
      children: [
        ..._getGroupedAndSortedTasks(tasksForWeek)
            .entries
            .toList()
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final group = entry.value;
              final key = 'weekly_group_${group.key}_${startOfWeek.toIso8601String()}';
              final shouldAnimate = !_animatedKeys.contains(key);
              if (shouldAnimate) _animatedKeys.add(key);
              return FadeInOnce(
                key: ValueKey(key),
                delay: (200 + (index * 50)).ms,
                animate: shouldAnimate,
                child: _buildWeeklyTaskGroup(group.key, group.value, categories, startOfWeek),
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

      final tasksForMonth = <Task>[];
      for (var task in tasks) {
        final hasRecurrence = task.recurrence != null && task.recurrence!.type != RecurrenceType.none;

        if (hasRecurrence) {
          bool isActiveOrHasStatusInMonth = false;
          for (var week in weeks) {
            for (var d in week) {
              if (Jalali.fromDateTime(d).month != jalaliDate.month) continue;
              if (task.isActiveOnDate(d) || task.statusHistory.containsKey(getDateKey(d))) {
                isActiveOrHasStatusInMonth = true;
                break;
              }
            }
            if (isActiveOrHasStatusInMonth) break;
          }
          if (isActiveOrHasStatusInMonth) tasksForMonth.add(task);
        } else {
          final tJalali = Jalali.fromDateTime(task.dueDate);
          final isInMonth = (tJalali.year == jalaliDate.year && tJalali.month == jalaliDate.month);

          if (isInMonth) {
            tasksForMonth.add(task);
          } else {
            bool hasStatusInMonth = false;
            for (var week in weeks) {
              for (var d in week) {
                if (Jalali.fromDateTime(d).month == jalaliDate.month &&
                    task.statusHistory.containsKey(getDateKey(d))) {
                  hasStatusInMonth = true;
                  break;
                }
              }
              if (hasStatusInMonth) break;
            }
            if (hasStatusInMonth) tasksForMonth.add(task);
          }
        }
      }

      if (tasksForMonth.isEmpty) {
        return _buildEmptyState('برای این ماه برنامه‌ای نداری!');
      }

      return ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 80,
          left: 12,
          right: 12,
          bottom: 12,
        ),
        children: [
          ..._getGroupedAndSortedTasks(tasksForMonth)
              .entries
              .toList()
              .asMap()
              .entries
              .map((entry) {
                final index = entry.key;
                final group = entry.value;
                final key = 'monthly_group_${group.key}_${jalaliDate.year}_${jalaliDate.month}';
                final shouldAnimate = !_animatedKeys.contains(key);
                if (shouldAnimate) _animatedKeys.add(key);

                return FadeInOnce(
                  key: ValueKey(key),
                  delay: (200 + (index * 50)).ms,
                  animate: shouldAnimate,
                  child: _buildMonthlyTaskGroup(group.key, group.value, categories, weeks, jalaliDate.month),
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

  Map<String, List<Task>> _getGroupedAndSortedTasks(
    List<Task> tasks, {
    DateTime? statusDateOverride,
  }) {
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
        if (a == 'combined') return -1;
        if (b == 'combined') return 1;

        // 1. Uncategorized is always last (biggest)
        if (a == 'uncategorized') return 1;
        if (b == 'uncategorized') return -1;

        // 3. Normal categories
        return a.compareTo(b);
      });

    final Map<String, List<Task>> result = {};
    final tasksNotifier = ref.read(tasksProvider.notifier);
    for (var key in sortedKeys) {
      final list = grouped[key]!;
      // Sort tasks within category: High priority first, then move cancelled to bottom
      list.sort((a, b) {
        final dateA = statusDateOverride ?? ((a.recurrence != null && a.recurrence!.type != RecurrenceType.none) ? _selectedDate : a.dueDate);
        final dateB = statusDateOverride ?? ((b.recurrence != null && b.recurrence!.type != RecurrenceType.none) ? _selectedDate : b.dueDate);

        final statusA = a.id != null
            ? tasksNotifier.getStatusForDate(a.id!, dateA)
            : a.status;
        final statusB = b.id != null
            ? tasksNotifier.getStatusForDate(b.id!, dateB)
            : b.status;

        // Move cancelled to bottom
        if (statusA == TaskStatus.cancelled &&
            statusB != TaskStatus.cancelled) {
          return 1;
        }
        if (statusA != TaskStatus.cancelled &&
            statusB == TaskStatus.cancelled) {
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

  Widget _buildTaskGroup(
    String key,
    List<Task> tasks,
    List<CategoryData> categories, {
    DateTime? dateOverride,
  }) {
    String title;
    Color color;
    String emoji;

    if (key == 'combined') {
      title = 'کارهای ترکیبی';
      emoji = DuckEmojis.hypn;
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

    final tasksNotifier = ref.read(tasksProvider.notifier);

    // Calculate progress (excluding cancelled and deferred tasks)
    int total = 0;
    int completed = 0;

    for (var t in tasks) {
      final date = dateOverride ?? ((t.recurrence != null && t.recurrence!.type != RecurrenceType.none) ? _selectedDate : t.dueDate);
      final status = tasksNotifier.getStatusForDate(t.id!, date);

      if (status != TaskStatus.cancelled && status != TaskStatus.deferred) {
        total++;
        if (status == TaskStatus.success) {
          completed++;
        }
      }
    }

    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias, // For progress bar clipping
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
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
                    velocity: const Velocity(pixelsPerSecond: Offset(12, 0)),
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
            padding: const EdgeInsets.symmetric(horizontal: 10.5),
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
                  child: _buildCompactTaskRow(task, dateOverride: dateOverride),
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
    );
  }

  Widget _buildCompactTaskRow(Task task, {DateTime? dateOverride}) {
    final date = dateOverride ?? ((task.recurrence != null && task.recurrence!.type != RecurrenceType.none) ? _selectedDate : task.dueDate);
    final status = ref.read(tasksProvider.notifier).getStatusForDate(task.id!, date);

    final isCancelled = status == TaskStatus.cancelled;
    final isSuccess = status == TaskStatus.success;

    final row = Opacity(
      opacity: isCancelled ? 0.6 : 1.0,
      child: Container(
        // Add transparent background to catch drag gestures effectively
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10.5, vertical: 3),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            // Status Icon (Left side)
            _buildStatusIcon(task: task, date: date, size: 22),

            const SizedBox(width: 10),

            // Task Title (Right side)
            Expanded(
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _toggleTaskStatus(task, date);
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  _showTaskOptions(context, task, date: date);
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
                          decoration: isSuccess
                              ? TextDecoration.lineThrough
                              : null,
                          color: isSuccess
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

    return Dismissible(
      key: Key('planning_dismiss_${task.id}_${date.toIso8601String()}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Done
          HapticFeedback.mediumImpact();
          _toggleTaskStatus(task, date);
          return false;
        } else {
          // Swipe Left: Defer
          HapticFeedback.mediumImpact();
          PostponeDialog.show(context, ref, task, targetDate: date);
          return false;
        }
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 12),
        color: Colors.green.shade400,
        child: const Icon(Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 12),
        color: Colors.orange.shade400,
        child: const Icon(Icons.history, color: Colors.white),
      ),
      child: row,
    );
  }

  void _showTaskOptions(BuildContext context, Task task, {DateTime? date}) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskOptionsSheet(
        task: task,
        date: date ?? task.dueDate,
      ),
    );
  }

  void _toggleTaskStatus(Task task, DateTime date) {
    if (task.id == null) return;

    // Always use getStatusForDate for accurate per-date status
    final status = ref.read(tasksProvider.notifier).getStatusForDate(task.id!, date);

    final nextStatus =
        status == TaskStatus.success ? TaskStatus.pending : TaskStatus.success;

    // Always provide the date to updateStatus to ensure specific day tracking
    ref
        .read(tasksProvider.notifier)
        .updateStatus(task.id!, nextStatus, date: date);

    HapticFeedback.lightImpact();
  }

  Widget _buildStatusIcon({
    required Task task,
    required DateTime date,
    double size = 24,
    bool isCurrentMonth = true,
  }) {
    final tasksNotifier = ref.read(tasksProvider.notifier);
    
    final hasRecurrence = task.recurrence != null && task.recurrence!.type != RecurrenceType.none;
    TaskStatus status = hasRecurrence ? TaskStatus.pending : task.status;
    
    if (task.id != null) {
      status = tasksNotifier.getStatusForDate(task.id!, date);
    }

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

    final isActive = task.isActiveOnDate(date);
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
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
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

}

class FadeInOnce extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool animate;
  const FadeInOnce({
    super.key,
    required this.child,
    required this.delay,
    this.animate = true,
  });

  @override
  State<FadeInOnce> createState() => _FadeInOnceState();
}

class _FadeInOnceState extends State<FadeInOnce> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!widget.animate) return widget.child;

    return widget.child
        .animate()
        .fadeIn(duration: 400.ms, delay: widget.delay)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic)
        .blur(begin: const Offset(4, 4), end: Offset.zero);
  }
}
