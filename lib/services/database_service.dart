import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      version: 13,
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
      // Legacy: task_completions created
      await db.execute('''
        CREATE TABLE IF NOT EXISTS task_completions(
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
      await db.execute('ALTER TABLE tasks ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE tasks ADD COLUMN deletedAt TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN updatedAt TEXT');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS task_events(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          taskId INTEGER NOT NULL,
          type TEXT NOT NULL,
          occurredAt TEXT NOT NULL,
          payload TEXT
        )
      ''');
    }
    if (oldVersion < 8) {
      // Nothing to do here anymore (rootId removed)
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE tasks ADD COLUMN metadata TEXT');
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings(
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE tasks ADD COLUMN tags TEXT');
    }
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE tasks ADD COLUMN statusHistory TEXT');
      // Drop task_completions table as it's no longer needed
      await db.execute('DROP TABLE IF EXISTS task_completions');
    }
    if (oldVersion < 13) {
      // Version 13: Migration to remove 'status' column from tasks table
      // SQLite doesn't support DROP COLUMN directly in older versions, 
      // but we can just leave it or do the table swap dance.
      // For safety and simplicity in mobile DBs, we'll keep the column but stop using it.
      // However, we should migrate any existing 'status' data to 'statusHistory' if not already done.
      
      final List<Map<String, dynamic>> tasks = await db.query('tasks');
      for (var taskMap in tasks) {
        if (taskMap['status'] != null && (taskMap['statusHistory'] == null || taskMap['statusHistory'] == '{}')) {
          final dueDate = taskMap['dueDate'].toString().split('T')[0];
          final status = taskMap['status'];
          final history = json.encode({dueDate: status});
          await db.update(
            'tasks',
            {'statusHistory': history},
            where: 'id = ?',
            whereArgs: [taskMap['id']],
          );
        }
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        dueDate TEXT NOT NULL,
        priority INTEGER NOT NULL,
        categories TEXT,
        tags TEXT,
        taskEmoji TEXT,
        attachments TEXT,
        recurrence TEXT,
        statusHistory TEXT,
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
      CREATE TABLE IF NOT EXISTS task_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        type TEXT NOT NULL,
        occurredAt TEXT NOT NULL,
        payload TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories(
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

    await insertTaskEvent(
      taskId: id,
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
    
    debugPrint("📥 DB: Fetched ${maps.length} tasks (includeDeleted: $includeDeleted)");
    
    List<Task> tasks = [];
    for (var i = 0; i < maps.length; i++) {
      try {
        tasks.add(Task.fromMap(maps[i]));
      } catch (e) {
        debugPrint("❌ Error parsing task at index $i (ID: ${maps[i]['id']}): $e");
        // debugPrint("   Raw Data: ${maps[i]}");
      }
    }
    
    debugPrint("✅ DB: Successfully parsed ${tasks.length} tasks");
    return tasks;
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

    final result = await db.update(
      'tasks',
      {'isDeleted': 1, 'deletedAt': now, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    await insertTaskEvent(
      taskId: id,
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
    final result = await db.update(
      'tasks',
      {'isDeleted': 0, 'deletedAt': null, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    await insertTaskEvent(
      taskId: id,
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
    final db = await database;
    final events = await db.query('task_events');
    final settings = await db.query('settings');

    return {
      'version': 2, // Updated version for new array-based status structure
      'timestamp': DateTime.now().toIso8601String(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'events': events,
      'settings': settings,
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    debugPrint('Starting data import...');
    Database db = await database;
    final now = DateTime.now().toIso8601String();
    
    try {
      await db.transaction((txn) async {
        // 1. Import Categories (Deduplicate by ID or label - Case Insensitive)
        Map<String, String> categoryIdMap = {}; // oldId -> newId
        if (data['categories'] != null) {
          final categoriesList = (data['categories'] as List).cast<Map<String, dynamic>>();
          debugPrint('Importing ${categoriesList.length} categories...');
          
          final existingCategories = await txn.query('categories');
          
          for (var catMap in categoriesList) {
            final importId = catMap['id']?.toString() ?? '';
            final importLabel = catMap['label']?.toString() ?? '';
            
            // Check if category with same ID or label exists (case-insensitive)
            final existing = existingCategories.firstWhere(
              (c) {
                final dbId = c['id']?.toString().toLowerCase();
                final dbLabel = c['label']?.toString().toLowerCase();
                final impIdLower = importId.toLowerCase();
                final impLabelLower = importLabel.toLowerCase();
                return dbId == impIdLower || dbLabel == impLabelLower;
              },
              orElse: () => {},
            );
            
            if (existing.isNotEmpty) {
              final existingId = existing['id'] as String;
              categoryIdMap[importId] = existingId;
              
              // Update emoji or color if they changed
              final updates = <String, dynamic>{};
              if (catMap['emoji'] != null && catMap['emoji'] != existing['emoji']) {
                updates['emoji'] = catMap['emoji'];
              }
              if (catMap['color'] != null && catMap['color'] != existing['color']) {
                updates['color'] = catMap['color'];
              }
              
              if (updates.isNotEmpty) {
                await txn.update('categories', updates, where: 'id = ?', whereArgs: [existingId]);
              }
            } else {
              // New category
              await txn.insert('categories', catMap, conflictAlgorithm: ConflictAlgorithm.replace);
              categoryIdMap[importId] = importId;
            }
          }
        }

        // 2. Import Tasks (Deduplicate by title, description, and dueDate)
        Map<int, int> taskIdMap = {}; // oldId -> newId
        if (data['tasks'] != null) {
          final tasksList = (data['tasks'] as List).cast<Map<String, dynamic>>();
          debugPrint('Importing ${tasksList.length} tasks...');
          
          final existingTasks = await txn.query('tasks', where: 'isDeleted = 0');
          
          for (var taskMap in tasksList) {
            final oldId = taskMap['id'] as int;
            final title = taskMap['title'] as String;
            final description = taskMap['description'] as String?;
            final dueDate = taskMap['dueDate'] as String;
            
            // Basic deduplication: same title, description, and dueDate
            final duplicate = existingTasks.firstWhere(
              (t) => t['title'] == title && 
                     t['description'] == description && 
                     t['dueDate'] == dueDate,
              orElse: () => {},
            );
            
            if (duplicate.isNotEmpty) {
              taskIdMap[oldId] = duplicate['id'] as int;
              debugPrint('Skipping duplicate task: $title');
            } else {
              // New task
              final newTaskMap = Map<String, dynamic>.from(taskMap);
              newTaskMap.remove('id'); // Let SQLite handle ID
              
              // Ensure numeric fields are actually numbers
              if (newTaskMap['status'] is String) newTaskMap['status'] = int.tryParse(newTaskMap['status']) ?? 0;
              if (newTaskMap['priority'] is String) newTaskMap['priority'] = int.tryParse(newTaskMap['priority']) ?? 0;
              if (newTaskMap['isDeleted'] is String) newTaskMap['isDeleted'] = (newTaskMap['isDeleted'] == '1' || newTaskMap['isDeleted'] == 'true') ? 1 : 0;
              if (newTaskMap['position'] is String) newTaskMap['position'] = int.tryParse(newTaskMap['position']) ?? 0;

              // Map categories to new IDs if they changed
              if (newTaskMap['categories'] != null) {
                try {
                  final dynamic catsRaw = newTaskMap['categories'];
                  List<dynamic> cats;
                  if (catsRaw is String) {
                    cats = json.decode(catsRaw);
                  } else if (catsRaw is List) {
                    cats = catsRaw;
                  } else {
                    cats = [];
                  }

                  final List<String> updatedCats = [];
                  for (var c in cats) {
                    final catId = c.toString();
                    if (categoryIdMap.containsKey(catId)) {
                      updatedCats.add(categoryIdMap[catId]!);
                    } else {
                      // Check if category exists in DB
                      final exists = await txn.query('categories', where: 'id = ?', whereArgs: [catId]);
                      if (exists.isNotEmpty) {
                        updatedCats.add(catId);
                      } else {
                        // Category missing! Create a placeholder category
                        final newCatId = 'imported_$catId';
                        await txn.insert('categories', {
                          'id': newCatId,
                          'label': catId, // Use the ID as label for now
                          'emoji': '🏷️',
                          'color': 0xFF9E9E9E, // Grey
                          'position': 999,
                        }, conflictAlgorithm: ConflictAlgorithm.ignore);
                        categoryIdMap[catId] = newCatId;
                        updatedCats.add(newCatId);
                      }
                    }
                  }
                  newTaskMap['categories'] = json.encode(updatedCats);
                } catch (_) {
                  newTaskMap['categories'] = '[]';
                }
              } else {
                newTaskMap['categories'] = '[]';
              }

              // Ensure tags is a JSON string
              if (newTaskMap['tags'] != null) {
                if (newTaskMap['tags'] is List) {
                  newTaskMap['tags'] = json.encode(newTaskMap['tags']);
                } else if (newTaskMap['tags'] is! String) {
                  newTaskMap['tags'] = '[]';
                }
              } else {
                newTaskMap['tags'] = '[]';
              }

              // Ensure recurrence is a JSON string
              if (newTaskMap['recurrence'] != null) {
                if (newTaskMap['recurrence'] is Map || newTaskMap['recurrence'] is List) {
                  newTaskMap['recurrence'] = json.encode(newTaskMap['recurrence']);
                } else if (newTaskMap['recurrence'] is! String) {
                  newTaskMap['recurrence'] = null;
                }
              }

              // Move legacy status to statusHistory if it exists and statusHistory is empty
              if (newTaskMap['status'] != null && (newTaskMap['statusHistory'] == null || newTaskMap['statusHistory'] == '{}' || newTaskMap['statusHistory'] == '[]')) {
                 final int statusValue = newTaskMap['status'] is int ? newTaskMap['status'] : int.tryParse(newTaskMap['status'].toString()) ?? 0;
                 final dateKey = dueDate.split('T')[0];
                 newTaskMap['statusHistory'] = json.encode({dateKey: statusValue});
              }

              if (newTaskMap['statusHistory'] != null) {
                if (newTaskMap['statusHistory'] is Map) {
                  newTaskMap['statusHistory'] = json.encode(newTaskMap['statusHistory']);
                } else if (newTaskMap['statusHistory'] is! String) {
                  newTaskMap['statusHistory'] = '{}';
                }
              } else {
                newTaskMap['statusHistory'] = '{}';
              }

              // Update metadata with import info
              Map<String, dynamic> metadata = {};
              if (newTaskMap['metadata'] != null) {
                try {
                  final dynamic metaRaw = newTaskMap['metadata'];
                  if (metaRaw is String) {
                    metadata = Map<String, dynamic>.from(json.decode(metaRaw));
                  } else if (metaRaw is Map) {
                    metadata = Map<String, dynamic>.from(metaRaw);
                  }
                } catch (_) {}
              }
              metadata['importedAt'] = now;
              metadata['isImported'] = true;
              newTaskMap['metadata'] = json.encode(metadata);
              newTaskMap['updatedAt'] = now;
              
              // Remove fields that are not in the table
              newTaskMap.remove('status'); 

              final newId = await txn.insert('tasks', newTaskMap);
              taskIdMap[oldId] = newId;
            }
          }
        }

        // 3. Import Events
        if (data['events'] != null) {
          final eventsList = (data['events'] as List).cast<Map<String, dynamic>>();
          debugPrint('Importing ${eventsList.length} events...');
          for (var eventMap in eventsList) {
            final oldTaskId = eventMap['taskId'] as int;
            if (taskIdMap.containsKey(oldTaskId)) {
               final newTaskId = taskIdMap[oldTaskId]!;
               final newEventMap = Map<String, dynamic>.from(eventMap);
               newEventMap.remove('id');
               newEventMap['taskId'] = newTaskId;
               await txn.insert('task_events', newEventMap);
            }
          }
        }

        // 4. Import Settings
        if (data['settings'] != null) {
          final settingsList = (data['settings'] as List).cast<Map<String, dynamic>>();
          debugPrint('Importing ${settingsList.length} settings...');
          for (var settingMap in settingsList) {
            await txn.insert('settings', settingMap, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });
      debugPrint('Data import completed successfully!');
    } catch (e) {
      debugPrint('Error during data import: $e');
      rethrow;
    }
  }

  // Settings methods
  Future<void> setSetting(String key, String value) async {
    Database db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    Database db = await database;
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }
  Future<void> updateTaskStatus(int taskId, TaskStatus status, {String? dateKey}) async {
    Database db = await database;
    final taskMap = (await db.query('tasks', where: 'id = ?', whereArgs: [taskId])).first;
    
    Map<String, int> history = {};
    if (taskMap['statusHistory'] != null) {
      try {
        history = Map<String, int>.from(json.decode(taskMap['statusHistory'] as String));
      } catch (_) {}
    }
    
    final effectiveDateKey = dateKey ?? taskMap['dueDate'].toString().split('T')[0];
    history[effectiveDateKey] = status.index;
    
    await db.update(
      'tasks',
      {'statusHistory': json.encode(history)},
      where: 'id = ?',
      whereArgs: [taskId],
    );

    await insertTaskEvent(
      taskId: taskId,
      type: 'status_update',
      payload: {'status': status.index, 'date': effectiveDateKey},
      occurredAt: DateTime.now(),
    );
  }

  Future<void> insertTaskEvent({
    required int taskId,
    required String type,
    Map<String, dynamic>? payload,
    DateTime? occurredAt,
  }) async {
    Database db = await database;
    
    // Create a human-readable log message based on type and payload
    String logMessage = '';
    switch (type) {
      case 'create':
        logMessage = 'تسک ایجاد شد';
        break;
      case 'update':
        logMessage = 'تسک ویرایش شد';
        break;
      case 'status':
        final statusIndex = payload?['status'] as int?;
        String statusName = 'نامشخص';
        if (statusIndex != null) {
          switch (TaskStatus.values[statusIndex]) {
            case TaskStatus.pending: statusName = 'در انتظار'; break;
            case TaskStatus.success: statusName = 'انجام شده'; break;
            case TaskStatus.failed: statusName = 'ناموفق'; break;
            case TaskStatus.cancelled: statusName = 'لغو شده'; break;
            case TaskStatus.deferred: statusName = 'به تعویق افتاده'; break;
          }
        }
        logMessage = 'وضعیت تسک به "$statusName" تغییر کرد';
        break;
      case 'completion':
        final statusIndex = payload?['status'] as int?;
        final date = payload?['date'] as String?;
        String statusName = 'نامشخص';
        if (statusIndex != null) {
          switch (TaskStatus.values[statusIndex]) {
            case TaskStatus.pending: statusName = 'در انتظار'; break;
            case TaskStatus.success: statusName = 'انجام شده'; break;
            case TaskStatus.failed: statusName = 'ناموفق'; break;
            case TaskStatus.cancelled: statusName = 'لغو شده'; break;
            case TaskStatus.deferred: statusName = 'به تعویق افتاده'; break;
          }
        }
        logMessage = 'تسک در تاریخ $date به وضعیت "$statusName" تغییر یافت';
        break;
      case 'delete':
        logMessage = 'تسک حذف شد';
        break;
      case 'restore':
        logMessage = 'تسک بازیابی شد';
        break;
      case 'duplicate':
        logMessage = 'تسک کپی شد';
        break;
      case 'postpone':
        final fromDate = payload?['fromDate'] as String?;
        final toDate = payload?['toDate'] as String?;
        logMessage = 'تسک از تاریخ $fromDate به $toDate موکول شد';
        break;
      default:
        logMessage = 'رویداد نامشخص: $type';
    }

    final eventPayload = Map<String, dynamic>.from(payload ?? {});
    eventPayload['log'] = logMessage;

    await db.insert('task_events', {
      'taskId': taskId,
      'type': type,
      'occurredAt': (occurredAt ?? DateTime.now()).toIso8601String(),
      'payload': jsonEncode(eventPayload),
    });
  }
}
