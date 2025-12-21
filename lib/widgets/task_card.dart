import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../screens/add_task_screen.dart';

class TaskCard extends ConsumerWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color cardColor;
    Color onCardColor;
    
    switch (task.priority) {
      case TaskPriority.high:
        cardColor = Theme.of(context).colorScheme.errorContainer;
        onCardColor = Theme.of(context).colorScheme.onErrorContainer;
        break;
      case TaskPriority.medium:
        cardColor = Theme.of(context).colorScheme.primaryContainer;
        onCardColor = Theme.of(context).colorScheme.onPrimaryContainer;
        break;
      case TaskPriority.low:
        cardColor = Theme.of(context).colorScheme.secondaryContainer;
        onCardColor = Theme.of(context).colorScheme.onSecondaryContainer;
        break;
    }

    if (task.status == TaskStatus.success) {
      cardColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      onCardColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => AddTaskScreen(task: task),
        );
      },
      child: Card(
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusDropdown(context, ref),
                  if (task.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        task.category!,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                task.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: onCardColor,
                  decoration: task.status == TaskStatus.success ? TextDecoration.lineThrough : null,
                ),
              ),
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  task.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: onCardColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<TaskStatus>(
      initialValue: task.status,
      onSelected: (status) {
        ref.read(tasksProvider.notifier).updateStatus(task.id!, status);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: TaskStatus.pending, child: Text('در جریان')),
        const PopupMenuItem(value: TaskStatus.success, child: Text('موفق')),
        const PopupMenuItem(value: TaskStatus.failed, child: Text('ناموفق')),
        const PopupMenuItem(value: TaskStatus.cancelled, child: Text('لغو شده')),
      ],
      child: Icon(
        _getStatusIcon(task.status),
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.success:
        return Icons.check_circle;
      case TaskStatus.failed:
        return Icons.cancel;
      case TaskStatus.cancelled:
        return Icons.block;
      case TaskStatus.pending:
        return Icons.radio_button_unchecked;
    }
  }
}

