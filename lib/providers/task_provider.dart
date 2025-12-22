import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/database_service.dart';

final databaseServiceProvider = Provider((ref) => DatabaseService());

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return TasksNotifier(dbService);
});

final allTasksIncludingDeletedProvider = FutureProvider<List<Task>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getAllTasks(includeDeleted: true);
});

// Provider to expose task completion history
final taskCompletionsProvider = StateProvider<Map<int, Map<String, int>>>((ref) => {});

class TasksNotifier extends StateNotifier<List<Task>> {
  final DatabaseService _dbService;
  // We don't have direct access to 'ref' here to update other providers, 
  // but we can expose a way to get completions or update them.
  // Actually, better to keep completions separate or manage them here.
  // For simplicity, let's keep completions in a separate field in this notifier or use a separate provider.
  // But since we need to update the UI when completions change, and they are linked to tasks,
  // we might want to expose them.
  
  // Let's use a simpler approach: load completions into a public field or expose via a getter/stream.
  // But Riverpod recommends separate providers.
  
  // Refactored approach: TasksNotifier will handle both for now to keep it simple
  // or we need to pass a callback or Ref to TasksNotifier (not recommended).
  
  Map<int, Map<String, int>> _completions = {};
  Map<int, Map<String, int>> get completions => _completions;

  String _dateKey(DateTime date) {
    final d = date.toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  TasksNotifier(this._dbService) : super([]) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    final tasks = await _dbService.getAllTasks();
    _completions = await _dbService.getAllTaskCompletions();
    state = tasks;
  }

  Future<void> addTask(Task task) async {
    await _dbService.insertTask(task);
    await loadTasks();
  }

  Future<void> updateTask(Task task) async {
    await _dbService.updateTask(task);
    await loadTasks();
  }

  Future<void> deleteTask(int id) async {
    await _dbService.deleteTask(id);
    await loadTasks();
  }

  Future<void> updateStatus(int id, TaskStatus status, {DateTime? date}) async {
    if (date != null) {
      final dateStr = _dateKey(date);
      final previous = _completions[id]?[dateStr];

      _completions.putIfAbsent(id, () => {});
      _completions[id]![dateStr] = status.index;
      state = [...state];

      try {
        await _dbService.setTaskCompletion(id, date, status);
      } catch (e) {
        if (previous == null) {
          _completions[id]!.remove(dateStr);
          if (_completions[id]!.isEmpty) _completions.remove(id);
        } else {
          _completions[id]![dateStr] = previous;
        }
        state = [...state];
        rethrow;
      }
    } else {
      // Regular single task - Optimistic Update
      final previousState = [...state];
      state = state.map((t) => t.id == id ? t.copyWith(status: status) : t).toList();

      try {
        await _dbService.updateTaskStatus(id, status);
        // We don't need to reload all tasks if the update succeeded
        // But to be safe, we can sync in background or just trust the optimistic update
        // await loadTasks(); 
      } catch (e) {
        // Revert on failure
        state = previousState;
        rethrow;
      }
    }
  }

  Future<void> reorderTasks(List<Task> reorderedTasks) async {
    // Update positions locally first to prevent flicker
    final updatedTasks = <Task>[];
    for (int i = 0; i < reorderedTasks.length; i++) {
      updatedTasks.add(reorderedTasks[i].copyWith(position: i));
    }
    state = updatedTasks;
    
    // Fire and forget DB updates
    Future.microtask(() async {
      for (final task in updatedTasks) {
        await _dbService.updateTask(task);
      }
    });
  }
  
  TaskStatus getStatusForDate(int taskId, DateTime date) {
    final dateStr = _dateKey(date);
    final byDay = _completions[taskId];
    if (byDay != null) {
      final stored = byDay[dateStr];
      if (stored != null) return TaskStatus.values[stored];

      final legacy = date.toIso8601String().split('T')[0];
      final legacyStored = byDay[legacy];
      if (legacyStored != null) return TaskStatus.values[legacyStored];
    }
    return TaskStatus.pending; // Default if not found
  }
}
