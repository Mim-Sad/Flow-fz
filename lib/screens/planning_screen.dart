import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('برنامه‌ریزی'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'روزانه'),
            Tab(text: 'هفتگی'),
            Tab(text: 'ماهانه'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyView(tasks),
          _buildWeeklyView(tasks),
          _buildMonthlyView(tasks),
        ],
      ),
    );
  }

  Widget _buildDailyView(List<Task> tasks) {
    final now = DateTime.now();
    final dailyTasks = tasks.where((t) => _isSameDay(t.dueDate, now)).toList();

    return _buildTaskList(dailyTasks, 'برای امروز برنامه‌ای نداری.');
  }

  Widget _buildWeeklyView(List<Task> tasks) {
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    final weeklyTasks = tasks.where((t) => t.dueDate.isAfter(now.subtract(const Duration(days: 1))) && t.dueDate.isBefore(weekEnd)).toList();

    return _buildTaskList(weeklyTasks, 'برای این هفته برنامه‌ای نداری.');
  }

  Widget _buildMonthlyView(List<Task> tasks) {
    final now = DateTime.now();
    final monthlyTasks = tasks.where((t) => t.dueDate.year == now.year && t.dueDate.month == now.month).toList();

    return _buildTaskList(monthlyTasks, 'برای این ماه برنامه‌ای نداری.');
  }

  Widget _buildTaskList(List<Task> tasks, String emptyMessage) {
    if (tasks.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      intl.DateFormat('dd').format(task.dueDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      intl.DateFormat('MMM').format(task.dueDate),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: -0.2),
              const SizedBox(width: 16),
              Expanded(
                child: TaskCard(task: task)
                    .animate()
                    .fadeIn(delay: (index * 100).ms)
                    .slideX(begin: 0.2),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
