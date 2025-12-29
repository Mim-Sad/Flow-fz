import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:lottie/lottie.dart';

import '../models/task.dart';
import '../models/category_data.dart';
import '../providers/search_provider.dart';
import '../providers/task_provider.dart';
import '../providers/category_provider.dart';
import '../providers/tag_provider.dart';
import '../services/search_service.dart';
import '../widgets/lottie_category_icon.dart';
import '../screens/home_screen.dart';
import '../utils/route_builder.dart';
import '../utils/string_utils.dart';
import '../widgets/animations.dart';
import '../widgets/task_sheets.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final Map<String, String>? initialParams;

  const SearchScreen({super.key, this.initialParams});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Set to track animated task IDs to prevent re-animation
  final Set<int> _animatedTaskIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialParams != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyInitialParams(widget.initialParams!);
      });
    }
  }

  void _applyInitialParams(Map<String, String> params) {
    final parsed = SearchRouteBuilder.parseSearchParams(params);
    final searchNotifier = ref.read(searchProvider.notifier);

    if (parsed.query != null) {
      _searchController.text = parsed.query!;
      searchNotifier.setQuery(parsed.query!);
    }

    if (parsed.categories != null) {
      searchNotifier.setCategories(parsed.categories);
    }

    if (parsed.tags != null) {
      searchNotifier.setTags(parsed.tags);
    }

    if (parsed.dateFrom != null || parsed.dateTo != null) {
      searchNotifier.setDateRange(parsed.dateFrom, parsed.dateTo);
    }

    if (parsed.priority != null) {
      searchNotifier.setPriority(parsed.priority);
    }

    if (parsed.statuses != null && parsed.statuses!.isNotEmpty) {
      searchNotifier.setStatuses(parsed.statuses);
    } else if (parsed.status != null) {
      // Legacy support - convert single status to list
      searchNotifier.setStatuses([parsed.status!]);
    }

    if (parsed.specificDate != null) {
      searchNotifier.setSpecificDate(parsed.specificDate);
    }

    if (parsed.isRecurring != null) {
      searchNotifier.setRecurring(parsed.isRecurring);
    }

    if (parsed.sortOption != null) {
      searchNotifier.setSortOption(parsed.sortOption!);
    }

    if (parsed.viewStyle != null) {
      searchNotifier.setViewStyle(parsed.viewStyle!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showFilterSheet([String? target]) {
    final searchState = ref.read(searchProvider);
    final categories = ref.read(categoryProvider).valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterSheet(
        initialFilters: searchState.filters,
        categories: categories,
        initialTarget: target,
      ),
    );
  }

  void _showSortSheet() {
    final searchState = ref.read(searchProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SortSheet(currentSort: searchState.sortOption),
    );
  }

  Widget _buildCompactTaskRow(Task task, int index) {
    final status = ref
        .read(tasksProvider.notifier)
        .getStatusForDate(task.id!, task.dueDate);
    final isCancelled = status == TaskStatus.cancelled;

    dynamic icon;
    Color color;

    switch (status) {
      case TaskStatus.success:
        icon = HugeIcons.strokeRoundedCheckmarkCircle03;
        color = Colors.green;
        break;
      case TaskStatus.failed:
        icon = HugeIcons.strokeRoundedCancelCircle;
        color = Colors.red;
        break;
      case TaskStatus.cancelled:
        icon = HugeIcons.strokeRoundedMinusSignCircle;
        color = Colors.grey;
        break;
      case TaskStatus.deferred:
        icon = HugeIcons.strokeRoundedClock01;
        color = Colors.orange;
        break;
      case TaskStatus.pending:
        icon = HugeIcons.strokeRoundedCircle;
        color = Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
        break;
    }

    bool shouldAnimate = !_animatedTaskIds.contains(task.id);
    if (shouldAnimate) {
      _animatedTaskIds.add(task.id!);
    }

    final row = Opacity(
      opacity: isCancelled ? 0.6 : 1.0,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) =>
                TaskOptionsSheet(task: task, date: task.dueDate),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.5, vertical: 8),
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref
                        .read(tasksProvider.notifier)
                        .updateStatus(
                          task.id!,
                          status == TaskStatus.success
                              ? TaskStatus.pending
                              : TaskStatus.success,
                          date: task.dueDate,
                        );
                  },
                  child: HugeIcon(icon: icon, size: 22, color: color),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    if (task.taskEmoji != null) ...[
                      Text(
                        task.taskEmoji!,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (task.recurrence != null &&
                        task.recurrence!.type != RecurrenceType.none) ...[
                      _buildDateBadge(task.dueDate),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: TextScroll(
                        task.title,
                        mode: TextScrollMode.endless,
                        velocity: const Velocity(
                          pixelsPerSecond: Offset(30, 0),
                        ),
                        delayBefore: const Duration(seconds: 2),
                        pauseBetween: const Duration(seconds: 2),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return shouldAnimate ? FadeInOnce(delay: (index * 50).ms, child: row) : row;
  }

  Widget _buildSortToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSortOption(ViewStyle.list, HugeIcons.strokeRoundedListView),
          _buildSortOption(ViewStyle.compact, HugeIcons.strokeRoundedMenu07),
        ],
      ),
    );
  }

  Widget _buildSortOption(ViewStyle style, dynamic icon) {
    final searchState = ref.watch(searchProvider);
    final isSelected = searchState.viewStyle == style;
    return GestureDetector(
      onTap: () {
        ref.read(searchProvider.notifier).setViewStyle(style);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: HugeIcon(
          icon: icon,
          size: 18,
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final results = ref.watch(searchResultsProvider);
    final categories = ref.watch(categoryProvider).valueOrNull ?? [];
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Spacer for sticky header
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 80, // SafeArea top + padding + height
                ),
              ),
              // Filter Chips
              if (searchState.filters.hasFilters)
                SliverToBoxAdapter(
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 12,
                          bottom: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Sort Option Capsule
                            if (searchState.sortOption !=
                                SortOption.createdAtDesc)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _buildHeaderFilterChip(
                                  label: _getSortLabel(searchState.sortOption),
                                  avatar: HugeIcon(
                                    icon: _getSortIcon(searchState.sortOption),
                                    size: 14,
                                  ),
                                  onDeleted: () {
                                    ref
                                        .read(searchProvider.notifier)
                                        .setSortOption(
                                          SortOption.createdAtDesc,
                                        );
                                  },
                                  onSelected: (_) => _showSortSheet(),
                                ),
                              ),
                            if (searchState.filters.isRecurring != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _buildHeaderFilterChip(
                                  label: searchState.filters.isRecurring!
                                      ? 'تکرار شونده'
                                      : 'غیر تکرار شونده',
                                  avatar: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedRepeat,
                                    size: 14,
                                  ),
                                  onDeleted: () {
                                    ref
                                        .read(searchProvider.notifier)
                                        .setRecurring(null);
                                  },
                                  onSelected: (_) =>
                                      _showFilterSheet('recurring'),
                                ),
                              ),
                            if (searchState.filters.specificDate != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _buildHeaderFilterChip(
                                  label: _formatDate(
                                    searchState.filters.specificDate!,
                                  ),
                                  avatar: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedCalendar03,
                                    size: 14,
                                  ),
                                  onDeleted: () {
                                    ref
                                        .read(searchProvider.notifier)
                                        .setSpecificDate(null);
                                  },
                                  onSelected: (_) => _showFilterSheet('date'),
                                ),
                              )
                            else if (searchState.filters.dateFrom != null ||
                                searchState.filters.dateTo != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _buildHeaderFilterChip(
                                  label: _formatDateRange(
                                    searchState.filters.dateFrom,
                                    searchState.filters.dateTo,
                                  ),
                                  avatar: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedCalendar03,
                                    size: 14,
                                  ),
                                  onDeleted: () {
                                    ref
                                        .read(searchProvider.notifier)
                                        .setDateRange(null, null);
                                  },
                                  onSelected: (_) => _showFilterSheet('date'),
                                ),
                              ),
                            if (searchState.filters.statuses != null &&
                                searchState.filters.statuses!.isNotEmpty)
                              ...searchState.filters.statuses!.map((status) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: _buildHeaderFilterChip(
                                    label: _getStatusLabel(status),
                                    avatar: HugeIcon(
                                      icon: _getStatusIcon(status),
                                      size: 14,
                                    ),
                                    onDeleted: () {
                                      ref
                                          .read(searchProvider.notifier)
                                          .toggleStatus(status);
                                    },
                                    onSelected: (_) =>
                                        _showFilterSheet('status'),
                                  ),
                                );
                              }),
                            if (searchState.filters.priority != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _buildHeaderFilterChip(
                                  label: _getPriorityLabel(
                                    searchState.filters.priority!,
                                  ),
                                  avatar: HugeIcon(
                                    icon: _getPriorityIcon(
                                      searchState.filters.priority!,
                                    ),
                                    size: 14,
                                  ),
                                  onDeleted: () {
                                    ref
                                        .read(searchProvider.notifier)
                                        .setPriority(null);
                                  },
                                  onSelected: (_) =>
                                      _showFilterSheet('priority'),
                                ),
                              ),
                            if (searchState.filters.tags != null &&
                                searchState.filters.tags!.isNotEmpty)
                              ...searchState.filters.tags!.map((tag) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: _buildHeaderFilterChip(
                                    label: tag,
                                    avatar: const HugeIcon(
                                      icon: HugeIcons.strokeRoundedTag01,
                                      size: 14,
                                    ),
                                    onDeleted: () {
                                      final newTags = List<String>.from(
                                        searchState.filters.tags ?? [],
                                      )..remove(tag);
                                      ref
                                          .read(searchProvider.notifier)
                                          .setTags(
                                            newTags.isEmpty ? null : newTags,
                                          );
                                    },
                                    onSelected: (_) => _showFilterSheet('tags'),
                                  ),
                                );
                              }),
                            if (searchState.filters.categories != null &&
                                searchState.filters.categories!.isNotEmpty)
                              ...searchState.filters.categories!.map((catId) {
                                final cat = categories.firstWhere(
                                  (c) => c.id == catId,
                                  orElse: () => CategoryData(
                                    id: catId,
                                    label: catId,
                                    emoji: '',
                                    color: Colors.grey,
                                  ),
                                );
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: _buildHeaderFilterChip(
                                    label: cat.label,
                                    avatar: LottieCategoryIcon(
                                      assetPath: cat.emoji,
                                      width: 14,
                                      height: 14,
                                      repeat: false,
                                    ),
                                    onDeleted: () {
                                      final newCats = List<String>.from(
                                        searchState.filters.categories ?? [],
                                      )..remove(catId);
                                      ref
                                          .read(searchProvider.notifier)
                                          .setCategories(
                                            newCats.isEmpty ? null : newCats,
                                          );
                                    },
                                    onSelected: (_) =>
                                        _showFilterSheet('categories'),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Results Count

              // Results
              if (results.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          'assets/images/TheSoul/18 rock F.json',
                          width: 140,
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchState.filters.hasFilters ||
                                  searchState.query.isNotEmpty
                              ? 'نتیجه‌ای یافت نشد!'
                              : 'جستجو کنید...',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (searchState.viewStyle == ViewStyle.list)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final task = results[index];
                      bool shouldAnimate = !_animatedTaskIds.contains(task.id);
                      if (shouldAnimate) {
                        _animatedTaskIds.add(task.id!);
                      }

                      return Padding(
                        key: ValueKey(task.id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: shouldAnimate
                            ? FadeInOnce(
                                delay: (index * 50).ms,
                                child: TaskListTile(
                                  task: task,
                                  index: index,
                                  onStatusToggle: () {
                                    ref
                                        .read(tasksProvider.notifier)
                                        .updateStatus(
                                          task.id!,
                                          task.status == TaskStatus.success
                                              ? TaskStatus.pending
                                              : TaskStatus.success,
                                          date: task.dueDate,
                                        );
                                  },
                                  isReorderEnabled: false,
                                  isSelectionMode: false,
                                  isSelected: false,
                                  showDecoration: false,
                                  titlePrefix:
                                      (task.recurrence != null &&
                                          task.recurrence!.type !=
                                              RecurrenceType.none)
                                      ? _buildDateBadge(task.dueDate)
                                      : null,
                                ),
                              )
                            : TaskListTile(
                                task: task,
                                index: index,
                                onStatusToggle: () {
                                  ref
                                      .read(tasksProvider.notifier)
                                      .updateStatus(
                                        task.id!,
                                        task.status == TaskStatus.success
                                            ? TaskStatus.pending
                                            : TaskStatus.success,
                                        date: task.dueDate,
                                      );
                                },
                                isReorderEnabled: false,
                                isSelectionMode: false,
                                isSelected: false,
                                showDecoration: false,
                                titlePrefix:
                                    (task.recurrence != null &&
                                        task.recurrence!.type !=
                                            RecurrenceType.none)
                                    ? _buildDateBadge(task.dueDate)
                                    : null,
                              ),
                      );
                    }, childCount: results.length),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final task = results[index];
                      return Padding(
                        key: ValueKey(task.id),
                        padding: const EdgeInsets.only(bottom: 0),
                        child: _buildCompactTaskRow(task, index),
                      );
                    }, childCount: results.length),
                  ),
                ),
            ],
          ),
          // Sticky Header - Like home screen
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.surface.withValues(alpha: 0.8),
                    theme.colorScheme.surface.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.6, 1.0],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 20),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        // View Style Toggle - Like home screen sort toggle
                        _buildSortToggle(),
                        const SizedBox(width: 8),
                        // Search Box
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  ref
                                      .read(searchProvider.notifier)
                                      .setQuery(value);
                                },
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'جستجو...',
                                  hintStyle: const TextStyle(fontSize: 14),
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: HugeIcon(
                                      icon: HugeIcons.strokeRoundedSearch01,
                                      size: 18,
                                    ),
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const HugeIcon(
                                            icon:
                                                HugeIcons.strokeRoundedCancel01,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            ref
                                                .read(searchProvider.notifier)
                                                .setQuery('');
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: theme.colorScheme.surfaceContainer
                                      .withValues(alpha: 0.7),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  isDense: true,
                                ),
                              ),
                              if (results.isNotEmpty)
                                Positioned(
                                  bottom: -6,
                                  left: -4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '${results.length}',
                                      style: TextStyle(
                                        color: theme.colorScheme.onPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Sort Button
                        IconButton(
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedSorting19,
                            size: 22,
                          ),
                          onPressed: _showSortSheet,
                          tooltip: 'مرتب‌سازی',
                        ),
                        // Filter Button
                        IconButton(
                          icon: Stack(
                            children: [
                              const HugeIcon(
                                icon: HugeIcons.strokeRoundedFilter,
                                size: 22,
                              ),
                              if (searchState.filters.hasFilters)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onPressed: _showFilterSheet,
                          tooltip: 'فیلتر',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderFilterChip({
    required String label,
    required VoidCallback onDeleted,
    required Function(bool) onSelected,
    Widget? avatar,
  }) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      avatar: avatar != null
          ? IconTheme.merge(
              data: IconThemeData(
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
              ),
              child: avatar,
            )
          : null,
      deleteIcon: Icon(
        Icons.close_rounded,
        size: 12,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      onDeleted: onDeleted,
      onSelected: onSelected,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      labelPadding: const EdgeInsets.fromLTRB(-4, 2, -4, 2),
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      side: BorderSide(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        width: 0.8,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildDateBadge(DateTime date) {
    final j = Jalali.fromDateTime(date);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _toPersianDigit('${j.day} ${j.formatter.mN}'),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
        ),
      ),
    );
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.dateAsc:
        return 'تاریخ ↑';
      case SortOption.dateDesc:
        return 'تاریخ ↓';
      case SortOption.priorityAsc:
        return 'اولویت ↑';
      case SortOption.priorityDesc:
        return 'اولویت ↓';
      case SortOption.createdAtAsc:
        return 'قدیمی‌ترین';
      case SortOption.createdAtDesc:
        return 'جدیدترین';
      case SortOption.titleAsc:
        return 'الفبا (آ-ی)';
      case SortOption.titleDesc:
        return 'الفبا (ی-آ)';
      case SortOption.manual:
        return 'دستی';
    }
  }

  dynamic _getSortIcon(SortOption option) {
    return HugeIcons.strokeRoundedSorting19;
  }

  dynamic _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return HugeIcons.strokeRoundedCircle;
      case TaskStatus.success:
        return HugeIcons.strokeRoundedCheckmarkCircle03;
      case TaskStatus.failed:
        return HugeIcons.strokeRoundedCancelCircle;
      case TaskStatus.cancelled:
        return HugeIcons.strokeRoundedMinusSignCircle;
      case TaskStatus.deferred:
        return HugeIcons.strokeRoundedClock01;
    }
  }

  dynamic _getPriorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return HugeIcons.strokeRoundedArrowDown01;
      case TaskPriority.medium:
        return HugeIcons.strokeRoundedMinusSign;
      case TaskPriority.high:
        return HugeIcons.strokeRoundedAlertCircle;
    }
  }

  String _getPriorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'فرعی';
      case TaskPriority.medium:
        return 'عادی';
      case TaskPriority.high:
        return 'فوری';
    }
  }

  String _getStatusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'در جریان';
      case TaskStatus.success:
        return 'انجام شده';
      case TaskStatus.failed:
        return 'انجام نشده';
      case TaskStatus.cancelled:
        return 'لغو شده';
      case TaskStatus.deferred:
        return 'به تعویق افتاده';
    }
  }

  String _toPersianDigit(String input) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    String result = input;
    for (int i = 0; i < englishDigits.length; i++) {
      result = result.replaceAll(englishDigits[i], persianDigits[i]);
    }
    return result;
  }

  String _formatDate(DateTime date) {
    final j = Jalali.fromDateTime(date);
    return _toPersianDigit('${j.day} ${j.formatter.mN}');
  }

  String _formatDateRange(DateTime? from, DateTime? to) {
    if (from != null && to != null) {
      final jFrom = Jalali.fromDateTime(from);
      final jTo = Jalali.fromDateTime(to);
      return _toPersianDigit(
        '${jFrom.day} ${jFrom.formatter.mN} - ${jTo.day} ${jTo.formatter.mN}',
      );
    } else if (from != null) {
      final jFrom = Jalali.fromDateTime(from);
      return _toPersianDigit('از ${jFrom.day} ${jFrom.formatter.mN}');
    } else if (to != null) {
      final jTo = Jalali.fromDateTime(to);
      return _toPersianDigit('تا ${jTo.day} ${jTo.formatter.mN}');
    }
    return '';
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  final SearchFilters initialFilters;
  final List<CategoryData> categories;
  final String? initialTarget;

  const _FilterSheet({
    required this.initialFilters,
    required this.categories,
    this.initialTarget,
  });

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late SearchFilters _filters;
  final TextEditingController _tagController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final Map<String, GlobalKey> _sectionKeys = {
    'categories': GlobalKey(),
    'tags': GlobalKey(),
    'priority': GlobalKey(),
    'status': GlobalKey(),
    'date': GlobalKey(),
    'recurring': GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;

    if (widget.initialTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSection(widget.initialTarget!);
      });
    }
  }

  void _scrollToSection(String target) {
    final key = _sectionKeys[target];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim();
    if (trimmedTag.isNotEmpty &&
        !StringUtils.containsTag(_filters.tags ?? [], trimmedTag)) {
      setState(() {
        final current = List<String>.from(_filters.tags ?? []);
        current.add(trimmedTag);
        _filters = _filters.copyWith(tags: current);
        _tagController.clear();
      });
    } else if (trimmedTag.isNotEmpty) {
      _tagController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('این تگ قبلاً اضافه شده است'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectSpecificDate() async {
    final Jalali? picked = await showPersianDatePicker(
      context: context,
      initialDate: _filters.specificDate != null
          ? Jalali.fromDateTime(_filters.specificDate!)
          : Jalali.now(),
      firstDate: Jalali(1300, 1, 1),
      lastDate: Jalali(1500, 1, 1),
      helpText: 'انتخاب تاریخ',
    );

    if (picked != null) {
      setState(() {
        _filters = _filters.copyWith(
          specificDate: picked.toDateTime(),
          dateFrom: null,
          dateTo: null,
        );
      });
    }
  }

  Future<void> _selectDateRange() async {
    final Jalali? pickedFrom = await showPersianDatePicker(
      context: context,
      initialDate: _filters.dateFrom != null
          ? Jalali.fromDateTime(_filters.dateFrom!)
          : Jalali.now(),
      firstDate: Jalali(1300, 1, 1),
      lastDate: Jalali(1500, 1, 1),
      helpText: 'انتخاب تاریخ شروع',
    );

    if (pickedFrom == null) return;

    final Jalali? pickedTo = await showPersianDatePicker(
      context: context,
      initialDate: _filters.dateTo != null
          ? Jalali.fromDateTime(_filters.dateTo!)
          : pickedFrom,
      firstDate: pickedFrom,
      lastDate: Jalali(1500, 1, 1),
      helpText: 'انتخاب تاریخ پایان',
    );

    if (pickedTo != null) {
      setState(() {
        _filters = _filters.copyWith(
          dateFrom: pickedFrom.toDateTime(),
          dateTo: pickedTo.toDateTime(),
          specificDate: null,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedSettings03,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'فیلترها',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(searchProvider.notifier).clearFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('پاک کردن همه'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories - Similar to add_task_screen
                  Consumer(
                    builder: (context, ref, child) {
                      final categoriesAsync = ref.watch(categoryProvider);
                      return categoriesAsync.when(
                        data: (categories) {
                          final cats = categories.isEmpty
                              ? defaultCategories
                              : categories;
                          final activeCats = cats
                              .where((c) => !c.isDeleted)
                              .toList();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'دسته‌بندی',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: activeCats.map((cat) {
                                    final isSelected =
                                        _filters.categories?.contains(cat.id) ??
                                        false;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          final current = List<String>.from(
                                            _filters.categories ?? [],
                                          );
                                          if (isSelected) {
                                            current.remove(cat.id);
                                          } else {
                                            current.add(cat.id);
                                          }
                                          _filters = _filters.copyWith(
                                            categories: current.isEmpty
                                                ? null
                                                : current,
                                          );
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? cat.color.withValues(
                                                  alpha: 0.15,
                                                )
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? cat.color.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : Colors.transparent,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            LottieCategoryIcon(
                                              assetPath: cat.emoji,
                                              width: 22,
                                              height: 22,
                                              repeat: false,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              cat.label,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? cat.color
                                                    : Theme.of(
                                                        context,
                                                      ).colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Text('خطا: $err'),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Tags - Similar to add_task_screen
                  Center(
                    key: _sectionKeys['tags'],
                    child: Text(
                      'تگ‌ها',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tagController,
                    onChanged: (value) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'افزودن تگ جدید...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: Container(
                        margin: const EdgeInsetsDirectional.only(
                          start: 14,
                          end: 10,
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedTag01,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      suffixIcon: IconButton(
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedAddCircle,
                          size: 20,
                        ),
                        onPressed: () => _addTag(_tagController.text),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (val) => _addTag(val),
                  ),
                  // Suggestions
                  if (_tagController.text.isNotEmpty) ...[
                    Consumer(
                      builder: (context, ref, child) {
                        final suggestions = ref.watch(
                          tagSuggestionsProvider(_tagController.text),
                        );
                        final filteredSuggestions = suggestions
                            .where(
                              (s) => !StringUtils.containsTag(
                                _filters.tags ?? [],
                                s,
                              ),
                            )
                            .take(5)
                            .toList();

                        if (filteredSuggestions.isEmpty)
                          return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                          child: Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: filteredSuggestions
                                  .map(
                                    (suggestion) => ActionChip(
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            suggestion,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.add,
                                            size: 14,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ],
                                      ),
                                      onPressed: () => _addTag(suggestion),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.3),
                                      side: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.2),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 0,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  // Added Tags
                  if (_filters.tags != null && _filters.tags!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: _filters.tags!
                            .map(
                              (tag) => ActionChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tag,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    ),
                                  ],
                                ),
                                onPressed: () {
                                  setState(() {
                                    final current = List<String>.from(
                                      _filters.tags ?? [],
                                    );
                                    current.remove(tag);
                                    _filters = _filters.copyWith(
                                      tags: current.isEmpty ? null : current,
                                    );
                                  });
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                    .withValues(alpha: 0.3),
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.secondary
                                      .withValues(alpha: 0.2),
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Priority - Similar to add_task_screen
                  Center(
                    key: _sectionKeys['priority'],
                    child: Text(
                      'اولویت',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<TaskPriority?>(
                        segments: const [
                          ButtonSegment(
                            value: TaskPriority.low,
                            label: Text('فرعی'),
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedArrowDown01,
                              color: Colors.green,
                              size: 18,
                            ),
                          ),
                          ButtonSegment(
                            value: TaskPriority.medium,
                            label: Text('عادی'),
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedMinusSign,
                              color: Colors.grey,
                              size: 18,
                            ),
                          ),
                          ButtonSegment(
                            value: TaskPriority.high,
                            label: Text('فوری'),
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedAlertCircle,
                              color: Colors.red,
                              size: 18,
                            ),
                          ),
                        ],
                        selected: {
                          if (_filters.priority != null) _filters.priority!,
                        },
                        onSelectionChanged: (Set<TaskPriority?> newSelection) {
                          setState(() {
                            _filters = _filters.copyWith(
                              priority: newSelection.isEmpty
                                  ? null
                                  : newSelection.first,
                            );
                          });
                        },
                        emptySelectionAllowed: true,
                        style: SegmentedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'IRANSansX',
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Status - Like task status picker sheet with multiple selection
                  Center(
                    key: _sectionKeys['status'],
                    child: Text(
                      'وضعیت',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusAction(
                          TaskStatus.success,
                          'انجام شده',
                          HugeIcons.strokeRoundedCheckmarkCircle03,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatusAction(
                          TaskStatus.pending,
                          'در جریان',
                          HugeIcons.strokeRoundedCircle,
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatusAction(
                          TaskStatus.failed,
                          'انجام نشده',
                          HugeIcons.strokeRoundedCancelCircle,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusAction(
                          TaskStatus.cancelled,
                          'لغو شده',
                          HugeIcons.strokeRoundedMinusSignCircle,
                          Colors.grey,
                          horizontal: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatusAction(
                          TaskStatus.deferred,
                          'تعویق شده',
                          HugeIcons.strokeRoundedClock01,
                          Colors.orange,
                          horizontal: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Date Selection
                  Center(
                    key: _sectionKeys['date'],
                    child: Text(
                      'تاریخ',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_filters.specificDate != null)
                    _buildDateCapsule(
                      onTap: _selectSpecificDate,
                      label: _formatDate(_filters.specificDate!),
                      icon: HugeIcons.strokeRoundedCalendar03,
                      isSelected: true,
                      onClear: () {
                        setState(() {
                          _filters = _filters.copyWith(specificDate: null);
                        });
                      },
                    )
                  else if (_filters.dateFrom != null || _filters.dateTo != null)
                    _buildDateCapsule(
                      onTap: _selectDateRange,
                      label: _formatDateRange(
                        _filters.dateFrom,
                        _filters.dateTo,
                      ),
                      icon: HugeIcons.strokeRoundedCalendar02,
                      isSelected: true,
                      onClear: () {
                        setState(() {
                          _filters = _filters.copyWith(
                            dateFrom: null,
                            dateTo: null,
                          );
                        });
                      },
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateCapsule(
                            onTap: _selectSpecificDate,
                            label: 'تاریخ مشخص',
                            icon: HugeIcons.strokeRoundedCalendar03,
                            isSelected: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDateCapsule(
                            onTap: _selectDateRange,
                            label: 'بازه تاریخی',
                            icon: HugeIcons.strokeRoundedCalendar02,
                            isSelected: false,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  // Recurring - Full width with icons like priority
                  Center(
                    key: _sectionKeys['recurring'],
                    child: Text(
                      'نوع تسک',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool?>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('تکرار شونده'),
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedRepeat,
                            size: 18,
                          ),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('غیر تکرار شونده'),
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendarRemove01,
                            size: 18,
                          ),
                        ),
                      ],
                      selected: {
                        if (_filters.isRecurring != null) _filters.isRecurring!,
                      },
                      onSelectionChanged: (Set<bool?> newSelection) {
                        setState(() {
                          _filters = _filters.copyWith(
                            isRecurring: newSelection.isEmpty
                                ? null
                                : newSelection.first,
                          );
                        });
                      },
                      emptySelectionAllowed: true,
                      style: SegmentedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'IRANSansX',
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Apply Button - Faded background like add task button
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.8),
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.6, 1.0],
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () {
                    ref.read(searchProvider.notifier).setFilters(_filters);
                    Navigator.pop(context);
                  },
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkSquare04,
                    size: 20,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  label: Text(
                    'اعمال فیلترها',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCapsule({
    required VoidCallback onTap,
    required String label,
    required dynamic icon,
    required bool isSelected,
    VoidCallback? onClear,
  }) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.1)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? color
                      : Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: icon,
                    size: 20,
                    color: isSelected
                        ? color
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? color
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onClear != null && isSelected) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusAction(
    TaskStatus status,
    String label,
    dynamic icon,
    Color color, {
    bool horizontal = false,
  }) {
    final isSelected = _filters.statuses?.contains(status) ?? false;

    return InkWell(
      onTap: () {
        setState(() {
          final current = List<TaskStatus>.from(_filters.statuses ?? []);
          if (isSelected) {
            current.remove(status);
            // Allow removing even if it's the last one
            _filters = _filters.copyWith(
              statuses: current.isEmpty ? null : current,
            );
          } else {
            current.add(status);
            _filters = _filters.copyWith(statuses: current);
          }
        });
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? color
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: horizontal
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: icon,
                    size: 20,
                    color: isSelected
                        ? color
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? color
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: icon,
                    size: 28,
                    color: isSelected
                        ? color
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? color
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final j = Jalali.fromDateTime(date);
    return '${j.year}/${j.month}/${j.day}';
  }

  String _formatDateRange(DateTime? from, DateTime? to) {
    if (from != null && to != null) {
      final jFrom = Jalali.fromDateTime(from);
      final jTo = Jalali.fromDateTime(to);
      return '${jFrom.year}/${jFrom.month}/${jFrom.day} - ${jTo.year}/${jTo.month}/${jTo.day}';
    } else if (from != null) {
      final jFrom = Jalali.fromDateTime(from);
      return 'از ${jFrom.year}/${jFrom.month}/${jFrom.day}';
    } else if (to != null) {
      final jTo = Jalali.fromDateTime(to);
      return 'تا ${jTo.year}/${jTo.month}/${jTo.day}';
    }
    return '';
  }
}

class _SortSheet extends ConsumerWidget {
  final SortOption currentSort;

  const _SortSheet({required this.currentSort});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedSorting19,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'مرتب‌سازی',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: SortOption.values.map((option) {
                    final isSelected = currentSort == option;
                    return _buildStatusAction(
                      context,
                      ref,
                      option,
                      _getSortLabel(option),
                      isSelected
                          ? HugeIcons.strokeRoundedCheckmarkSquare02
                          : null,
                      isSelected,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusAction(
    BuildContext context,
    WidgetRef ref,
    SortOption option,
    String label,
    dynamic icon,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () {
        ref.read(searchProvider.notifier).setSortOption(option);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            if (icon != null)
              HugeIcon(
                icon: icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              )
            else
              const SizedBox(width: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.dateAsc:
        return 'تاریخ (قدیمی به جدید)';
      case SortOption.dateDesc:
        return 'تاریخ (جدید به قدیمی)';
      case SortOption.priorityAsc:
        return 'اولویت (پایین به بالا)';
      case SortOption.priorityDesc:
        return 'اولویت (بالا به پایین)';
      case SortOption.createdAtAsc:
        return 'تاریخ ایجاد (قدیمی به جدید)';
      case SortOption.createdAtDesc:
        return 'تاریخ ایجاد (جدید به قدیمی)';
      case SortOption.titleAsc:
        return 'عنوان (الفبایی)';
      case SortOption.titleDesc:
        return 'عنوان (معکوس)';
      case SortOption.manual:
        return 'دستی';
    }
  }
}
