import '../models/task.dart';

enum SortOption {
  dateAsc,
  dateDesc,
  priorityAsc,
  priorityDesc,
  createdAtAsc,
  createdAtDesc,
  titleAsc,
  titleDesc,
  manual,
}

class SearchFilters {
  final String? query;
  final List<String>? categories;
  final List<String>? tags;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final DateTime? specificDate;
  final TaskPriority? priority;
  final List<TaskStatus>? statuses;
  final bool? isRecurring;

  SearchFilters({
    this.query,
    this.categories,
    this.tags,
    this.dateFrom,
    this.dateTo,
    this.specificDate,
    this.priority,
    this.statuses,
    this.isRecurring,
  });

  SearchFilters copyWith({
    String? query,
    List<String>? categories,
    List<String>? tags,
    DateTime? dateFrom,
    DateTime? dateTo,
    DateTime? specificDate,
    TaskPriority? priority,
    List<TaskStatus>? statuses,
    bool? isRecurring,
  }) {
    return SearchFilters(
      query: query ?? this.query,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      specificDate: specificDate ?? this.specificDate,
      priority: priority ?? this.priority,
      statuses: statuses ?? this.statuses,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  bool get hasFilters {
    return query != null && query!.isNotEmpty ||
        (categories != null && categories!.isNotEmpty) ||
        (tags != null && tags!.isNotEmpty) ||
        dateFrom != null ||
        dateTo != null ||
        specificDate != null ||
        priority != null ||
        (statuses != null && statuses!.isNotEmpty) ||
        isRecurring != null;
  }
}

class SearchService {
  List<Task> searchTasks(
    List<Task> tasks,
    SearchFilters filters,
    SortOption sortOption,
  ) {
    var results = List<Task>.from(tasks);

    // Apply text search
    if (filters.query != null && filters.query!.isNotEmpty) {
      final query = filters.query!.toLowerCase().trim();
      results = results.where((task) {
        final titleMatch = task.title.toLowerCase().contains(query);
        final descMatch = task.description?.toLowerCase().contains(query) ?? false;
        final tagsMatch = task.tags.any((tag) => tag.toLowerCase().contains(query));
        final categoriesMatch = task.categories.any((cat) => cat.toLowerCase().contains(query));
        return titleMatch || descMatch || tagsMatch || categoriesMatch;
      }).toList();
    }

    // Apply category filter
    if (filters.categories != null && filters.categories!.isNotEmpty) {
      results = results.where((task) {
        return task.categories.any((cat) => filters.categories!.contains(cat));
      }).toList();
    }

    // Apply tag filter
    if (filters.tags != null && filters.tags!.isNotEmpty) {
      results = results.where((task) {
        return task.tags.any((tag) => filters.tags!.contains(tag));
      }).toList();
    }

    // Apply date filter (specific date takes priority over range)
    if (filters.specificDate != null) {
      final specificDateOnly = DateTime(
        filters.specificDate!.year,
        filters.specificDate!.month,
        filters.specificDate!.day,
      );
      results = results.where((task) {
        final taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
        return taskDate.isAtSameMomentAs(specificDateOnly);
      }).toList();
    } else if (filters.dateFrom != null || filters.dateTo != null) {
      results = results.where((task) {
        final taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
        
        if (filters.dateFrom != null) {
          final fromDate = DateTime(
            filters.dateFrom!.year,
            filters.dateFrom!.month,
            filters.dateFrom!.day,
          );
          if (taskDate.isBefore(fromDate)) return false;
        }
        
        if (filters.dateTo != null) {
          final toDate = DateTime(
            filters.dateTo!.year,
            filters.dateTo!.month,
            filters.dateTo!.day,
          );
          if (taskDate.isAfter(toDate)) return false;
        }
        
        return true;
      }).toList();
    }

    // Apply priority filter
    if (filters.priority != null) {
      results = results.where((task) => task.priority == filters.priority).toList();
    }

    // Apply status filter (multiple statuses)
    if (filters.statuses != null && filters.statuses!.isNotEmpty) {
      results = results.where((task) => filters.statuses!.contains(task.status)).toList();
    }

    // Apply recurring filter
    if (filters.isRecurring != null) {
      results = results.where((task) {
        final isRecurring = task.recurrence != null &&
            task.recurrence!.type != RecurrenceType.none;
        return isRecurring == filters.isRecurring;
      }).toList();
    }

    // Apply sorting
    switch (sortOption) {
      case SortOption.dateAsc:
        results.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case SortOption.dateDesc:
        results.sort((a, b) => b.dueDate.compareTo(a.dueDate));
        break;
      case SortOption.priorityAsc:
        results.sort((a, b) => a.priority.index.compareTo(b.priority.index));
        break;
      case SortOption.priorityDesc:
        results.sort((a, b) => b.priority.index.compareTo(a.priority.index));
        break;
      case SortOption.createdAtAsc:
        results.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.createdAtDesc:
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.titleAsc:
        results.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.titleDesc:
        results.sort((a, b) => b.title.compareTo(a.title));
        break;
      case SortOption.manual:
        results.sort((a, b) => a.position.compareTo(b.position));
        break;
    }

    return results;
  }
}

