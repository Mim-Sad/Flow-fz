import 'dart:convert';

enum MoodLevel {
  rad,      // عالی - 5
  good,     // خوب - 4
  meh,      // معمولی - 3
  bad,      // بد - 2
  awful     // افتضاح - 1
}

class MoodEntry {
  final int? id;
  final DateTime dateTime;
  final MoodLevel moodLevel;
  final String? label; // Custom label for this entry
  final String? emoji; // Custom emoji for this entry
  final String? note;
  final List<String> attachments; // Paths to files/photos
  final List<int> activityIds; // Linked activities
  final DateTime createdAt;
  final DateTime? updatedAt;

  MoodEntry({
    this.id,
    required this.dateTime,
    required this.moodLevel,
    this.label,
    this.emoji,
    this.note,
    this.attachments = const [],
    this.activityIds = const [],
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateTime': dateTime.toIso8601String(),
      'moodLevel': moodLevel.index,
      'label': label,
      'emoji': emoji,
      'note': note,
      'attachments': json.encode(attachments),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map, {List<int>? activities}) {
    return MoodEntry(
      id: map['id'],
      dateTime: DateTime.parse(map['dateTime']),
      moodLevel: MoodLevel.values[map['moodLevel'] ?? 2],
      label: map['label'],
      emoji: map['emoji'],
      note: map['note'],
      attachments: map['attachments'] != null
          ? List<String>.from(json.decode(map['attachments']))
          : [],
      activityIds: activities ?? [],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  MoodEntry copyWith({
    int? id,
    DateTime? dateTime,
    MoodLevel? moodLevel,
    String? label,
    String? emoji,
    String? note,
    List<String>? attachments,
    List<int>? activityIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      moodLevel: moodLevel ?? this.moodLevel,
      label: label ?? this.label,
      emoji: emoji ?? this.emoji,
      note: note ?? this.note,
      attachments: attachments ?? this.attachments,
      activityIds: activityIds ?? this.activityIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
