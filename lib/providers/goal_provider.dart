import 'package:flutter/material.dart';
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

/// Arguments for goal progress calculation
class GoalProgressArgs {
  final int goalId;
  final DateTimeRange? range;

  GoalProgressArgs({required this.goalId, this.range});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalProgressArgs &&
          runtimeType == other.runtimeType &&
          goalId == other.goalId &&
          range == other.range;

  @override
  int get hashCode => goalId.hashCode ^ range.hashCode;
}

/// Provider to calculate progress for a specific goal
final goalProgressProvider = Provider.family<double?, GoalProgressArgs>((ref, args) {
  final tasks = ref.watch(tasksProvider);
  final goals = ref.watch(goalsProvider);
  final goalId = args.goalId;
  final range = args.range;
  
  // Find the goal to check for deadline
  final goal = goals.firstWhere((g) => g.id == goalId, orElse: () => Goal(title: '', emoji: ''));
  
  // Find tasks linked to this goal
  final goalTasks = tasks.where((t) => t.goalIds.contains(goalId)).toList();
  
  if (goalTasks.isEmpty) return null;

  int totalExpected = 0;
  int totalCompleted = 0;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  bool hasAnyRelevantTask = false;

  for (final task in goalTasks) {
    if (task.recurrence == null || task.recurrence!.type == RecurrenceType.none) {
      // One-off task
      final isRelevant = range != null 
          ? (task.dueDate.isAfter(range.start) || isSameDay(task.dueDate, range.start)) &&
            (task.dueDate.isBefore(range.end) || isSameDay(task.dueDate, range.end))
          : true; // Overall includes all one-off tasks

      if (isRelevant) {
        hasAnyRelevantTask = true;
        totalExpected += 1;
        final status = task.getStatusForDate(task.dueDate);
        if (status == TaskStatus.success) {
          totalCompleted += 1;
        }
      }
    } else {
      // Recurring task
      DateTime start;
      DateTime end;
      DateTime completionEnd; // Only count completions up to today

      if (range != null) {
        start = range.start;
        end = range.end;
        completionEnd = end;
      } else {
        // Overall progress
        start = task.dueDate;
        // End date for "Overall" calculation:
        // Use task's recurrence end date, or goal's deadline, or fallback to today
        end = task.recurrence?.endDate ?? goal.deadline ?? today;
        
        // If the end is in the future, we still want to count total expected until that end
        // but only completions until today.
        completionEnd = today;
      }

      // We need to iterate through the range and check each day
      DateTime current = start;
      while (current.isBefore(end) || isSameDay(current, end)) {
        // Only count if it's after or on the task's original due date
        if ((current.isAfter(task.dueDate) || isSameDay(current, task.dueDate)) && task.isActiveOnDate(current)) {
          hasAnyRelevantTask = true;
          totalExpected += 1;
          
          // Only count completion if it's within the range or (for overall) before today
          if (current.isBefore(completionEnd) || isSameDay(current, completionEnd)) {
            final status = task.getStatusForDate(current);
            if (status == TaskStatus.success) {
              totalCompleted += 1;
            }
          }
        }
        current = current.add(const Duration(days: 1));
      }
    }
  }

  if (!hasAnyRelevantTask) return null;
  if (totalExpected == 0) return 0.0;
  return (totalCompleted / totalExpected) * 100;
});
