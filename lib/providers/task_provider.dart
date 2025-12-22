import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../models/task.dart';
import '../services/database_service.dart';

final databaseServiceProvider = Provider((ref) => DatabaseService());

// Provider for all tasks including deleted (for reports)
final allTasksIncludingDeletedProvider = FutureProvider<List<Task>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getAllTasks(includeDeleted: true);
});

// Provider for completion status of tasks (especially recurring ones)
// Map<taskId, Map<dateKey, statusIndex>>
final taskCompletionsProvider = StateNotifierProvider<TaskCompletionsNotifier, Map<int, Map<String, int>>>((ref) {
  return TaskCompletionsNotifier(ref);
});

class TaskCompletionsNotifier extends StateNotifier<Map<int, Map<String, int>>> {
  final Ref _ref;
  final DatabaseService _dbService;

  TaskCompletionsNotifier(this._ref) : _dbService = _ref.read(databaseServiceProvider), super({}) {
    _loadCompletions();
  }

  Future<void> _loadCompletions() async {
    state = await _dbService.getAllTaskCompletions();
  }

  void updateCompletion(int taskId, String dateKey, int statusIndex) {
    final newState = Map<int, Map<String, int>>.from(state);
    newState.putIfAbsent(taskId, () => {});
    newState[taskId]![dateKey] = statusIndex;
    state = newState;
    _ref.invalidate(allTasksIncludingDeletedProvider); // Ensure reports refresh
  }

  void setCompletions(Map<int, Map<String, int>> completions) {
    state = completions;
  }
}

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  return TasksNotifier(ref);
});

class TasksNotifier extends StateNotifier<List<Task>> {
  final Ref _ref;
  final DatabaseService _dbService;

  TasksNotifier(this._ref) : _dbService = _ref.read(databaseServiceProvider), super([]) {
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    state = await _dbService.getAllTasks();
  }

  Future<void> addTask(Task task) async {
    final id = await _dbService.insertTask(task);
    final newTask = task.copyWith(id: id, rootId: task.rootId ?? id);
    state = [...state, newTask];
    _ref.invalidate(allTasksIncludingDeletedProvider);
  }

  Future<void> updateTask(Task task) async {
    final newId = await _dbService.updateTask(task);
    final newTask = task.copyWith(
      id: newId, 
      rootId: task.rootId ?? task.id,
      updatedAt: DateTime.now(),
    );
    state = state.map((t) => t.id == task.id ? newTask : t).toList();
    // Also refresh the allTasksIncludingDeletedProvider to include the new version and archived old version
    _ref.invalidate(allTasksIncludingDeletedProvider);
  }

  Future<void> deleteTask(int id) async {
    await _dbService.softDeleteTask(id);
    state = state.where((t) => t.id != id).toList();
    _ref.invalidate(allTasksIncludingDeletedProvider);
  }

  Future<void> updateStatus(int id, TaskStatus status, {DateTime? date, Map<String, dynamic>? metadata}) async {
    final task = state.firstWhere((t) => t.id == id, orElse: () => Task(title: '', dueDate: DateTime.now()));
    final rootId = task.rootId ?? id;

    if (date != null) {
      final dateStr = getDateKey(date);
      
      // Update local completions provider for immediate UI response
      _ref.read(taskCompletionsProvider.notifier).updateCompletion(rootId, dateStr, status.index);
      
      try {
        await _dbService.setTaskCompletion(id, date, status);
        
        // If metadata is provided (e.g. for deferCount), update the main task as well
        if (metadata != null) {
          final updatedTask = task.copyWith(metadata: metadata);
          await updateTask(updatedTask);
        }
      } catch (e) {
        // Rollback on error
        _loadTasks(); 
        _ref.read(taskCompletionsProvider.notifier)._loadCompletions();
        rethrow;
      }
    } else {
      // Regular task status update
      final previousState = [...state];
      final updatedTask = task.copyWith(status: status, metadata: metadata ?? task.metadata);
      state = state.map((t) => t.id == id ? updatedTask : t).toList();
      _ref.invalidate(allTasksIncludingDeletedProvider);

      try {
        if (metadata != null) {
          await _dbService.updateTask(updatedTask);
        } else {
          await _dbService.updateTaskStatus(id, status);
        }
      } catch (e) {
        state = previousState;
        rethrow;
      }
    }
  }

  Future<void> reorderTasks(List<Task> reorderedTasks) async {
    state = reorderedTasks;
    for (int i = 0; i < reorderedTasks.length; i++) {
      final updatedTask = reorderedTasks[i].copyWith(position: i);
      await _dbService.updateTask(updatedTask);
    }
  }

  TaskStatus getStatusForDate(int taskId, DateTime date) {
    final task = state.firstWhere((t) => t.id == taskId, orElse: () => Task(title: '', dueDate: DateTime.now()));
    final rootId = task.rootId ?? taskId;
    
    final completions = _ref.read(taskCompletionsProvider);
    final dateStr = getDateKey(date);
    final statusIndex = completions[rootId]?[dateStr];
    
    if (statusIndex != null) {
      return TaskStatus.values[statusIndex];
    }
    
    return task.status;
  }
}

// Provider for active tasks on a specific date (Real-time and Sync-free)
final activeTasksProvider = Provider.family<List<Task>, DateTime>((ref, date) {
  final allTasks = ref.watch(tasksProvider);
  final completions = ref.watch(taskCompletionsProvider);
  
  final dateOnly = DateTime(date.year, date.month, date.day);
  final List<Task> activeTasks = [];

  for (final task in allTasks) {
    if (isTaskActiveOnDate(task, dateOnly, completions)) {
      TaskStatus status = task.status;
      
      final dateKey = getDateKey(dateOnly);
      final rootId = task.rootId ?? task.id!;
      final statusIndex = completions[rootId]?[dateKey];
      if (statusIndex != null) {
        status = TaskStatus.values[statusIndex];
      }
      
      activeTasks.add(task.copyWith(dueDate: dateOnly, status: status));
    }
  }
  
  return activeTasks;
});

// Provider for historical active tasks (includes deleted tasks if they were active on that date)
final historicalActiveTasksProvider = Provider.family<List<Task>, DateTime>((ref, date) {
  final allTasksAsync = ref.watch(allTasksIncludingDeletedProvider);
  final completions = ref.watch(taskCompletionsProvider);
  
  return allTasksAsync.maybeWhen(
    data: (allTasks) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      // Group by rootId to handle multiple versions on the same day
      final Map<int, Task> activeVersions = {};

      for (final task in allTasks) {
        if (task.isDeleted) continue; // Exclude deleted tasks from historical view as requested
        
        final rootId = task.rootId ?? task.id!;

        // 2. Check if task definition says it's active on this date
        if (isTaskActiveOnDate(task, dateOnly, completions)) {
          // If multiple versions are active on the same day, pick the latest one (highest ID)
          final existing = activeVersions[rootId];
          if (existing == null || (task.id ?? 0) > (existing.id ?? 0)) {
            TaskStatus status = task.status;
            final dateKey = getDateKey(dateOnly);
            final statusIndex = completions[rootId]?[dateKey];
            if (statusIndex != null) {
              status = TaskStatus.values[statusIndex];
            }
            activeVersions[rootId] = task.copyWith(dueDate: dateOnly, status: status);
          }
        }
      }
      return activeVersions.values.toList();
    },
    orElse: () => [],
  );
});

// Provider for tasks in a date range (for reports)
final tasksForRangeProvider = Provider.family<List<Task>, DateTimeRange>((ref, range) {
  final allTasksAsync = ref.watch(allTasksIncludingDeletedProvider);
  final completions = ref.watch(taskCompletionsProvider);

  return allTasksAsync.maybeWhen(
    data: (allTasks) {
      final List<Task> results = [];
      final startDate = DateTime(range.start.year, range.start.month, range.start.day);
      final endDate = DateTime(range.end.year, range.end.month, range.end.day);

      for (var d = startDate;
          d.isBefore(endDate) || isSameDay(d, endDate);
          d = d.add(const Duration(days: 1))) {
        
        final dateOnly = d;
        final Map<int, Task> activeVersions = {};

        for (final task in allTasks) {
          if (task.isDeleted) continue; // Exclude deleted tasks from range reports as requested
          
          final rootId = task.rootId ?? task.id!;

          // 2. Check if task definition says it's active on this date
          if (isTaskActiveOnDate(task, dateOnly, completions)) {
            final existing = activeVersions[rootId];
            if (existing == null || (task.id ?? 0) > (existing.id ?? 0)) {
              TaskStatus status = task.status;
              final dateKey = getDateKey(dateOnly);
              final statusIndex = completions[rootId]?[dateKey];
              if (statusIndex != null) {
                status = TaskStatus.values[statusIndex];
              }
              activeVersions[rootId] = task.copyWith(dueDate: dateOnly, status: status);
            }
          }
        }
        results.addAll(activeVersions.values);
      }
      return results;
    },
    orElse: () => [],
  );
});

String getDateKey(DateTime date) {
  final d = date.toLocal();
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

bool isTaskActiveOnDate(Task task, DateTime date, Map<int, Map<String, int>> completions) {
  if (task.recurrence == null || task.recurrence!.type == RecurrenceType.none) {
    return isSameDay(task.dueDate, date);
  }

  try {
    // Check end date
    if (task.recurrence!.endDate != null && date.isAfter(task.recurrence!.endDate!)) {
      return false;
    }

    // Check start date
    final dateOnly = DateTime(date.year, date.month, date.day);
    final dueOnly = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    if (dateOnly.isBefore(dueOnly)) {
      return false;
    }

    // Check if it has an explicit status for this date
    final dateKey = getDateKey(dateOnly);
    if (completions[task.rootId ?? task.id!]?.containsKey(dateKey) ?? false) {
      return true;
    }

    switch (task.recurrence!.type) {
      case RecurrenceType.daily:
        return true;
      case RecurrenceType.weekly:
        return date.weekday == task.dueDate.weekday;
      case RecurrenceType.monthly:
        final jDate = Jalali.fromDateTime(date);
        final jDue = Jalali.fromDateTime(task.dueDate);
        return jDate.day == jDue.day;
      case RecurrenceType.yearly:
        final jDate = Jalali.fromDateTime(date);
        final jDue = Jalali.fromDateTime(task.dueDate);
        return jDate.month == jDue.month && jDate.day == jDue.day;
      case RecurrenceType.specificDays:
        return task.recurrence!.daysOfWeek?.contains(date.weekday) ?? false;
      case RecurrenceType.custom:
        final diff = date.difference(dueOnly).inDays;
        final interval = task.recurrence!.interval;
        return interval != null && interval > 0 && diff % interval == 0;
      default:
        return false;
    }
  } catch (e) {
    return false;
  }
}

bool isSameDay(DateTime d1, DateTime d2) {
  return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
}
