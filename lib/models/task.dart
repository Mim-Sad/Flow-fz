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
  final String title;
  final String? description;
  final DateTime dueDate;
  final TaskStatus status;
  final TaskPriority priority;
  final String? category; // Kept for backward compatibility, but we use categories list
  final List<String> categories;
  final DateTime createdAt;
  final int position;
  final String? taskEmoji;
  final List<String> attachments;
  final RecurrenceConfig? recurrence;

  Task({
    this.id,
    required this.title,
    this.description,
    required this.dueDate,
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.medium,
    this.category,
    List<String>? categories,
    DateTime? createdAt,
    this.position = 0,
    this.taskEmoji,
    this.attachments = const [],
    this.recurrence,
  }) : 
    createdAt = createdAt ?? DateTime.now(),
    categories = categories ?? (category != null ? [category] : []);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'status': status.index,
      'priority': priority.index,
      'category': category, // maintain for compatibility if needed, or update based on categories.first
      'categories': json.encode(categories),
      'createdAt': createdAt.toIso8601String(),
      'position': position,
      'taskEmoji': taskEmoji,
      'attachments': json.encode(attachments),
      'recurrence': recurrence?.toJson(),
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

    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      dueDate: DateTime.parse(map['dueDate']),
      status: TaskStatus.values[map['status']],
      priority: TaskPriority.values[map['priority']],
      category: map['category'],
      categories: loadedCategories,
      createdAt: DateTime.parse(map['createdAt']),
      position: map['position'] ?? 0,
      taskEmoji: map['taskEmoji'],
      attachments: map['attachments'] != null 
          ? List<String>.from(json.decode(map['attachments'])) 
          : [],
      recurrence: map['recurrence'] != null 
          ? RecurrenceConfig.fromJson(map['recurrence']) 
          : null,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? dueDate,
    TaskStatus? status,
    TaskPriority? priority,
    String? category,
    List<String>? categories,
    DateTime? createdAt,
    int? position,
    String? taskEmoji,
    List<String>? attachments,
    RecurrenceConfig? recurrence,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      position: position ?? this.position,
      taskEmoji: taskEmoji ?? this.taskEmoji,
      attachments: attachments ?? this.attachments,
      recurrence: recurrence ?? this.recurrence,
    );
  }
}
