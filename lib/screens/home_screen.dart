import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import '../widgets/lottie_category_icon.dart';
import 'package:text_scroll/text_scroll.dart';
import '../providers/task_provider.dart';
import '../providers/category_provider.dart';
import '../providers/goal_provider.dart';
import '../models/task.dart';
import '../models/goal.dart';
import '../models/category_data.dart';
import '../widgets/postpone_dialog.dart';
import '../widgets/task_sheets.dart';
import '../widgets/animations.dart';
import 'package:go_router/go_router.dart';
import '../utils/route_builder.dart';
import 'add_task_screen.dart';
import '../widgets/flow_toast.dart';

enum SortMode { manual, defaultSort }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  SortMode _sortMode = SortMode.manual;

  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<int> _selectedTaskIds = {};

  // Set to track animated task IDs to prevent re-animation
  final Set<int> _animatedTaskIds = {};

  void _toggleSelectionMode(bool enable) {
    setState(() {
      _isSelectionMode = enable;
      if (!enable) {
        _selectedTaskIds.clear();
      }
    });
  }

  void _toggleTaskSelection(int taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
        if (_selectedTaskIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _selectAll(List<Task> tasks) {
    setState(() {
      if (_selectedTaskIds.length == tasks.length) {
        _selectedTaskIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedTaskIds.addAll(tasks.map((t) => t.id!));
      }
    });
    HapticFeedback.mediumImpact();
  }

  void _deleteSelected(List<Task> allTasks) {
    if (_selectedTaskIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف تسک‌ها', textAlign: TextAlign.right),
        content: Text(
          'آیا مطمئن هستید که می‌خواهید ${_selectedTaskIds.length} تسک را حذف کنید؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () {
              for (var id in _selectedTaskIds) {
                ref.read(tasksProvider.notifier).deleteTask(id);
              }
              Navigator.pop(context);
              _toggleSelectionMode(false);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _changeStatusSelected(DateTime today) async {
    if (_selectedTaskIds.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BulkTaskStatusPickerSheet(
        selectedTaskIds: _selectedTaskIds,
        todayDate: today,
      ),
    );
    _toggleSelectionMode(false);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayTasks = [...ref.watch(activeTasksProvider(today))];
    final isLoading = ref.watch(tasksLoadingProvider);

    // Apply Sorting
    if (_sortMode == SortMode.manual) {
      todayTasks.sort((a, b) => a.position.compareTo(b.position));
    } else {
      todayTasks.sort((a, b) {
        // 1. Status Order: Pending > Success > Deferred > Failed > Cancelled
        final statusOrder = {
          TaskStatus.pending: 0,
          TaskStatus.success: 1,
          TaskStatus.deferred: 2,
          TaskStatus.failed: 3,
          TaskStatus.cancelled: 4,
        };

        final statusA = statusOrder[a.status] ?? 99;
        final statusB = statusOrder[b.status] ?? 99;

        if (statusA != statusB) {
          return statusA.compareTo(statusB);
        }

        // 2. High priority first
        if (a.priority != b.priority) {
          return b.priority.index.compareTo(a.priority.index);
        }
        // 3. Then by Category
        final catA = a.categories.isNotEmpty ? a.categories.first : '';
        final catB = b.categories.isNotEmpty ? b.categories.first : '';
        if (catA != catB) {
          return catA.compareTo(catB);
        }
        // 4. Then by creation date (old to new)
        return a.createdAt.compareTo(b.createdAt);
      });
    }

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSelectionMode) {
          _toggleSelectionMode(false);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                const SliverPadding(padding: EdgeInsets.only(top: 80)),
                SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: 80,
                  ),
                  sliver: isLoading
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                      width: 72,
                                      height: 72,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 8,
                                        strokeCap: StrokeCap.round,
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.2),
                                      ),
                                    )
                                    .animate(
                                      onPlay: (controller) =>
                                          controller.repeat(reverse: true),
                                    )
                                    .scale(
                                      begin: const Offset(0.85, 0.85),
                                      end: const Offset(1.0, 1.0),
                                      duration: 1200.ms,
                                      curve: Curves.easeInOut,
                                    )
                                    .fade(
                                      begin: 0.6,
                                      end: 1.0,
                                      duration: 1200.ms,
                                      curve: Curves.easeInOut,
                                    ),
                              ],
                            ),
                          ),
                        )
                      : todayTasks.isEmpty
                      ? SliverToBoxAdapter(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              Lottie.asset(
                                'assets/images/TheSoul/20 glasses.json',
                                width: 120,
                                height: 120,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'برای امروز برنامه‌ای نداری!',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SliverReorderableList(
                          itemBuilder: (context, index) {
                            final task = todayTasks[index];
                            bool shouldAnimate = !_animatedTaskIds.contains(
                              task.id,
                            );
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
                                        onStatusToggle: () =>
                                            _handleStatusToggle(task),
                                        isReorderEnabled:
                                            _sortMode == SortMode.manual,
                                        isSelectionMode: _isSelectionMode,
                                        isSelected: _selectedTaskIds.contains(
                                          task.id,
                                        ),
                                        onSelect: () =>
                                            _toggleTaskSelection(task.id!),
                                        onEnterSelectionMode: () {
                                          if (!_isSelectionMode) {
                                            _toggleSelectionMode(true);
                                          }
                                          _toggleTaskSelection(
                                            task.id!,
                                          ); // Always select the task
                                        },
                                      ),
                                    )
                                  : TaskListTile(
                                      task: task,
                                      index: index,
                                      onStatusToggle: () =>
                                          _handleStatusToggle(task),
                                      isReorderEnabled:
                                          _sortMode == SortMode.manual,
                                      isSelectionMode: _isSelectionMode,
                                      isSelected: _selectedTaskIds.contains(
                                        task.id,
                                      ),
                                      onSelect: () =>
                                          _toggleTaskSelection(task.id!),
                                      onEnterSelectionMode: () {
                                        if (!_isSelectionMode) {
                                          _toggleSelectionMode(true);
                                        }
                                        _toggleTaskSelection(
                                          task.id!,
                                        ); // Always select the task
                                      },
                                    ),
                            );
                          },
                          itemCount: todayTasks.length,
                          onReorder: (oldIndex, newIndex) {
                            // Allow reorder if manual sort OR selection mode is active
                            if (_sortMode != SortMode.manual &&
                                !_isSelectionMode) {
                              return;
                            }

                            if (newIndex > oldIndex) newIndex -= 1;
                            final items = [...todayTasks];
                            final item = items.removeAt(oldIndex);
                            items.insert(newIndex, item);

                            ref
                                .read(tasksProvider.notifier)
                                .reorderTasks(items);
                            HapticFeedback.mediumImpact();
                          },
                        ),
                ),
              ],
            ),
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
                      Theme.of(context).colorScheme.surface,
                      Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.8),
                      Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.6, 1.0],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: _isSelectionMode
                        ? SizedBox(
                            height: 48,
                            child: _buildSelectionHeader(todayTasks, today),
                          )
                        : SizedBox(
                            height: 48,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'تسک‌های امروز',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                _buildSortToggle(),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const AddTaskScreen(),
            );
          },
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 24),
          label: const Text(
            'تسک جدید',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionHeader(List<Task> allTasks, DateTime today) {
    return Row(
      children: [
        IconButton(
          onPressed: () => _toggleSelectionMode(false),
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedCancel01,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: 'لغو',
        ),
        const Spacer(),
        IconButton(
          onPressed: () => _selectAll(allTasks),
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedFullScreen,
            size: 24,
            color: Colors.grey,
          ),
          tooltip: 'انتخاب همه',
        ),
        IconButton(
          onPressed: () => _changeStatusSelected(today),
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedEdit02,
            size: 24,
            color: Colors.grey,
          ),
          tooltip: 'تغییر وضعیت گروهی',
        ),
        IconButton(
          onPressed: () => _deleteSelected(allTasks),
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedDelete02,
            size: 24,
            color: Colors.grey,
          ),
          tooltip: 'حذف گروهی',
        ),
      ],
    );
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
          _buildSortOption(SortMode.manual, HugeIcons.strokeRoundedSorting05),
          _buildSortOption(
            SortMode.defaultSort,
            HugeIcons.strokeRoundedSorting19,
          ),
        ],
      ),
    );
  }

  Widget _buildSortOption(SortMode mode, dynamic icon) {
    final isSelected = _sortMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _sortMode = mode),
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

  void _handleStatusToggle(Task task) {
    if (_isSelectionMode) {
      _toggleTaskSelection(task.id!);
    } else {
      HapticFeedback.lightImpact();
      ref
          .read(tasksProvider.notifier)
          .updateStatus(
            task.id!,
            task.status == TaskStatus.success
                ? TaskStatus.pending
                : TaskStatus.success,
            date: task.dueDate,
          );
    }
  }
}

class TaskListTile extends ConsumerWidget {
  final Task task;
  final int index;
  final VoidCallback onStatusToggle;
  final bool isReorderEnabled;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelect;
  final VoidCallback? onEnterSelectionMode;
  final bool showDecoration;
  final Widget? titlePrefix;

  const TaskListTile({
    super.key,
    required this.task,
    required this.index,
    required this.onStatusToggle,
    this.isReorderEnabled = true,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelect,
    this.onEnterSelectionMode,
    this.showDecoration = true,
    this.titlePrefix,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCancelled = task.status == TaskStatus.cancelled;
    final cardContent = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isSelectionMode ? onSelect : onStatusToggle,
        onLongPress: isSelectionMode ? onSelect : onEnterSelectionMode,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 6,
            right: 12,
            top: 12,
            bottom: 12,
          ),
          child: Row(
            children: [
              isSelectionMode
                  ? Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: HugeIcon(
                        icon: isSelected
                            ? HugeIcons.strokeRoundedCheckmarkSquare02
                            : HugeIcons.strokeRoundedSquare,
                        size: 28,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  : _getStatusIconForTile(task, context, ref, onStatusToggle),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (task.taskEmoji != null) ...[
                          Text(
                            task.taskEmoji!,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (titlePrefix != null) ...[
                          titlePrefix!,
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
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              decoration:
                                  (showDecoration &&
                                      task.status == TaskStatus.success)
                                  ? TextDecoration.lineThrough
                                  : null,
                              color:
                                  (showDecoration &&
                                      task.status == TaskStatus.success)
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (task.priority != TaskPriority.medium ||
                        task.categories.isNotEmpty ||
                        (task.recurrence != null &&
                            task.recurrence!.type != RecurrenceType.none)) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 24,
                        child: _AutoScrollCapsules(
                          children: [
                            _buildPriorityCapsule(context),
                            if (task.priority != TaskPriority.medium &&
                                (task.categories.isNotEmpty || task.goalIds.isNotEmpty))
                              const SizedBox(width: 6),
                            _buildCategoryCapsules(context, ref),
                            if (task.categories.isNotEmpty && task.goalIds.isNotEmpty)
                              const SizedBox(width: 6),
                            _buildGoalCapsules(context, ref, task),
                            if (task.recurrence != null &&
                                task.recurrence!.type !=
                                    RecurrenceType.none) ...[
                              if (task.priority != TaskPriority.medium ||
                                  task.categories.isNotEmpty ||
                                  task.goalIds.isNotEmpty)
                                const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedRepeat,
                                  size: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              isSelectionMode
                  ? (isReorderEnabled
                        ? ReorderableDragStartListener(
                            index: index,
                            child: IconButton(
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedMove,
                                size: 24,
                                color: Colors.grey,
                              ),
                              padding: const EdgeInsets.all(10),
                              constraints: const BoxConstraints(),
                              onPressed: null, // Drag handle, not clickable
                            ),
                          )
                        : IconButton(
                            icon: const HugeIcon(
                              icon: HugeIcons.strokeRoundedMove,
                              size: 24,
                              color: Colors.grey,
                            ),
                            padding: const EdgeInsets.all(10),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              FlowToast.show(
                                context,
                                message:
                                    'برای جابه‌جایی دستی باید در حالت مرتب‌سازی دستی قرار داشته باشید',
                                type: FlowToastType.info,
                              );
                            },
                          ))
                  : IconButton(
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedMoreVertical,
                        size: 22,
                        color: Colors.grey,
                      ),
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(),
                      onPressed: () => _showTaskOptions(context, ref, task),
                    ),
            ],
          ),
        ),
      ),
    );

    return Opacity(
      opacity: isCancelled ? 0.6 : 1.0,
      child: Dismissible(
        key: Key('dismiss_${task.id}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // Swipe Right: Defer
            HapticFeedback.mediumImpact();
            PostponeDialog.show(context, ref, task, targetDate: task.dueDate);
            return false;
          } else {
            // Swipe Left: Done
            HapticFeedback.mediumImpact();
            ref
                .read(tasksProvider.notifier)
                .updateStatus(task.id!, TaskStatus.success, date: task.dueDate);
            return false;
          }
        },
        secondaryBackground: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(color: Colors.green.shade400),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle03,
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
        background: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(color: Colors.orange.shade400),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedClock01,
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
        child: cardContent,
      ),
    );
  }

  Widget _buildPriorityCapsule(BuildContext context) {
    if (task.priority == TaskPriority.medium) return const SizedBox.shrink();

    dynamic icon;
    Color color;
    String label;

    switch (task.priority) {
      case TaskPriority.low:
        icon = HugeIcons.strokeRoundedArrowDown01;
        color = Colors.green;
        label = 'فرعی';
        break;
      case TaskPriority.medium:
        icon = HugeIcons.strokeRoundedMinusSign;
        color = Colors.grey;
        label = 'عادی';
        break;
      case TaskPriority.high:
        icon = HugeIcons.strokeRoundedAlertCircle;
        color = Colors.red;
        label = 'فوری';
        break;
    }

    return InkWell(
      onTap: () {
        context.push(
          SearchRouteBuilder.buildSearchUrl(
            priority: task.priority,
            specificDate: task.dueDate,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, size: 10, color: color),
            const SizedBox(width: 4),
            Text(
              _toPersianDigit(label),
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildCategoryCapsules(BuildContext context, WidgetRef ref) {
    if (task.categories.isEmpty) return const SizedBox.shrink();

    final categories = task.categories;

    final allCategories =
        ref.watch(categoryProvider).valueOrNull ?? defaultCategories;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: categories.asMap().entries.map((entry) {
        final index = entry.key;
        final catId = entry.value;
        final catData = getCategoryById(catId, allCategories);
        final isDeleted = catData.isDeleted;
        final displayColor = isDeleted ? Colors.grey : catData.color;

        return InkWell(
          onTap: () {
            context.push(
              SearchRouteBuilder.buildSearchUrl(
                categories: [catId],
                specificDate: task.dueDate,
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: EdgeInsetsDirectional.only(start: index == 0 ? 0 : 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: displayColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: displayColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: isDeleted ? 0.5 : 1.0,
                  child: LottieCategoryIcon(
                    assetPath: catData.emoji,
                    width: 14,
                    height: 14,
                    repeat: false,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _toPersianDigit(catData.label),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: displayColor,
                    decoration: isDeleted ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGoalCapsules(BuildContext context, WidgetRef ref, Task task) {
    if (task.goalIds.isEmpty) return const SizedBox.shrink();

    final goalIds = task.goalIds;
    final allGoals = ref.watch(goalsProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: goalIds.asMap().entries.map((entry) {
        final index = entry.key;
        final goalId = entry.value;
        final goalData = allGoals.cast<Goal?>().firstWhere(
          (g) => g?.id == goalId,
          orElse: () => null,
        );
        
        if (goalData == null) return const SizedBox.shrink();

        return Container(
          margin: EdgeInsetsDirectional.only(start: index == 0 ? 0 : 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                goalData.emoji,
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(width: 4),
              Text(
                goalData.title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Removed _showStatusPicker as it is replaced by direct call in _getStatusIconForTile
  void _showTaskOptions(BuildContext context, WidgetRef ref, Task task) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskOptionsSheet(task: task, date: task.dueDate),
    );
  }

  Widget _getStatusIconForTile(
    Task task,
    BuildContext context,
    WidgetRef ref,
    VoidCallback onToggle,
  ) {
    dynamic icon;
    Color color;

    switch (task.status) {
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
        icon = Theme.of(context).colorScheme.outline;
        icon = HugeIcons.strokeRoundedCircle;
        color = Theme.of(context).colorScheme.outline;
        break;
    }

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(50),
      onLongPress: () {
        HapticFeedback.heavyImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => TaskStatusPickerSheet(task: task),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: HugeIcon(icon: icon, size: 28, color: color),
      ),
    );
  }
}

class _AutoScrollCapsules extends StatefulWidget {
  final List<Widget> children;
  const _AutoScrollCapsules({required this.children});

  @override
  State<_AutoScrollCapsules> createState() => _AutoScrollCapsulesState();
}

class _AutoScrollCapsulesState extends State<_AutoScrollCapsules> {
  final ScrollController _scrollController = ScrollController();
  bool _shouldScroll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling() async {
    if (!_scrollController.hasClients) return;

    // Wait for the next frame to ensure maxScrollExtent is calculated
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      if (_shouldScroll) setState(() => _shouldScroll = false);
      return;
    }

    if (!_shouldScroll) setState(() => _shouldScroll = true);

    while (_scrollController.hasClients && _shouldScroll) {
      await Future.delayed(const Duration(seconds: 2));
      if (!_scrollController.hasClients) break;

      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: (maxScroll * 40).toInt()),
        curve: Curves.linear,
      );

      await Future.delayed(const Duration(seconds: 2));
      if (!_scrollController.hasClients) break;

      await _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: (maxScroll * 40).toInt()),
        curve: Curves.linear,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: _shouldScroll
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      child: Row(mainAxisSize: MainAxisSize.min, children: widget.children),
    );
  }
}
