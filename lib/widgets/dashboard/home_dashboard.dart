import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:intl/intl.dart' as intl;
import 'package:go_router/go_router.dart';

import '../../models/mood_entry.dart';
import '../../models/task.dart';
import '../../providers/mood_provider.dart';
import '../../providers/task_provider.dart';
import '../../utils/string_utils.dart';
import '../../utils/route_builder.dart';

const _kPersianDigitFeatures = [FontFeature.enable('ss01')];
const _kEnglishDigitFeatures = [FontFeature.enable('ss00')];

TextStyle _getTitleStyle(BuildContext context) => TextStyle(
  fontSize: 12,
  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
  fontWeight: FontWeight.w600,
  height: 1.3,
);

Color _getProductivityColor(BuildContext context, int percentage) {
  if (percentage >= 80) return Colors.greenAccent;
  if (percentage >= 50) return Theme.of(context).colorScheme.primary;
  if (percentage >= 30) return Colors.orangeAccent;
  return Colors.redAccent;
}

class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        height: 300, // کل ارتفاع داشبورد
        child: Row(
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ستون چپ: 40 درصد
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(flex: 1, child: _DateCard()),
                  SizedBox(height: 12),
                  Expanded(flex: 2, child: _MoodCard()),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // ستون راست: 60 درصد
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(flex: 5, child: _ProductivityCard()),
                  SizedBox(height: 12),
                  Expanded(flex: 5, child: _StreakCard()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final jalali = Jalali.fromDateTime(now);
    final formatter = jalali.formatter;
    final colorScheme = Theme.of(context).colorScheme;

    final borderColor = colorScheme.onSurface.withValues(alpha: 0.1);
    final cardColor = colorScheme.surfaceContainerLow;

    return InkWell(
      onTap: () {
        context.push(SearchRouteBuilder.buildSearchUrl(specificDate: now));
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                'امروز',
                textAlign: TextAlign.center,
                style: _getTitleStyle(context),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      StringUtils.toPersianDigit(
                        '${jalali.day} ${formatter.mN}',
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        height: 1.0,
                        fontFeatures: _kPersianDigitFeatures,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      intl.DateFormat('MMMM d').format(now),
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        fontWeight: FontWeight.w400,
                        fontFeatures: _kEnglishDigitFeatures,
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
}

class _ProductivityCard extends ConsumerWidget {
  const _ProductivityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final weekly = _calculateWeeklyProductivity(tasks);
    final percentText = '${weekly.percentage}%';
    final colorScheme = Theme.of(context).colorScheme;

    final borderColor = colorScheme.onSurface.withValues(alpha: 0.1);
    final cardColor = colorScheme.surfaceContainerLow;
    final dynamicColor = _getProductivityColor(context, weekly.percentage);
    final hasData = tasks.isNotEmpty && weekly.spots.isNotEmpty;

    return InkWell(
      onTap: () => context.push('/planning?viewMode=1'),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'بهره‌وری این هفته ات',
                textAlign: TextAlign.center,
                style: _getTitleStyle(context),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: hasData
                    ? Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          Positioned.fill(
                            child: ShaderMask(
                              shaderCallback: (rect) {
                                return LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.black.withValues(alpha: 0),
                                    Colors.black,
                                    Colors.black,
                                    Colors.black.withValues(alpha: 0),
                                  ],
                                  stops: const [0.0, 0.15, 0.85, 1.0],
                                ).createShader(rect);
                              },
                              blendMode: BlendMode.dstIn,
                              child: _buildChart(
                                context,
                                spots: weekly.spots,
                                maxX: weekly.maxX,
                                color: dynamicColor,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              percentText,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w200,
                                color: dynamicColor,
                                height: 1.0,
                                fontFeatures: _kEnglishDigitFeatures,
                                shadows: [
                                  Shadow(
                                    color: colorScheme.shadow.withValues(
                                      alpha: 0.1,
                                    ),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 36,
                              child: FilledButton.icon(
                                onPressed: () => context.push('/planning'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedAdd01,
                                  size: 16,
                                ),
                                label: const Text('ایجاد تسک'),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(
    BuildContext context, {
    required List<FlSpot> spots,
    required int maxX,
    required Color color,
  }) {
    if (spots.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final gridColor = colorScheme.outlineVariant.withValues(alpha: 0.2);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX:
            10, // تنظیم روی ۱۰ برای اینکه بازه ۰ تا ۶ (۷ روز) دقیقاً بشود ۶۰ درصد عرض
        minY: -10,
        maxY: 110,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          horizontalInterval: 20,
          verticalInterval: 1,
          getDrawingVerticalLine: (value) =>
              FlLine(color: gridColor, strokeWidth: 1),
          getDrawingHorizontalLine: (value) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.1), color],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }

  _WeeklyProductivity _calculateWeeklyProductivity(List<Task> tasks) {
    final now = DateUtils.dateOnly(DateTime.now());
    // محاسبه ۷ روز اخیر (از ۶ روز پیش تا امروز)
    final startDate = now.subtract(const Duration(days: 6));

    int totalSuccess = 0;
    int totalFailed = 0;
    final spots = <FlSpot>[];

    for (int i = 0; i <= 6; i++) {
      final day = DateUtils.dateOnly(startDate.add(Duration(days: i)));
      int success = 0;
      int failed = 0;

      for (final task in tasks) {
        if (!task.isActiveOnDate(day)) continue;
        final status = task.getStatusForDate(day);
        if (status == TaskStatus.success) {
          success++;
        } else if (status == TaskStatus.failed) {
          failed++;
        }
      }

      final denom = success + failed;
      if (denom > 0) {
        final rate = (success / denom) * 100;
        // x از ۰ تا ۶ خواهد بود که نیمه اول بازه ۰ تا ۱۲ است
        spots.add(FlSpot(i.toDouble(), rate));
      }

      totalSuccess += success;
      totalFailed += failed;
    }

    final totalRelevant = totalSuccess + totalFailed;
    final percentage = totalRelevant == 0
        ? 0
        : ((totalSuccess / totalRelevant) * 100).round();
    return _WeeklyProductivity(spots: spots, maxX: 6, percentage: percentage);
  }
}

class _WeeklyProductivity {
  final List<FlSpot> spots;
  final int maxX;
  final int percentage;

  const _WeeklyProductivity({
    required this.spots,
    required this.maxX,
    required this.percentage,
  });
}

class _MoodCard extends ConsumerWidget {
  const _MoodCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodState = ref.watch(moodProvider);
    final avgMood = _calculateWeeklyMoodAverage(moodState.entries);
    final colorScheme = Theme.of(context).colorScheme;

    final moodLevel = _moodLevelForValue(avgMood);
    final color =
        moodLevel?.color ?? colorScheme.onSurface.withValues(alpha: 0.35);
    final borderColor = colorScheme.onSurface.withValues(alpha: 0.1);
    final cardColor = colorScheme.surfaceContainerLow;
    final avgText = avgMood > 0 ? avgMood.toStringAsFixed(1) : '-';
    final hasData = avgMood > 0;

    return InkWell(
      onTap: () => context.push('/mood?showAdd=true'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: hasData
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (moodLevel != null)
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: moodLevel.color.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 25,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Image.asset(
                                  moodLevel.iconPath,
                                  width: 52,
                                  height: 52,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.04,
                                ),
                                border: Border.all(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.08,
                                  ),
                                  width: 1,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(
                            avgText,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w200,
                              color: color,
                              height: 1.0,
                              fontFeatures: _kEnglishDigitFeatures,
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 36,
                              child: FilledButton.icon(
                                onPressed: () => context.push('/mood?showAdd=true'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedAdd01,
                                  size: 16,
                                ),
                                label: const Text('ثبت مود'),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                'میانگین مود\nاین هفته ات',
                textAlign: TextAlign.center,
                style: _getTitleStyle(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateWeeklyMoodAverage(List<MoodEntry> entries) {
    final now = DateUtils.dateOnly(DateTime.now());
    final startOfWeek = now.subtract(Duration(days: (now.weekday + 1) % 7));
    final endOfWeek = DateUtils.dateOnly(
      startOfWeek.add(const Duration(days: 6)),
    ).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    final weeklyEntries = entries.where((e) {
      return !e.dateTime.isBefore(startOfWeek) &&
          !e.dateTime.isAfter(endOfWeek);
    }).toList();

    if (weeklyEntries.isEmpty) return 0.0;

    final sum = weeklyEntries
        .map((m) => (5 - m.moodLevel.index).toDouble())
        .reduce((a, b) => a + b);
    return sum / weeklyEntries.length;
  }

  MoodLevel? _moodLevelForValue(double value) {
    if (value <= 0) return null;
    if (value >= 4.5) return MoodLevel.rad;
    if (value >= 3.5) return MoodLevel.good;
    if (value >= 2.5) return MoodLevel.meh;
    if (value >= 1.5) return MoodLevel.bad;
    return MoodLevel.awful;
  }
}

class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final moodState = ref.watch(moodProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final activeDates = _getActiveDatesSet(tasks, moodState.entries);
    final streak = _calculateActivityStreakFromSet(activeDates);

    final borderColor = colorScheme.onSurface.withValues(alpha: 0.1);
    final cardColor = colorScheme.surfaceContainerLow;

    // محاسبه وضعیت ۵ روز برای نمایش در دایره‌ها
    // [امروز+2, امروز+1, امروز, دیروز, دو روز پیش] -> به دلیل LTR بودن Row و طراحی بصری
    // اما برای اینکه حس پیشرفت داشته باشد، از چپ به راست: [دو روز پیش, دیروز, امروز, فردا, پس‌فردا]
    final now = DateTime.now();
    final days = List.generate(
      5,
      (index) => now.add(Duration(days: index - 2)),
    );

    return InkWell(
      onTap: () => context.push('/reports?viewMode=1'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedFire,
                            size: 14,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            StringUtils.toPersianDigit('$streak روز متوالی'),
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFeatures: _kPersianDigitFeatures,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Chain Visual
                    SizedBox(
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: 20,
                            right: 20,
                            child: Container(
                              height: 1,
                              decoration: BoxDecoration(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            textDirection: TextDirection.ltr,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildChainLink(
                                context,
                                activeDates.contains(_formatDate(days[0])),
                                size: _kChainLinkSizeSmall,
                              ),
                              _buildChainLink(
                                context,
                                activeDates.contains(_formatDate(days[1])),
                                size: _kChainLinkSizeLarge,
                              ),
                              _buildActiveLink(
                                context,
                                activeDates.contains(_formatDate(days[2])),
                                size: _kActiveLinkSize,
                              ),
                              _buildChainLink(
                                context,
                                activeDates.contains(_formatDate(days[3])),
                                size: _kChainLinkSizeLarge,
                              ),
                              _buildChainLink(
                                context,
                                activeDates.contains(_formatDate(days[4])),
                                size: _kChainLinkSizeSmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'زنجیره در جریان بودنت',
                textAlign: TextAlign.center,
                style: _getTitleStyle(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _kActiveLinkSize = 38.0;
  static const double _kChainLinkSizeLarge = 28.0;
  static const double _kChainLinkSizeSmall = 22.0;

  Widget _buildActiveLink(
    BuildContext context,
    bool isActive, {
    double? size,
  }) {
    final effectiveSize = size ?? _kActiveLinkSize;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: isActive ? 'روز فعال در زنجیره' : 'روز غیرفعال در زنجیره',
      selected: isActive,
      child: Container(
        width: effectiveSize,
        height: effectiveSize,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          border: isActive
              ? null
              : Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  width: 1,
                ),
        ),
        child: Center(
          child: isActive
              ? Icon(
                  Icons.check,
                  color: colorScheme.onPrimary,
                  size: effectiveSize * 0.6,
                )
              : Icon(
                  Icons.question_mark,
                  color: colorScheme.primary,
                  size: effectiveSize * 0.5,
                ),
        ),
      ),
    );
  }

  Widget _buildChainLink(
    BuildContext context,
    bool isFilled, {
    double? size,
  }) {
    final effectiveSize = size ?? _kChainLinkSizeLarge;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: isFilled ? 'روز موفق در زنجیره' : 'روز ناموفق در زنجیره',
      selected: isFilled,
      child: Container(
        width: effectiveSize,
        height: effectiveSize,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isFilled
              ? colorScheme.primary.withValues(alpha: 0.8)
              : colorScheme.surfaceContainerLow,
          border: isFilled
              ? null
              : Border.all(
                  color: colorScheme.surfaceContainerHighest,
                  width: 1.5,
                ),
        ),
        child: isFilled
            ? Center(
                child: Icon(
                  Icons.check,
                  color: colorScheme.onPrimary,
                  size: effectiveSize * 0.5,
                ),
              )
            : null,
      ),
    );
  }

  Set<String> _getActiveDatesSet(
    List<Task> tasks,
    List<MoodEntry> moodEntries,
  ) {
    final Set<String> activeDates = {};

    // 1. Collect Task Completions from Status Logs (Actual Time of Work)
    for (final task in tasks) {
      if (task.statusLogs.isNotEmpty) {
        for (final log in task.statusLogs) {
          final payload = log['payload'];
          final occurredAtStr = log['occurredAt'];
          
          if (payload is Map && 
              payload['status'] == TaskStatus.success.index && 
              occurredAtStr != null) {
            try {
              final occurredAt = DateTime.parse(occurredAtStr);
              activeDates.add(_formatDate(occurredAt));
            } catch (_) {
              // If log parsing fails, fallback to statusHistory might happen below
            }
          }
        }
      }
      
      // Fallback/Legacy: Also check statusHistory if no logs exist for that success
      // Note: This ensures we don't lose old streaks before statusLogs was implemented
      task.statusHistory.forEach((dateStr, statusIndex) {
        if (statusIndex == TaskStatus.success.index) {
          // Only add if not already present from logs (logs are more accurate)
          if (!activeDates.contains(dateStr)) {
            // We still add this for compatibility, but logs take precedence for "today's work"
            activeDates.add(dateStr);
          }
        }
      });
    }

    // 2. Collect Mood Entries
    for (final entry in moodEntries) {
      activeDates.add(_formatDate(entry.dateTime));
    }

    return activeDates;
  }

  int _calculateActivityStreakFromSet(Set<String> activeDates) {
    if (activeDates.isEmpty) return 0;

    final todayStr = _formatDate(DateTime.now());
    final yesterdayStr = _formatDate(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    if (!activeDates.contains(todayStr) &&
        !activeDates.contains(yesterdayStr)) {
      return 0;
    }

    int streak = 0;
    DateTime currentCheck = DateTime.now();

    if (!activeDates.contains(todayStr)) {
      currentCheck = currentCheck.subtract(const Duration(days: 1));
    }

    while (true) {
      final dateStr = _formatDate(currentCheck);
      if (activeDates.contains(dateStr)) {
        streak++;
        currentCheck = currentCheck.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
