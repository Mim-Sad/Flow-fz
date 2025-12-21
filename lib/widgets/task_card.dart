import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../models/task.dart';
import '../models/category_data.dart';
import '../providers/task_provider.dart';
import '../providers/category_provider.dart';
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
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedMoreHorizontal, size: 20, color: onCardColor),
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
                            HugeIcon(icon: HugeIcons.strokeRoundedEdit02, size: 18),
                            SizedBox(width: 8),
                            Text('ویرایش'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'status_sheet',
                        child: Row(
                          children: [
                            HugeIcon(icon: HugeIcons.strokeRoundedTask01, size: 18),
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
                            HugeIcon(icon: HugeIcons.strokeRoundedDelete02, size: 18, color: Colors.red),
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
                  if (task.categories.isNotEmpty || (task.category != null && task.category!.isNotEmpty))
                    _buildCategoryCapsule(onCardColor, ref),
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

  Widget _buildCategoryCapsule(Color onCardColor, WidgetRef ref) {
    final categories = task.categories.isNotEmpty 
        ? task.categories 
        : (task.category != null ? [task.category!] : []);
    
    final firstCatId = categories.first;
    final allCategories = ref.watch(categoryProvider).valueOrNull ?? defaultCategories;
    final catData = getCategoryById(firstCatId, allCategories);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: onCardColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onCardColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(catData.emoji, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            catData.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: onCardColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getStatusIconForCard(TaskStatus status, Color color) {
    dynamic iconData;
    switch (status) {
      case TaskStatus.success:
        iconData = HugeIcons.strokeRoundedCheckmarkCircle03;
        break;
      case TaskStatus.failed:
        iconData = HugeIcons.strokeRoundedCancelCircle;
        break;
      case TaskStatus.cancelled:
        iconData = HugeIcons.strokeRoundedMinusSignCircle;
        break;
      case TaskStatus.deferred:
        iconData = HugeIcons.strokeRoundedClock01;
        break;
      case TaskStatus.pending:
        iconData = HugeIcons.strokeRoundedCircle;
        break;
    }
    return Align(
      alignment: Alignment.centerRight,
      child: HugeIcon(icon: iconData, size: 24, color: color.withValues(alpha: 0.8)),
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
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 16),
                  _buildStatusAction(context, ref, task, TaskStatus.success, 'انجام شده', HugeIcons.strokeRoundedCheckmarkCircle03, Colors.green),
                  const SizedBox(width: 16),
                  _buildStatusAction(context, ref, task, TaskStatus.failed, 'انجام نشده', HugeIcons.strokeRoundedCancelCircle, Colors.red),
                  const SizedBox(width: 16),
                  _buildStatusAction(context, ref, task, TaskStatus.cancelled, 'لغو شده', HugeIcons.strokeRoundedMinusSignCircle, Colors.grey),
                  const SizedBox(width: 16),
                  _buildStatusAction(context, ref, task, TaskStatus.deferred, 'تعویق شده', HugeIcons.strokeRoundedClock01, Colors.orange),
                  const SizedBox(width: 16),
                  _buildStatusAction(context, ref, task, TaskStatus.pending, 'در جریان', HugeIcons.strokeRoundedCircle, Colors.blue),
                  const SizedBox(width: 16),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusAction(BuildContext context, WidgetRef ref, Task task, TaskStatus status, String label, dynamic icon, Color color) {
    final isSelected = task.status == status;
    return InkWell(
      onTap: () {
        ref.read(tasksProvider.notifier).updateStatus(task.id!, status);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            HugeIcon(icon: icon, color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

