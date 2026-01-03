import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart' as intl;
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../providers/task_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/category_provider.dart';
import '../models/task.dart';
import '../models/mood_entry.dart';
import '../models/activity.dart';
import '../models/category_data.dart';
import '../constants/duck_emojis.dart';
import '../widgets/lottie_category_icon.dart';
import '../providers/mood_provider.dart' hide isSameDay;
import 'package:go_router/go_router.dart';
import '../utils/route_builder.dart';
import '../widgets/animations.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _selectedDate = DateTime.now();
  int _viewMode = 0; // 0: Daily, 1: Weekly, 2: Monthly

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

  String _formatMiladi(DateTime dt, int viewMode) {
    if (viewMode == 0) {
      return intl.DateFormat('d MMMM yyyy', 'en_US').format(dt);
    } else if (viewMode == 1) {
      final startOfWeek = dt.subtract(Duration(days: (dt.weekday + 1) % 7));
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
      helpText: 'انتخاب تاریخ گزارش',
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

  /// Helper method to wrap widgets with FadeInOnce animation with sequential delays
  List<Widget> _buildAnimatedChildren({
    required List<Widget> children,
    int startDelay = 0,
    int delayStep = 100,
    List<bool>? useScaleList,
  }) {
    return children.asMap().entries.map((entry) {
      final index = entry.key;
      final child = entry.value;
      final delay = (startDelay + (index * delayStep)).ms;
      final useScale =
          useScaleList != null &&
          index < useScaleList.length &&
          useScaleList[index];

      return FadeInOnce(delay: delay, useScale: useScale, child: child);
    }).toList();
  }

  /// Build report content widgets list
  List<Widget> _buildReportContent(
    BuildContext context,
    DateTimeRange range,
    List<Task> filteredTasks,
    int successCount,
    int failedCount,
    int cancelledCount,
    int pendingCount,
    int deferredCount,
    int relevantTasksLength,
    double prevPercentage,
    double avgPercentage,
  ) {
    final List<Widget> content = [
      _buildStatSummary(
        context,
        successCount,
        failedCount,
        relevantTasksLength,
        prevPercentage,
        avgPercentage,
      ),
    ];

    if (filteredTasks.isNotEmpty) {
      content.addAll([
        const SizedBox(height: 32),
        Center(
          child: InkWell(
            onTap: () {
              context.push(
                SearchRouteBuilder.buildSearchUrl(
                  dateFrom: range.start,
                  dateTo: range.end,
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'وضعیت کلی تسک‌ها',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
      ]);

      content.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      sections: [
                        if (successCount > 0)
                          PieChartSectionData(
                            value: successCount.toDouble(),
                            title: '',
                            color: Colors.greenAccent,
                            radius: 35,
                          ),
                        if (failedCount > 0)
                          PieChartSectionData(
                            value: failedCount.toDouble(),
                            title: '',
                            color: Colors.redAccent,
                            radius: 35,
                          ),
                        if (cancelledCount > 0)
                          PieChartSectionData(
                            value: cancelledCount.toDouble(),
                            title: '',
                            color: Colors.grey,
                            radius: 35,
                          ),
                        if (pendingCount > 0)
                          PieChartSectionData(
                            value: pendingCount.toDouble(),
                            title: '',
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            radius: 35,
                          ),
                        if (deferredCount > 0)
                          PieChartSectionData(
                            value: deferredCount.toDouble(),
                            title: '',
                            color: Colors.orangeAccent,
                            radius: 35,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem(
                      context,
                      'کل تسک‌ها',
                      Theme.of(context).colorScheme.primary,
                      filteredTasks.length,
                      range,
                    ),
                    _buildLegendItem(
                      context,
                      'موفق',
                      Colors.greenAccent,
                      successCount,
                      range,
                      status: TaskStatus.success,
                    ),
                    _buildLegendItem(
                      context,
                      'ناموفق',
                      Colors.redAccent,
                      failedCount,
                      range,
                      status: TaskStatus.failed,
                    ),
                    _buildLegendItem(
                      context,
                      'لغو شده',
                      Colors.grey,
                      cancelledCount,
                      range,
                      status: TaskStatus.cancelled,
                    ),
                    _buildLegendItem(
                      context,
                      'تعویق',
                      Colors.orangeAccent,
                      deferredCount,
                      range,
                      status: TaskStatus.deferred,
                    ),
                    _buildLegendItem(
                      context,
                      'در جریان',
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                      pendingCount,
                      range,
                      status: TaskStatus.pending,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      if (_viewMode != 0) {
        final rangeAvg = relevantTasksLength > 0
            ? (successCount / relevantTasksLength) * 100
            : 0.0;
        content.addAll([
          const SizedBox(height: 32),
          Center(
            child: InkWell(
              onTap: () {
                context.push(
                  SearchRouteBuilder.buildSearchUrl(
                    dateFrom: range.start,
                    dateTo: range.end,
                    status: TaskStatus.success,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Text(
                  'روند موفقیت',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SizedBox(
              height: 200,
              child: _buildSuccessRateChart(filteredTasks, rangeAvg),
            ),
          ),
        ]);
      }

      content.addAll([
        const SizedBox(height: 32),
        _buildCategoryCapsules(context, filteredTasks, range),
        const SizedBox(height: 32),
        _buildGoalsReport(context),
        const SizedBox(height: 32),
        _buildMoodReportSection(context, range),
      ]);
    } else {
      content.addAll([
        _buildMoodReportSection(context, range),
      ]);
    }

    return content;
  }

  Widget _buildMoodReportSection(BuildContext context, DateTimeRange range) {
    final moods = ref.watch(moodsForRangeProvider(range));
    final theme = Theme.of(context);

    // Calculate Previous Range Stats
    DateTimeRange prevRange;
    if (_viewMode == 0) {
      final prevDay = _selectedDate.subtract(const Duration(days: 1));
      prevRange = DateTimeRange(start: prevDay, end: prevDay);
    } else if (_viewMode == 1) {
      final startOfWeek = _selectedDate.subtract(Duration(days: (_selectedDate.weekday + 1) % 7));
      final prevStartOfWeek = startOfWeek.subtract(const Duration(days: 7));
      final prevEndOfWeek = prevStartOfWeek.add(const Duration(days: 6));
      prevRange = DateTimeRange(start: prevStartOfWeek, end: prevEndOfWeek);
    } else {
      final jSelected = Jalali.fromDateTime(_selectedDate);
      final jPrev = jSelected.addMonths(-1);
      prevRange = DateTimeRange(
        start: jPrev.copy(day: 1).toDateTime(),
        end: jPrev.copy(day: jPrev.monthLength).toDateTime(),
      );
    }
    final prevMoods = ref.watch(moodsForRangeProvider(prevRange));

    if (moods.isEmpty && prevMoods.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Lottie.asset(
              'assets/images/TheSoul/24 news b.json',
              height: 120,
              repeat: true,
            ),
            const SizedBox(height: 16),
            Text(
              'اطلاعاتی برای این بازه پیدا نکردم!',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Calculations
    final totalMoods = moods.length;
    final prevTotalMoods = prevMoods.length;
    
    double avgMood = 0;
    if (moods.isNotEmpty) {
      avgMood = moods.map((m) => 5 - m.moodLevel.index).reduce((a, b) => a + b) / totalMoods;
    }

    double prevAvgMood = 0;
    if (prevMoods.isNotEmpty) {
      prevAvgMood = prevMoods.map((m) => 5 - m.moodLevel.index).reduce((a, b) => a + b) / prevTotalMoods;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'گزارش وضعیت روحی',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 18),
        
        // Stats Boxes
        Row(
          children: [
            Expanded(
              child: _buildMoodStatCard(
                context,
                'تعداد ثبت شده',
                totalMoods.toString(),
                (totalMoods - prevTotalMoods).toDouble(),
                HugeIcons.strokeRoundedActivity01,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMoodStatCard(
                context,
                'میانگین مود',
                avgMood.toStringAsFixed(1),
                avgMood - prevAvgMood,
                HugeIcons.strokeRoundedDashboardCircle,
                isMoodValue: true,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        Center(
          child: Text(
            'روند تغییرات مود',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 200,
          child: _buildMoodTrendChart(moods, range),
        ),

        const SizedBox(height: 32),
        Center(
          child: Text(
            'تاثیر فعالیت‌ها بر مود',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 18),
        _buildActivityImpactChart(context, moods),
      ],
    );
  }

  Widget _buildMoodStatCard(
    BuildContext context,
    String title,
    String value,
    double diff,
    dynamic icon, {
    bool isMoodValue = false,
  }) {
    final theme = Theme.of(context);
    final isPositive = diff > 0;
    final diffText = diff == 0 ? '' : (isPositive ? '+${isMoodValue ? diff.toStringAsFixed(1) : diff.toInt()}' : (isMoodValue ? diff.toStringAsFixed(1) : diff.toInt().toString()));
    final diffColor = isPositive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: icon,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _toPersianDigit(value),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (diff != 0) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _toPersianDigit(diffText),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: diffColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoodTrendChart(List<MoodEntry> moods, DateTimeRange range) {
    if (moods.isEmpty) return const SizedBox.shrink();

    // Group moods by day and calculate average
    final Map<String, List<double>> dailyMoods = {};
    for (var mood in moods) {
      final key = intl.DateFormat('yyyy-MM-dd').format(mood.dateTime);
      dailyMoods.putIfAbsent(key, () => []).add((5 - mood.moodLevel.index).toDouble());
    }

    final List<FlSpot> spots = [];
    final List<String> dates = [];
    
    DateTime current = range.start;
    int index = 0;
    while (current.isBefore(range.end) || isSameDay(current, range.end)) {
      final key = intl.DateFormat('yyyy-MM-dd').format(current);
      final dayMoods = dailyMoods[key];
      if (dayMoods != null) {
        final avg = dayMoods.reduce((a, b) => a + b) / dayMoods.length;
        spots.add(FlSpot(index.toDouble(), avg));
      }
      dates.add(intl.DateFormat('MM/dd').format(current));
      current = current.add(const Duration(days: 1));
      index++;
    }

    if (spots.isEmpty) return const SizedBox.shrink();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                _toPersianDigit(value.toInt().toString()),
                style: const TextStyle(fontSize: 10),
              ),
              reservedSize: 22,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (dates.isEmpty) return const SizedBox.shrink();
                final interval = (dates.length / 5).ceil();
                if (value % (interval == 0 ? 1 : interval) != 0) return const SizedBox.shrink();
                final idx = value.toInt();
                if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
                return Text(
                  _toPersianDigit(dates[idx]),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
        minY: 1,
        maxY: 5,
      ),
    );
  }

  Widget _buildActivityImpactChart(BuildContext context, List<MoodEntry> moods) {
    if (moods.isEmpty) return const SizedBox.shrink();

    final activityState = ref.watch(activityProvider);
    final allActivities = activityState.activities;
    
    // Map activity ID to its average mood impact
    final Map<int, List<double>> activityMoods = {};
    for (var mood in moods) {
      for (var activityId in mood.activityIds) {
        activityMoods.putIfAbsent(activityId, () => []).add((5 - mood.moodLevel.index).toDouble());
      }
    }

    final impacts = activityMoods.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      final activity = allActivities.firstWhere((a) => a.id == e.key, orElse: () => Activity(id: e.key, name: 'Unknown', categoryId: 0, iconName: '❓'));
      return MapEntry(activity, avg);
    }).toList();

    // Sort by impact
    impacts.sort((a, b) => b.value.compareTo(a.value));

    // Show top 5 activities
    final displayImpacts = impacts.take(5).toList();

    return Column(
      children: displayImpacts.map((entry) {
        final activity = entry.key;
        final avg = entry.value;
        final theme = Theme.of(context);
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(activity.iconName, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.name,
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: avg / 5,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: _getMoodColor(avg),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _toPersianDigit(avg.toStringAsFixed(1)),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getMoodColor(avg),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getMoodColor(double value) {
    if (value >= 4.5) return MoodLevel.rad.color;
    if (value >= 3.5) return MoodLevel.good.color;
    if (value >= 2.5) return MoodLevel.meh.color;
    if (value >= 1.5) return MoodLevel.bad.color;
    return MoodLevel.awful.color;
  }

  @override
  Widget build(BuildContext context) {
    DateTimeRange range;
    if (_viewMode == 0) {
      range = DateTimeRange(start: _selectedDate, end: _selectedDate);
    } else if (_viewMode == 1) {
      final startOfWeek = _selectedDate.subtract(
        Duration(days: (_selectedDate.weekday + 1) % 7),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      range = DateTimeRange(start: startOfWeek, end: endOfWeek);
    } else {
      final jSelected = Jalali.fromDateTime(_selectedDate);
      final jStart = jSelected.copy(day: 1);
      final jEnd = jSelected.copy(day: jSelected.monthLength);
      range = DateTimeRange(start: jStart.toDateTime(), end: jEnd.toDateTime());
    }

    final filteredTasks = ref.watch(tasksForRangeProvider(range));

    // For productivity: only include success and failed tasks
    final relevantTasks = filteredTasks
        .where(
          (t) =>
              t.status == TaskStatus.success || t.status == TaskStatus.failed,
        )
        .toList();

    final successCount = filteredTasks
        .where((t) => t.status == TaskStatus.success)
        .length;
    final failedCount = filteredTasks
        .where((t) => t.status == TaskStatus.failed)
        .length;
    final cancelledCount = filteredTasks
        .where((t) => t.status == TaskStatus.cancelled)
        .length;
    final pendingCount = filteredTasks
        .where((t) => t.status == TaskStatus.pending)
        .length;
    final deferredCount = filteredTasks
        .where((t) => t.status == TaskStatus.deferred)
        .length;

    // --- Start: Calculate Stats for Comparison ---

    // 1. Previous Range Calculation
    DateTimeRange prevRange;
    if (_viewMode == 0) {
      final prevDay = _selectedDate.subtract(const Duration(days: 1));
      prevRange = DateTimeRange(start: prevDay, end: prevDay);
    } else if (_viewMode == 1) {
      final startOfWeek = _selectedDate.subtract(
        Duration(days: (_selectedDate.weekday + 1) % 7),
      );
      final prevStartOfWeek = startOfWeek.subtract(const Duration(days: 7));
      final prevEndOfWeek = prevStartOfWeek.add(const Duration(days: 6));
      prevRange = DateTimeRange(start: prevStartOfWeek, end: prevEndOfWeek);
    } else {
      final jSelected = Jalali.fromDateTime(_selectedDate);
      final jPrev = jSelected.addMonths(-1);
      final jStart = jPrev.copy(day: 1);
      final jEnd = jPrev.copy(day: jPrev.monthLength);
      prevRange = DateTimeRange(
        start: jStart.toDateTime(),
        end: jEnd.toDateTime(),
      );
    }

    final prevFilteredTasks = ref.watch(tasksForRangeProvider(prevRange));
    final prevRelevantTasks = prevFilteredTasks
        .where(
          (t) =>
              t.status == TaskStatus.success || t.status == TaskStatus.failed,
        )
        .toList();

    double prevPercentage = 0.0;
    if (prevRelevantTasks.isNotEmpty) {
      final prevSuccess = prevRelevantTasks
          .where((t) => t.status == TaskStatus.success)
          .length;
      prevPercentage = (prevSuccess / prevRelevantTasks.length) * 100;
    }

    // 2. Average (All-time) Calculation
    final allTasksAsync = ref.watch(allTasksIncludingDeletedProvider);
    final allTasks = allTasksAsync.valueOrNull ?? [];

    int allTimeSuccess = 0;
    int allTimeFailed = 0;

    for (final task in allTasks) {
      if (task.isDeleted) continue;

      // Iterate through history to find all success/failed occurrences
      for (final statusIndex in task.statusHistory.values) {
        if (statusIndex == TaskStatus.success.index) {
          allTimeSuccess++;
        } else if (statusIndex == TaskStatus.failed.index) {
          allTimeFailed++;
        }
      }
    }

    final allTimeTotal = allTimeSuccess + allTimeFailed;
    double avgPercentage = 0.0;
    if (allTimeTotal > 0) {
      avgPercentage = (allTimeSuccess / allTimeTotal) * 100;
    }
    // --- End: Calculate Stats for Comparison ---

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 80,
                    left: 12,
                    right: 12,
                    bottom: 110,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildAnimatedChildren(
                      children: _buildReportContent(
                        context,
                        range,
                        filteredTasks,
                        successCount,
                        failedCount,
                        cancelledCount,
                        pendingCount,
                        deferredCount,
                        relevantTasks.length,
                        prevPercentage,
                        avgPercentage,
                      ),
                      useScaleList: filteredTasks.isNotEmpty
                          ? [
                              false,
                              false,
                              false,
                              true,
                            ] // Scale effect for pie chart (index 3)
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.8),
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.6, 1.0],
                ),
              ),
              child: _buildRangePicker(),
            ),
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
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0),
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
                    onSelectionChanged: (val) =>
                        setState(() => _viewMode = val.first),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCapsules(
    BuildContext context,
    List<Task> filteredTasks,
    DateTimeRange range,
  ) {
    final categoriesAsync = ref.watch(categoryProvider);
    return categoriesAsync.when(
      data: (categories) {
        // Group tasks by category
        final Map<String, List<Task>> categoryTasks = {};
        for (final task in filteredTasks) {
          final catId = task.categories.isNotEmpty ? task.categories.first : 'uncategorized';
          categoryTasks.putIfAbsent(catId, () => []).add(task);
        }

        if (categoryTasks.isEmpty) return const SizedBox.shrink();

        // Filter categories that have tasks in this range
        final activeCategories = categories
            .where((cat) => categoryTasks.containsKey(cat.id))
            .toList();

        // Also check for "uncategorized"
        bool hasUncategorized = categoryTasks.containsKey('uncategorized');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'پیشرفت دسته‌بندی‌ها',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ...activeCategories.map((cat) {
                    final tasks = categoryTasks[cat.id]!;
                    return _buildCategoryCapsule(context, cat, tasks, range);
                  }),
                  if (hasUncategorized)
                    _buildCategoryCapsule(
                      context,
                      const CategoryData(
                        id: 'uncategorized',
                        label: 'بدون دسته‌بندی',
                        emoji: DuckEmojis.other,
                        color: Colors.grey,
                      ),
                      categoryTasks['uncategorized']!,
                      range,
                    ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCategoryCapsule(
    BuildContext context,
    CategoryData category,
    List<Task> tasks,
    DateTimeRange range,
  ) {
    int total = 0;
    int completed = 0;

    for (var t in tasks) {
      if (t.status != TaskStatus.cancelled && t.status != TaskStatus.deferred) {
        total++;
        if (t.status == TaskStatus.success) {
          completed++;
        }
      }
    }

    if (total == 0) return const SizedBox.shrink();

    final progress = (completed / total) * 100;

    return InkWell(
      onTap: () {
        context.push(
          SearchRouteBuilder.buildSearchUrl(
            categories: [category.id],
            dateFrom: range.start,
            dateTo: range.end,
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: IntrinsicWidth(
          child: Stack(
            children: [
              // Progress Background
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerRight,
                  widthFactor: progress / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              // Content
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: category.color.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LottieCategoryIcon(
                      assetPath: category.emoji,
                      width: 22,
                      height: 22,
                      repeat: false,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: category.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_toPersianDigit(progress.toStringAsFixed(0))}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: category.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalsReport(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    if (goals.isEmpty) return const SizedBox.shrink();

    // Determine range for navigation
    DateTimeRange range;
    if (_viewMode == 0) {
      range = DateTimeRange(start: _selectedDate, end: _selectedDate);
    } else if (_viewMode == 1) {
      final startOfWeek = _selectedDate.subtract(
        Duration(days: (_selectedDate.weekday + 1) % 7),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      range = DateTimeRange(start: startOfWeek, end: endOfWeek);
    } else {
      final jSelected = Jalali.fromDateTime(_selectedDate);
      final jStart = jSelected.copy(day: 1);
      final jEnd = jSelected.copy(day: jSelected.monthLength);
      range = DateTimeRange(start: jStart.toDateTime(), end: jEnd.toDateTime());
    }

    // Filter goals that have tasks in the selected range
    final activeGoals = goals.where((goal) {
      final progress = ref.watch(
        goalProgressProvider(GoalProgressArgs(goalId: goal.id!, range: range)),
      );
      return progress != null;
    }).toList();

    if (activeGoals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'پیشرفت اهداف',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 18),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activeGoals.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final goal = activeGoals[index];
            final progress = ref.watch(
              goalProgressProvider(
                GoalProgressArgs(goalId: goal.id!, range: range),
              ),
            );

            return InkWell(
              onTap: () {
                context.push(
                  SearchRouteBuilder.buildSearchUrl(
                    goals: [goal.id!],
                    dateFrom: range.start,
                    dateTo: range.end,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          width: 50,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.3),
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            goal.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goal.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (goal.description != null &&
                                  goal.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    goal.description!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                              // Progress Bar
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                      value: progress! / 100,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_toPersianDigit(progress.toStringAsFixed(0))}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      decoration: const BoxDecoration(color: Colors.transparent),
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
                      fontFeatures: [FontFeature.enable('ss00')],
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

  Widget _buildStatSummary(
    BuildContext context,
    int success,
    int failed,
    int total,
    double prevPercentage,
    double avgPercentage,
  ) {
    // Productivity formula: success / total relevant tasks (success + failed)
    // If total (relevant tasks) is 0, we treat it as no data.
    double percentage = total == 0 ? 0.0 : (success / total) * 100;
    bool hasData = total > 0;

    final theme = Theme.of(context);

    // Calculate changes
    // If no data for current period, the change is meaningless -> 0 or we handle display separately.
    double changeFromPrev = hasData ? (percentage - prevPercentage) : 0;
    double changeFromAvg = hasData ? (percentage - avgPercentage) : 0;

    // Helper to format change text
    String formatChange(double change) {
      final sign = change >= 0 ? '+' : '';
      return '$sign${_toPersianDigit(change.toStringAsFixed(1))}%';
    }

    // Helper to get color for change
    Color getChangeColor(double change) {
      if (change > 0) return Colors.greenAccent;
      if (change < 0) return Colors.redAccent;
      return theme.colorScheme.onSurfaceVariant;
    }

    // Helper to get icon for change
    Widget getChangeIcon(double change) {
      if (change > 0) {
        return const Icon(
          Icons.arrow_drop_up_rounded,
          color: Colors.greenAccent,
          size: 24,
        );
      }
      if (change < 0) {
        return const Icon(
          Icons.arrow_drop_down_rounded,
          color: Colors.redAccent,
          size: 24,
        );
      }
      return Icon(
        Icons.remove_rounded,
        color: theme.colorScheme.onSurfaceVariant,
        size: 16,
      );
    }

    String periodLabel = _viewMode == 0
        ? 'روز گذشته'
        : (_viewMode == 1 ? 'هفته گذشته' : 'ماه گذشته');

    // Use primary color (or neutral) regarding the "No Data" text color, distinct from "red"
    final statColor = hasData
        ? _getSpectrumColor(percentage)
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'بهره‌وری شما',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    !hasData
                        ? 'داده‌ای نداریم'
                        : '${_toPersianDigit(percentage.toStringAsFixed(1))}%',
                    style: TextStyle(
                      color: statColor,
                      fontSize: !hasData ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      height: !hasData ? 1.2 : 1,
                    ),
                  ),
                ],
              ),
              Icon(Icons.insights_rounded, color: statColor, size: 40),
            ],
          ),
          const SizedBox(height: 6),
          Divider(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 45,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: !hasData
                        ? [
                            Text(
                              'داده‌ای نداریم',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                          ]
                        : [
                            getChangeIcon(changeFromPrev),
                            const SizedBox(width: 4),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatChange(changeFromPrev),
                                  style: TextStyle(
                                    color: getChangeColor(changeFromPrev),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  'نسبت به $periodLabel',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(
                child: Container(
                  height: 45,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: !hasData
                        ? [
                            Text(
                              'داده‌ای نداریم',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                          ]
                        : [
                            getChangeIcon(changeFromAvg),
                            const SizedBox(width: 4),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatChange(changeFromAvg),
                                  style: TextStyle(
                                    color: getChangeColor(changeFromAvg),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  'نسبت به میانگین کل',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSpectrumColor(double percentage) {
    if (percentage < 0) return Theme.of(context).colorScheme.primary;
    // Clamp value between 0 and 100
    double t = percentage.clamp(0, 100);

    // Define stops and colors for a smooth transition
    final stops = [0.0, 25.0, 50.0, 75.0, 100.0];
    final colors = [
      Colors.redAccent,
      Colors.orangeAccent,
      Theme.of(context).colorScheme.primary,
      Colors.cyanAccent,
      Colors.greenAccent,
    ];

    for (int i = 0; i < stops.length - 1; i++) {
      if (t >= stops[i] && t <= stops[i + 1]) {
        double localT = (t - stops[i]) / (stops[i + 1] - stops[i]);
        return Color.lerp(colors[i], colors[i + 1], localT)!;
      }
    }
    return colors.last;
  }

  LinearGradient _calculateGradient(List<FlSpot> spots) {
    if (spots.isEmpty) {
      final primaryColor = Theme.of(context).colorScheme.primary;
      return LinearGradient(colors: [primaryColor, primaryColor]);
    }

    double minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);

    // If flat line, handle gracefully
    if ((maxY - minY).abs() < 0.1) {
      Color c = _getSpectrumColor(maxY);
      return LinearGradient(colors: [c, c]);
    }

    // Spectrum stops
    final spectrumStops = [0, 25, 50, 75, 100];

    List<Color> gradientColors = [];
    List<double> gradientStops = [];

    // Add start point
    gradientColors.add(_getSpectrumColor(minY));
    gradientStops.add(0.0);

    // Add intermediate spectrum stops that fall within range
    for (var stop in spectrumStops) {
      if (stop > minY && stop < maxY) {
        gradientColors.add(_getSpectrumColor(stop.toDouble()));
        gradientStops.add((stop - minY) / (maxY - minY));
      }
    }

    // Add end point
    gradientColors.add(_getSpectrumColor(maxY));
    gradientStops.add(1.0);

    return LinearGradient(
      colors: gradientColors,
      stops: gradientStops,
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );
  }

  Widget _buildSuccessRateChart(List<Task> filteredTasks, double rangeAvg) {
    List<FlSpot> spots = [];
    List<String> labels = [];

    if (_viewMode == 1) {
      // Weekly
      final startOfWeek = _selectedDate.subtract(
        Duration(days: (_selectedDate.weekday + 1) % 7),
      );
      for (int i = 0; i < 7; i++) {
        final day = startOfWeek.add(Duration(days: i));
        final dayTasks = filteredTasks
            .where((t) => DateUtils.isSameDay(t.dueDate, day))
            .toList();

        // Relevant tasks for trend: only include success and failed
        final relevantDayTasks = dayTasks
            .where(
              (t) =>
                  t.status == TaskStatus.success ||
                  t.status == TaskStatus.failed,
            )
            .toList();

        final success = relevantDayTasks
            .where((t) => t.status == TaskStatus.success)
            .length;
        final denominator = relevantDayTasks.length;

        final isFuture =
            day.isAfter(DateTime.now()) &&
            !DateUtils.isSameDay(day, DateTime.now());
        if (!isFuture && denominator > 0) {
          double rate = (success / denominator) * 100;
          spots.add(FlSpot(i.toDouble(), rate));
        }

        final j = Jalali.fromDateTime(day);
        labels.add('${j.formatter.wN.substring(0, 1)} ${j.day}');
      }
    } else if (_viewMode == 2) {
      // Monthly
      final jalali = Jalali.fromDateTime(_selectedDate);
      final daysInMonth = jalali.monthLength;
      for (int i = 1; i <= daysInMonth; i++) {
        final day = Jalali(jalali.year, jalali.month, i).toDateTime();
        final dayTasks = filteredTasks
            .where((t) => DateUtils.isSameDay(t.dueDate, day))
            .toList();

        // Relevant tasks for trend: only include success and failed
        final relevantDayTasks = dayTasks
            .where(
              (t) =>
                  t.status == TaskStatus.success ||
                  t.status == TaskStatus.failed,
            )
            .toList();

        final success = relevantDayTasks
            .where((t) => t.status == TaskStatus.success)
            .length;
        final denominator = relevantDayTasks.length;

        final isFuture =
            day.isAfter(DateTime.now()) &&
            !DateUtils.isSameDay(day, DateTime.now());
        if (!isFuture && denominator > 0) {
          double rate = (success / denominator) * 100;
          spots.add(FlSpot(i.toDouble(), rate));
        }

        if (i % 5 == 0 || i == 1 || i == daysInMonth) {
          labels.add(i.toString());
        } else {
          labels.add('');
        }
      }
    }

    double minX = 0;
    double maxX = 6;
    if (_viewMode == 2) {
      final jalali = Jalali.fromDateTime(_selectedDate);
      minX = 1;
      maxX = jalali.monthLength.toDouble();
    }

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                if (touchedSpot.y < 0) {
                  return LineTooltipItem(
                    'داده‌ای نداریم',
                    TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }
                return LineTooltipItem(
                  '${_toPersianDigit(touchedSpot.y.toInt().toString())}٪',
                  TextStyle(
                    color: _getSpectrumColor(touchedSpot.y),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              }).toList();
            },
          ),
        ),
        minY: -5,
        maxY: 105,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 25,
          verticalInterval: 1,
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (rangeAvg > 0)
              HorizontalLine(
                y: rangeAvg,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                strokeWidth: 1,
                dashArray: [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: -18, bottom: 2),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.enable('ss01')],
                  ),
                  labelResolver: (line) => '${_toPersianDigit(rangeAvg.toInt().toString())}٪',
                ),
              ),
          ],
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > 100) return const SizedBox.shrink();
                return Text(
                  '  ${value.toInt()}%  ',
                  style: const TextStyle(fontSize: 9),
                );
              },
              reservedSize: 30,
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (_viewMode == 1) {
                  if (index >= 0 && index < labels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _toPersianDigit(labels[index]),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                } else {
                  if (index >= 1 && index <= labels.length) {
                    final label = labels[index - 1];
                    if (label.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _toPersianDigit(label),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
              reservedSize: 30,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            gradient: _calculateGradient(spots),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: _calculateGradient(
                  spots,
                ).colors.map((c) => c.withValues(alpha: 0.15)).toList(),
                stops: _calculateGradient(spots).stops,
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    String label,
    Color color,
    int count,
    DateTimeRange range, {
    TaskStatus? status,
  }) {
    return InkWell(
      onTap: () {
        context.push(
          SearchRouteBuilder.buildSearchUrl(
            dateFrom: range.start,
            dateTo: range.end,
            statuses: status != null ? [status] : null,
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _toPersianDigit(count.toString()),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
