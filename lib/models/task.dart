import 'dart:convert';
import 'package:shamsi_date/shamsi_date.dart';

enum TaskStatus { pending, success, failed, cancelled, deferred }

enum TaskPriority { low, medium, high }

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
      daysOfWeek: map['daysOfWeek'] != null
          ? List<int>.from(map['daysOfWeek'])
          : null,
      specificDates: map['specificDates'] != null
          ? List<DateTime>.from(
              map['specificDates'].map((e) => DateTime.parse(e)),
            )
          : null,
      dayOfMonth: map['dayOfMonth'],
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory RecurrenceConfig.fromJson(String source) =>
      RecurrenceConfig.fromMap(json.decode(source));
}

class Task {
  final int? id;
  final String title;
  final String? description;
  final DateTime dueDate;
  final DateTime? endTime;
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
  final List<int> goalIds;
  final RecurrenceConfig? recurrence;
  final DateTime? reminderDateTime;
  final Map<String, int> statusHistory;
  final Map<String, dynamic> metadata;
  final List<Map<String, dynamic>> statusLogs;

  Task({
    this.id,
    required this.title,
    this.description,
    required this.dueDate,
    this.endTime,
    this.priority = TaskPriority.medium,
    List<String>? categories,
    List<String>? tags,
    List<int>? goalIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.position = 0,
    this.taskEmoji,
    List<String>? attachments,
    this.recurrence,
    this.reminderDateTime,
    Map<String, int>? statusHistory,
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? statusLogs,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? (createdAt ?? DateTime.now()),
       categories = categories ?? [],
       tags = tags ?? const [],
       goalIds = goalIds ?? const [],
       attachments = attachments ?? [],
       statusHistory = statusHistory ?? {},
       metadata = metadata ?? {},
       statusLogs = statusLogs ?? [];

  // Helper to get status for a specific date
  TaskStatus getStatusForDate(DateTime date) {
    if (!isActiveOnDate(date)) {
      return TaskStatus.pending;
    }

    final key =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // 1. Prioritize explicitly set status in statusHistory
    final statusIndex = statusHistory[key];
    if (statusIndex != null) {
      return TaskStatus.values[statusIndex];
    }

    // 2. Fallback to latest status from logs for this specific date
    if (statusLogs.isNotEmpty) {
      // Find the latest log entry for this date
      Map<String, dynamic>? latestLog;
      for (final log in statusLogs) {
        final payload = log['payload'];
        if (payload is Map && payload['date'] == key) {
          if (latestLog == null ||
              DateTime.parse(
                log['occurredAt'],
              ).isAfter(DateTime.parse(latestLog['occurredAt']))) {
            latestLog = log;
          }
        }
      }

      if (latestLog != null) {
        final statusIndexFromLog = latestLog['payload']['status'] as int?;
        if (statusIndexFromLog != null &&
            statusIndexFromLog < TaskStatus.values.length) {
          return TaskStatus.values[statusIndexFromLog];
        }
      }
    }

    return TaskStatus.pending;
  }

  /// Checks if the status for a given date was explicitly recorded in history.
  bool hasExplicitStatusForDate(DateTime date) {
    final key =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return statusHistory.containsKey(key);
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

    final jalaliDate = Jalali.fromDateTime(dateOnly);
    final jalaliDueDate = Jalali.fromDateTime(dueDateOnly);

    // Specific recurrence logic
    switch (recurrence!.type) {
      case RecurrenceType.daily:
        final interval = recurrence!.interval ?? 1;
        final diff = (dateOnly.difference(dueDateOnly).inHours / 24).round();
        return diff % interval == 0;

      case RecurrenceType.weekly:
        final interval = recurrence!.interval ?? 1;
        final daysOfWeek = recurrence!.daysOfWeek ?? [];

        // If specific days are selected, check if current date is one of them
        if (daysOfWeek.isNotEmpty) {
          if (!daysOfWeek.contains(dateOnly.weekday)) return false;
        } else {
          // If no specific days, it defaults to the same weekday as start date
          if (dateOnly.weekday != dueDateOnly.weekday) return false;
        }

        // Calculate weeks difference.
        // We find the start of the week (Saturday for Iran) for both dates
        // to calculate the absolute week difference.
        // DateTime.weekday: 1=Mon, ..., 6=Sat, 7=Sun
        // Days since Saturday: Sat=0, Sun=1, Mon=2, Tue=3, Wed=4, Thu=5, Fri=6
        final daysSinceSatStart = (dueDateOnly.weekday + 1) % 7;
        final daysSinceSatCurrent = (dateOnly.weekday + 1) % 7;

        final startOfStartWeek = dueDateOnly.subtract(
          Duration(days: daysSinceSatStart),
        );
        final startOfCurrentWeek = dateOnly.subtract(
          Duration(days: daysSinceSatCurrent),
        );
        final weeksDiff =
            (startOfCurrentWeek.difference(startOfStartWeek).inDays / 7)
                .round();

        return weeksDiff % interval == 0;

      case RecurrenceType.monthly:
        final interval = recurrence!.interval ?? 1;

        // Use Jalali for monthly recurrence to stay consistent with Persian calendar
        if (jalaliDate.day != jalaliDueDate.day) {
          // Handle end of month cases (e.g., task on 31st, but month has 30 days)
          // If the target day is > current month length, we could either skip or use the last day.
          // For now, let's match the exact day.
          return false;
        }

        final monthsDiff =
            (jalaliDate.year - jalaliDueDate.year) * 12 +
            (jalaliDate.month - jalaliDueDate.month);
        return monthsDiff >= 0 && monthsDiff % interval == 0;

      case RecurrenceType.yearly:
        final interval = recurrence!.interval ?? 1;

        // Use Jalali for yearly recurrence
        if (jalaliDate.month != jalaliDueDate.month ||
            jalaliDate.day != jalaliDueDate.day) {
          return false;
        }

        final yearsDiff = jalaliDate.year - jalaliDueDate.year;
        return yearsDiff >= 0 && yearsDiff % interval == 0;

      case RecurrenceType.specificDays:
        // This is used for "Specific Weekdays" in the UI
        final daysOfWeek = recurrence!.daysOfWeek ?? [];
        if (daysOfWeek.isEmpty) return _isSameDay(dueDateOnly, dateOnly);
        return daysOfWeek.contains(dateOnly.weekday);

      case RecurrenceType.custom:
        final interval = recurrence!.interval ?? 1;
        final diff = (dateOnly.difference(dueDateOnly).inHours / 24).round();
        return diff >= 0 && diff % interval == 0;

      default:
        return _isSameDay(dueDateOnly, dateOnly);
    }
  }

  bool occursInRange(DateTime? from, DateTime? to) {
    final rangeStart = from != null
        ? DateTime(from.year, from.month, from.day)
        : null;
    final rangeEnd = to != null ? DateTime(to.year, to.month, to.day) : null;
    final taskStart = DateTime(dueDate.year, dueDate.month, dueDate.day);

    // 1. Task starts after range
    if (rangeEnd != null && taskStart.isAfter(rangeEnd)) return false;

    // 2. Task has end date and ends before range
    if (rangeStart != null && recurrence?.endDate != null) {
      final taskEnd = DateTime(
        recurrence!.endDate!.year,
        recurrence!.endDate!.month,
        recurrence!.endDate!.day,
      );
      if (taskEnd.isBefore(rangeStart)) return false;
    }

    // 3. Non-recurring task
    if (recurrence == null || recurrence!.type == RecurrenceType.none) {
      if (rangeStart != null && taskStart.isBefore(rangeStart)) return false;
      if (rangeEnd != null && taskStart.isAfter(rangeEnd)) return false;
      return true;
    }

    // 4. Recurring task - check range
    final effectiveStart = rangeStart ?? taskStart;
    final effectiveEnd =
        rangeEnd ?? effectiveStart.add(const Duration(days: 365));

    // Intersection check
    final searchStart = effectiveStart.isBefore(taskStart)
        ? taskStart
        : effectiveStart;
    if (rangeEnd != null && searchStart.isAfter(rangeEnd)) return false;

    // Small range optimization: if range <= 31 days, just loop.
    final diffDays = (effectiveEnd.difference(searchStart).inHours / 24)
        .round();
    if (diffDays <= 31) {
      for (int i = 0; i <= diffDays; i++) {
        if (isActiveOnDate(searchStart.add(Duration(days: i)))) return true;
      }
      return false;
    }

    // Large range logic
    switch (recurrence!.type) {
      case RecurrenceType.daily:
        final interval = recurrence!.interval ?? 1;
        if (interval <= 1) return true;
        final daysSinceTaskStart =
            (searchStart.difference(taskStart).inHours / 24).round();
        final nextOccurrence = taskStart.add(
          Duration(days: (daysSinceTaskStart / interval).ceil() * interval),
        );
        return !nextOccurrence.isAfter(effectiveEnd);

      case RecurrenceType.weekly:
        final interval = recurrence!.interval ?? 1;
        if (interval == 1 && diffDays >= 7) return true;
        final checkLimit = (7 * interval).clamp(0, 365);
        for (int i = 0; i <= checkLimit && i <= diffDays; i++) {
          if (isActiveOnDate(searchStart.add(Duration(days: i)))) return true;
        }
        return false;

      case RecurrenceType.monthly:
      case RecurrenceType.yearly:
      case RecurrenceType.specificDays:
        final checkLimit = diffDays.clamp(0, 365);
        for (int i = 0; i <= checkLimit; i++) {
          if (isActiveOnDate(searchStart.add(Duration(days: i)))) return true;
        }
        return false;

      default:
        final checkLimit = diffDays.clamp(0, 31);
        for (int i = 0; i <= checkLimit; i++) {
          if (isActiveOnDate(searchStart.add(Duration(days: i)))) return true;
        }
        return false;
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
    
    final hasTime = newMetadata['hasTime'] ?? false;

    return Task(
      title: title,
      description: description,
      dueDate: dueDate,
      endTime: hasTime ? endTime : null,
      priority: priority,
      categories: List.from(categories),
      tags: List.from(tags),
      goalIds: List.from(goalIds),
      taskEmoji: taskEmoji,
      attachments: List.from(attachments),
      recurrence: recurrence,
      statusHistory: {}, // Don't copy status history when duplicating
      metadata: newMetadata,
    );
  }

  int get deferCount => metadata['deferCount'] ?? 0;
  bool get hasTime => metadata['hasTime'] ?? true;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'priority': priority.index,
      'categories': json.encode(categories),
      'tags': json.encode(tags),
      'goalIds': json.encode(goalIds),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.toIso8601String(),
      'position': position,
      'taskEmoji': taskEmoji,
      'attachments': json.encode(attachments),
      'recurrence': recurrence?.toJson(),
      'reminderDateTime': reminderDateTime?.toIso8601String(),
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

    List<int> loadedGoalIds = [];
    if (map['goalIds'] != null) {
      try {
        loadedGoalIds = List<int>.from(json.decode(map['goalIds']));
      } catch (e) {
        // Fallback
      }
    }

    Map<String, dynamic> loadedMetadata = {};
    if (map['metadata'] != null) {
      try {
        loadedMetadata = Map<String, dynamic>.from(
          json.decode(map['metadata']),
        );
      } catch (e) {
        // Fallback
      }
    }

    Map<String, int> loadedStatusHistory = {};
    if (map['statusHistory'] != null) {
      try {
        loadedStatusHistory = Map<String, int>.from(
          json.decode(map['statusHistory']),
        );
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
      endTime: (loadedMetadata['hasTime'] == true && map['endTime'] != null)
          ? DateTime.parse(map['endTime'])
          : null,
      priority: loadedPriority,
      categories: loadedCategories,
      tags: loadedTags,
      goalIds: loadedGoalIds,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : null,
      isDeleted: (map['isDeleted'] ?? 0) == 1,
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'])
          : null,
      position: map['position'] ?? 0,
      taskEmoji: map['taskEmoji'],
      attachments: map['attachments'] != null
          ? List<String>.from(json.decode(map['attachments']))
          : [],
      recurrence: map['recurrence'] != null
          ? RecurrenceConfig.fromJson(map['recurrence'])
          : null,
      reminderDateTime: map['reminderDateTime'] != null
          ? DateTime.parse(map['reminderDateTime'])
          : null,
      statusHistory: loadedStatusHistory,
      metadata: loadedMetadata,
      statusLogs: map['statusLogs'] != null
          ? List<Map<String, dynamic>>.from(json.decode(map['statusLogs']))
          : [],
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? dueDate,
    DateTime? endTime,
    TaskPriority? priority,
    List<String>? categories,
    List<String>? tags,
    List<int>? goalIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    int? position,
    String? taskEmoji,
    List<String>? attachments,
    RecurrenceConfig? recurrence,
    DateTime? reminderDateTime,
    Map<String, int>? statusHistory,
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? statusLogs,
  }) {
    final finalMetadata = metadata ?? this.metadata;
    final hasTime = finalMetadata['hasTime'] == true;

    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      endTime: hasTime ? (endTime ?? this.endTime) : null,
      priority: priority ?? this.priority,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      goalIds: goalIds ?? this.goalIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      position: position ?? this.position,
      taskEmoji: taskEmoji ?? this.taskEmoji,
      attachments: attachments ?? this.attachments,
      recurrence: recurrence ?? this.recurrence,
      reminderDateTime: reminderDateTime ?? this.reminderDateTime,
      statusHistory: statusHistory ?? this.statusHistory,
      metadata: finalMetadata,
      statusLogs: statusLogs ?? this.statusLogs,
    );
  }
}
