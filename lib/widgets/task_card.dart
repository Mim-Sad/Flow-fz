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

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: onCardColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          ref.read(tasksProvider.notifier).updateStatus(
                task.id!,
                task.status == TaskStatus.success ? TaskStatus.pending : TaskStatus.success,
              );
        },
        onLongPress: () => _showStatusPicker(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _getStatusIconForCard(task.status, onCardColor)),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz_rounded, size: 20, color: onCardColor),
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
                            const SizedBox(width: 8),
                            Text('ویرایش'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'status_sheet',
                        child: Row(
                          children: [
                            Icon(Icons.checklist_rounded, size: 18),
                            const SizedBox(width: 8),
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
                            const SizedBox(width: 8),
                            const Text('حذف', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: onCardColor,
                  decoration: task.status == TaskStatus.success ? TextDecoration.lineThrough : null,
                ),
              ),
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: onCardColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildPriorityCapsule(context, onCardColor),
                  if (task.category != null && task.category!.isNotEmpty)
                    _buildCategoryCapsule(onCardColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityCapsule(BuildContext context, Color onCardColor) {
    String label;
    switch (task.priority) {
      case TaskPriority.high:
        label = 'بالا';
        break;
      case TaskPriority.medium:
        label = 'متوسط';
        break;
      case TaskPriority.low:
        label = 'کم';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: onCardColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onCardColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: onCardColor,
        ),
      ),
    );
  }

  Widget _buildCategoryCapsule(Color onCardColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: onCardColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onCardColor.withValues(alpha: 0.1)),
      ),
      child: Text(
        task.category!,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: onCardColor,
        ),
      ),
    );
  }

  Widget _getStatusIconForCard(TaskStatus status, Color color) {
    IconData iconData;
    switch (status) {
      case TaskStatus.success:
        iconData = Icons.check_circle;
        break;
      case TaskStatus.failed:
        iconData = Icons.cancel;
        break;
      case TaskStatus.cancelled:
        iconData = Icons.block;
        break;
      case TaskStatus.deferred:
        iconData = Icons.history_rounded;
        break;
      case TaskStatus.pending:
        iconData = Icons.check_box_outline_blank_rounded;
        break;
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Icon(iconData, size: 24, color: color.withValues(alpha: 0.8)),
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

  PopupMenuItem<String> _buildStatusMenuItem(TaskStatus status, String label, IconData icon, Color onCardColor) {
    return PopupMenuItem(
      value: 'status_${status.index}',
      child: Row(
        children: [
          Icon(icon, size: 18, color: onCardColor),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: onCardColor)),
        ],
      ),
    );
  }
}

