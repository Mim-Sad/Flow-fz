import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
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
    final db = await openDatabase(
      path,
      version: 15,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    
    // Migrate old attachments to media table on startup
    await _migrateOldAttachments(db);
    
    return db;
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
    if (oldVersion < 14) {
      // Version 14: Create media table for attachments
      await _createMediaTable(db);
      
      // Ensure mimeType column exists (in case table was created without it)
      try {
        await db.execute('ALTER TABLE media ADD COLUMN mimeType TEXT');
      } catch (e) {
        // Column might already exist, ignore error
        debugPrint('mimeType column might already exist: $e');
      }
    }
    if (oldVersion < 15) {
      // Version 15: Fix media table - remove fileType column if it exists
      // SQLite doesn't support DROP COLUMN directly, so we need to recreate the table
      try {
        // Check if media table exists
        final tableInfo = await db.rawQuery('PRAGMA table_info(media)');
        final hasFileType = tableInfo.any((column) => column['name'] == 'fileType');
        
        if (hasFileType) {
          debugPrint('fileType column exists, recreating media table...');
          
          // Create new table with correct structure
          await db.execute('''
            CREATE TABLE IF NOT EXISTS media_new(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              filePath TEXT NOT NULL,
              fileName TEXT NOT NULL,
              fileSize INTEGER,
              mimeType TEXT,
              createdAt TEXT NOT NULL,
              taskId INTEGER
            )
          ''');
          
          // Copy data from old table to new table (excluding fileType)
          // Use COALESCE to handle NULL values
          await db.execute('''
            INSERT INTO media_new (id, filePath, fileName, fileSize, mimeType, createdAt, taskId)
            SELECT id, filePath, fileName, fileSize, 
                   COALESCE(mimeType, 'application/octet-stream') as mimeType,
                   createdAt, taskId
            FROM media
          ''');
          
          // Drop old table
          await db.execute('DROP TABLE media');
          
          // Rename new table
          await db.execute('ALTER TABLE media_new RENAME TO media');
          
          debugPrint('✅ Media table recreated successfully without fileType');
        } else {
          debugPrint('fileType column does not exist, no migration needed');
        }
        
        // Ensure mimeType column exists
        try {
          await db.execute('ALTER TABLE media ADD COLUMN mimeType TEXT');
        } catch (e) {
          // Column might already exist, ignore error
          debugPrint('mimeType column might already exist: $e');
        }
      } catch (e) {
        debugPrint('Error in media table migration: $e');
        // If migration fails, try to ensure mimeType exists
        try {
          await db.execute('ALTER TABLE media ADD COLUMN mimeType TEXT');
        } catch (_) {}
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
    await _createMediaTable(db);
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

  Future<void> _createMediaTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS media(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filePath TEXT NOT NULL,
        fileName TEXT NOT NULL,
        fileSize INTEGER,
        mimeType TEXT,
        createdAt TEXT NOT NULL,
        taskId INTEGER
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

    // Convert attachment paths to media IDs
    final List<int> mediaIds = [];
    for (var attachment in task.attachments) {
      // Check if it's already a media ID
      if (RegExp(r'^\d+$').hasMatch(attachment)) {
        mediaIds.add(int.parse(attachment));
      } else {
        // It's a file path, create media entry
        final file = File(attachment);
        if (await file.exists()) {
          final fileName = attachment.split('/').last;
          final fileSize = await file.length();
          final mimeType = _getMimeType(fileName);
          
          final mediaId = await insertMedia(
            filePath: attachment,
            fileName: fileName,
            fileSize: fileSize,
            mimeType: mimeType,
            taskId: null, // Will be updated after task is created
          );
          mediaIds.add(mediaId);
        }
      }
    }
    
    // Update attachments with media IDs
    map['attachments'] = json.encode(mediaIds.map((id) => id.toString()).toList());

    final id = await db.insert('tasks', map);

    // Update media entries with taskId
    if (mediaIds.isNotEmpty) {
      final placeholders = mediaIds.map((_) => '?').join(',');
      await db.update(
        'media',
        {'taskId': id},
        where: 'id IN ($placeholders)',
        whereArgs: mediaIds,
      );
    }

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
    
    // Collect all media IDs from all tasks for batch lookup
    final Map<int, String> mediaIdToFilePath = {};
    final Set<int> allMediaIds = {};
    
    for (var taskMap in maps) {
      final attachmentsJson = taskMap['attachments'] as String?;
      if (attachmentsJson != null && attachmentsJson.isNotEmpty) {
        try {
          final List<dynamic> attachmentIds = json.decode(attachmentsJson);
          final List<int> mediaIds = attachmentIds
              .where((id) => RegExp(r'^\d+$').hasMatch(id.toString()))
              .map((id) => int.parse(id.toString()))
              .toList();
          allMediaIds.addAll(mediaIds);
        } catch (_) {}
      }
    }
    
    // Batch fetch all media in one query
    if (allMediaIds.isNotEmpty) {
      final mediaList = await getMediaByIds(allMediaIds.toList());
      for (var media in mediaList) {
        mediaIdToFilePath[media['id'] as int] = media['filePath'] as String;
      }
    }
    
    // Convert task maps and resolve media IDs to file paths
    List<Task> tasks = [];
    for (var i = 0; i < maps.length; i++) {
      try {
        final taskMap = Map<String, dynamic>.from(maps[i]);
        final attachmentsJson = taskMap['attachments'] as String?;
        if (attachmentsJson != null && attachmentsJson.isNotEmpty) {
          try {
            final List<dynamic> attachmentIds = json.decode(attachmentsJson);
            final List<String> filePaths = [];
            
            for (var id in attachmentIds) {
              if (RegExp(r'^\d+$').hasMatch(id.toString())) {
                final mediaId = int.parse(id.toString());
                final filePath = mediaIdToFilePath[mediaId];
                if (filePath != null) {
                  filePaths.add(filePath);
                }
              } else {
                // Legacy file path, keep as is
                filePaths.add(id.toString());
              }
            }
            
            taskMap['attachments'] = json.encode(filePaths);
          } catch (e) {
            debugPrint('Error converting media IDs to file paths for task ${taskMap['id']}: $e');
            // Keep original attachments on error
          }
        }
        
        tasks.add(Task.fromMap(taskMap));
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

    // Get old media IDs
    final oldTaskMap = (await db.query('tasks', where: 'id = ?', whereArgs: [task.id])).first;
    final oldAttachmentsJson = oldTaskMap['attachments'] as String?;
    List<int> oldMediaIds = [];
    if (oldAttachmentsJson != null && oldAttachmentsJson.isNotEmpty) {
      try {
        final oldAttachments = json.decode(oldAttachmentsJson) as List;
        // Only extract numeric IDs (media IDs), ignore file paths (legacy)
        oldMediaIds = oldAttachments
            .where((a) => RegExp(r'^\d+$').hasMatch(a.toString()))
            .map((a) => int.parse(a.toString()))
            .toList();
      } catch (_) {}
    }

    // Convert new attachment paths to media IDs
    final List<int> newMediaIds = [];
    for (var attachment in task.attachments) {
      try {
        // Check if it's already a media ID (as string)
        if (RegExp(r'^\d+$').hasMatch(attachment.toString())) {
          newMediaIds.add(int.parse(attachment.toString()));
        } else {
          // It's a file path, create media entry
          final file = File(attachment.toString());
          if (await file.exists()) {
            final fileName = attachment.toString().split('/').last;
            final fileSize = await file.length();
            final mimeType = _getMimeType(fileName);
            
            final mediaId = await insertMedia(
              filePath: attachment.toString(),
              fileName: fileName,
              fileSize: fileSize,
              mimeType: mimeType,
              taskId: task.id,
            );
            newMediaIds.add(mediaId);
          } else {
            debugPrint('Warning: Attachment file not found: $attachment');
          }
        }
      } catch (e) {
        debugPrint('Error processing attachment $attachment: $e');
        // Continue with other attachments
      }
    }

    // Delete media that are no longer referenced
    final mediaToDelete = oldMediaIds.where((id) => !newMediaIds.contains(id)).toList();
    for (var mediaId in mediaToDelete) {
      await deleteMedia(mediaId);
    }

    final map = task.toMap();
    map.remove('id'); // Ensure we don't try to update the primary key column
    map['updatedAt'] = nowStr;
    map['attachments'] = json.encode(newMediaIds.map((id) => id.toString()).toList());

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
    // Delete associated media files
    await deleteMediaByTaskId(id);
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

  // Export full data including media files as ZIP
  Future<Uint8List> exportFullData() async {
    // Export JSON data
    final data = await exportData();
    final jsonString = jsonEncode(data);
    final jsonBytes = utf8.encode(jsonString);

    // Get all media files
    final db = await database;
    final allMedia = await db.query('media');
    
    // Create ZIP archive
    final archive = Archive();
    
    // Add JSON data file
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));
    
    // Add all media files
    for (var media in allMedia) {
      final filePath = media['filePath'] as String;
      final fileName = media['fileName'] as String;
      final mediaId = media['id'] as int;
      
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final fileBytes = await file.readAsBytes();
          // Store in media/ folder with media ID prefix to avoid name conflicts
          archive.addFile(ArchiveFile('media/${mediaId}_$fileName', fileBytes.length, fileBytes));
        } else {
          debugPrint('Media file not found: $filePath');
        }
      } catch (e) {
        debugPrint('Error reading media file $filePath: $e');
      }
    }
    
    // Create ZIP file
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    
    if (zipBytes == null) {
      throw Exception('Failed to create ZIP archive');
    }
    
    return Uint8List.fromList(zipBytes);
  }

  Future<void> importData(dynamic inputData) async {
    debugPrint('Starting data import...');
    Database db = await database;
    final now = DateTime.now().toIso8601String();

    Map<String, dynamic> data;
    if (inputData is List) {
      data = {'tasks': inputData};
    } else if (inputData is Map<String, dynamic>) {
      data = inputData;
    } else {
      throw Exception('Invalid data format for import');
    }
    
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
            final oldId = taskMap['id'] as int?; // Safe cast to nullable int
            final title = taskMap['title'] as String? ?? '';
            final description = taskMap['description'] as String?;
            final dueDate = taskMap['dueDate'] as String? ?? now;
            
            // Basic deduplication: same title, description, and dueDate
            final duplicate = existingTasks.firstWhere(
              (t) => t['title'] == title && 
                     t['description'] == description && 
                     t['dueDate'] == dueDate,
              orElse: () => {},
            );
            
            if (duplicate.isNotEmpty) {
              if (oldId != null) taskIdMap[oldId] = duplicate['id'] as int;
              debugPrint('Skipping duplicate task: $title');
            } else {
              // New task
              final newTaskMap = Map<String, dynamic>.from(taskMap);
              newTaskMap.remove('id'); // Let SQLite handle ID
              
              // Ensure numeric fields are actually numbers and not null
              newTaskMap['title'] = title;
              newTaskMap['dueDate'] = dueDate;
              newTaskMap['priority'] = _toInt(newTaskMap['priority'], 1); // Default to Medium (1)
              newTaskMap['isDeleted'] = _toInt(newTaskMap['isDeleted'], 0) == 1 ? 1 : 0;
              newTaskMap['position'] = _toInt(newTaskMap['position'], 0);
              newTaskMap['createdAt'] = newTaskMap['createdAt'] ?? now;

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
                 final int statusValue = _toInt(newTaskMap['status'], 0);
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
              if (oldId != null) taskIdMap[oldId] = newId;
            }
          }
        }

        // 3. Import Events
        if (data['events'] != null) {
          final eventsList = (data['events'] as List).cast<Map<String, dynamic>>();
          debugPrint('Importing ${eventsList.length} events...');
          for (var eventMap in eventsList) {
            final oldTaskId = eventMap['taskId'] as int?;
            if (oldTaskId != null && taskIdMap.containsKey(oldTaskId)) {
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

  // Import full data from ZIP file (including media files)
  Future<void> importFullData(String zipFilePath) async {
    debugPrint('Starting full data import from ZIP...');
    
    try {
      // Read ZIP file
      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        throw Exception('ZIP file not found: $zipFilePath');
      }
      
      final zipBytes = await zipFile.readAsBytes();
      
      // Decode ZIP archive
      final archive = ZipDecoder().decodeBytes(zipBytes);
      
      // Find and read data.json
      ArchiveFile? dataFile;
      final List<ArchiveFile> mediaFiles = [];
      
      for (var file in archive) {
        if (file.name == 'data.json') {
          dataFile = file;
        } else if (file.name.startsWith('media/')) {
          mediaFiles.add(file);
        }
      }
      
      if (dataFile == null) {
        throw Exception('data.json not found in ZIP archive');
      }
      
      // Parse JSON data
      final jsonString = utf8.decode(dataFile.content as List<int>);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Get application documents directory for media files
      final appDir = await getApplicationDocumentsDirectory();
      final Map<int, String> oldMediaIdToNewPath = {}; // oldMediaId -> newFilePath
      
      // Extract and copy media files
      for (var mediaFile in mediaFiles) {
        try {
          // Extract media ID from filename (format: media/{id}_{filename})
          final fileName = mediaFile.name.replaceFirst('media/', '');
          final underscoreIndex = fileName.indexOf('_');
          if (underscoreIndex > 0) {
            final oldMediaId = int.tryParse(fileName.substring(0, underscoreIndex));
            final originalFileName = fileName.substring(underscoreIndex + 1);
            
            if (oldMediaId != null) {
              // Create new file path
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final newFileName = 'imported_${timestamp}_$originalFileName';
              final newFilePath = join(appDir.path, newFileName);
              
              // Write media file
              final file = File(newFilePath);
              await file.writeAsBytes(mediaFile.content as List<int>);
              
              oldMediaIdToNewPath[oldMediaId] = newFilePath;
              debugPrint('Extracted media file: $originalFileName -> $newFilePath');
            }
          }
        } catch (e) {
          debugPrint('Error extracting media file ${mediaFile.name}: $e');
        }
      }
      
      // Create media table entries for extracted files and map old IDs to new IDs
      final db = await database;
      final Map<int, int> oldMediaIdToNewMediaId = {}; // oldMediaId -> newMediaId
      
      for (var entry in oldMediaIdToNewPath.entries) {
        final oldMediaId = entry.key;
        final newFilePath = entry.value;
        final file = File(newFilePath);
        
        if (await file.exists()) {
          try {
            final fileName = newFilePath.split('/').last;
            final fileSize = await file.length();
            final mimeType = _getMimeType(fileName);
            
            final newMediaId = await insertMedia(
              filePath: newFilePath,
              fileName: fileName,
              fileSize: fileSize,
              mimeType: mimeType,
              taskId: null, // Will be updated when tasks are imported
            );
            
            oldMediaIdToNewMediaId[oldMediaId] = newMediaId;
            debugPrint('Created media entry: $oldMediaId -> $newMediaId ($fileName)');
          } catch (e) {
            debugPrint('Error creating media entry for $newFilePath: $e');
          }
        }
      }
      
      // Update task attachments to use new media IDs
      if (data['tasks'] != null && oldMediaIdToNewMediaId.isNotEmpty) {
        final tasksList = data['tasks'] as List;
        for (var task in tasksList) {
          final taskMap = task as Map<String, dynamic>;
          final attachmentsJson = taskMap['attachments'] as String?;
          
          if (attachmentsJson != null && attachmentsJson.isNotEmpty) {
            try {
              final attachments = json.decode(attachmentsJson) as List;
              final updatedAttachments = <String>[];
              
              for (var attachment in attachments) {
                final attachmentStr = attachment.toString();
                // Check if it's a media ID (numeric string)
                if (RegExp(r'^\d+$').hasMatch(attachmentStr)) {
                  final oldMediaId = int.parse(attachmentStr);
                  final newMediaId = oldMediaIdToNewMediaId[oldMediaId];
                  if (newMediaId != null) {
                    updatedAttachments.add(newMediaId.toString());
                  } else {
                    debugPrint('Media ID $oldMediaId not found in extracted files');
                  }
                } else {
                  // Legacy file path, keep as is
                  updatedAttachments.add(attachmentStr);
                }
              }
              
              taskMap['attachments'] = json.encode(updatedAttachments);
            } catch (e) {
              debugPrint('Error updating attachments for task: $e');
            }
          }
        }
      }
      
      // Import the data
      await importData(data);
      
      // Update media entries with task IDs after import
      if (data['tasks'] != null) {
        final tasksList = data['tasks'] as List;
        
        // Update media entries by matching tasks
        for (var task in tasksList) {
          final taskMap = task as Map<String, dynamic>;
          final oldTaskId = taskMap['id'] as int?;
          final attachmentsJson = taskMap['attachments'] as String?;
          
          if (oldTaskId != null && attachmentsJson != null && attachmentsJson.isNotEmpty) {
            try {
              final attachments = json.decode(attachmentsJson) as List;
              // Find the new task ID by matching title, description, and dueDate
              final title = taskMap['title'] as String? ?? '';
              final description = taskMap['description'] as String?;
              final dueDate = taskMap['dueDate'] as String?;
              
              final newTask = await db.query(
                'tasks',
                where: 'title = ? AND description = ? AND dueDate = ?',
                whereArgs: [title, description, dueDate],
                limit: 1,
              );
              
              if (newTask.isNotEmpty) {
                final newTaskId = newTask.first['id'] as int;
                
                // Update media entries with new task ID
                for (var attachment in attachments) {
                  final attachmentStr = attachment.toString();
                  if (RegExp(r'^\d+$').hasMatch(attachmentStr)) {
                    final mediaId = int.parse(attachmentStr);
                    await db.update(
                      'media',
                      {'taskId': newTaskId},
                      where: 'id = ?',
                      whereArgs: [mediaId],
                    );
                  }
                }
              }
            } catch (e) {
              debugPrint('Error updating media task IDs: $e');
            }
          }
        }
      }
      
      debugPrint('Full data import completed successfully!');
    } catch (e) {
      debugPrint('Error during full data import: $e');
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

  Future<void> deleteAllData() async {
    Database db = await database;
    await db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('task_events');
      await txn.delete('settings');
      await txn.delete('categories');
      
      // Re-insert default categories
      for (var cat in defaultCategories) {
        await txn.insert('categories', cat.toMap());
      }
    });
  }

  int _toInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is bool) return value ? 1 : 0;
    return defaultValue;
  }

  // Media CRUD operations
  Future<int> insertMedia({
    required String filePath,
    required String fileName,
    int? fileSize,
    String? mimeType,
    int? taskId,
  }) async {
    Database db = await database;
    final now = DateTime.now().toIso8601String();
    
    return await db.insert('media', {
      'filePath': filePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'createdAt': now,
      'taskId': taskId,
    });
  }

  Future<Map<String, dynamic>?> getMedia(int mediaId) async {
    Database db = await database;
    final maps = await db.query(
      'media',
      where: 'id = ?',
      whereArgs: [mediaId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<List<Map<String, dynamic>>> getMediaByTaskId(int taskId) async {
    Database db = await database;
    return await db.query(
      'media',
      where: 'taskId = ?',
      whereArgs: [taskId],
      orderBy: 'createdAt ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getMediaByIds(List<int> mediaIds) async {
    if (mediaIds.isEmpty) return [];
    Database db = await database;
    final placeholders = mediaIds.map((_) => '?').join(',');
    return await db.query(
      'media',
      where: 'id IN ($placeholders)',
      whereArgs: mediaIds,
      orderBy: 'createdAt ASC',
    );
  }

  Future<void> deleteMedia(int mediaId) async {
    Database db = await database;
    final media = await getMedia(mediaId);
    if (media != null) {
      // Delete the physical file
      try {
        final file = File(media['filePath'] as String);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting media file: $e');
      }
      
      // Delete from database
      await db.delete(
        'media',
        where: 'id = ?',
        whereArgs: [mediaId],
      );
    }
  }

  Future<void> deleteMediaByTaskId(int taskId) async {
    Database db = await database;
    final mediaList = await getMediaByTaskId(taskId);
    
    for (var media in mediaList) {
      try {
        final file = File(media['filePath'] as String);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting media file: $e');
      }
    }
    
    await db.delete(
      'media',
      where: 'taskId = ?',
      whereArgs: [taskId],
    );
  }

  // Migrate old attachments (file paths) to media table
  Future<void> _migrateOldAttachments(Database db) async {
    try {
      final List<Map<String, dynamic>> tasks = await db.query('tasks');
      final now = DateTime.now().toIso8601String();
      
      for (var taskMap in tasks) {
        final taskId = taskMap['id'] as int;
        final attachmentsJson = taskMap['attachments'] as String?;
        
        if (attachmentsJson == null || attachmentsJson.isEmpty || attachmentsJson == '[]') {
          continue;
        }
        
        try {
          final List<dynamic> attachments = json.decode(attachmentsJson);
          final List<int> mediaIds = [];
          
          for (var attachment in attachments) {
            final filePath = attachment.toString();
            
            // Check if this is already a media ID (numeric string)
            if (RegExp(r'^\d+$').hasMatch(filePath)) {
              // Already migrated, just add to list
              mediaIds.add(int.parse(filePath));
              continue;
            }
            
            // Check if file exists
            final file = File(filePath);
            if (!await file.exists()) {
              debugPrint('Attachment file not found: $filePath');
              continue;
            }
            
            // Get file info
            final fileName = filePath.split('/').last;
            final fileSize = await file.length();
            final mimeType = _getMimeType(fileName);
            
            // Insert into media table
            final mediaId = await db.insert('media', {
              'filePath': filePath,
              'fileName': fileName,
              'fileSize': fileSize,
              'mimeType': mimeType,
              'createdAt': now,
              'taskId': taskId,
            });
            
            mediaIds.add(mediaId);
          }
          
          // Update task with media IDs
          if (mediaIds.isNotEmpty) {
            await db.update(
              'tasks',
              {'attachments': json.encode(mediaIds.map((id) => id.toString()).toList())},
              where: 'id = ?',
              whereArgs: [taskId],
            );
          }
        } catch (e) {
          debugPrint('Error migrating attachments for task $taskId: $e');
        }
      }
      
      debugPrint('✅ Old attachments migration completed');
    } catch (e) {
      debugPrint('❌ Error in attachments migration: $e');
    }
  }

  String? _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'm4a':
      case 'mp3':
      case 'wav':
      case 'aac':
        return 'audio/$extension';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }
}
