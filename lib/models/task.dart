import 'dart:convert';

enum TaskStatus {
  pending,
  success,
  failed,
  cancelled,
  deferred,
}

enum TaskPriority {
  low,
  medium,
  high,
}

enum RecurrenceType {
  none,
  hourly,
  daily,
  weekly,
  monthly,
  yearly,
  custom,
  specificDays,
}

class RecurrenceConfig {
  final RecurrenceType type;
  final int? interval;
  final List<int>? daysOfWeek;
  final List<DateTime>? specificDates;
  final int? dayOfMonth;
  final DateTime? endDate;

  RecurrenceConfig({
    required this.type,
    this.interval,
    this.daysOfWeek,
    this.specificDates,
    this.dayOfMonth,
    this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'interval': interval,
      'daysOfWeek': daysOfWeek,
      'specificDates': specificDates?.map((e) => e.toIso8601String()).toList(),
      'dayOfMonth': dayOfMonth,
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory RecurrenceConfig.fromMap(Map<String, dynamic> map) {
    // Safe Enum Parsing
    RecurrenceType loadedType = RecurrenceType.none;
    if (map['type'] != null && map['type'] is int) {
      final tIndex = map['type'] as int;
      if (tIndex >= 0 && tIndex < RecurrenceType.values.length) {
        loadedType = RecurrenceType.values[tIndex];
      }
    }

    return RecurrenceConfig(
      type: loadedType,
      interval: map['interval'],
      daysOfWeek: map['daysOfWeek'] != null ? List<int>.from(map['daysOfWeek']) : null,
      specificDates: map['specificDates'] != null 
          ? List<DateTime>.from(map['specificDates'].map((e) => DateTime.parse(e)))
          : null,
      dayOfMonth: map['dayOfMonth'],
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
    );
  }
  
  String toJson() => json.encode(toMap());
  
  factory RecurrenceConfig.fromJson(String source) => RecurrenceConfig.fromMap(json.decode(source));
}

class Task {
  final int? id;
  final String title;
  final String? description;
  final DateTime dueDate;
  final TaskPriority priority;
  final List<String> categories;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final int position;
  final String? taskEmoji;
  final List<String> attachments;
  final List<String> tags;
  final RecurrenceConfig? recurrence;
  final Map<String, int> statusHistory;
  final Map<String, dynamic> metadata;

  Task({
    this.id,
    required this.title,
    this.description,
    required this.dueDate,
    this.priority = TaskPriority.medium,
    List<String>? categories,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.position = 0,
    this.taskEmoji,
    this.attachments = const [],
    this.recurrence,
    Map<String, int>? statusHistory,
    this.metadata = const {},
  }) : 
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? (createdAt ?? DateTime.now()),
    categories = categories ?? [],
    tags = tags ?? const [],
    statusHistory = statusHistory ?? {};

  // Helper to get status for a specific date
  TaskStatus getStatusForDate(DateTime date) {
    if (!isActiveOnDate(date)) {
      return TaskStatus.pending;
    }
    
    final key = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final statusIndex = statusHistory[key];
    if (statusIndex != null) {
      return TaskStatus.values[statusIndex];
    }
    return TaskStatus.pending;
  }

  bool isActiveOnDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);

    // 1. For one-off tasks (no recurrence)
    if (recurrence == null || recurrence!.type == RecurrenceType.none) {
      return _isSameDay(dueDateOnly, dateOnly);
    }

    // 2. For recurring tasks
    // Check if date is before start date
    if (dateOnly.isBefore(dueDateOnly)) return false;

    // Check if date is after end date
    if (recurrence!.endDate != null) {
      final endDateOnly = DateTime(
        recurrence!.endDate!.year,
        recurrence!.endDate!.month,
        recurrence!.endDate!.day,
      );
      if (dateOnly.isAfter(endDateOnly)) return false;
    }

    // Specific recurrence logic
    switch (recurrence!.type) {
      case RecurrenceType.daily:
        final interval = recurrence!.interval ?? 1;
        final diff = dateOnly.difference(dueDateOnly).inDays;
        return diff % interval == 0;

      case RecurrenceType.weekly:
        final interval = recurrence!.interval ?? 1;
        final daysOfWeek = recurrence!.daysOfWeek ?? [];
        
        // If specific days are selected, check if current date is one of them
        if (daysOfWeek.isNotEmpty) {
          // Dart's weekday is 1-7 (Mon-Sun)
          if (!daysOfWeek.contains(dateOnly.weekday)) return false;
        }
        
        final diffInDays = dateOnly.difference(dueDateOnly).inDays;
        final weeksDiff = (diffInDays / 7).floor();
        return weeksDiff % interval == 0;

      case RecurrenceType.monthly:
        final interval = recurrence!.interval ?? 1;
        final dayOfMonth = recurrence!.dayOfMonth ?? dueDateOnly.day;
        
        if (dateOnly.day != dayOfMonth) return false;
        
        final monthsDiff = (dateOnly.year - dueDateOnly.year) * 12 + (dateOnly.month - dueDateOnly.month);
        return monthsDiff % interval == 0;

      case RecurrenceType.yearly:
        final interval = recurrence!.interval ?? 1;
        if (dateOnly.month != dueDateOnly.month || dateOnly.day != dueDateOnly.day) return false;
        
        final yearsDiff = dateOnly.year - dueDateOnly.year;
        return yearsDiff % interval == 0;

      case RecurrenceType.specificDays:
        final specificDates = recurrence!.specificDates ?? [];
        return specificDates.any((d) => _isSameDay(d, dateOnly));

      default:
        return _isSameDay(dueDateOnly, dateOnly);
    }
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  // Current status (for backward compatibility and single-instance tasks)
  TaskStatus get status => getStatusForDate(dueDate);

  Task duplicate() {
    final newMetadata = Map<String, dynamic>.from(metadata);
    newMetadata['duplicatedAt'] = DateTime.now().toIso8601String();
    newMetadata['duplicatedFromId'] = id;

    return Task(
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      categories: List.from(categories),
      tags: List.from(tags),
      taskEmoji: taskEmoji,
      attachments: List.from(attachments),
      recurrence: recurrence,
      statusHistory: Map.from(statusHistory),
      metadata: newMetadata,
    );
  }

  int get deferCount => metadata['deferCount'] ?? 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority.index,
      'categories': json.encode(categories),
      'tags': json.encode(tags),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.toIso8601String(),
      'position': position,
      'taskEmoji': taskEmoji,
      'attachments': json.encode(attachments),
      'recurrence': recurrence?.toJson(),
      'statusHistory': json.encode(statusHistory),
      'metadata': json.encode(metadata),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    List<String> loadedCategories = [];
    if (map['categories'] != null) {
      try {
        loadedCategories = List<String>.from(json.decode(map['categories']));
      } catch (e) {
        // Fallback or ignore
      }
    } else if (map['category'] != null) {
      // Legacy support for single category
      loadedCategories = [map['category']];
    }

    List<String> loadedTags = [];
    if (map['tags'] != null) {
      try {
        loadedTags = List<String>.from(json.decode(map['tags']));
      } catch (e) {
        // Fallback
      }
    }

    Map<String, dynamic> loadedMetadata = {};
    if (map['metadata'] != null) {
      try {
        loadedMetadata = Map<String, dynamic>.from(json.decode(map['metadata']));
      } catch (e) {
        // Fallback
      }
    }

    Map<String, int> loadedStatusHistory = {};
    if (map['statusHistory'] != null) {
      try {
        loadedStatusHistory = Map<String, int>.from(json.decode(map['statusHistory']));
      } catch (e) {
        // Fallback
      }
    } else if (map['status'] != null) {
      // Legacy migration: move single status to statusHistory
      final dueDateStr = map['dueDate'] != null 
          ? map['dueDate'].toString().split('T')[0] 
          : "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
      loadedStatusHistory[dueDateStr] = map['status'];
    }

    // Safe Priority Parsing
    TaskPriority loadedPriority = TaskPriority.medium;
    if (map['priority'] != null && map['priority'] is int) {
      final pIndex = map['priority'] as int;
      if (pIndex >= 0 && pIndex < TaskPriority.values.length) {
        loadedPriority = TaskPriority.values[pIndex];
      }
    }

    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      dueDate: DateTime.parse(map['dueDate']),
      priority: loadedPriority,
      categories: loadedCategories,
      tags: loadedTags,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      isDeleted: (map['isDeleted'] ?? 0) == 1,
      deletedAt: map['deletedAt'] != null ? DateTime.parse(map['deletedAt']) : null,
      position: map['position'] ?? 0,
      taskEmoji: map['taskEmoji'],
      attachments: map['attachments'] != null 
          ? List<String>.from(json.decode(map['attachments'])) 
          : [],
      recurrence: map['recurrence'] != null 
          ? RecurrenceConfig.fromJson(map['recurrence']) 
          : null,
      statusHistory: loadedStatusHistory,
      metadata: loadedMetadata,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
    List<String>? categories,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    int? position,
    String? taskEmoji,
    List<String>? attachments,
    RecurrenceConfig? recurrence,
    Map<String, int>? statusHistory,
    Map<String, dynamic>? metadata,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      position: position ?? this.position,
      taskEmoji: taskEmoji ?? this.taskEmoji,
      attachments: attachments ?? this.attachments,
      recurrence: recurrence ?? this.recurrence,
      statusHistory: statusHistory ?? this.statusHistory,
      metadata: metadata ?? this.metadata,
    );
  }
}
