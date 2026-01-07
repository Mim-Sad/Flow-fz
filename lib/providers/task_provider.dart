import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

final databaseServiceProvider = Provider((ref) => DatabaseService());
final notificationServiceProvider = Provider((ref) => NotificationService());

final tasksLoadingProvider = StateProvider<bool>((ref) => true);

// Provider for all tasks including deleted (for reports)
final allTasksIncludingDeletedProvider = FutureProvider<List<Task>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getAllTasks(includeDeleted: true);
});

class TasksNotifier extends StateNotifier<List<Task>> {
  final Ref _ref;
  final DatabaseService _dbService;
  final NotificationService _notificationService;
  StreamSubscription<String>? _subscription;

  TasksNotifier(this._ref) 
      : _dbService = _ref.read(databaseServiceProvider),
        _notificationService = _ref.read(notificationServiceProvider),
        super([]) {
    _loadTasks();
    _subscribeToChanges();
  }

  void _subscribeToChanges() {
    _subscription?.cancel();
    _subscription = _dbService.changeStream.listen((table) {
      if (table == 'tasks') {
        _loadTasks();
        _ref.invalidate(allTasksIncludingDeletedProvider);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      state = await _dbService.getAllTasks();
    } finally {
      _ref.read(tasksLoadingProvider.notifier).state = false;
    }
  }

  // Public method to force reload tasks from database
  Future<void> reloadTasks() async {
    _ref.read(tasksLoadingProvider.notifier).state = true;
    await _loadTasks();
    _ref.invalidate(allTasksIncludingDeletedProvider);
  }

  Future<void> addTask(Task task, {bool isDuplicate = false}) async {
    final id = await _dbService.insertTask(task);
    if (isDuplicate) {
      await _dbService.insertTaskEvent(
        taskId: id,
        type: 'duplicate',
        payload: {'fromId': task.metadata['duplicatedFromId']},
      );
    }
    final newTask = task.copyWith(id: id);
    
    // Schedule notification if reminder is set
    if (newTask.reminderDateTime != null) {
      await _notificationService.scheduleTaskReminder(newTask);
    }

    state = [...state, newTask];
    _ref.invalidate(allTasksIncludingDeletedProvider);
  }

  Future<void> updateTask(Task task) async {
    final newId = await _dbService.updateTask(task);
    final newTask = task.copyWith(
      id: newId, 
      updatedAt: DateTime.now(),
    );

    // Update notification
    if (newTask.id != null) {
      if (newTask.reminderDateTime != null) {
        await _notificationService.scheduleTaskReminder(newTask);
      } else {
        await _notificationService.cancelTaskReminder(newTask.id!);
      }
    }

    state = state.map((t) => t.id == task.id ? newTask : t).toList();
    // Also refresh the allTasksIncludingDeletedProvider to include the new version and archived old version
    _ref.invalidate(allTasksIncludingDeletedProvider);
  }

  Future<void> deleteTask(int id) async {
    await _dbService.softDeleteTask(id);
    
    // Cancel notification
    await _notificationService.cancelTaskReminder(id);

    state = state.where((t) => t.id != id).toList();
    _ref.invalidate(allTasksIncludingDeletedProvider);
  }

  Future<void> updateStatus(int id, TaskStatus status, {DateTime? date, Map<String, dynamic>? metadata}) async {
    final task = state.firstWhere((t) => t.id == id, orElse: () => Task(title: '', dueDate: DateTime.now()));
    final effectiveDate = date ?? task.dueDate;
    
    // Safety check: Prevent updating status for dates where the task is not active
    if (!task.isActiveOnDate(effectiveDate)) {
      debugPrint('Warning: Attempted to update status for task ${task.id} on inactive date $effectiveDate');
      return;
    }

    final dateStr = getDateKey(effectiveDate);

    try {
      // 1. Update status and history in database
      await _dbService.updateTaskStatus(id, status, dateKey: dateStr);
      
      // Update notification based on status
      if (status == TaskStatus.success || status == TaskStatus.cancelled) {
        await _notificationService.cancelTaskReminder(id);
      } else if (task.reminderDateTime != null) {
        await _notificationService.scheduleTaskReminder(task);
      }
      final updatedHistory = Map<String, int>.from(task.statusHistory);
      updatedHistory[dateStr] = status.index;
      
      state = state.map((t) {
        if (t.id == id) {
          var updatedTask = t.copyWith(
            statusHistory: updatedHistory,
          );
          if (metadata != null) {
            updatedTask = updatedTask.copyWith(metadata: metadata);
          }
          return updatedTask;
        }
        return t;
      }).toList();

      // 3. If metadata is provided, also update it in the database
      if (metadata != null) {
        final updatedTask = task.copyWith(metadata: metadata);
        await _dbService.updateTask(updatedTask);
      }
      
      _ref.invalidate(allTasksIncludingDeletedProvider);
    } catch (e) {
      // Rollback on error
      _loadTasks(); 
      rethrow;
    }
  }

  Future<void> reorderTasks(List<Task> reorderedSubset) async {
    // 1. Create a map of new positions from the reordered subset
    final Map<int, int> newPositions = {};
    for (int i = 0; i < reorderedSubset.length; i++) {
      if (reorderedSubset[i].id != null) {
        newPositions[reorderedSubset[i].id!] = i;
      }
    }

    // 2. Update local state by merging positions
    state = state.map((task) {
      if (newPositions.containsKey(task.id)) {
        return task.copyWith(position: newPositions[task.id!]!);
      }
      return task;
    }).toList();
    
    // 3. Update positions in database
    await _dbService.updateTaskPositions(state);
  }

  TaskStatus getStatusForDate(int taskId, DateTime date) {
    final task = state.firstWhere((t) => t.id == taskId, orElse: () => Task(title: '', dueDate: DateTime.now()));
    return task.getStatusForDate(date);
  }
}

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  return TasksNotifier(ref);
});

// Provider for active tasks on a specific date (Real-time and Sync-free)
final activeTasksProvider = Provider.family<List<Task>, DateTime>((ref, date) {
  final allTasks = ref.watch(tasksProvider);
  
  final dateOnly = DateTime(date.year, date.month, date.day);
  final List<Task> activeTasks = [];

  for (final task in allTasks) {
    // Only include task if it's active on this date
    // Status history entries are only valid if the task is active on that date
    if (task.isActiveOnDate(dateOnly)) {
      // Preserve time from original task's dueDate when copying for a specific date
      final occurrenceDate = DateTime(
        dateOnly.year,
        dateOnly.month,
        dateOnly.day,
        task.dueDate.hour,
        task.dueDate.minute,
        task.dueDate.second,
      );
      activeTasks.add(task.copyWith(dueDate: occurrenceDate));
    }
  }
  
  activeTasks.sort((a, b) => a.position.compareTo(b.position));
  return activeTasks;
});

// Provider for historical active tasks (includes deleted tasks if they were active on that date)
final historicalActiveTasksProvider = Provider.family<List<Task>, DateTime>((ref, date) {
  final allTasksAsync = ref.watch(allTasksIncludingDeletedProvider);
  
  return allTasksAsync.maybeWhen(
    data: (allTasks) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      // Group by taskId to handle multiple versions on the same day
      final Map<int, Task> activeVersions = {};

      for (final task in allTasks) {
        if (task.isDeleted) continue; // Exclude deleted tasks from historical view as requested
        
        final taskId = task.id!;

        // 2. Check if task definition says it's active on this date
        if (task.isActiveOnDate(dateOnly)) {
          // If multiple versions are active on the same day, pick the latest one (highest ID)
          final existing = activeVersions[taskId];
          if (existing == null || (task.id ?? 0) > (existing.id ?? 0)) {
            // Preserve time from original task's dueDate when copying for a specific date
            final occurrenceDate = DateTime(
              dateOnly.year,
              dateOnly.month,
              dateOnly.day,
              task.dueDate.hour,
              task.dueDate.minute,
              task.dueDate.second,
            );
            activeVersions[taskId] = task.copyWith(dueDate: occurrenceDate);
          }
        }
      }
      final tasks = activeVersions.values.toList();
      tasks.sort((a, b) => a.position.compareTo(b.position));
      return tasks;
    },
    orElse: () => [],
  );
});

// Provider for tasks in a date range (for reports)
final tasksForRangeProvider = Provider.family<List<Task>, DateTimeRange>((ref, range) {
  final allTasksAsync = ref.watch(allTasksIncludingDeletedProvider);

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
          
          final taskId = task.id!;

          // 2. Check if task definition says it's active on this date
          if (task.isActiveOnDate(dateOnly)) {
            final existing = activeVersions[taskId];
            if (existing == null || (task.id ?? 0) > (existing.id ?? 0)) {
              // Preserve time from original task's dueDate when copying for a specific date
              final occurrenceDate = DateTime(
                dateOnly.year,
                dateOnly.month,
                dateOnly.day,
                task.dueDate.hour,
                task.dueDate.minute,
                task.dueDate.second,
              );
              activeVersions[taskId] = task.copyWith(dueDate: occurrenceDate);
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

bool isSameDay(DateTime d1, DateTime d2) {
  return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
}
