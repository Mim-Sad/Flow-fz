import '../models/task.dart';
import '../utils/string_utils.dart';

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
    Object? query = _sentinel,
    Object? categories = _sentinel,
    Object? tags = _sentinel,
    Object? dateFrom = _sentinel,
    Object? dateTo = _sentinel,
    Object? specificDate = _sentinel,
    Object? priority = _sentinel,
    Object? statuses = _sentinel,
    Object? isRecurring = _sentinel,
  }) {
    return SearchFilters(
      query: query == _sentinel ? this.query : query as String?,
      categories: categories == _sentinel
          ? this.categories
          : categories as List<String>?,
      tags: tags == _sentinel ? this.tags : tags as List<String>?,
      dateFrom: dateFrom == _sentinel ? this.dateFrom : dateFrom as DateTime?,
      dateTo: dateTo == _sentinel ? this.dateTo : dateTo as DateTime?,
      specificDate: specificDate == _sentinel
          ? this.specificDate
          : specificDate as DateTime?,
      priority: priority == _sentinel
          ? this.priority
          : priority as TaskPriority?,
      statuses: statuses == _sentinel
          ? this.statuses
          : statuses as List<TaskStatus>?,
      isRecurring: isRecurring == _sentinel
          ? this.isRecurring
          : isRecurring as bool?,
    );
  }

  static const _sentinel = Object();

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
      final normalizedQuery = StringUtils.normalize(filters.query!);
      results = results.where((task) {
        final normalizedTitle = StringUtils.normalize(task.title);
        final normalizedDesc = task.description != null
            ? StringUtils.normalize(task.description!)
            : '';

        final titleMatch = normalizedTitle.contains(normalizedQuery);
        final descMatch = normalizedDesc.contains(normalizedQuery);
        final tagsMatch = task.tags.any(
          (tag) => StringUtils.normalize(tag).contains(normalizedQuery),
        );
        final categoriesMatch = task.categories.any(
          (cat) => cat.toLowerCase().contains(
            normalizedQuery,
          ), // Categories are usually IDs
        );
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
      final normalizedFiltersTags = filters.tags!
          .map((t) => StringUtils.normalize(t))
          .toSet();
      results = results.where((task) {
        return task.tags.any(
          (tag) => normalizedFiltersTags.contains(StringUtils.normalize(tag)),
        );
      }).toList();
    }

    // Apply priority filter
    if (filters.priority != null) {
      results = results
          .where((task) => task.priority == filters.priority)
          .toList();
    }

    // Apply recurring filter
    if (filters.isRecurring != null) {
      results = results.where((task) {
        final isRecurring =
            task.recurrence != null &&
            task.recurrence!.type != RecurrenceType.none;
        return isRecurring == filters.isRecurring;
      }).toList();
    }

    // Apply date filter - EXPAND RECURRING TASKS
    // This MUST happen before status filtering because status depends on the specific date
    if (filters.specificDate != null ||
        filters.dateFrom != null ||
        filters.dateTo != null) {
      final List<Task> expandedResults = [];
      final startDate =
          filters.specificDate ??
          filters.dateFrom ??
          DateTime(2000); // Fallback start
      final endDate =
          filters.specificDate ??
          filters.dateTo ??
          DateTime.now().add(const Duration(days: 365)); // Fallback end

      final rangeDays = (endDate.difference(startDate).inHours / 24).round();
      final effectiveEnd = rangeDays > 365
          ? startDate.add(const Duration(days: 365))
          : endDate;

      for (final task in results) {
        for (
          int i = 0;
          i <= (effectiveEnd.difference(startDate).inHours / 24).round();
          i++
        ) {
          final currentDate = startDate.add(Duration(days: i));
          if (task.isActiveOnDate(currentDate)) {
            expandedResults.add(task.copyWith(dueDate: currentDate));
          }
        }
      }
      results = expandedResults;
    }

    // Apply status filter (multiple statuses)
    // This now correctly filters based on the occurrence date's status
    if (filters.statuses != null && filters.statuses!.isNotEmpty) {
      results = results
          .where((task) => filters.statuses!.contains(task.status))
          .toList();
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
