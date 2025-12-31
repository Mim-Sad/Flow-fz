import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/search_service.dart';
import 'task_provider.dart';

enum ViewStyle { list, compact }

class SearchState {
  final String query;
  final SearchFilters filters;
  final SortOption sortOption;
  final ViewStyle viewStyle;

  SearchState({
    this.query = '',
    SearchFilters? filters,
    this.sortOption = SortOption.createdAtDesc,
    this.viewStyle = ViewStyle.list,
  }) : filters = filters ?? SearchFilters();

  SearchState copyWith({
    String? query,
    SearchFilters? filters,
    SortOption? sortOption,
    ViewStyle? viewStyle,
  }) {
    return SearchState(
      query: query ?? this.query,
      filters: filters ?? this.filters,
      sortOption: sortOption ?? this.sortOption,
      viewStyle: viewStyle ?? this.viewStyle,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(Ref ref) : super(SearchState());

  void setQuery(String query) {
    state = state.copyWith(
      query: query,
      filters: state.filters.copyWith(query: query.isEmpty ? null : query),
    );
  }

  void setCategories(List<String>? categories) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        categories: categories?.isEmpty ?? true ? null : categories,
      ),
    );
  }

  void setTags(List<String>? tags) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        tags: tags?.isEmpty ?? true ? null : tags,
      ),
    );
  }

  void setGoals(List<int>? goals) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        goals: goals?.isEmpty ?? true ? null : goals,
      ),
    );
  }

  void setDateRange(DateTime? dateFrom, DateTime? dateTo) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        dateFrom: dateFrom,
        dateTo: dateTo,
        specificDate: null, // Clear specific date when setting range
      ),
    );
  }

  void setSpecificDate(DateTime? date) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        specificDate: date,
        dateFrom: null, // Clear range when setting specific date
        dateTo: null,
      ),
    );
  }

  void setPriority(TaskPriority? priority) {
    state = state.copyWith(filters: state.filters.copyWith(priority: priority));
  }

  void setStatuses(List<TaskStatus>? statuses) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        statuses: statuses?.isEmpty ?? true ? null : statuses,
      ),
    );
  }

  void toggleStatus(TaskStatus status) {
    final current = List<TaskStatus>.from(state.filters.statuses ?? []);
    if (current.contains(status)) {
      current.remove(status);
    } else {
      current.add(status);
    }
    setStatuses(current.isEmpty ? null : current);
  }

  void setRecurring(bool? isRecurring) {
    state = state.copyWith(
      filters: state.filters.copyWith(isRecurring: isRecurring),
    );
  }

  void setFilters(SearchFilters filters) {
    state = state.copyWith(filters: filters);
  }

  void updateSearchState({
    String? query,
    SearchFilters? filters,
    SortOption? sortOption,
    ViewStyle? viewStyle,
  }) {
    state = state.copyWith(
      query: query,
      filters: filters,
      sortOption: sortOption,
      viewStyle: viewStyle,
    );
  }

  void toggleGoal(int goalId) {
    final current = List<int>.from(state.filters.goals ?? []);
    if (current.contains(goalId)) {
      current.remove(goalId);
    } else {
      current.add(goalId);
    }
    setGoals(current.isEmpty ? null : current);
  }

  void setSortOption(SortOption sortOption) {
    state = state.copyWith(sortOption: sortOption);
  }

  void setViewStyle(ViewStyle viewStyle) {
    state = state.copyWith(viewStyle: viewStyle);
  }

  void clearFilters() {
    state = SearchState(
      query: state.query,
      sortOption: state.sortOption,
      viewStyle: state.viewStyle,
    );
  }

  void reset() {
    state = SearchState();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  return SearchNotifier(ref);
});

final searchResultsProvider = Provider<List<Task>>((ref) {
  final searchState = ref.watch(searchProvider);
  final allTasks = ref.watch(tasksProvider);
  final searchService = SearchService();

  return searchService.searchTasks(
    allTasks,
    searchState.filters,
    searchState.sortOption,
  );
});
