import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:text_scroll/text_scroll.dart';
import '../providers/task_provider.dart';
import '../providers/category_provider.dart';
import '../models/task.dart';
import '../models/category_data.dart';
import '../widgets/postpone_dialog.dart';
import '../widgets/task_sheets.dart';
import 'add_task_screen.dart';

enum SortMode { manual, defaultSort }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  SortMode _sortMode = SortMode.manual;

  // Set to track animated task IDs to prevent re-animation
  final Set<int> _animatedTaskIds = {};

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayTasks = [...ref.watch(activeTasksProvider(today))];
    
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
        final catA = a.categories.isNotEmpty ? a.categories.first : (a.category ?? '');
        final catB = b.categories.isNotEmpty ? b.categories.first : (b.category ?? '');
        if (catA != catB) {
            return catA.compareTo(catB);
        }
        // 4. Then by creation date (old to new)
        return a.createdAt.compareTo(b.createdAt);
      });
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تسک‌های امروز',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  _buildSortToggle(),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverReorderableList(
              itemBuilder: (context, index) {
                final task = todayTasks[index];
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
                          onStatusToggle: () => _handleStatusToggle(task),
                          isReorderEnabled: _sortMode == SortMode.manual,
                        ),
                      )
                    : TaskListTile(
                        task: task, 
                        index: index,
                        onStatusToggle: () => _handleStatusToggle(task),
                        isReorderEnabled: _sortMode == SortMode.manual,
                      ),
                );
              },
              itemCount: todayTasks.length,
              onReorder: (oldIndex, newIndex) {
                if (_sortMode != SortMode.manual) return;
                
                if (newIndex > oldIndex) newIndex -= 1;
                final items = [...todayTasks];
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                
                ref.read(tasksProvider.notifier).reorderTasks(items);
                HapticFeedback.mediumImpact();
              },
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
        label: const Text('تسک جدید', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSortToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSortOption(SortMode.manual, HugeIcons.strokeRoundedSorting05),
          _buildSortOption(SortMode.defaultSort, HugeIcons.strokeRoundedSorting19),
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
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: HugeIcon(
          icon: icon,
          size: 18,
          color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  void _handleStatusToggle(Task task) {
    HapticFeedback.lightImpact();
    ref.read(tasksProvider.notifier).updateStatus(
      task.id!,
      task.status == TaskStatus.success ? TaskStatus.pending : TaskStatus.success,
      date: task.dueDate,
    );
  }
}

class FadeInOnce extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const FadeInOnce({super.key, required this.child, required this.delay});

  @override
  State<FadeInOnce> createState() => _FadeInOnceState();
}

class _FadeInOnceState extends State<FadeInOnce> with AutomaticKeepAliveClientMixin {
  bool _hasAnimated = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_hasAnimated) return widget.child;

    return widget.child
        .animate(onComplete: (controller) => _hasAnimated = true)
        .fadeIn(duration: 400.ms, delay: widget.delay)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic)
        .blur(begin: const Offset(4, 4), end: Offset.zero);
  }
}

class TaskListTile extends ConsumerWidget {
  final Task task;
  final int index;
  final VoidCallback onStatusToggle;
  final bool isReorderEnabled;
  const TaskListTile({super.key, required this.task, required this.index, required this.onStatusToggle, this.isReorderEnabled = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCancelled = task.status == TaskStatus.cancelled;
    final cardContent = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onStatusToggle, 
        onLongPress: null, 
        child: Padding(
          padding: const EdgeInsets.only(left: 6, right: 12, top: 12, bottom: 12),
          child: Row(
            children: [
              _getStatusIconForTile(task, context, ref, onStatusToggle),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (task.taskEmoji != null) ...[
                          Text(task.taskEmoji!, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: TextScroll(
                            task.title,
                            mode: TextScrollMode.endless,
                            velocity: const Velocity(pixelsPerSecond: Offset(30, 0)),
                            delayBefore: const Duration(seconds: 2),
                            pauseBetween: const Duration(seconds: 2),
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              decoration: task.status == TaskStatus.success ? TextDecoration.lineThrough : null,
                              color: task.status == TaskStatus.success
                                  ? Theme.of(context).colorScheme.onSurfaceVariant
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (task.description != null && task.description!.isNotEmpty)
                      Text(
                        task.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildCategoryCapsule(context, ref),
                        _buildPriorityCapsule(context),
                        if (task.recurrence != null && task.recurrence!.type != RecurrenceType.none)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                            ),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedRepeat, 
                              size: 12, 
                              color: Theme.of(context).colorScheme.primary
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedMoreVertical, size: 22, color: Colors.grey),
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
            // Swipe Right: Done
            HapticFeedback.mediumImpact();
            ref.read(tasksProvider.notifier).updateStatus(task.id!, TaskStatus.success, date: task.dueDate);
            return false;
          } else {
            // Swipe Left: Defer
            HapticFeedback.mediumImpact();
            PostponeDialog.show(context, ref, task, targetDate: task.dueDate);
            return false;
          }
        },
        background: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(color: Colors.green.shade400),
            child: const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle03, size: 24, color: Colors.white),
          ),
        ),
        secondaryBackground: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(color: Colors.orange.shade400),
            child: const HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 24, color: Colors.white),
          ),
        ),
        child: isReorderEnabled
            ? ReorderableDelayedDragStartListener(
                index: index,
                child: cardContent,
              )
            : cardContent,
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
        label = 'کم';
        break;
      case TaskPriority.medium:
        icon = HugeIcons.strokeRoundedMinusSign;
        color = Colors.grey;
        label = 'عادی';
        break;
      case TaskPriority.high:
        icon = HugeIcons.strokeRoundedAlertCircle;
        color = Colors.red;
        label = 'بالا';
        break;
    }

    return Container(
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
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
        ],
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

  Widget _buildCategoryCapsule(BuildContext context, WidgetRef ref) {
    if (task.categories.isEmpty && (task.category == null || task.category!.isEmpty)) return const SizedBox.shrink();
    
    // Use categories list if available, otherwise fallback to legacy category
    final categories = task.categories.isNotEmpty 
        ? task.categories 
        : (task.category != null ? [task.category!] : []);
    
    // Show first category + count if more
    final firstCatId = categories.first;
    final allCategories = ref.watch(categoryProvider).valueOrNull ?? defaultCategories;
    final catData = getCategoryById(firstCatId, allCategories);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      constraints: const BoxConstraints(maxWidth: 100), // Limit width for marquee
      decoration: BoxDecoration(
        color: catData.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: catData.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(catData.emoji, width: 14, height: 14),
          const SizedBox(width: 4),
          Flexible(
            child: TextScroll(
              _toPersianDigit(catData.label),
              mode: TextScrollMode.endless,
              velocity: const Velocity(pixelsPerSecond: Offset(20, 0)),
              delayBefore: const Duration(seconds: 2),
              pauseBetween: const Duration(seconds: 2),
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: catData.color,
              ),
            ),
          ),
          if (categories.length > 1) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: catData.color,
                shape: BoxShape.circle,
              ),
              child: Text(
                _toPersianDigit('+${categories.length - 1}'),
                style: const TextStyle(fontSize: 8, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Removed _showStatusPicker as it is replaced by direct call in _getStatusIconForTile
  void _showTaskOptions(BuildContext context, WidgetRef ref, Task task) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => TaskOptionsSheet(task: task),
    );
  }

  Widget _getStatusIconForTile(Task task, BuildContext context, WidgetRef ref, VoidCallback onToggle) {
    dynamic icon;
    Color color;

    switch (task.status) {
      case TaskStatus.success: icon = HugeIcons.strokeRoundedCheckmarkCircle03; color = Colors.green; break;
      case TaskStatus.failed: icon = HugeIcons.strokeRoundedCancelCircle; color = Colors.red; break;
      case TaskStatus.cancelled: icon = HugeIcons.strokeRoundedMinusSignCircle; color = Colors.grey; break;
      case TaskStatus.deferred: icon = HugeIcons.strokeRoundedClock01; color = Colors.orange; break;
      case TaskStatus.pending: icon = HugeIcons.strokeRoundedCircle; color = Theme.of(context).colorScheme.outline; break;
    }

    return InkWell(
      onTap: onToggle,
      onLongPress: () {
         HapticFeedback.heavyImpact();
         showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
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
