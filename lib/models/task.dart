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

class Task {
  final int? id;
  final String title;
  final String? description;
  final DateTime dueDate;
  final TaskStatus status;
  final TaskPriority priority;
  final String? category;
  final DateTime createdAt;
  final int position;

  Task({
    this.id,
    required this.title,
    this.description,
    required this.dueDate,
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.medium,
    this.category,
    DateTime? createdAt,
    this.position = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'status': status.index,
      'priority': priority.index,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'position': position,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      dueDate: DateTime.parse(map['dueDate']),
      status: TaskStatus.values[map['status']],
      priority: TaskPriority.values[map['priority']],
      category: map['category'],
      createdAt: DateTime.parse(map['createdAt']),
      position: map['position'] ?? 0,
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
    DateTime? createdAt,
    int? position,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      position: position ?? this.position,
    );
  }
}
