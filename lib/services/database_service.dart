import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/category_data.dart';
import '../providers/task_provider.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'flow_database.db');
    return await openDatabase(
      path,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN position INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN categories TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN taskEmoji TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN attachments TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN recurrence TEXT');
    }
    if (oldVersion < 4) {
      await _createCategoriesTable(db);
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE task_completions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          taskId INTEGER NOT NULL,
          date TEXT NOT NULL,
          status INTEGER NOT NULL,
          UNIQUE(taskId, date)
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE categories ADD COLUMN position INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE tasks ADD COLUMN rootId INTEGER');
      await db.execute('ALTER TABLE tasks ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE tasks ADD COLUMN deletedAt TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN updatedAt TEXT');

      await db.execute('''
        CREATE TABLE task_events(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          taskId INTEGER NOT NULL,
          rootId INTEGER,
          type TEXT NOT NULL,
          occurredAt TEXT NOT NULL,
          payload TEXT
        )
      ''');

      await db.execute('UPDATE tasks SET rootId = id WHERE rootId IS NULL');
    }
    if (oldVersion < 8) {
      // Add rootId to task_completions for better historical tracking
      await db.execute('ALTER TABLE task_completions ADD COLUMN rootId INTEGER');
      
      // Populate rootId in task_completions based on tasks table
      await db.execute('''
        UPDATE task_completions 
        SET rootId = (SELECT rootId FROM tasks WHERE tasks.id = task_completions.taskId)
      ''');
      
      // If some tasks are missing, fallback to taskId
      await db.execute('UPDATE task_completions SET rootId = taskId WHERE rootId IS NULL');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE tasks ADD COLUMN metadata TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rootId INTEGER,
        title TEXT NOT NULL,
        description TEXT,
        dueDate TEXT NOT NULL,
        status INTEGER NOT NULL,
        priority INTEGER NOT NULL,
        category TEXT,
        categories TEXT,
        taskEmoji TEXT,
        attachments TEXT,
        recurrence TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        deletedAt TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0,
        metadata TEXT
      )
    ''');
    await _createCategoriesTable(db);
    await db.execute('''
      CREATE TABLE task_completions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        rootId INTEGER,
        date TEXT NOT NULL,
        status INTEGER NOT NULL,
        UNIQUE(rootId, date)
      )
    ''');
    await db.execute('''
      CREATE TABLE task_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        rootId INTEGER,
        type TEXT NOT NULL,
        occurredAt TEXT NOT NULL,
        payload TEXT
      )
    ''');
  }

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE categories(
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        emoji TEXT NOT NULL,
        color INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    // Insert default categories
    final batch = db.batch();
    for (var cat in defaultCategories) {
      batch.insert('categories', cat.toMap());
    }
    await batch.commit();
  }

  // Categories CRUD
  Future<List<CategoryData>> getAllCategories() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('categories', orderBy: 'position ASC');
    if (maps.isEmpty) return [];
    return List.generate(maps.length, (i) => CategoryData.fromMap(maps[i]));
  }

  Future<int> insertCategory(CategoryData category) async {
    Database db = await database;
    return await db.insert('categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateCategory(CategoryData category) async {
    Database db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    Database db = await database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertTask(Task task) async {
    Database db = await database;
    final now = DateTime.now().toIso8601String();
    final map = task.toMap();
    map['updatedAt'] = now;

    final id = await db.insert('tasks', map);
    final rootId = task.rootId ?? id;
    if (task.rootId == null) {
      await db.update('tasks', {'rootId': rootId}, where: 'id = ?', whereArgs: [id]);
    }

    await insertTaskEvent(
      taskId: id,
      rootId: rootId,
      type: 'create',
      payload: {'task': map},
      occurredAt: DateTime.now(),
    );

    return id;
  }

  Future<List<Task>> getAllTasks({bool includeDeleted = false}) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: includeDeleted ? null : 'isDeleted = 0',
      orderBy: 'position ASC, dueDate ASC',
    );
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<Map<int, Map<String, int>>> getAllTaskCompletions() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('task_completions');
    
    final Map<int, Map<String, int>> completions = {};
    for (final map in maps) {
      final rootId = map['rootId'] as int;
      final date = map['date'] as String;
      final status = map['status'] as int;
      
      completions.putIfAbsent(rootId, () => {});
      completions[rootId]![date] = status;
    }
    return completions;
  }

  Future<void> setTaskCompletion(int taskId, DateTime date, TaskStatus status) async {
    Database db = await database;
    final dateStr = getDateKey(date);
    final rootId = await getTaskRootId(taskId) ?? taskId;
    
    await db.insert(
      'task_completions',
      {
        'taskId': taskId,
        'rootId': rootId,
        'date': dateStr,
        'status': status.index,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await insertTaskEvent(
      taskId: taskId,
      rootId: rootId,
      type: 'completion',
      payload: {'date': dateStr, 'status': status.index},
      occurredAt: DateTime.now(),
    );
  }

  Future<int> updateTask(Task task) async {
    Database db = await database;
    final now = DateTime.now();
    final nowStr = now.toIso8601String();

    if (task.id == null) return -1;

    final map = task.toMap();
    map.remove('id'); // Ensure we don't try to update the primary key column
    map['updatedAt'] = nowStr;

    await db.update(
      'tasks',
      map,
      where: 'id = ?',
      whereArgs: [task.id],
    );

    await insertTaskEvent(
      taskId: task.id!,
      rootId: task.rootId ?? task.id,
      type: 'update',
      payload: {'task': map},
      occurredAt: now,
    );

    return task.id!;
  }

  Future<void> updateTaskPositions(List<Task> tasks) async {
    Database db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final task in tasks) {
        batch.update(
          'tasks',
          {'position': task.position},
          where: 'id = ?',
          whereArgs: [task.id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> softDeleteTask(int id) async {
    Database db = await database;
    final now = DateTime.now().toIso8601String();

    final rootId = await getTaskRootId(id);
    final result = await db.update(
      'tasks',
      {'isDeleted': 1, 'deletedAt': now, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    await insertTaskEvent(
      taskId: id,
      rootId: rootId,
      type: 'delete',
      payload: {'deletedAt': now},
      occurredAt: DateTime.now(),
    );

    return result;
  }

  Future<int> deleteTask(int id) async {
    return softDeleteTask(id);
  }

  Future<int> restoreTask(int id) async {
    Database db = await database;
    final now = DateTime.now().toIso8601String();
    final rootId = await getTaskRootId(id);
    final result = await db.update(
      'tasks',
      {'isDeleted': 0, 'deletedAt': null, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    await insertTaskEvent(
      taskId: id,
      rootId: rootId,
      type: 'restore',
      payload: {'restoredAt': now},
      occurredAt: DateTime.now(),
    );

    return result;
  }

  // Export/Import Logic
  Future<Map<String, dynamic>> exportData() async {
    final tasks = await getAllTasks(includeDeleted: true);
    final categories = await getAllCategories();
    final completions = await getAllTaskCompletions();
    final db = await database;
    final events = await db.query('task_events');

    // Convert completions to list for JSON serialization
    // Structure: [{taskId: 1, date: "2023-01-01", status: 1}, ...]
    List<Map<String, dynamic>> completionsList = [];
    completions.forEach((taskId, dates) {
      dates.forEach((date, status) {
        completionsList.add({
          'taskId': taskId,
          'date': date,
          'status': status,
        });
      });
    });

    return {
      'version': 1, // Data export format version
      'timestamp': DateTime.now().toIso8601String(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'completions': completionsList,
      'events': events,
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    Database db = await database;
    
    await db.transaction((txn) async {
      // Clear existing data
      await txn.delete('tasks');
      await txn.delete('categories');
      await txn.delete('task_completions');
      try {
        await txn.delete('task_events');
      } catch (_) {}

      // Import Categories
      final categoriesList = (data['categories'] as List).cast<Map<String, dynamic>>();
      for (var catMap in categoriesList) {
        await txn.insert('categories', catMap);
      }

      // Import Tasks
      final tasksList = (data['tasks'] as List).cast<Map<String, dynamic>>();
      for (var taskMap in tasksList) {
        // We need to ensure we don't have ID conflicts if we are merging, 
        // but here we are replacing, so we can keep IDs or let autoincrement handle it.
        // If we want to keep relationships (completions), we MUST keep IDs.
        await txn.insert('tasks', taskMap);
      }
      await txn.execute('UPDATE tasks SET rootId = id WHERE rootId IS NULL');

      // Import Completions
      if (data['completions'] != null) {
        final completionsList = (data['completions'] as List).cast<Map<String, dynamic>>();
        for (var compMap in completionsList) {
          await txn.insert('task_completions', compMap);
        }
      }

      if (data['events'] != null) {
        final eventsList = (data['events'] as List).cast<Map<String, dynamic>>();
        for (var eventMap in eventsList) {
          await txn.insert('task_events', eventMap);
        }
      }
    });
  }
  Future<int> updateTaskStatus(int id, TaskStatus status) async {
    Database db = await database;
    final now = DateTime.now().toIso8601String();
    final rootId = await getTaskRootId(id);
    final result = await db.update(
      'tasks',
      {'status': status.index, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    await insertTaskEvent(
      taskId: id,
      rootId: rootId,
      type: 'status',
      payload: {'status': status.index},
      occurredAt: DateTime.now(),
    );

    return result;
  }

  Future<int?> getTaskRootId(int taskId) async {
    Database db = await database;
    final rows = await db.query(
      'tasks',
      columns: ['rootId', 'id'],
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final rootId = row['rootId'] as int?;
    return rootId ?? (row['id'] as int?);
  }

  Future<void> insertTaskEvent({
    required int taskId,
    int? rootId,
    required String type,
    Map<String, dynamic>? payload,
    DateTime? occurredAt,
  }) async {
    Database db = await database;
    await db.insert('task_events', {
      'taskId': taskId,
      'rootId': rootId,
      'type': type,
      'occurredAt': (occurredAt ?? DateTime.now()).toIso8601String(),
      'payload': payload == null ? null : jsonEncode(payload),
    });
  }
}
