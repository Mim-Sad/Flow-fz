import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);

    final successCount = tasks.where((t) => t.status == TaskStatus.success).length;
    final failedCount = tasks.where((t) => t.status == TaskStatus.failed).length;
    final cancelledCount = tasks.where((t) => t.status == TaskStatus.cancelled).length;
    final pendingCount = tasks.where((t) => t.status == TaskStatus.pending).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('گزارشات و آمار'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatSummary(context, successCount, tasks.length)
                .animate()
                .fadeIn(duration: 600.ms)
                .slideX(begin: 0.1),
            const SizedBox(height: 32),
            Text(
              'وضعیت کلی تسک‌ها',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 60,
                  sections: [
                    PieChartSectionData(
                      value: successCount.toDouble(),
                      title: 'موفق',
                      color: Colors.greenAccent,
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      value: failedCount.toDouble(),
                      title: 'ناموفق',
                      color: Colors.redAccent,
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      value: cancelledCount.toDouble(),
                      title: 'لغو شده',
                      color: Colors.grey,
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      value: pendingCount.toDouble(),
                      title: 'در انتظار',
                      color: Colors.blueAccent,
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
            ),
            const SizedBox(height: 32),
            _buildLegendItem(context, 'موفقیت‌آمیز', Colors.greenAccent, successCount)
                .animate()
                .fadeIn(delay: 400.ms)
                .slideY(begin: 0.5),
            _buildLegendItem(context, 'انجام نشده', Colors.redAccent, failedCount)
                .animate()
                .fadeIn(delay: 500.ms)
                .slideY(begin: 0.5),
            _buildLegendItem(context, 'لغو شده', Colors.grey, cancelledCount)
                .animate()
                .fadeIn(delay: 600.ms)
                .slideY(begin: 0.5),
            _buildLegendItem(context, 'در جریان', Colors.blueAccent, pendingCount)
                .animate()
                .fadeIn(delay: 700.ms)
                .slideY(begin: 0.5),
          ],
        ),
      ),
    );
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
