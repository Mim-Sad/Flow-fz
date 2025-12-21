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
            expandedHeight: 120,
            floating: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(
                      'assets/images/flow-prm.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Flow',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
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
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TaskListTile(task: todayTasks[index]),
                  );
                },
                childCount: todayTasks.length,
              ),
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
  const TaskListTile({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(task.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
      ),
      onDismissed: (direction) {
        ref.read(tasksProvider.notifier).deleteTask(task.id!);
      },
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => AddTaskScreen(task: task),
            );
          },
          leading: Checkbox(
            value: task.status == TaskStatus.success,
            onChanged: (val) {
              ref.read(tasksProvider.notifier).updateStatus(
                    task.id!,
                    val! ? TaskStatus.success : TaskStatus.pending,
                  );
            },
          ),
          title: Text(
            task.title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              decoration: task.status == TaskStatus.success
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
          subtitle: Text(
            task.category ?? 'بدون دسته‌بندی',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: _getPriorityIndicator(context, task.priority),
        ),
      ),
    );
  }

  Widget _getPriorityIndicator(BuildContext context, TaskPriority priority) {
    Color color;
    switch (priority) {
      case TaskPriority.high:
        color = Theme.of(context).colorScheme.error;
        break;
      case TaskPriority.medium:
        color = Theme.of(context).colorScheme.primary;
        break;
      case TaskPriority.low:
        color = Theme.of(context).colorScheme.secondary;
        break;
    }
    return Container(
      width: 4,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
