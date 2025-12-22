import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart' as intl;
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';

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

    // For productivity: exclude cancelled and deferred tasks
    final relevantTasks = filteredTasks.where((t) => 
      t.status != TaskStatus.cancelled && t.status != TaskStatus.deferred
    ).toList();

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

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 80,
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatSummary(
                        context,
                        successCount,
                        failedCount,
                        relevantTasks.length, // Total relevant tasks (excluding cancelled/deferred)
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'وضعیت کلی تسک‌ها',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 24),
                      if (filteredTasks.isNotEmpty)
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: SizedBox(
                                      height: 180,
                                      child:
                                          PieChart(
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
                                                    value: cancelledCount
                                                        .toDouble(),
                                                    title: '',
                                                    color: Colors.grey,
                                                    radius: 35,
                                                  ),
                                                if (pendingCount > 0)
                                                  PieChartSectionData(
                                                    value: pendingCount.toDouble(),
                                                    title: '',
                                                    color: Theme.of(context).colorScheme.primary,
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
                                          ).animate().scale(
                                            duration: 500.ms,
                                            curve: Curves.easeOutBack,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildLegendItem(
                                          context,
                                          'موفق',
                                          Colors.greenAccent,
                                          successCount,
                                        ),
                                        _buildLegendItem(
                                          context,
                                          'ناموفق',
                                          Colors.redAccent,
                                          failedCount,
                                        ),
                                        _buildLegendItem(
                                          context,
                                          'لغو شده',
                                          Colors.grey,
                                          cancelledCount,
                                        ),
                                        _buildLegendItem(
                                          context,
                                          'در جریان',
                                          Theme.of(context).colorScheme.primary,
                                          pendingCount,
                                        ),
                                        _buildLegendItem(
                                          context,
                                          'تعویق',
                                          Colors.orangeAccent,
                                          deferredCount,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_viewMode != 0) ...[
                              const SizedBox(height: 32),
                              Text(
                                'روند موفقیت',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ).animate().fadeIn(delay: 400.ms),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 200,
                                child: _buildSuccessRateChart(filteredTasks),
                              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
                            ],
                          ],
                        )
                      else
                        const SizedBox(
                          height: 250,
                          child: Center(
                            child: Text('تسک برای این بازه وجود ندارد'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
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
                              icon: HugeIcon(icon: HugeIcons.strokeRoundedCalendar03, size: 18),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text('هفتگی'),
                              icon: HugeIcon(icon: HugeIcons.strokeRoundedCalendar02, size: 18),
                            ),
                            ButtonSegment(
                              value: 2,
                              label: Text('ماهانه'),
                              icon: HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, size: 18),
                            ),
                          ],
                        selected: {_viewMode},
                        onSelectionChanged: (val) =>
                            setState(() => _viewMode = val.first),
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

  Widget _buildStatSummary(BuildContext context, int success, int failed, int total) {
    // Productivity formula: success / (success + failed)
    final int denominator = success + failed;
    double percentage = denominator == 0 ? 0 : (success / denominator) * 100;
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'بهره‌وری شما',
                    style: TextStyle(
                      color: isDark
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onPrimaryContainer.withValues(
                              alpha: 0.8,
                            ),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_toPersianDigit(percentage.toStringAsFixed(1))}%',
                    style: TextStyle(
                      color: _getSpectrumColor(percentage),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.insights_rounded,
                color: _getSpectrumColor(percentage),
                size: 40,
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic)
        .blur(begin: const Offset(4, 4), end: Offset.zero);
  }

  Color _getSpectrumColor(double value) {
    // Clamp value between 0 and 100
    double t = value.clamp(0, 100);

    // Define stops and colors
    final stops = [0, 25, 50, 75, 100];
    final colors = [
      Colors.redAccent,
      Colors.orangeAccent,
      Theme.of(context).colorScheme.primary,
      Colors.cyanAccent,
      Colors.greenAccent,
    ];

    // Find the segment
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

  Widget _buildSuccessRateChart(List<Task> filteredTasks) {
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
        final success = dayTasks
            .where((t) => t.status == TaskStatus.success)
            .length;
        final total = dayTasks.length;
        double rate = total == 0 ? 0 : (success / total) * 100;
        spots.add(FlSpot(i.toDouble(), rate));
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
        final success = dayTasks
            .where((t) => t.status == TaskStatus.success)
            .length;
        final total = dayTasks.length;
        double rate = total == 0 ? 0 : (success / total) * 100;
        spots.add(FlSpot(i.toDouble(), rate));
        if (i % 5 == 0 || i == 1 || i == daysInMonth) {
          labels.add(i.toString());
        } else {
          labels.add('');
        }
      }
    }

    return LineChart(
      LineChartData(
        minY: -10,
        maxY: 110,
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
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > 100) return const SizedBox.shrink();
                return Text(
                  '${value.toInt()}%',
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
            gradient: _calculateGradient(spots),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  _calculateGradient(spots).colors.first.withValues(alpha: 0.1),
                  _calculateGradient(spots).colors.last.withValues(alpha: 0.1),
                ],
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
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
    );
  }
}
