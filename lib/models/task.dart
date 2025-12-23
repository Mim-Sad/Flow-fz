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
    return RecurrenceConfig(
      type: RecurrenceType.values[map['type']],
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
  final int? rootId;
  final String title;
  final String? description;
  final DateTime dueDate;
  final TaskStatus status;
  final TaskPriority priority;
  final String? category; // Kept for backward compatibility, but we use categories list
  final List<String> categories;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final int position;
  final String? taskEmoji;
  final List<String> attachments;
  final RecurrenceConfig? recurrence;
  final Map<String, dynamic> metadata;

  Task({
    this.id,
    this.rootId,
    required this.title,
    this.description,
    required this.dueDate,
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.medium,
    this.category,
    List<String>? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.position = 0,
    this.taskEmoji,
    this.attachments = const [],
    this.recurrence,
    this.metadata = const {},
  }) : 
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? (createdAt ?? DateTime.now()),
    categories = categories ?? (category != null ? [category] : []);

  Task duplicate() {
    final newMetadata = Map<String, dynamic>.from(metadata);
    newMetadata['duplicatedAt'] = DateTime.now().toIso8601String();
    newMetadata['duplicatedFromId'] = id;

    return Task(
      title: title,
      description: description,
      dueDate: dueDate,
      status: TaskStatus.pending,
      priority: priority,
      categories: List.from(categories),
      taskEmoji: taskEmoji,
      attachments: List.from(attachments),
      recurrence: recurrence,
      metadata: newMetadata,
    );
  }

  int get deferCount => metadata['deferCount'] ?? 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rootId': rootId,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'status': status.index,
      'priority': priority.index,
      'category': category, // maintain for compatibility if needed, or update based on categories.first
      'categories': json.encode(categories),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.toIso8601String(),
      'position': position,
      'taskEmoji': taskEmoji,
      'attachments': json.encode(attachments),
      'recurrence': recurrence?.toJson(),
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
      loadedCategories = [map['category']];
    }

    Map<String, dynamic> loadedMetadata = {};
    if (map['metadata'] != null) {
      try {
        loadedMetadata = Map<String, dynamic>.from(json.decode(map['metadata']));
      } catch (e) {
        // Fallback
      }
    }

    return Task(
      id: map['id'],
      rootId: map['rootId'],
      title: map['title'],
      description: map['description'],
      dueDate: DateTime.parse(map['dueDate']),
      status: TaskStatus.values[map['status']],
      priority: TaskPriority.values[map['priority']],
      category: map['category'],
      categories: loadedCategories,
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
      metadata: loadedMetadata,
    );
  }

  Task copyWith({
    int? id,
    int? rootId,
    String? title,
    String? description,
    DateTime? dueDate,
    TaskStatus? status,
    TaskPriority? priority,
    String? category,
    List<String>? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    int? position,
    String? taskEmoji,
    List<String>? attachments,
    RecurrenceConfig? recurrence,
    Map<String, dynamic>? metadata,
  }) {
    return Task(
      id: id ?? this.id,
      rootId: rootId ?? this.rootId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      position: position ?? this.position,
      taskEmoji: taskEmoji ?? this.taskEmoji,
      attachments: attachments ?? this.attachments,
      recurrence: recurrence ?? this.recurrence,
      metadata: metadata ?? this.metadata,
    );
  }
}
