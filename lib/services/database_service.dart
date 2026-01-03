import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/task.dart';
import '../models/goal.dart';
import '../models/category_data.dart';
import '../models/mood_entry.dart';
import '../models/activity.dart';
import '../constants/duck_emojis.dart';

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

  // Mood Tables Creation
  Future<void> _createMoodTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mood_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dateTime TEXT NOT NULL,
        moodLevel INTEGER NOT NULL,
        note TEXT,
        activityIds TEXT,
        attachments TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');

    // Activity Categories Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        iconName TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        isSystem INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Activities Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activities(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        iconName TEXT NOT NULL,
        categoryId INTEGER NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        isSystem INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (categoryId) REFERENCES activity_categories (id) ON DELETE CASCADE
      )
    ''');

    // Insert Default Data
    await _insertDefaultMoodData(db);
  }

  Future<void> _insertDefaultMoodData(dynamic db) async {
    final batch = db.batch();

    // 1. Emotions (احساسات)
    final emotionsId = await db.insert('activity_categories', {
      'name': 'احساسات',
      'iconName': '❤️',
      'sortOrder': 0,
      'isSystem': 1
    });

    final emotions = [
      {'name': 'خوشحال', 'icon': '😊', 'cat': emotionsId},
      {'name': 'هیجان‌زده', 'icon': '🤩', 'cat': emotionsId},
      {'name': 'شکرگزار', 'icon': '🙏', 'cat': emotionsId},
      {'name': 'آرام', 'icon': '😌', 'cat': emotionsId},
      {'name': 'خسته', 'icon': '😴', 'cat': emotionsId},
      {'name': 'بی‌حوصله', 'icon': '😑', 'cat': emotionsId},
      {'name': 'مضطرب', 'icon': '😰', 'cat': emotionsId},
      {'name': 'عصبانی', 'icon': '😠', 'cat': emotionsId},
      {'name': 'غمگین', 'icon': '😢', 'cat': emotionsId},
    ];

    for (var i = 0; i < emotions.length; i++) {
      batch.insert('activities', {
        'name': emotions[i]['name'],
        'iconName': emotions[i]['icon'],
        'categoryId': emotions[i]['cat'],
        'sortOrder': i,
        'isSystem': 1
      });
    }

    // 2. Hobbies (سرگرمی)
    final hobbiesId = await db.insert('activity_categories', {
      'name': 'سرگرمی',
      'iconName': '🎮',
      'sortOrder': 1,
      'isSystem': 1
    });

    final hobbies = [
      {'name': 'بازی', 'icon': '🕹️', 'cat': hobbiesId},
      {'name': 'فیلم', 'icon': '🎬', 'cat': hobbiesId},
      {'name': 'مطالعه', 'icon': '📚', 'cat': hobbiesId},
      {'name': 'سفر', 'icon': '✈️', 'cat': hobbiesId},
      {'name': 'موسیقی', 'icon': '🎵', 'cat': hobbiesId},
      {'name': 'مهمانی', 'icon': '🥳', 'cat': hobbiesId},
    ];

    for (var i = 0; i < hobbies.length; i++) {
      batch.insert('activities', {
        'name': hobbies[i]['name'],
        'iconName': hobbies[i]['icon'],
        'categoryId': hobbies[i]['cat'],
        'sortOrder': i,
        'isSystem': 1
      });
    }

    // 3. Sleep (خواب)
    final sleepId = await db.insert('activity_categories', {
      'name': 'خواب',
      'iconName': '💤',
      'sortOrder': 2,
      'isSystem': 1
    });

    final sleep = [
      {'name': 'خواب خوب', 'icon': '😴', 'cat': sleepId},
      {'name': 'خواب معمولی', 'icon': '🥱', 'cat': sleepId},
      {'name': 'خواب بد', 'icon': '😫', 'cat': sleepId},
    ];

    for (var i = 0; i < sleep.length; i++) {
      batch.insert('activities', {
        'name': sleep[i]['name'],
        'iconName': sleep[i]['icon'],
        'categoryId': sleep[i]['cat'],
        'sortOrder': i,
        'isSystem': 1
      });
    }

    // 4. Health (سلامت)
    final healthId = await db.insert('activity_categories', {
      'name': 'سلامت',
      'iconName': '🩺',
      'sortOrder': 3,
      'isSystem': 1
    });

    final health = [
      {'name': 'ورزش', 'icon': '🏃', 'cat': healthId},
      {'name': 'غذای سالم', 'icon': '🥗', 'cat': healthId},
      {'name': 'آب نوشیدن', 'icon': '💧', 'cat': healthId},
      {'name': 'پیاده‌روی', 'icon': '🚶', 'cat': healthId},
    ];

    for (var i = 0; i < health.length; i++) {
      batch.insert('activities', {
        'name': health[i]['name'],
        'iconName': health[i]['icon'],
        'categoryId': health[i]['cat'],
        'sortOrder': i,
        'isSystem': 1
      });
    }

    await batch.commit();
  }

  // --- Mood CRUD ---

  Future<int> insertMoodEntry(MoodEntry entry) async {
    Database db = await database;
    final map = entry.toMap();
    map.remove('id');

    // Handle Attachments (Convert paths to media IDs)
    final List<int> mediaIds = [];
    for (var attachment in entry.attachments) {
      if (RegExp(r'^\d+$').hasMatch(attachment)) {
        mediaIds.add(int.parse(attachment));
      } else {
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
            moodId: null, // Will be updated after entry is created
          );
          mediaIds.add(mediaId);
        }
      }
    }
    map['attachments'] = json.encode(mediaIds.map((id) => id.toString()).toList());

    final id = await db.insert('mood_entries', map);

    // Update media entries with the new mood ID
    if (mediaIds.isNotEmpty) {
      await db.update(
        'media',
        {'moodId': id},
        where: 'id IN (${mediaIds.join(',')})',
      );
    }

    return id;
  }

  Future<int> updateMoodEntry(MoodEntry entry) async {
    Database db = await database;
    final now = DateTime.now().toIso8601String();
    final map = entry.toMap();
    map['updatedAt'] = now;

    // Handle Attachments
    final List<int> mediaIds = [];
    for (var attachment in entry.attachments) {
      if (RegExp(r'^\d+$').hasMatch(attachment)) {
        mediaIds.add(int.parse(attachment));
      } else {
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
            moodId: entry.id,
          );
          mediaIds.add(mediaId);
        }
      }
    }
    map['attachments'] = json.encode(mediaIds.map((id) => id.toString()).toList());

    return await db.update(
      'mood_entries',
      map,
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<List<MoodEntry>> getAllMoodEntries() async {
    Database db = await database;
    final maps = await db.query('mood_entries', orderBy: 'dateTime DESC');

    List<MoodEntry> entries = [];

    for (var map in maps) {
      // Get Attachments (resolve IDs to paths)
      final attachmentsJson = map['attachments'] as String?;
      List<String> attachments = [];
      if (attachmentsJson != null) {
        try {
          final List<dynamic> ids = json.decode(attachmentsJson);
          final mediaIds = ids.map((e) => int.parse(e.toString())).toList();
          if (mediaIds.isNotEmpty) {
            final mediaList = await getMediaByIds(mediaIds);
            attachments = mediaList.map((m) => m['filePath'] as String).toList();
          }
        } catch (_) {}
      }

      entries.add(MoodEntry.fromMap(map).copyWith(attachments: attachments));
    }
    return entries;
  }

  Future<int> deleteMoodEntry(int id) async {
    Database db = await database;
    // Delete associated media files
    await deleteMediaByMoodId(id);
    return await db.delete('mood_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMediaByMoodId(int moodId) async {
    Database db = await database;
    final mediaList = await db.query(
      'media',
      where: 'moodId = ?',
      whereArgs: [moodId],
    );

    for (var media in mediaList) {
      await deleteMedia(media['id'] as int);
    }
  }

  // --- Activity CRUD ---

  Future<List<ActivityCategory>> getAllActivityCategories() async {
    Database db = await database;
    final maps = await db.query('activity_categories', orderBy: 'sortOrder ASC');
    return maps.map((e) => ActivityCategory.fromMap(e)).toList();
  }

  Future<List<Activity>> getActivitiesByCategoryId(int categoryId) async {
    Database db = await database;
    final maps = await db.query(
      'activities', 
      where: 'categoryId = ?', 
      whereArgs: [categoryId],
      orderBy: 'sortOrder ASC'
    );
    return maps.map((e) => Activity.fromMap(e)).toList();
  }

  Future<List<Activity>> getAllActivities() async {
    Database db = await database;
    final maps = await db.query('activities', orderBy: 'sortOrder ASC');
    return maps.map((e) => Activity.fromMap(e)).toList();
  }

  Future<int> insertActivityCategory(String name, String iconName) async {
    Database db = await database;
    return await db.insert('activity_categories', {
      'name': name,
      'iconName': iconName,
      'sortOrder': 0,
      'isSystem': 0
    });
  }

  Future<int> updateActivityCategory(ActivityCategory category) async {
    Database db = await database;
    return await db.update(
      'activity_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id]
    );
  }

  Future<int> deleteActivityCategory(int id) async {
    Database db = await database;
    return await db.delete('activity_categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertActivity(String name, String iconName, int categoryId) async {
    Database db = await database;
    return await db.insert('activities', {
      'name': name,
      'iconName': iconName,
      'categoryId': categoryId,
      'sortOrder': 0,
      'isSystem': 0
    });
  }

  Future<int> deleteActivity(int id) async {
    Database db = await database;
    return await db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateActivity(Activity activity) async {
    Database db = await database;
    return await db.update(
      'activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'flow_database.db');
    
    Database? db;
    try {
      db = await openDatabase(
        path,
        version: 27,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      debugPrint('Error opening database: $e');
      // If database opening fails (e.g. corruption), try to recover or at least not crash
      // We DON'T delete the database here to prevent data loss, 
      // instead we let the app handle the null or throw.
      rethrow;
    }

    // Migrate old attachments to media table on startup
    try {
      await _migrateOldAttachments(db);
    } catch (e) {
      debugPrint('Error in initial migration of attachments: $e');
    }

    return db;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN position INTEGER NOT NULL DEFAULT 0',
      );
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
      await db.execute(
        'ALTER TABLE categories ADD COLUMN position INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0',
      );
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
        if (taskMap['status'] != null &&
            (taskMap['statusHistory'] == null ||
                taskMap['statusHistory'] == '{}')) {
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
        final hasFileType = tableInfo.any(
          (column) => column['name'] == 'fileType',
        );

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
    if (oldVersion < 16) {
      // Version 16: Add deletedAt column to categories table for soft delete
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN deletedAt TEXT');
        debugPrint('✅ Added deletedAt column to categories table');
      } catch (e) {
        debugPrint('Error adding deletedAt column: $e');
        // Column might already exist, ignore error
      }

      // Merge duplicate categories by name (case-insensitive) and update tasks
      try {
        final allCategories = await db.query(
          'categories',
          orderBy: 'position ASC',
        );
        final Map<String, List<Map<String, dynamic>>> categoriesByName = {};

        // Group categories by lowercase label
        for (var cat in allCategories) {
          final labelLower = (cat['label'] as String? ?? '').toLowerCase();
          if (!categoriesByName.containsKey(labelLower)) {
            categoriesByName[labelLower] = [];
          }
          categoriesByName[labelLower]!.add(cat);
        }

        // For each group with duplicates, keep the oldest one and merge others
        for (var entry in categoriesByName.entries) {
          final duplicates = entry.value;
          if (duplicates.length > 1) {
            // Sort by position (lower position = older)
            duplicates.sort(
              (a, b) => (a['position'] as int? ?? 0).compareTo(
                b['position'] as int? ?? 0,
              ),
            );
            final keepCategory = duplicates.first;
            final keepId = keepCategory['id'] as String;

            debugPrint(
              'Merging duplicate categories for "${entry.key}": keeping $keepId',
            );

            // Update all tasks that reference duplicate categories to use the kept one
            for (var duplicate in duplicates.skip(1)) {
              final duplicateId = duplicate['id'] as String;

              // Find all tasks with this category
              final tasks = await db.query(
                'tasks',
                where: 'categories LIKE ?',
                whereArgs: ['%$duplicateId%'],
              );

              for (var task in tasks) {
                try {
                  final categoriesJson = task['categories'] as String? ?? '[]';
                  final categories = List<String>.from(
                    json.decode(categoriesJson),
                  );

                  if (categories.contains(duplicateId)) {
                    // Replace duplicate ID with kept ID
                    categories.remove(duplicateId);
                    if (!categories.contains(keepId)) {
                      categories.add(keepId);
                    }

                    await db.update(
                      'tasks',
                      {'categories': json.encode(categories)},
                      where: 'id = ?',
                      whereArgs: [task['id']],
                    );
                  }
                } catch (e) {
                  debugPrint('Error updating task categories: $e');
                }
              }

              // Soft delete the duplicate category
              await db.update(
                'categories',
                {'deletedAt': DateTime.now().toIso8601String()},
                where: 'id = ?',
                whereArgs: [duplicateId],
              );
            }
          }
        }

        // Update study category emoji to 74_BOTAN_OUT
        final studyCategory = allCategories.firstWhere(
          (c) => (c['id'] as String? ?? '').toLowerCase() == 'study',
          orElse: () => {},
        );

        if (studyCategory.isNotEmpty) {
          await db.update(
            'categories',
            {'emoji': DuckEmojis.academic},
            where: 'id = ?',
            whereArgs: [studyCategory['id']],
          );
        }

        // Check if "تحصیلی" category exists, if not add it, if yes ensure it uses correct emoji
        final academicExists = allCategories.any(
          (c) =>
              (c['label'] as String? ?? '').toLowerCase() == 'تحصیلی' ||
              (c['id'] as String? ?? '').toLowerCase() == 'academic',
        );

        if (!academicExists) {
          // Add new academic category
          final maxPosition = allCategories.isEmpty
              ? 0
              : (allCategories
                        .map((c) => c['position'] as int? ?? 0)
                        .reduce((a, b) => a > b ? a : b) +
                    1);

          await db.insert(
            'categories',
            {
              'id': 'academic',
              'label': 'تحصیلی',
              'emoji': DuckEmojis.academic,
              'color': 0xFF9C27B0,
              'position': maxPosition,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        } else {
          // Update existing academic category to use correct emoji
          final academicCategory = allCategories.firstWhere(
            (c) =>
                (c['label'] as String? ?? '').toLowerCase() == 'تحصیلی' ||
                (c['id'] as String? ?? '').toLowerCase() == 'academic',
            orElse: () => {},
          );

          if (academicCategory.isNotEmpty &&
              academicCategory['emoji'] != DuckEmojis.academic) {
            await db.update(
              'categories',
              {'emoji': DuckEmojis.academic},
              where: 'id = ?',
              whereArgs: [academicCategory['id']],
            );
          }
        }
      } catch (e) {
        debugPrint('Error in category migration: $e');
      }
    }
    if (oldVersion < 17) {
      // Version 17: Add goals table and goalIds to tasks
      await _createGoalsTable(db);
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN goalIds TEXT');
        debugPrint('✅ Added goalIds column to tasks table');
      } catch (e) {
        debugPrint('Error adding goalIds column: $e');
      }
    }
    if (oldVersion < 18) {
      // Version 18: Add goalId to media table and audioPath to goals table if missing
      try {
        await db.execute('ALTER TABLE media ADD COLUMN goalId INTEGER');
        debugPrint('✅ Added goalId column to media table');
      } catch (e) {
        debugPrint('Error adding goalId column to media: $e');
      }

      try {
        await db.execute('ALTER TABLE goals ADD COLUMN audioPath TEXT');
        debugPrint('✅ Added audioPath column to goals table');
      } catch (e) {
        debugPrint('Error adding audioPath column to goals: $e');
      }
    }
    if (oldVersion < 19) {
      try {
        // Add categoryIds column
        await db.execute('ALTER TABLE goals ADD COLUMN categoryIds TEXT');
        
        // Migrate existing data from categoryId to categoryIds
        final goals = await db.query('goals');
        for (var goal in goals) {
          final catId = goal['categoryId'] as String?;
          final List<String> catIds = [];
          if (catId != null && catId.isNotEmpty) {
            catIds.add(catId);
          }
          await db.update(
            'goals', 
            {'categoryIds': json.encode(catIds)}, 
            where: 'id = ?', 
            whereArgs: [goal['id']]
          );
        }
        debugPrint('✅ Migrated goals to support multiple categories');
      } catch (e) {
        debugPrint('Error migrating goals to version 19: $e');
      }
    }
    if (oldVersion < 20) {
      // Version 20: Maintenance update to ensure migration stability
      debugPrint('✅ Database migrated to version 20');
    }
    if (oldVersion < 21) {
      // Version 21: Add endTime to tasks table
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN endTime TEXT');
        debugPrint('✅ Added endTime column to tasks table');
      } catch (e) {
        debugPrint('Error adding endTime column to tasks: $e');
      }
    }
    if (oldVersion < 22) {
      // Version 22: Add reminderDateTime to tasks table
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN reminderDateTime TEXT');
        debugPrint('✅ Added reminderDateTime column to tasks table');
      } catch (e) {
        debugPrint('Error adding reminderDateTime column to tasks: $e');
      }
    }
    if (oldVersion < 23) {
      // Version 23: Add mood tracking tables
      await _createMoodTables(db);
    }
    if (oldVersion < 24) {
      // Version 24: Drop and recreate mood tables to ensure clean state after emoji updates
      await db.execute('DROP TABLE IF EXISTS mood_activities_link');
      await db.execute('DROP TABLE IF EXISTS activities');
      await db.execute('DROP TABLE IF EXISTS activity_categories');
      await db.execute('DROP TABLE IF EXISTS mood_entries');
      await _createMoodTables(db);
    }
    if (oldVersion < 27) {
        // Version 27: Drop unused mood_activities_link table
        try {
          await db.execute('DROP TABLE IF EXISTS mood_activities_link');
          debugPrint('✅ Dropped unused mood_activities_link table');
        } catch (e) {
          debugPrint('Error dropping mood_activities_link: $e');
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
        endTime TEXT,
        priority INTEGER NOT NULL,
        categories TEXT,
        tags TEXT,
        goalIds TEXT,
        taskEmoji TEXT,
        attachments TEXT,
        recurrence TEXT,
        statusHistory TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        deletedAt TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0,
        reminderDateTime TEXT,
        metadata TEXT
      )
    ''');
    await _createCategoriesTable(db);
    await _createMediaTable(db);
    await _createGoalsTable(db);
    await _createMoodTables(db);
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

  Future<void> _createGoalsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        emoji TEXT NOT NULL,
        categoryIds TEXT,
        deadline TEXT,
        priority INTEGER NOT NULL,
        tags TEXT,
        attachments TEXT,
        audioPath TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // Goals CRUD
  Future<List<Goal>> getAllGoals({bool includeDeleted = false}) async {
    Database db = await database;
    List<Map<String, dynamic>> maps;
    if (includeDeleted) {
      maps = await db.query('goals', orderBy: 'position ASC');
    } else {
      maps = await db.query(
        'goals',
        where: 'isDeleted = 0',
        orderBy: 'position ASC',
      );
    }
    if (maps.isEmpty) return [];
    return List.generate(maps.length, (i) => Goal.fromMap(maps[i]));
  }

  Future<Goal?> getGoalById(int id) async {
    Database db = await database;
    final maps = await db.query('goals', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Goal.fromMap(maps.first);
  }

  Future<int> insertGoal(Goal goal) async {
    Database db = await database;
    final now = DateTime.now().toIso8601String();
    final map = goal.toMap();
    map['updatedAt'] = now;

    // Convert attachment paths to media IDs
    final List<int> mediaIds = [];
    for (var attachment in goal.attachments) {
      if (RegExp(r'^\d+$').hasMatch(attachment)) {
        mediaIds.add(int.parse(attachment));
      } else {
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
            goalId: null, // Will be updated after goal is created
          );
          mediaIds.add(mediaId);
        }
      }
    }

    // Handle audioPath if it exists and is not already a media entry
    if (goal.audioPath != null && goal.audioPath!.isNotEmpty) {
      final audioFile = File(goal.audioPath!);
      if (await audioFile.exists()) {
        final fileName = goal.audioPath!.split('/').last;
        final fileSize = await audioFile.length();
        final mimeType = _getMimeType(fileName);

        final mediaId = await insertMedia(
          filePath: goal.audioPath!,
          fileName: fileName,
          fileSize: fileSize,
          mimeType: mimeType,
          goalId: null,
        );
        // We don't add audioPath to mediaIds list as it's a separate field, 
        // but we'll update its goalId later.
        mediaIds.add(mediaId);
      }
    }

    map['attachments'] = json.encode(
      mediaIds.map((id) => id.toString()).toList(),
    );

    final id = await db.insert('goals', map);

    // Update media entries with goalId
    if (mediaIds.isNotEmpty) {
      final placeholders = mediaIds.map((_) => '?').join(',');
      await db.update(
        'media',
        {'goalId': id},
        where: 'id IN ($placeholders)',
        whereArgs: mediaIds,
      );
    }

    return id;
  }

  Future<int> updateGoal(Goal goal) async {
    Database db = await database;
    final now = DateTime.now().toIso8601String();
    final map = goal.toMap();
    map['updatedAt'] = now;

    // Get old attachments to find what to delete
    final oldGoal = await getGoalById(goal.id!);
    List<int> oldMediaIds = [];
    if (oldGoal != null) {
      try {
        oldMediaIds = oldGoal.attachments
            .where((a) => RegExp(r'^\d+$').hasMatch(a))
            .map((a) => int.parse(a))
            .toList();
        if (oldGoal.audioPath != null && RegExp(r'^\d+$').hasMatch(oldGoal.audioPath!)) {
           oldMediaIds.add(int.parse(oldGoal.audioPath!));
        }
      } catch (_) {}
    }

    // Convert new attachment paths to media IDs
    final List<int> newMediaIds = [];
    for (var attachment in goal.attachments) {
      if (RegExp(r'^\d+$').hasMatch(attachment)) {
        newMediaIds.add(int.parse(attachment));
      } else {
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
            goalId: goal.id,
          );
          newMediaIds.add(mediaId);
        }
      }
    }

    // Handle audioPath
    if (goal.audioPath != null && goal.audioPath!.isNotEmpty) {
      if (RegExp(r'^\d+$').hasMatch(goal.audioPath!)) {
        newMediaIds.add(int.parse(goal.audioPath!));
      } else {
        final audioFile = File(goal.audioPath!);
        if (await audioFile.exists()) {
          final fileName = goal.audioPath!.split('/').last;
          final fileSize = await audioFile.length();
          final mimeType = _getMimeType(fileName);

          final mediaId = await insertMedia(
            filePath: goal.audioPath!,
            fileName: fileName,
            fileSize: fileSize,
            mimeType: mimeType,
            goalId: goal.id,
          );
          newMediaIds.add(mediaId);
          map['audioPath'] = mediaId.toString();
        }
      }
    }

    // Delete media that are no longer referenced
    final mediaToDelete = oldMediaIds
        .where((id) => !newMediaIds.contains(id))
        .toList();
    for (var mediaId in mediaToDelete) {
      await deleteMedia(mediaId);
    }

    map['attachments'] = json.encode(
      newMediaIds.map((id) => id.toString()).toList(),
    );

    return await db.update(
      'goals',
      map,
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteGoal(int id) async {
    Database db = await database;
    // Soft delete
    return await db.update(
      'goals',
      {
        'isDeleted': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
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
        taskId INTEGER,
        goalId INTEGER,
        moodId INTEGER
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
        position INTEGER NOT NULL DEFAULT 0,
        deletedAt TEXT
      )
    ''');

    // Insert default categories
    final batch = db.batch();
    for (var cat in defaultCategories) {
      batch.insert(
        'categories',
        cat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit();
  }

  // Categories CRUD
  Future<List<CategoryData>> getAllCategories({
    bool includeDeleted = false,
  }) async {
    Database db = await database;
    List<Map<String, dynamic>> maps;
    if (includeDeleted) {
      maps = await db.query('categories', orderBy: 'position ASC');
    } else {
      maps = await db.query(
        'categories',
        where: 'deletedAt IS NULL',
        orderBy: 'position ASC',
      );
    }
    if (maps.isEmpty) return [];
    return List.generate(maps.length, (i) => CategoryData.fromMap(maps[i]));
  }

  // Get category by ID (including deleted ones for task display)
  Future<CategoryData?> getCategoryById(String id) async {
    Database db = await database;
    final maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CategoryData.fromMap(maps.first);
  }

  Future<int> insertCategory(CategoryData category) async {
    Database db = await database;

    // Check for duplicate name (case-insensitive)
    final existing = await db.query(
      'categories',
      where: 'LOWER(label) = ? AND deletedAt IS NULL',
      whereArgs: [category.label.toLowerCase()],
    );

    if (existing.isNotEmpty) {
      throw Exception('دسته‌بندی با این نام از قبل وجود دارد');
    }

    return await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateCategory(CategoryData category) async {
    Database db = await database;

    // Check for duplicate name (case-insensitive), excluding current category
    final existing = await db.query(
      'categories',
      where: 'LOWER(label) = ? AND id != ? AND deletedAt IS NULL',
      whereArgs: [category.label.toLowerCase(), category.id],
    );

    if (existing.isNotEmpty) {
      throw Exception('دسته‌بندی با این نام از قبل وجود دارد');
    }

    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    Database db = await database;
    // Soft delete: mark as deleted instead of removing
    final now = DateTime.now().toIso8601String();
    return await db.update(
      'categories',
      {'deletedAt': now},
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
    map['attachments'] = json.encode(
      mediaIds.map((id) => id.toString()).toList(),
    );

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

    debugPrint(
      "📥 DB: Fetched ${maps.length} tasks (includeDeleted: $includeDeleted)",
    );

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
    // Also fetch status events for all tasks to populate statusLogs
    final List<int> taskIds = maps.map((m) => m['id'] as int).toList();
    final Map<int, List<Map<String, dynamic>>> taskStatusLogs = {};

    if (taskIds.isNotEmpty) {
      final placeholders = taskIds.map((_) => '?').join(',');
      final eventMaps = await db.query(
        'task_events',
        where: 'taskId IN ($placeholders) AND type = ?',
        whereArgs: [...taskIds, 'status_update'],
        orderBy: 'occurredAt ASC',
      );

      for (var eventMap in eventMaps) {
        final taskId = eventMap['taskId'] as int;
        final logs = taskStatusLogs[taskId] ?? [];

        // Decode payload if it's a string
        var processedEvent = Map<String, dynamic>.from(eventMap);
        if (processedEvent['payload'] is String) {
          try {
            processedEvent['payload'] = json.decode(
              processedEvent['payload'] as String,
            );
          } catch (_) {}
        }

        logs.add(processedEvent);
        taskStatusLogs[taskId] = logs;
      }
    }

    List<Task> tasks = [];
    for (var i = 0; i < maps.length; i++) {
      try {
        final taskMap = Map<String, dynamic>.from(maps[i]);
        final taskId = taskMap['id'] as int;

        // Resolve media attachments
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
            debugPrint(
              'Error converting media IDs to file paths for task ${taskMap['id']}: $e',
            );
          }
        }

        // Add status logs
        final logs = taskStatusLogs[taskId] ?? [];
        taskMap['statusLogs'] = json.encode(logs);

        tasks.add(Task.fromMap(taskMap));
      } catch (e) {
        debugPrint(
          "❌ Error parsing task at index $i (ID: ${maps[i]['id']}): $e",
        );
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
    final oldTaskMap = (await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [task.id],
    )).first;
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
    final mediaToDelete = oldMediaIds
        .where((id) => !newMediaIds.contains(id))
        .toList();
    for (var mediaId in mediaToDelete) {
      await deleteMedia(mediaId);
    }

    final map = task.toMap();
    map.remove('id'); // Ensure we don't try to update the primary key column
    map['updatedAt'] = nowStr;
    map['attachments'] = json.encode(
      newMediaIds.map((id) => id.toString()).toList(),
    );

    await db.update('tasks', map, where: 'id = ?', whereArgs: [task.id]);

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
    final goals = await getAllGoals(includeDeleted: true);
    final categories = await getAllCategories();
    final db = await database;
    final events = await db.query('task_events');
    final settings = await db.query('settings');
    
    // Export Mood Tracking Data
    final moodEntries = await db.query('mood_entries');
    final activityCategories = await db.query('activity_categories');
    final activities = await db.query('activities');

    return {
      'version': 5, // Increment version for mood support refactor
      'timestamp': DateTime.now().toIso8601String(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'goals': goals.map((g) => g.toMap()).toList(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'events': events,
      'settings': settings,
      'mood_entries': moodEntries,
      'activity_categories': activityCategories,
      'activities': activities,
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
          archive.addFile(
            ArchiveFile(
              'media/${mediaId}_$fileName',
              fileBytes.length,
              fileBytes,
            ),
          );
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

  Future<Map<String, Map<dynamic, dynamic>>> importData(dynamic inputData) async {
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

    // Initialize all ID mapping maps
    Map<String, String> categoryIdMap = {}; // oldId -> newId
    Map<int, int> goalIdMap = {}; // oldId -> newId
    Map<int, int> taskIdMap = {}; // oldId -> newId
    Map<int, int> activityCategoryIdMap = {}; // oldId -> newId
    Map<int, int> activityIdMap = {}; // oldId -> newId
    Map<int, int> moodIdMap = {}; // oldId -> newId

    try {
      await db.transaction((txn) async {
        // 1. Import Categories (Deduplicate by ID or label - Case Insensitive)
        if (data['categories'] != null) {
          final categoriesList = (data['categories'] as List)
              .cast<Map<String, dynamic>>();
          debugPrint('Importing ${categoriesList.length} categories...');

          // Get existing categories (including deleted ones for merging)
          final existingCategories = await txn.query(
            'categories',
            orderBy: 'position ASC',
          );

          // First, check for duplicates within imported categories and merge them
          final Map<String, List<Map<String, dynamic>>> importedByName = {};
          for (var catMap in categoriesList) {
            final importLabel = (catMap['label']?.toString() ?? '')
                .toLowerCase();
            if (!importedByName.containsKey(importLabel)) {
              importedByName[importLabel] = [];
            }
            importedByName[importLabel]!.add(catMap);
          }

          // Merge duplicates within imported data (keep the first one)
          final List<Map<String, dynamic>> deduplicatedImports = [];
          for (var entry in importedByName.entries) {
            final duplicates = entry.value;
            if (duplicates.length > 1) {
              // Sort by position if available, otherwise keep first
              duplicates.sort((a, b) {
                final posA = a['position'] as int? ?? 999;
                final posB = b['position'] as int? ?? 999;
                return posA.compareTo(posB);
              });
              debugPrint(
                'Merging duplicate imported categories for "${entry.key}": keeping first',
              );
            }
            deduplicatedImports.add(duplicates.first);
          }

          // Now process deduplicated imports against existing categories
          for (var catMap in deduplicatedImports) {
            final importId = catMap['id']?.toString() ?? '';
            final importLabel = catMap['label']?.toString() ?? '';

            // Check if category with same ID or label exists (case-insensitive, excluding deleted)
            final existing = existingCategories.firstWhere((c) {
              final dbId = c['id']?.toString().toLowerCase();
              final dbLabel = c['label']?.toString().toLowerCase();
              final impIdLower = importId.toLowerCase();
              final impLabelLower = importLabel.toLowerCase();
              final isDeleted = c['deletedAt'] != null;
              return !isDeleted &&
                  (dbId == impIdLower || dbLabel == impLabelLower);
            }, orElse: () => {});

            if (existing.isNotEmpty) {
              final existingId = existing['id'] as String;
              final existingPosition = existing['position'] as int? ?? 999;
              final importPosition = catMap['position'] as int? ?? 999;

              // Keep the older category (lower position)
              if (importPosition < existingPosition) {
                // Imported is older, update existing with imported data
                categoryIdMap[importId] = existingId;
                final updates = <String, dynamic>{'position': importPosition};
                if (catMap['emoji'] != null) {
                  updates['emoji'] = catMap['emoji'];
                }
                if (catMap['color'] != null) {
                  updates['color'] = catMap['color'];
                }
                await txn.update(
                  'categories',
                  updates,
                  where: 'id = ?',
                  whereArgs: [existingId],
                );
              } else {
                // Existing is older, just map import ID to existing
                categoryIdMap[importId] = existingId;

                // Update emoji or color if they changed (but keep existing position)
                final updates = <String, dynamic>{};
                if (catMap['emoji'] != null &&
                    catMap['emoji'] != existing['emoji']) {
                  updates['emoji'] = catMap['emoji'];
                }
                if (catMap['color'] != null &&
                    catMap['color'] != existing['color']) {
                  updates['color'] = catMap['color'];
                }

                if (updates.isNotEmpty) {
                  await txn.update(
                    'categories',
                    updates,
                    where: 'id = ?',
                    whereArgs: [existingId],
                  );
                }
              }
            } else {
              // Check if there's a deleted category with same name to restore
              final deleted = existingCategories.firstWhere((c) {
                final dbId = c['id']?.toString().toLowerCase();
                final dbLabel = c['label']?.toString().toLowerCase();
                final impIdLower = importId.toLowerCase();
                final impLabelLower = importLabel.toLowerCase();
                final isDeleted = c['deletedAt'] != null;
                return isDeleted &&
                    (dbId == impIdLower || dbLabel == impLabelLower);
              }, orElse: () => {});

              if (deleted.isNotEmpty) {
                // Restore deleted category
                final deletedId = deleted['id'] as String;
                categoryIdMap[importId] = deletedId;
                final updates = <String, dynamic>{'deletedAt': null};
                if (catMap['emoji'] != null) {
                  updates['emoji'] = catMap['emoji'];
                }
                if (catMap['color'] != null) {
                  updates['color'] = catMap['color'];
                }
                if (catMap['position'] != null) {
                  updates['position'] = catMap['position'];
                }
                await txn.update(
                  'categories',
                  updates,
                  where: 'id = ?',
                  whereArgs: [deletedId],
                );
              } else {
                // New category - check for duplicate name in existing (case-insensitive)
                final duplicateName = existingCategories.firstWhere((c) {
                  final dbLabel = (c['label']?.toString() ?? '').toLowerCase();
                  final impLabelLower = importLabel.toLowerCase();
                  return dbLabel == impLabelLower;
                }, orElse: () => {});

                if (duplicateName.isNotEmpty) {
                  // Merge into existing category with same name
                  final duplicateId = duplicateName['id'] as String;
                  categoryIdMap[importId] = duplicateId;
                  debugPrint(
                    'Merging imported category "$importLabel" into existing "$duplicateId"',
                  );
                } else {
                  // Truly new category
                  await txn.insert(
                    'categories',
                    catMap,
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                  categoryIdMap[importId] = importId;
                }
              }
            }
          }
        }

        // 2. Import Goals
        if (data['goals'] != null) {
          final goalsList = (data['goals'] as List).cast<Map<String, dynamic>>();
          debugPrint('Importing ${goalsList.length} goals...');

          final existingGoals = await txn.query('goals');

          for (var goalMap in goalsList) {
            final oldId = int.tryParse(goalMap['id']?.toString() ?? '');
            final title = goalMap['title'] as String? ?? '';
            final description = goalMap['description'] as String? ?? '';

            // Deduplication: same title and description
            final duplicate = existingGoals.firstWhere(
              (g) =>
                  g['title'].toString().toLowerCase() == title.toLowerCase() &&
                  g['description'].toString().toLowerCase() ==
                      description.toLowerCase(),
              orElse: () => {},
            );

            if (duplicate.isNotEmpty) {
              if (oldId != null) goalIdMap[oldId] = duplicate['id'] as int;
              debugPrint('Skipping duplicate goal: $title');
            } else {
              // New goal
              final newGoalMap = Map<String, dynamic>.from(goalMap);
              newGoalMap.remove('id');

              // Map categories
              if (newGoalMap['categoryIds'] != null) {
                try {
                  final dynamic catsRaw = newGoalMap['categoryIds'];
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
                    updatedCats.add(categoryIdMap[catId] ?? catId);
                  }
                  newGoalMap['categoryIds'] = json.encode(updatedCats);
                } catch (_) {}
              }

              newGoalMap['updatedAt'] = now;
              newGoalMap['createdAt'] = newGoalMap['createdAt'] ?? now;

              final newId = await txn.insert('goals', newGoalMap);
              if (oldId != null) goalIdMap[oldId] = newId;
            }
          }
        }

        // 3. Import Tasks (Deduplicate by title, description, and dueDate)
        if (data['tasks'] != null) {
          final tasksList =
              (data['tasks'] as List).cast<Map<String, dynamic>>();
          debugPrint('Importing ${tasksList.length} tasks...');

          final existingTasks = await txn.query(
            'tasks',
            where: 'isDeleted = 0',
          );

          for (var taskMap in tasksList) {
            final oldId = int.tryParse(taskMap['id']?.toString() ?? '');
            final title = taskMap['title'] as String? ?? '';
            final description = taskMap['description'] as String?;
            final dueDate = taskMap['dueDate'] as String? ?? now;

            // Basic deduplication: same title, description, and dueDate
            final duplicate = existingTasks.firstWhere(
              (t) =>
                  t['title'].toString().toLowerCase() == title.toLowerCase() &&
                  (t['description']?.toString().toLowerCase() ==
                      description?.toLowerCase()) &&
                  t['dueDate'] == dueDate,
              orElse: () => {},
            );

            if (duplicate.isNotEmpty) {
              final existingTaskId = duplicate['id'] as int;
              if (oldId != null) taskIdMap[oldId] = existingTaskId;
              debugPrint('Skipping duplicate task: $title');

              // Even if duplicate, we might want to update goalIds if provided in import
              try {
                List<int> importGoalIds = [];
                if (taskMap['goalId'] != null) {
                  final gId = int.tryParse(taskMap['goalId'].toString());
                  if (gId != null) importGoalIds.add(gId);
                }
                if (taskMap['goalIds'] != null) {
                  final dynamic goalsRaw = taskMap['goalIds'];
                  if (goalsRaw is String) {
                    final List<dynamic> decoded = json.decode(goalsRaw);
                    importGoalIds.addAll(
                      decoded.map((e) => int.parse(e.toString())),
                    );
                  } else if (goalsRaw is List) {
                    importGoalIds.addAll(
                      goalsRaw.map((e) => int.parse(e.toString())),
                    );
                  }
                }

                if (importGoalIds.isNotEmpty) {
                  // Map and merge with existing goalIds
                  final List<int> mappedImportIds = [];
                  for (var oldGoalId in importGoalIds) {
                    if (goalIdMap.containsKey(oldGoalId)) {
                      mappedImportIds.add(goalIdMap[oldGoalId]!);
                    }
                  }

                  if (mappedImportIds.isNotEmpty) {
                    // Get existing goalIds
                    List<int> existingGoalIds = [];
                    if (duplicate['goalIds'] != null) {
                      try {
                        final List<dynamic> decoded = json.decode(
                          duplicate['goalIds'] as String,
                        );
                        existingGoalIds = decoded
                            .map((e) => int.parse(e.toString()))
                            .toList();
                      } catch (_) {}
                    }

                    // Merge and deduplicate
                    final mergedIds =
                        (existingGoalIds + mappedImportIds).toSet().toList();
                    if (mergedIds.length > existingGoalIds.length) {
                      await txn.update(
                        'tasks',
                        {
                          'goalIds': json.encode(mergedIds),
                        },
                        where: 'id = ?',
                        whereArgs: [existingTaskId],
                      );
                      debugPrint('Updated goalIds for existing task: $title');
                    }
                  }
                }
              } catch (e) {
                debugPrint('Error updating goalIds for duplicate task: $e');
              }
            } else {
              // New task
              final newTaskMap = Map<String, dynamic>.from(taskMap);
              newTaskMap.remove('id'); // Let SQLite handle ID

              // Handle goal linking (Support both goalId and goalIds)
              List<int> currentGoalIds = [];

              // 1. Check legacy goalId
              if (taskMap['goalId'] != null) {
                final gId = int.tryParse(taskMap['goalId'].toString());
                if (gId != null) currentGoalIds.add(gId);
              }

              // 2. Check goalIds list
              if (taskMap['goalIds'] != null) {
                try {
                  final dynamic goalsRaw = taskMap['goalIds'];
                  if (goalsRaw is String) {
                    final List<dynamic> decoded = json.decode(goalsRaw);
                    currentGoalIds.addAll(
                      decoded.map((e) => int.parse(e.toString())),
                    );
                  } else if (goalsRaw is List) {
                    currentGoalIds.addAll(
                      goalsRaw.map((e) => int.parse(e.toString())),
                    );
                  }
                } catch (_) {}
              }

              // Map old goal IDs to new goal IDs
              final List<int> updatedGoalIds = [];
              for (var oldGoalId in currentGoalIds.toSet()) {
                // deduplicate
                if (goalIdMap.containsKey(oldGoalId)) {
                  updatedGoalIds.add(goalIdMap[oldGoalId]!);
                }
                // Removed the "else add old ID" part as it's safer for goal links
              }

              newTaskMap['goalIds'] = json.encode(updatedGoalIds);
              newTaskMap.remove('goalId'); // Ensure legacy field is removed

              // Ensure numeric fields are actually numbers and not null
              newTaskMap['title'] = title;
              newTaskMap['dueDate'] = dueDate;
              newTaskMap['priority'] = _toInt(
                newTaskMap['priority'],
                1,
              ); // Default to Medium (1)
              newTaskMap['isDeleted'] = _toInt(newTaskMap['isDeleted'], 0) == 1
                  ? 1
                  : 0;
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
                      final exists = await txn.query(
                        'categories',
                        where: 'id = ?',
                        whereArgs: [catId],
                      );
                      if (exists.isNotEmpty) {
                        updatedCats.add(catId);
                      } else {
                        // Category missing! Create a placeholder category
                        final newCatId = 'imported_$catId';
                        await txn.insert(
                          'categories',
                          {
                            'id': newCatId,
                            'label': catId, // Use the ID as label for now
                            'emoji': '🏷️',
                            'color': 0xFF9E9E9E, // Grey
                            'position': 999,
                          },
                          conflictAlgorithm: ConflictAlgorithm.ignore,
                        );
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
                if (newTaskMap['recurrence'] is Map ||
                    newTaskMap['recurrence'] is List) {
                  newTaskMap['recurrence'] = json.encode(
                    newTaskMap['recurrence'],
                  );
                } else if (newTaskMap['recurrence'] is! String) {
                  newTaskMap['recurrence'] = null;
                }
              }

              // Move legacy status to statusHistory if it exists and statusHistory is empty
              if (newTaskMap['status'] != null &&
                  (newTaskMap['statusHistory'] == null ||
                      newTaskMap['statusHistory'] == '{}' ||
                      newTaskMap['statusHistory'] == '[]')) {
                final int statusValue = _toInt(newTaskMap['status'], 0);
                final dateKey = dueDate.split('T')[0];
                newTaskMap['statusHistory'] = json.encode({
                  dateKey: statusValue,
                });
              }

              if (newTaskMap['statusHistory'] != null) {
                if (newTaskMap['statusHistory'] is Map) {
                  newTaskMap['statusHistory'] = json.encode(
                    newTaskMap['statusHistory'],
                  );
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
          final eventsList = (data['events'] as List)
              .cast<Map<String, dynamic>>();
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
          final settingsList = (data['settings'] as List)
              .cast<Map<String, dynamic>>();
          debugPrint('Importing ${settingsList.length} settings...');
          for (var settingMap in settingsList) {
            await txn.insert(
              'settings',
              settingMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        // 5. Import Mood Tracking Data
        if (data['activity_categories'] != null) {
          final catList = (data['activity_categories'] as List)
              .cast<Map<String, dynamic>>();
          debugPrint('Importing ${catList.length} activity categories...');
          final existingCats = await txn.query('activity_categories');
          for (var catMap in catList) {
            final oldId = int.tryParse(catMap['id']?.toString() ?? '');
            final name = catMap['name'] as String? ?? '';

            final duplicate = existingCats.firstWhere(
              (c) => c['name'].toString().toLowerCase() == name.toLowerCase(),
              orElse: () => {},
            );

            if (duplicate.isNotEmpty) {
              if (oldId != null) {
                activityCategoryIdMap[oldId] = duplicate['id'] as int;
              }
            } else {
              final newCatMap = Map<String, dynamic>.from(catMap);
              newCatMap.remove('id');
              final newId = await txn.insert('activity_categories', newCatMap);
              if (oldId != null) activityCategoryIdMap[oldId] = newId;
            }
          }
        }

        if (data['activities'] != null) {
          final actList =
              (data['activities'] as List).cast<Map<String, dynamic>>();
          debugPrint('Importing ${actList.length} activities...');
          final existingActs = await txn.query('activities');
          for (var actMap in actList) {
            final oldId = int.tryParse(actMap['id']?.toString() ?? '');
            final name = actMap['name'] as String? ?? '';
            final oldCatId = int.tryParse(actMap['categoryId']?.toString() ?? '');
            final newCatId =
                oldCatId != null ? activityCategoryIdMap[oldCatId] : null;

            final duplicate = existingActs.firstWhere(
              (a) =>
                  a['name'].toString().toLowerCase() == name.toLowerCase() &&
                  a['categoryId'] == (newCatId ?? a['categoryId']),
              orElse: () => {},
            );

            if (duplicate.isNotEmpty) {
              if (oldId != null) activityIdMap[oldId] = duplicate['id'] as int;
            } else {
              final newActMap = Map<String, dynamic>.from(actMap);
              newActMap.remove('id');
              if (newCatId != null) newActMap['categoryId'] = newCatId;
              final newId = await txn.insert('activities', newActMap);
              if (oldId != null) activityIdMap[oldId] = newId;
            }
          }
        }

        if (data['mood_entries'] != null) {
          final moodList =
              (data['mood_entries'] as List).cast<Map<String, dynamic>>();
          debugPrint('Importing ${moodList.length} mood entries...');
          for (var moodMap in moodList) {
            final oldId = int.tryParse(moodMap['id']?.toString() ?? '');
            final newMoodMap = Map<String, dynamic>.from(moodMap);
            newMoodMap.remove('id');

            // Map activity IDs if they exist
            if (newMoodMap['activityIds'] != null) {
              try {
                final dynamic actIdsRaw = newMoodMap['activityIds'];
                List<dynamic> oldActIds;
                if (actIdsRaw is String) {
                  oldActIds = json.decode(actIdsRaw);
                } else if (actIdsRaw is List) {
                  oldActIds = actIdsRaw;
                } else {
                  oldActIds = [];
                }

                final List<int> newActIds = [];
                for (var oId in oldActIds) {
                  final id = int.tryParse(oId.toString());
                  if (id != null && activityIdMap.containsKey(id)) {
                    newActIds.add(activityIdMap[id]!);
                  }
                }
                newMoodMap['activityIds'] = json.encode(newActIds);
              } catch (_) {}
            }

            final newId = await txn.insert('mood_entries', newMoodMap);
             if (oldId != null) moodIdMap[oldId] = newId;
           }
         }
      });
      debugPrint('Data import completed successfully!');
      return {
        'categoryIdMap': categoryIdMap,
        'goalIdMap': goalIdMap,
        'taskIdMap': taskIdMap,
        'activityCategoryIdMap': activityCategoryIdMap,
        'activityIdMap': activityIdMap,
        'moodIdMap': moodIdMap,
      };
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
      final Map<int, String> oldMediaIdToNewPath =
          {}; // oldMediaId -> newFilePath

      // Extract and copy media files
      for (var mediaFile in mediaFiles) {
        try {
          // Extract media ID from filename (format: media/{id}_{filename})
          final fileName = mediaFile.name.replaceFirst('media/', '');
          final underscoreIndex = fileName.indexOf('_');
          if (underscoreIndex > 0) {
            final oldMediaId = int.tryParse(
              fileName.substring(0, underscoreIndex),
            );
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
              debugPrint(
                'Extracted media file: $originalFileName -> $newFilePath',
              );
            }
          }
        } catch (e) {
          debugPrint('Error extracting media file ${mediaFile.name}: $e');
        }
      }

      // Create media table entries for extracted files and map old IDs to new IDs
      final db = await database;
      final Map<int, int> oldMediaIdToNewMediaId =
          {}; // oldMediaId -> newMediaId

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
            debugPrint(
              'Created media entry: $oldMediaId -> $newMediaId ($fileName)',
            );
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
                    debugPrint(
                      'Media ID $oldMediaId not found in extracted files',
                    );
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

      // Update goal attachments and audioPath to use new media IDs and paths
      if (data['goals'] != null && oldMediaIdToNewMediaId.isNotEmpty) {
        final goalsList = data['goals'] as List;
        for (var goal in goalsList) {
          final goalMap = goal as Map<String, dynamic>;
          
          // 1. Update attachments
          final attachmentsJson = goalMap['attachments'] as String?;
          if (attachmentsJson != null && attachmentsJson.isNotEmpty) {
            try {
              final attachments = json.decode(attachmentsJson) as List;
              final updatedAttachments = <String>[];

              for (var attachment in attachments) {
                final attachmentStr = attachment.toString();
                if (RegExp(r'^\d+$').hasMatch(attachmentStr)) {
                  final oldMediaId = int.parse(attachmentStr);
                  final newMediaId = oldMediaIdToNewMediaId[oldMediaId];
                  if (newMediaId != null) {
                    updatedAttachments.add(newMediaId.toString());
                  }
                } else {
                  updatedAttachments.add(attachmentStr);
                }
              }
              goalMap['attachments'] = json.encode(updatedAttachments);
            } catch (e) {
              debugPrint('Error updating attachments for goal: $e');
            }
          }

          // 2. Update audioPath
          final oldAudioPath = goalMap['audioPath'] as String?;
          if (oldAudioPath != null && oldAudioPath.isNotEmpty) {
            // Find if this audioPath was associated with a media ID that we mapped
            // Since we don't have a direct oldPath -> newPath mapping for all files,
            // we check if the audioPath's media ID is in attachments and was mapped.
            // Actually, we can use the oldMediaIdToNewPath mapping if we know the oldMediaId.
            // But the JSON doesn't store the mediaId for audioPath directly.
            
            // However, we know that audioPath's media ID is in the attachments list.
            // Let's find it.
            try {
              final attachments = json.decode(goalMap['attachments'] as String) as List;
              for (var attachment in attachments) {
                final attachmentStr = attachment.toString();
                if (RegExp(r'^\d+$').hasMatch(attachmentStr)) {
                  final newMediaId = int.parse(attachmentStr);
                  // Find the new path for this new media ID
                  final mediaEntry = await db.query(
                    'media',
                    where: 'id = ?',
                    whereArgs: [newMediaId],
                    limit: 1,
                  );
                  if (mediaEntry.isNotEmpty) {
                    final newPath = mediaEntry.first['filePath'] as String;
                    // Check if the filename matches (roughly)
                    if (newPath.endsWith(oldAudioPath.split('/').last)) {
                      goalMap['audioPath'] = newPath;
                      break;
                    }
                  }
                }
              }
            } catch (_) {}
          }
        }
      }

      // Update mood_entries attachments to use new media IDs
      if (data['mood_entries'] != null && oldMediaIdToNewMediaId.isNotEmpty) {
        final moodList = data['mood_entries'] as List;
        for (var mood in moodList) {
          final moodMap = mood as Map<String, dynamic>;
          final attachmentsJson = moodMap['attachments'] as String?;

          if (attachmentsJson != null && attachmentsJson.isNotEmpty) {
            try {
              final attachments = json.decode(attachmentsJson) as List;
              final updatedAttachments = <String>[];

              for (var attachment in attachments) {
                final attachmentStr = attachment.toString();
                if (RegExp(r'^\d+$').hasMatch(attachmentStr)) {
                  final oldMediaId = int.parse(attachmentStr);
                  final newMediaId = oldMediaIdToNewMediaId[oldMediaId];
                  if (newMediaId != null) {
                    updatedAttachments.add(newMediaId.toString());
                  }
                } else {
                  updatedAttachments.add(attachmentStr);
                }
              }

              moodMap['attachments'] = json.encode(updatedAttachments);
            } catch (e) {
              debugPrint('Error updating attachments for mood entry: $e');
            }
          }
        }
      }

      // Import the data and get ID mapping maps
      final idMaps = await importData(data);
      final Map<int, int> taskIdMap = idMaps['taskIdMap'] as Map<int, int>? ?? {};
      final Map<int, int> goalIdMap = idMaps['goalIdMap'] as Map<int, int>? ?? {};
      final Map<int, int> moodIdMap = idMaps['moodIdMap'] as Map<int, int>? ?? {};

      // Update media entries with correct taskId, goalId, and moodId
      if (oldMediaIdToNewMediaId.isNotEmpty) {
        // 1. Map task IDs for media
        if (data['tasks'] != null) {
          for (var task in data['tasks'] as List) {
            final taskMap = task as Map<String, dynamic>;
            final oldTaskId = int.tryParse(taskMap['id']?.toString() ?? '');
            final newTaskId = oldTaskId != null ? taskIdMap[oldTaskId] : null;
            final attachmentsJson = taskMap['attachments'] as String?;

            if (newTaskId != null &&
                attachmentsJson != null &&
                attachmentsJson.isNotEmpty) {
              try {
                final attachments = json.decode(attachmentsJson) as List;
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
              } catch (_) {}
            }
          }
        }

        // 2. Map goal IDs for media
        if (data['goals'] != null) {
          for (var goal in data['goals'] as List) {
            final goalMap = goal as Map<String, dynamic>;
            final oldGoalId = int.tryParse(goalMap['id']?.toString() ?? '');
            final newGoalId = oldGoalId != null ? goalIdMap[oldGoalId] : null;
            final attachmentsJson = goalMap['attachments'] as String?;

            if (newGoalId != null &&
                attachmentsJson != null &&
                attachmentsJson.isNotEmpty) {
              try {
                final attachments = json.decode(attachmentsJson) as List;
                for (var attachment in attachments) {
                  final attachmentStr = attachment.toString();
                  if (RegExp(r'^\d+$').hasMatch(attachmentStr)) {
                    final mediaId = int.parse(attachmentStr);
                    await db.update(
                      'media',
                      {'goalId': newGoalId},
                      where: 'id = ?',
                      whereArgs: [mediaId],
                    );
                  }
                }
              } catch (_) {}
            }
          }
        }

        // 3. Map mood IDs for media
        if (data['mood_entries'] != null) {
          for (var mood in data['mood_entries'] as List) {
            final moodMap = mood as Map<String, dynamic>;
            final oldMoodId = int.tryParse(moodMap['id']?.toString() ?? '');
            final newMoodId = oldMoodId != null ? moodIdMap[oldMoodId] : null;
            final attachmentsJson = moodMap['attachments'] as String?;

            if (newMoodId != null &&
                attachmentsJson != null &&
                attachmentsJson.isNotEmpty) {
              try {
                final attachments = json.decode(attachmentsJson) as List;
                for (var attachment in attachments) {
                  final attachmentStr = attachment.toString();
                  if (RegExp(r'^\d+$').hasMatch(attachmentStr)) {
                    final mediaId = int.parse(attachmentStr);
                    await db.update(
                      'media',
                      {'moodId': newMoodId},
                      where: 'id = ?',
                      whereArgs: [mediaId],
                    );
                  }
                }
              } catch (_) {}
            }
          }
        }
      }

      debugPrint('Full data import completed successfully');
    } catch (e) {
      debugPrint('Error during full data import: $e');
      rethrow;
    }
  }

  // Settings methods
  Future<void> setSetting(String key, String value) async {
    Database db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<void> updateTaskStatus(
    int taskId,
    TaskStatus status, {
    String? dateKey,
    Map<String, dynamic>? metadata,
  }) async {
    Database db = await database;
    final taskMap = (await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
    )).first;

    Map<String, int> history = {};
    if (taskMap['statusHistory'] != null) {
      try {
        history = Map<String, int>.from(
          json.decode(taskMap['statusHistory'] as String),
        );
      } catch (_) {}
    }

    final effectiveDateKey =
        dateKey ?? taskMap['dueDate'].toString().split('T')[0];
    history[effectiveDateKey] = status.index;

    final updateData = <String, dynamic>{'statusHistory': json.encode(history)};

    if (metadata != null) {
      updateData['metadata'] = json.encode(metadata);
    }

    await db.update('tasks', updateData, where: 'id = ?', whereArgs: [taskId]);

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
            case TaskStatus.pending:
              statusName = 'در انتظار';
              break;
            case TaskStatus.success:
              statusName = 'انجام شده';
              break;
            case TaskStatus.failed:
              statusName = 'ناموفق';
              break;
            case TaskStatus.cancelled:
              statusName = 'لغو شده';
              break;
            case TaskStatus.deferred:
              statusName = 'به تعویق افتاده';
              break;
          }
        }
        logMessage = 'وضعیت تسک به "$statusName" تغییر کرد';
        break;
      case 'completion':
      case 'status_update':
        final statusIndex = payload?['status'] as int?;
        final date = payload?['date'] as String?;
        String statusName = 'نامشخص';
        if (statusIndex != null && statusIndex < TaskStatus.values.length) {
          switch (TaskStatus.values[statusIndex]) {
            case TaskStatus.pending:
              statusName = 'در انتظار';
              break;
            case TaskStatus.success:
              statusName = 'انجام شده';
              break;
            case TaskStatus.failed:
              statusName = 'ناموفق';
              break;
            case TaskStatus.cancelled:
              statusName = 'لغو شده';
              break;
            case TaskStatus.deferred:
              statusName = 'به تعویق افتاده';
              break;
          }
        }
        if (date != null) {
          logMessage = 'تسک در تاریخ $date به وضعیت "$statusName" تغییر یافت';
        } else {
          logMessage = 'وضعیت تسک به "$statusName" تغییر کرد';
        }
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

    // Also delete all media files before clearing database
    await deleteAllMedia();

    await db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('task_events');
      await txn.delete('settings');
      await txn.delete('categories');
      await txn.delete('goals');
      
      // Clear mood tables
      await txn.delete('activities');
      await txn.delete('activity_categories');
      await txn.delete('mood_entries');

      // Re-insert default categories
      for (var cat in defaultCategories) {
        await txn.insert('categories', cat.toMap());
      }

      // Re-insert default mood data
      await _insertDefaultMoodData(txn);
    });
  }

  Future<void> deleteAllMedia() async {
    Database db = await database;
    final allMedia = await db.query('media');

    // Delete physical files
    for (var media in allMedia) {
      try {
        final filePath = media['filePath'] as String;
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting media file: $e');
      }
    }

    // Delete all rows from media table
    await db.delete('media');

    // Update tasks to remove references to media IDs
    // We do this to avoid tasks pointing to non-existent media
    final tasks = await db.query('tasks');
    for (var task in tasks) {
      final attachmentsJson = task['attachments'] as String?;
      if (attachmentsJson != null &&
          attachmentsJson.isNotEmpty &&
          attachmentsJson != '[]') {
        try {
          final List<dynamic> attachments = json.decode(attachmentsJson);
          // Keep only non-numeric attachments (legacy paths)
          final keptAttachments = attachments
              .where((a) => !RegExp(r'^\d+$').hasMatch(a.toString()))
              .toList();

          if (keptAttachments.length != attachments.length) {
            await db.update(
              'tasks',
              {'attachments': json.encode(keptAttachments)},
              where: 'id = ?',
              whereArgs: [task['id']],
            );
          }
        } catch (_) {}
      }
    }
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
    int? goalId,
    int? moodId,
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
      'goalId': goalId,
      'moodId': moodId,
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
      await db.delete('media', where: 'id = ?', whereArgs: [mediaId]);
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

    await db.delete('media', where: 'taskId = ?', whereArgs: [taskId]);
  }

  // Migrate old attachments (file paths) to media table
  Future<void> _migrateOldAttachments(Database db) async {
    try {
      final List<Map<String, dynamic>> tasks = await db.query('tasks');
      final now = DateTime.now().toIso8601String();

      for (var taskMap in tasks) {
        final taskId = taskMap['id'] as int;
        final attachmentsJson = taskMap['attachments'] as String?;

        if (attachmentsJson == null ||
            attachmentsJson.isEmpty ||
            attachmentsJson == '[]') {
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
              {
                'attachments': json.encode(
                  mediaIds.map((id) => id.toString()).toList(),
                ),
              },
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
