import 'dart:convert';

import 'package:flutter/material.dart';

enum MoodLevel {
  rad,      // عالی - 5
  good,     // خوب - 4
  meh,      // معمولی - 3
  bad,      // بد - 2
  awful     // افتضاح - 1
}

extension MoodLevelExtension on MoodLevel {
  String get label {
    switch (this) {
      case MoodLevel.rad: return 'عالی';
      case MoodLevel.good: return 'خوب';
      case MoodLevel.meh: return 'معمولی';
      case MoodLevel.bad: return 'بد';
      case MoodLevel.awful: return 'خیلی بد';
    }
  }

  Color get color {
    switch (this) {
      case MoodLevel.rad: return const Color(0xFFB5CF1E);
      case MoodLevel.good: return const Color(0xFF11c777);
      case MoodLevel.meh: return const Color(0xFF2b93e5);
      case MoodLevel.bad: return const Color(0xFFf29017);
      case MoodLevel.awful: return const Color(0xFFf3332b);
    }
  }

  String get iconPath {
    switch (this) {
      case MoodLevel.rad: return 'assets/images/Moods/5.png';
      case MoodLevel.good: return 'assets/images/Moods/4.png';
      case MoodLevel.meh: return 'assets/images/Moods/3.png';
      case MoodLevel.bad: return 'assets/images/Moods/2.png';
      case MoodLevel.awful: return 'assets/images/Moods/1.png';
    }
  }

  String get emoji {
    switch (this) {
      case MoodLevel.rad: return '🤩';
      case MoodLevel.good: return '😊';
      case MoodLevel.meh: return '😐';
      case MoodLevel.bad: return '☹️';
      case MoodLevel.awful: return '😫';
    }
  }
}

class MoodEntry {
  final int? id;
  final DateTime dateTime;
  final MoodLevel moodLevel;
  final String? note;
  final List<String> attachments; // Paths to files/photos
  final List<int> activityIds; // Linked activities
  final int? taskId; // Linked task
  final DateTime createdAt;
  final DateTime? updatedAt;

  MoodEntry({
    this.id,
    required this.dateTime,
    required this.moodLevel,
    this.note,
    this.attachments = const [],
    this.activityIds = const [],
    this.taskId,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateTime': dateTime.toIso8601String(),
      'moodLevel': moodLevel.index,
      'note': note,
      'activityIds': json.encode(activityIds),
      'attachments': json.encode(attachments),
      'taskId': taskId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map, {List<int>? activities}) {
    return MoodEntry(
      id: map['id'],
      dateTime: DateTime.parse(map['dateTime']),
      moodLevel: MoodLevel.values[map['moodLevel'] ?? 2],
      note: map['note'],
      activityIds: activities ?? (map['activityIds'] != null
          ? List<int>.from(json.decode(map['activityIds']))
          : []),
      attachments: map['attachments'] != null
          ? List<String>.from(json.decode(map['attachments']))
          : [],
      taskId: map['taskId'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  MoodEntry copyWith({
    int? id,
    DateTime? dateTime,
    MoodLevel? moodLevel,
    String? note,
    List<String>? attachments,
    List<int>? activityIds,
    int? taskId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      moodLevel: moodLevel ?? this.moodLevel,
      note: note ?? this.note,
      attachments: attachments ?? this.attachments,
      activityIds: activityIds ?? this.activityIds,
      taskId: taskId ?? this.taskId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
