import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      return DateUtils.isSameDay(_selectedDate, now);
    } else if (_viewMode == 1) {
      final startOfSelected = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
      final startOfNow = now.subtract(Duration(days: now.weekday % 7));
      return DateUtils.isSameDay(startOfSelected, startOfNow);
    } else {
      return _selectedDate.year == now.year && _selectedDate.month == now.month;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    
    final filteredTasks = tasks.where((t) {
      if (_viewMode == 0) {
        return DateUtils.isSameDay(t.dueDate, _selectedDate);
      } else if (_viewMode == 1) {
        final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return t.dueDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && 
               t.dueDate.isBefore(endOfWeek.add(const Duration(days: 1)));
      } else {
        return t.dueDate.year == _selectedDate.year && t.dueDate.month == _selectedDate.month;
      }
    }).toList();

    final successCount = filteredTasks.where((t) => t.status == TaskStatus.success).length;
    final failedCount = filteredTasks.where((t) => t.status == TaskStatus.failed).length;
    final cancelledCount = filteredTasks.where((t) => t.status == TaskStatus.cancelled).length;
    final pendingCount = filteredTasks.where((t) => t.status == TaskStatus.pending).length;
    final deferredCount = filteredTasks.where((t) => t.status == TaskStatus.deferred).length;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('روزانه')),
                ButtonSegment(value: 1, label: Text('هفتگی')),
                ButtonSegment(value: 2, label: Text('ماهانه')),
              ],
              selected: {_viewMode},
              onSelectionChanged: (val) => setState(() => _viewMode = val.first),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatSummary(context, successCount, filteredTasks.length)
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideX(begin: 0.1),
                  const SizedBox(height: 32),
                  Text(
                    'وضعیت کلی تسک‌ها',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 24),
                  if (filteredTasks.isNotEmpty)
                    SizedBox(
                      height: 250,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 60,
                          sections: [
                            if (successCount > 0)
                              PieChartSectionData(
                                value: successCount.toDouble(),
                                title: 'موفق',
                                color: Colors.greenAccent,
                                radius: 50,
                                titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            if (failedCount > 0)
                              PieChartSectionData(
                                value: failedCount.toDouble(),
                                title: 'ناموفق',
                                color: Colors.redAccent,
                                radius: 50,
                                titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            if (cancelledCount > 0)
                              PieChartSectionData(
                                value: cancelledCount.toDouble(),
                                title: 'لغو شده',
                                color: Colors.grey,
                                radius: 50,
                                titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            if (pendingCount > 0)
                              PieChartSectionData(
                                value: pendingCount.toDouble(),
                                title: 'در جریان',
                                color: Colors.blueAccent,
                                radius: 50,
                                titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            if (deferredCount > 0)
                              PieChartSectionData(
                                value: deferredCount.toDouble(),
                                title: 'تعویق',
                                color: Colors.orangeAccent,
                                radius: 50,
                                titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                    )
                  else
                    const SizedBox(
                      height: 250,
                      child: Center(child: Text('تسک برای این بازه وجود ندارد')),
                    ),
                  const SizedBox(height: 32),
                  _buildLegendItem(context, 'موفقیت‌آمیز', Colors.greenAccent, successCount),
                  _buildLegendItem(context, 'انجام نشده', Colors.redAccent, failedCount),
                  _buildLegendItem(context, 'لغو شده', Colors.grey, cancelledCount),
                  _buildLegendItem(context, 'در جریان', Colors.blueAccent, pendingCount),
                  _buildLegendItem(context, 'تعویق شده', Colors.orangeAccent, deferredCount),
                ],
              ),
            ),
          ),
          _buildRangePicker(),
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
      final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
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
            onPressed: () => _changeRange(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          InkWell(
            onTap: _selectDate,
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
                      onPressed: _jumpToCurrent,
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
            onPressed: () => _changeRange(1),
            icon: const Icon(Icons.chevron_right_rounded),
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
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta, 1);
      }
    });
  }

  Widget _buildStatSummary(BuildContext context, int success, int total) {
    double percentage = total == 0 ? 0 : (success / total) * 100;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'میزان بهره‌وری تو',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.trending_up, color: Colors.white, size: 48),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
