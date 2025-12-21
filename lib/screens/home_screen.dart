import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
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
    final tasks = ref.watch(tasksProvider);
    
    // Filter today tasks
    List<Task> todayTasks = tasks.where((t) => DateUtils.isSameDay(t.dueDate, DateTime.now())).toList();

    // Apply Sorting
    if (_sortMode == SortMode.manual) {
      todayTasks.sort((a, b) => a.position.compareTo(b.position));
    } else {
      todayTasks.sort((a, b) {
        // High priority first
        if (a.priority != b.priority) {
          return b.priority.index.compareTo(a.priority.index);
        }
        // Then by creation date (old to new)
        return a.createdAt.compareTo(b.createdAt);
      });
    }

    // Move cancelled tasks to end
    final cancelledTasks = todayTasks.where((t) => t.status == TaskStatus.cancelled).toList();
    final nonCancelledTasks = todayTasks.where((t) => t.status != TaskStatus.cancelled).toList();
    todayTasks = [...nonCancelledTasks, ...cancelledTasks];

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
            builder: (context) => const AddTaskScreen(),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('تسک جدید', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSortToggle() {
    return SegmentedButton<SortMode>(
      segments: const [
        ButtonSegment<SortMode>(
          value: SortMode.manual,
          label: Text('دستی', style: TextStyle(fontSize: 12)),
          icon: Icon(Icons.drag_indicator_rounded, size: 16),
        ),
        ButtonSegment<SortMode>(
          value: SortMode.defaultSort,
          label: Text('پیش‌فرض', style: TextStyle(fontSize: 12)),
          icon: Icon(Icons.sort_rounded, size: 16),
        ),
      ],
      selected: {_sortMode},
      onSelectionChanged: (Set<SortMode> newSelection) {
        setState(() {
          _sortMode = newSelection.first;
        });
        HapticFeedback.selectionClick();
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: MaterialStateProperty.all(const TextStyle(fontFamily: 'IRANSansX')),
      ),
      showSelectedIcon: false,
    );
  }

  void _handleStatusToggle(Task task) {
    HapticFeedback.lightImpact();
    ref.read(tasksProvider.notifier).updateStatus(
      task.id!,
      task.status == TaskStatus.success ? TaskStatus.pending : TaskStatus.success,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _getStatusIconForTile(task.status, context, ref, onStatusToggle),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        decoration: task.status == TaskStatus.success ? TextDecoration.lineThrough : null,
                        color: task.status == TaskStatus.success
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.onSurface,
                      ),
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
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildCategoryCapsule(context),
                        _buildPriorityCapsule(context),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                onSelected: (value) {
                  HapticFeedback.selectionClick();
                  if (value == 'edit') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (context) => AddTaskScreen(task: task),
                    );
                  } else if (value == 'delete') {
                    ref.read(tasksProvider.notifier).deleteTask(task.id!);
                  } else if (value == 'status_sheet') {
                    _showStatusPicker(context, ref);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('ویرایش'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'status_sheet',
                    child: Row(
                      children: [
                        Icon(Icons.checklist_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('تغییر وضعیت'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('حذف', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
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
            ref.read(tasksProvider.notifier).updateStatus(task.id!, TaskStatus.success);
            return false;
          } else {
            // Swipe Left: Defer
            HapticFeedback.mediumImpact();
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: task.dueDate.add(const Duration(days: 1)),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              helpText: 'انتخاب تاریخ تعویق',
            );

            if (picked != null) {
              await ref.read(tasksProvider.notifier).updateStatus(task.id!, TaskStatus.deferred);
              final newTask = Task(
                title: task.title,
                description: task.description,
                dueDate: picked,
                status: TaskStatus.pending,
                priority: task.priority,
                category: task.category,
              );
              await ref.read(tasksProvider.notifier).addTask(newTask);
            }
            return false;
          }
        },
        background: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(color: Colors.green.shade400),
            child: const Icon(Icons.check_circle_outline, color: Colors.white),
          ),
        ),
        secondaryBackground: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(color: Colors.orange.shade400),
            child: const Icon(Icons.history_rounded, color: Colors.white),
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
    Color color;
    String label;
    switch (task.priority) {
      case TaskPriority.high: color = Colors.red; label = 'بالا'; break;
      case TaskPriority.medium: color = Colors.blue; label = 'متوسط'; break;
      case TaskPriority.low: color = Colors.green; label = 'کم'; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _toPersianDigit(label),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
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

  Widget _buildCategoryCapsule(BuildContext context) {
    if (task.category == null || task.category!.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        _toPersianDigit(task.category!),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.tertiary,
        ),
      ),
    );
  }

  void _showStatusPicker(BuildContext context, WidgetRef ref) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تغییر وضعیت تسک',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statusIcon(context, ref, TaskStatus.success, Icons.check_circle_rounded, 'موفق', Colors.green),
                _statusIcon(context, ref, TaskStatus.failed, Icons.cancel_rounded, 'ناموفق', Colors.red),
                _statusIcon(context, ref, TaskStatus.deferred, Icons.history_rounded, 'تعویق', Colors.orange),
                _statusIcon(context, ref, TaskStatus.cancelled, Icons.block_rounded, 'لغو', Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(BuildContext context, WidgetRef ref, TaskStatus status, IconData icon, String label, Color color) {
    return InkWell(
      onTap: () async {
        HapticFeedback.mediumImpact();
        if (status == TaskStatus.deferred) {
          Navigator.pop(context);
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: task.dueDate.add(const Duration(days: 1)),
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            helpText: 'انتخاب تاریخ تعویق',
          );
          if (picked != null) {
            await ref.read(tasksProvider.notifier).updateStatus(task.id!, TaskStatus.deferred);
            final newTask = Task(
              title: task.title,
              description: task.description,
              dueDate: picked,
              status: TaskStatus.pending,
              priority: task.priority,
              category: task.category,
            );
            await ref.read(tasksProvider.notifier).addTask(newTask);
          }
        } else {
          ref.read(tasksProvider.notifier).updateStatus(task.id!, status);
          Navigator.pop(context);
        }
      },
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _getStatusIconForTile(TaskStatus status, BuildContext context, WidgetRef ref, VoidCallback onToggle) {
    IconData icon;
    Color color;

    switch (status) {
      case TaskStatus.success: icon = Icons.check_circle_rounded; color = Colors.green; break;
      case TaskStatus.failed: icon = Icons.cancel_rounded; color = Colors.red; break;
      case TaskStatus.cancelled: icon = Icons.block_rounded; color = Colors.grey; break;
      case TaskStatus.deferred: icon = Icons.history_rounded; color = Colors.orange; break;
      case TaskStatus.pending: icon = Icons.radio_button_unchecked_rounded; color = Theme.of(context).colorScheme.outline; break;
    }

    return InkWell(
      onTap: onToggle,
      onLongPress: () => _showStatusPicker(context, ref),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, size: 28, color: color),
      ),
    );
  }
}
