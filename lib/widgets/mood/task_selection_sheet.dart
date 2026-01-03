import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../models/task.dart';
import '../../providers/task_provider.dart';

class TaskSelectionSheet extends ConsumerWidget {
  final DateTime date;
  final int? selectedTaskId;

  const TaskSelectionSheet({
    super.key,
    required this.date,
    this.selectedTaskId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTasks = ref.watch(activeTasksProvider(date));
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Text(
                'انتخاب تسک مرتبط',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 24,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activeTasks.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedTask02,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'تسکى برای این روز یافت نشد',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: activeTasks.length + 1,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildTaskItem(
                      context,
                      null,
                      selectedTaskId == null,
                      theme,
                    );
                  }
                  final task = activeTasks[index - 1];
                  return _buildTaskItem(
                    context,
                    task,
                    selectedTaskId == task.id,
                    theme,
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTaskItem(
    BuildContext context,
    Task? task,
    bool isSelected,
    ThemeData theme,
  ) {
    final title = task?.title ?? 'هیچکدام';
    final color = isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: () {
        if (task == null) {
          // Return a dummy task with id -1 to signify "None"
          Navigator.pop(
            context,
            Task(
              id: -1,
              title: 'None',
              dueDate: DateTime.now(),
              categories: [],
            ),
          );
        } else {
          Navigator.pop(context, task);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            if (task?.taskEmoji != null) ...[
              Text(task!.taskEmoji!, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
            ] else
              HugeIcon(
                icon: task == null
                    ? HugeIcons.strokeRoundedCircle
                    : HugeIcons.strokeRoundedTask01,
                size: 20,
                color: color,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            if (isSelected)
              HugeIcon(
                icon: HugeIcons.strokeRoundedTick01,
                size: 20,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
