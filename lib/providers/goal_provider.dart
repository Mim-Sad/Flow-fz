import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/goal.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import 'task_provider.dart';

final goalLoadingProvider = StateProvider<bool>((ref) => true);

class GoalsNotifier extends StateNotifier<List<Goal>> {
  final Ref _ref;
  final DatabaseService _dbService;

  GoalsNotifier(this._ref) : _dbService = _ref.read(databaseServiceProvider), super([]) {
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      state = await _dbService.getAllGoals();
    } finally {
      _ref.read(goalLoadingProvider.notifier).state = false;
    }
  }

  Future<void> addGoal(Goal goal) async {
    final id = await _dbService.insertGoal(goal);
    final newGoal = goal.copyWith(id: id);
    state = [...state, newGoal];
  }

  Future<void> updateGoal(Goal goal) async {
    await _dbService.updateGoal(goal);
    state = state.map((g) => g.id == goal.id ? goal : g).toList();
  }

  Future<void> deleteGoal(int id) async {
    await _dbService.deleteGoal(id);
    state = state.where((g) => g.id != id).toList();
  }

  Future<void> reorderGoals(List<Goal> reorderedGoals) async {
    state = reorderedGoals;
    // We might need to implement updateGoalPositions in database_service if needed
    // For now, we update them individually or just keep state updated
    for (int i = 0; i < state.length; i++) {
      final updatedGoal = state[i].copyWith(position: i);
      await _dbService.updateGoal(updatedGoal);
    }
  }
}

final goalsProvider = StateNotifierProvider<GoalsNotifier, List<Goal>>((ref) {
  return GoalsNotifier(ref);
});

/// Provider to calculate progress for a specific goal
final goalProgressProvider = Provider.family<double, int>((ref, goalId) {
  final tasks = ref.watch(tasksProvider);
  
  // Find tasks linked to this goal
  final goalTasks = tasks.where((t) => t.goalIds.contains(goalId)).toList();
  
  if (goalTasks.isEmpty) return 0.0;

  int totalExpected = 0;
  int totalCompleted = 0;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  for (final task in goalTasks) {
    if (task.recurrence == null || task.recurrence!.type == RecurrenceType.none) {
      // One-off task
      totalExpected += 1;
      // Check if it's completed on any day
      final hasCompleted = task.statusHistory.values.any((status) => status == TaskStatus.success.index);
      if (hasCompleted) {
        totalCompleted += 1;
      }
    } else {
      // Recurring task - count from start date to today
      DateTime current = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      
      while (current.isBefore(today) || isSameDay(current, today)) {
        if (task.isActiveOnDate(current)) {
          totalExpected += 1;
          final status = task.getStatusForDate(current);
          if (status == TaskStatus.success) {
            totalCompleted += 1;
          }
        }
        current = current.add(const Duration(days: 1));
      }
    }
  }

  if (totalExpected == 0) return 0.0;
  return (totalCompleted / totalExpected) * 100;
});
