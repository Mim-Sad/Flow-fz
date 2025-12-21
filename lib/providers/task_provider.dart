import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/database_service.dart';

final databaseServiceProvider = Provider((ref) => DatabaseService());

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return TasksNotifier(dbService);
});

class TasksNotifier extends StateNotifier<List<Task>> {
  final DatabaseService _dbService;

  TasksNotifier(this._dbService) : super([]) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    final tasks = await _dbService.getAllTasks();
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

  Future<void> updateStatus(int id, TaskStatus status) async {
    await _dbService.updateTaskStatus(id, status);
    await loadTasks();
  }
}
