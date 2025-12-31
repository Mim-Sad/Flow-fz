import '../models/task.dart';
import '../services/search_service.dart';
import '../providers/search_provider.dart';

class SearchRouteBuilder {
  /// Builds a search URL with the given parameters
  static String buildSearchUrl({
    String? query,
    List<String>? categories,
    List<String>? tags,
    List<int>? goals,
    DateTime? dateFrom,
    DateTime? dateTo,
    DateTime? specificDate,
    TaskPriority? priority,
    List<TaskStatus>? statuses,
    TaskStatus? status, // Legacy support
    bool? isRecurring,
    SortOption? sortOption,
    ViewStyle? viewStyle,
  }) {
    final params = <String, String>{};

    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }

    if (categories != null && categories.isNotEmpty) {
      params['cat'] = categories.join(',');
    }

    if (tags != null && tags.isNotEmpty) {
      params['tag'] = tags.join(',');
    }

    if (goals != null && goals.isNotEmpty) {
      params['goal'] = goals.join(',');
    }

    if (specificDate != null) {
      params['specificDate'] = _formatDate(specificDate);
    } else {
      if (dateFrom != null) {
        params['dateFrom'] = _formatDate(dateFrom);
      }

      if (dateTo != null) {
        params['dateTo'] = _formatDate(dateTo);
      }
    }

    if (priority != null) {
      params['priority'] = _priorityToString(priority);
    }

    if (statuses != null && statuses.isNotEmpty) {
      params['statuses'] = statuses.map((s) => _statusToString(s)).join(',');
    } else if (status != null) {
      // Legacy support
      params['status'] = _statusToString(status);
    }

    if (isRecurring != null) {
      params['recurring'] = isRecurring.toString();
    }

    if (sortOption != null) {
      params['sort'] = _sortOptionToString(sortOption);
    }

    if (viewStyle != null) {
      params['view'] = viewStyle == ViewStyle.list ? 'list' : 'compact';
    }

    if (viewStyle != null) {
      params['view'] = viewStyle == ViewStyle.list ? 'list' : 'compact';
    }

    final uri = Uri(path: '/search', queryParameters: params);
    return uri.toString();
  }

  /// Parses search parameters from URL query string
  static SearchParams parseSearchParams(Map<String, String> queryParams) {
    List<TaskStatus>? statuses;
    if (queryParams['statuses'] != null) {
      statuses = queryParams['statuses']!
          .split(',')
          .map((s) => _stringToStatus(s))
          .whereType<TaskStatus>()
          .toList();
    } else if (queryParams['status'] != null) {
      // Legacy support - convert single status to list
      final status = _stringToStatus(queryParams['status']!);
      if (status != null) {
        statuses = [status];
      }
    }

    return SearchParams(
      query: queryParams['q'],
      categories: queryParams['cat']
          ?.split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      tags: queryParams['tag']?.split(',').where((s) => s.isNotEmpty).toList(),
      goals: queryParams['goal']
          ?.split(',')
          .where((s) => s.isNotEmpty)
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toList(),
      dateFrom:
          queryParams['specificDate'] == null && queryParams['dateFrom'] != null
          ? _parseDate(queryParams['dateFrom']!)
          : null,
      dateTo:
          queryParams['specificDate'] == null && queryParams['dateTo'] != null
          ? _parseDate(queryParams['dateTo']!)
          : null,
      specificDate: queryParams['specificDate'] != null
          ? _parseDate(queryParams['specificDate']!)
          : null,
      priority: queryParams['priority'] != null
          ? _stringToPriority(queryParams['priority']!)
          : null,
      statuses: statuses,
      status: statuses?.isNotEmpty == true
          ? statuses!.first
          : null, // Legacy support
      isRecurring: queryParams['recurring'] != null
          ? queryParams['recurring'] == 'true'
          : null,
      sortOption: queryParams['sort'] != null
          ? _stringToSortOption(queryParams['sort']!)
          : null,
      viewStyle: queryParams['view'] != null
          ? (queryParams['view'] == 'list' ? ViewStyle.list : ViewStyle.compact)
          : null,
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (e) {
      return null;
    }
  }

  static String _priorityToString(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'low';
      case TaskPriority.medium:
        return 'medium';
      case TaskPriority.high:
        return 'high';
    }
  }

  static TaskPriority? _stringToPriority(String str) {
    switch (str.toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'medium':
        return TaskPriority.medium;
      case 'high':
        return TaskPriority.high;
      default:
        return null;
    }
  }

  static String _statusToString(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'pending';
      case TaskStatus.success:
        return 'success';
      case TaskStatus.failed:
        return 'failed';
      case TaskStatus.cancelled:
        return 'cancelled';
      case TaskStatus.deferred:
        return 'deferred';
    }
  }

  static TaskStatus? _stringToStatus(String str) {
    switch (str.toLowerCase()) {
      case 'pending':
        return TaskStatus.pending;
      case 'success':
        return TaskStatus.success;
      case 'failed':
        return TaskStatus.failed;
      case 'cancelled':
        return TaskStatus.cancelled;
      case 'deferred':
        return TaskStatus.deferred;
      default:
        return null;
    }
  }

  static String _sortOptionToString(SortOption sortOption) {
    switch (sortOption) {
      case SortOption.dateAsc:
        return 'dateAsc';
      case SortOption.dateDesc:
        return 'dateDesc';
      case SortOption.priorityAsc:
        return 'priorityAsc';
      case SortOption.priorityDesc:
        return 'priorityDesc';
      case SortOption.createdAtAsc:
        return 'createdAtAsc';
      case SortOption.createdAtDesc:
        return 'createdAtDesc';
      case SortOption.titleAsc:
        return 'titleAsc';
      case SortOption.titleDesc:
        return 'titleDesc';
      case SortOption.manual:
        return 'manual';
    }
  }

  static SortOption? _stringToSortOption(String str) {
    switch (str.toLowerCase()) {
      case 'dateasc':
        return SortOption.dateAsc;
      case 'datedesc':
        return SortOption.dateDesc;
      case 'priorityasc':
        return SortOption.priorityAsc;
      case 'prioritydesc':
        return SortOption.priorityDesc;
      case 'createdatasc':
        return SortOption.createdAtAsc;
      case 'createdatdesc':
        return SortOption.createdAtDesc;
      case 'titleasc':
        return SortOption.titleAsc;
      case 'titledesc':
        return SortOption.titleDesc;
      case 'manual':
        return SortOption.manual;
      default:
        return null;
    }
  }
}

class SearchParams {
  final String? query;
  final List<String>? categories;
  final List<String>? tags;
  final List<int>? goals;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final DateTime? specificDate;
  final TaskPriority? priority;
  final List<TaskStatus>? statuses;
  final TaskStatus? status;
  final bool? isRecurring;
  final SortOption? sortOption;
  final ViewStyle? viewStyle;

  SearchParams({
    this.query,
    this.categories,
    this.tags,
    this.goals,
    this.dateFrom,
    this.dateTo,
    this.specificDate,
    this.priority,
    this.statuses,
    this.status,
    this.isRecurring,
    this.sortOption,
    this.viewStyle,
  });
}
