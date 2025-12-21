import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/database_service.dart';

final databaseServiceProvider = Provider((ref) => DatabaseService());

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return TasksNotifier(dbService);
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
      // For recurring tasks on a specific date
      await _dbService.setTaskCompletion(id, date, status);
      // Update local cache
      final dateStr = date.toIso8601String().split('T')[0];
      if (!_completions.containsKey(id)) _completions[id] = {};
      _completions[id]![dateStr] = status.index;
      
      // Force state update to rebuild listeners (even though list might be same)
      state = [...state]; 
    } else {
      // Regular single task
      await _dbService.updateTaskStatus(id, status);
      await loadTasks();
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
    final dateStr = date.toIso8601String().split('T')[0];
    if (_completions.containsKey(taskId) && _completions[taskId]!.containsKey(dateStr)) {
      return TaskStatus.values[_completions[taskId]![dateStr]!];
    }
    return TaskStatus.pending; // Default if not found
  }
}
