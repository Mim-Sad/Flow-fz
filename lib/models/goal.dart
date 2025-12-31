import 'dart:convert';
import 'task.dart';

class Goal {
  final int? id;
  final String title;
  final String? description;
  final String emoji;
  final List<String> categoryIds;
  final DateTime? deadline;
  final TaskPriority priority;
  final List<String> tags;
  final List<String> attachments;
  final String? audioPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final int position;

  Goal({
    this.id,
    required this.title,
    this.description,
    required this.emoji,
    this.categoryIds = const [],
    this.deadline,
    this.priority = TaskPriority.medium,
    this.tags = const [],
    this.attachments = const [],
    this.audioPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.position = 0,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? (createdAt ?? DateTime.now());

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'emoji': emoji,
      'categoryIds': json.encode(categoryIds),
      'deadline': deadline?.toIso8601String(),
      'priority': priority.index,
      'tags': json.encode(tags),
      'attachments': json.encode(attachments),
      'audioPath': audioPath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted ? 1 : 0,
      'position': position,
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      emoji: map['emoji'] ?? '🎯',
      categoryIds: map['categoryIds'] != null
          ? List<String>.from(json.decode(map['categoryIds']))
          : (map['categoryId'] != null ? [map['categoryId']] : []),
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
      priority: TaskPriority.values[map['priority'] ?? 1],
      tags: map['tags'] != null ? List<String>.from(json.decode(map['tags'])) : [],
      attachments: map['attachments'] != null
          ? List<String>.from(json.decode(map['attachments']))
          : [],
      audioPath: map['audioPath'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      isDeleted: (map['isDeleted'] ?? 0) == 1,
      position: map['position'] ?? 0,
    );
  }

  Goal copyWith({
    int? id,
    String? title,
    String? description,
    String? emoji,
    List<String>? categoryIds,
    DateTime? deadline,
    TaskPriority? priority,
    List<String>? tags,
    List<String>? attachments,
    String? audioPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    int? position,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      categoryIds: categoryIds ?? this.categoryIds,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
      audioPath: audioPath ?? this.audioPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      position: position ?? this.position,
    );
  }
}
