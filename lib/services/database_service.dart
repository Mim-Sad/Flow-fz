import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/category_data.dart';

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
      version: 6,
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
      // Check if position column exists in categories (it might not if created in v4)
      // Actually we are just adding it now.
      // But sqlite doesn't support IF NOT EXISTS for column.
      // We can just try adding it, but safer to assume it's needed if version < 6.
      // However, if table was created in v4 (before this change), it won't have position.
      // We need to alter table.
      await db.execute('ALTER TABLE categories ADD COLUMN position INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _createCategoriesTable(db);
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
    return await db.insert('tasks', task.toMap());
  }

  Future<List<Task>> getAllTasks() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('tasks', orderBy: 'dueDate ASC');
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<Map<int, Map<String, int>>> getAllTaskCompletions() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('task_completions');
    
    final Map<int, Map<String, int>> result = {};
    for (var map in maps) {
      final taskId = map['taskId'] as int;
      final date = map['date'] as String;
      final status = map['status'] as int;
      
      result.putIfAbsent(taskId, () => {});
      result[taskId]![date] = status;
    }
    return result;
  }

  Future<void> setTaskCompletion(int taskId, DateTime date, TaskStatus status) async {
    Database db = await database;
    final dateStr = date.toIso8601String().split('T')[0]; // Store as YYYY-MM-DD
    
    await db.insert(
      'task_completions',
      {
        'taskId': taskId,
        'date': dateStr,
        'status': status.index,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTask(Task task) async {
    Database db = await database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    Database db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateTaskStatus(int id, TaskStatus status) async {
    Database db = await database;
    return await db.update(
      'tasks',
      {'status': status.index},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
