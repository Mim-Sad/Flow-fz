import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';
import 'add_task_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final todayTasks = tasks.where((t) => DateUtils.isSameDay(t.dueDate, DateTime.now())).toList();
    final importantTasks = tasks.where((t) => t.priority == TaskPriority.high).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 80,
            floating: true,
            pinned: true,
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: null,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (importantTasks.isNotEmpty) ...[
                    Text(
                      'اولویت‌های بالا 🔥',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 16),
                    MasonryGridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      itemCount: importantTasks.length,
                      itemBuilder: (context, index) {
                        return TaskCard(task: importantTasks[index]);
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                  Text(
                    'برنامه امروز 📅',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverReorderableList(
              itemBuilder: (context, index) {
                return Padding(
                  key: ValueKey(todayTasks[index].id),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TaskListTile(task: todayTasks[index], index: index),
                );
              },
              itemCount: todayTasks.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final items = [...todayTasks];
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                // In a real app, you'd update the provider/DB here
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
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
}

class TaskListTile extends ConsumerWidget {
  final Task task;
  final int index;
  const TaskListTile({super.key, required this.task, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key('dismiss_${task.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Done
          ref.read(tasksProvider.notifier).updateStatus(task.id!, TaskStatus.success);
          return false;
        } else {
          // Swipe Left: Defer
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: task.dueDate.add(const Duration(days: 1)),
            firstDate: DateTime.now().subtract(const Duration(days: 365)), // Allow picking past if needed, but usually forward
            lastDate: DateTime.now().add(const Duration(days: 365)),
            helpText: 'انتخاب تاریخ تعویق',
          );

          if (picked != null) {
            // 1. Update original task to deferred
            await ref.read(tasksProvider.notifier).updateStatus(task.id!, TaskStatus.deferred);
            
            // 2. Create a copy for the new date
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
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.green.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.check_circle_outline, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.orange.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.history_rounded, color: Colors.white),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: InkWell(
          onLongPress: () => _showStatusPicker(context, ref),
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => AddTaskScreen(task: task),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          decoration: task.status == TaskStatus.success
                              ? TextDecoration.lineThrough
                              : null,
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
                        children: [
                          _buildPriorityCapsule(context),
                          _buildCategoryCapsule(context),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _getStatusIconForTile(task.status, context),
                const SizedBox(width: 4),
                ReorderableDragStartListener(
                  index: index,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    onSelected: (value) {
                      if (value == 'edit') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (context) => AddTaskScreen(task: task),
                        );
                      } else if (value == 'delete') {
                        ref.read(tasksProvider.notifier).deleteTask(task.id!);
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
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('حذف', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityCapsule(BuildContext context) {
    Color color;
    String label;
    switch (task.priority) {
      case TaskPriority.high:
        color = Colors.red;
        label = 'بالا';
        break;
      case TaskPriority.medium:
        color = Colors.blue;
        label = 'متوسط';
        break;
      case TaskPriority.low:
        color = Colors.green;
        label = 'کم';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  void _showStatusPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('تغییر وضعیت تسک', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            _statusTile(context, ref, TaskStatus.pending, 'در جریان', Icons.radio_button_unchecked),
            _statusTile(context, ref, TaskStatus.success, 'موفق', Icons.check_circle_outline, Colors.green),
            _statusTile(context, ref, TaskStatus.failed, 'ناموفق', Icons.cancel_outlined, Colors.red),
            _statusTile(context, ref, TaskStatus.cancelled, 'لغو شده', Icons.block_flipped, Colors.grey),
            _statusTile(context, ref, TaskStatus.deferred, 'تعویق شده', Icons.history_rounded, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _statusTile(BuildContext context, WidgetRef ref, TaskStatus status, String label, IconData icon, [Color? color]) {
    return ListTile(
      leading: Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
      title: Text(label),
      onTap: () {
        ref.read(tasksProvider.notifier).updateStatus(task.id!, status);
        Navigator.pop(context);
      },
    );
  }

  Widget _getStatusIconForTile(TaskStatus status, BuildContext context) {
    switch (status) {
      case TaskStatus.success:
        return Icon(Icons.check_circle, size: 28, color: Colors.green.shade400);
      case TaskStatus.failed:
        return Icon(Icons.cancel, size: 28, color: Colors.red.shade400);
      case TaskStatus.cancelled:
        return Icon(Icons.block, size: 28, color: Colors.grey.shade400);
      case TaskStatus.deferred:
        return Icon(Icons.history_rounded, size: 28, color: Colors.orange.shade400);
      case TaskStatus.pending:
        return Icon(Icons.check_box_outline_blank_rounded,
          size: 28,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
        );
    }
  }
}
