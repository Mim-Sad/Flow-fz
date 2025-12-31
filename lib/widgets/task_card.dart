import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart' as intl;
import '../utils/string_utils.dart';
import 'lottie_category_icon.dart';
import '../models/task.dart';
import '../models/goal.dart';
import '../models/category_data.dart';
import '../providers/task_provider.dart';
import '../providers/category_provider.dart';
import '../providers/goal_provider.dart';
import '../utils/route_builder.dart';
import 'package:go_router/go_router.dart';
import '../widgets/task_sheets.dart';
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
        cardColor = Theme.of(context).colorScheme.surfaceContainerLow;
        onCardColor = Theme.of(context).colorScheme.onSurface;
        break;
      case TaskPriority.low:
        cardColor = Colors.green.withValues(alpha: 0.1);
        onCardColor = Colors.green.shade800;
        break;
    }

    if (task.status == TaskStatus.success) {
      cardColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      onCardColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    final hasCapsules = (task.metadata['hasTime'] ?? false) ||
                        task.priority != TaskPriority.medium || 
                        task.categories.isNotEmpty ||
                        task.goalIds.isNotEmpty;

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
                date: task.dueDate,
              );
        },
        onLongPress: null, // Removed long press on body
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: hasCapsules ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _getStatusIconForCard(task, onCardColor, context)),
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
                          builder: (context) => AddTaskScreen(
                            task: task,
                            initialDate: task.dueDate,
                          ),
                        );
                      } else if (value == 'duplicate') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (context) => AddTaskScreen(
                            task: task.duplicate(),
                            initialDate: task.dueDate,
                          ),
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
                        value: 'duplicate',
                        child: Row(
                          children: [
                            HugeIcon(icon: HugeIcons.strokeRoundedCopy01, size: 18),
                            SizedBox(width: 8),
                            Text('تکثیر تسک'),
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
              if (hasCapsules) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 24,
                  child: _AutoScrollCapsules(
                    children: [
                      _buildTimeCapsule(context, onCardColor),
                      if (task.hasTime && (task.reminderDateTime != null || task.priority != TaskPriority.medium || task.categories.isNotEmpty || task.goalIds.isNotEmpty))
                        const SizedBox(width: 6),
                      _buildReminderCapsule(context, onCardColor),
                      if (task.reminderDateTime != null && (task.priority != TaskPriority.medium || task.categories.isNotEmpty || task.goalIds.isNotEmpty))
                        const SizedBox(width: 6),
                      _buildPriorityCapsule(context, onCardColor),
                      if (task.priority != TaskPriority.medium && (task.categories.isNotEmpty || task.goalIds.isNotEmpty))
                        const SizedBox(width: 6),
                      if (task.categories.isNotEmpty)
                        _buildCategoryCapsules(onCardColor, ref),
                      if (task.categories.isNotEmpty && task.goalIds.isNotEmpty)
                        const SizedBox(width: 6),
                      if (task.goalIds.isNotEmpty)
                        _buildGoalCapsules(onCardColor, ref),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCapsule(BuildContext context, Color onCardColor) {
    if (!task.hasTime) return const SizedBox.shrink();

    // Use task.dueDate for the time, as it's modified in activeTasksProvider to the occurrence date
    final timeStr = StringUtils.toPersianDigit(intl.DateFormat('HH:mm').format(task.dueDate));
    
    // Safety check for 00:00 - if it's 00:00 and metadata says hasTime is true, 
    // it might be a parsing issue or default value. 
    // But if hasTime is false, this function wouldn't be called.
    
    String label = timeStr;
    if (task.endTime != null) {
      final endTimeStr = StringUtils.toPersianDigit(intl.DateFormat('HH:mm').format(task.endTime!));
      label = '$timeStr - $endTimeStr';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: onCardColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onCardColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 10, color: onCardColor),
          const SizedBox(width: 4),
          Text(
            label,
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

  Widget _buildReminderCapsule(BuildContext context, Color onCardColor) {
    if (task.reminderDateTime == null) return const SizedBox.shrink();

    final reminderStr = StringUtils.toPersianDigit(intl.DateFormat('HH:mm').format(task.reminderDateTime!));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(icon: HugeIcons.strokeRoundedNotification03, size: 10, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            reminderStr,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityCapsule(BuildContext context, Color onCardColor) {
    if (task.priority == TaskPriority.medium) return const SizedBox.shrink();

    String label;
    switch (task.priority) {
      case TaskPriority.high:
        label = 'فوری';
        break;
      case TaskPriority.medium:
        label = 'عادی';
        break;
      case TaskPriority.low:
        label = 'فرعی';
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

  Widget _buildCategoryCapsules(Color onCardColor, WidgetRef ref) {
    final categories = task.categories;
    
    final allCategories = ref.watch(categoryProvider).valueOrNull ?? defaultCategories;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: categories.asMap().entries.map((entry) {
        final index = entry.key;
        final catId = entry.value;
        final catData = getCategoryById(catId, allCategories);
        final isDeleted = catData.isDeleted;
        
        return Container(
          margin: EdgeInsetsDirectional.only(start: index == 0 ? 0 : 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isDeleted 
                ? Colors.grey.withValues(alpha: 0.1)
                : onCardColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDeleted 
                  ? Colors.grey.withValues(alpha: 0.3)
                  : onCardColor.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: isDeleted ? 0.5 : 1.0,
                child: LottieCategoryIcon(assetPath: catData.emoji, width: 14, height: 14, repeat: false),
              ),
              const SizedBox(width: 4),
              Text(
                catData.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDeleted ? Colors.grey : onCardColor,
                  decoration: isDeleted ? TextDecoration.lineThrough : null,
                  decorationColor: Colors.grey,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGoalCapsules(Color onCardColor, WidgetRef ref) {
    final goalIds = task.goalIds;
    final allGoals = ref.watch(goalsProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: goalIds.asMap().entries.map((entry) {
        final index = entry.key;
        final goalId = entry.value;
        final goalData = allGoals.firstWhere(
          (g) => g.id == goalId,
          orElse: () => Goal(id: goalId, title: 'نامشخص', emoji: '🎯', position: 0),
        );

        return InkWell(
          onTap: () {
            ref.context.push(
              SearchRouteBuilder.buildSearchUrl(
                goals: [goalId],
                specificDate: task.dueDate,
              ),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: EdgeInsetsDirectional.only(start: index == 0 ? 0 : 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: onCardColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: onCardColor.withValues(alpha: 0.1),
              ),
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
                    color: onCardColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _getStatusIconForCard(Task task, Color color, BuildContext context) {
    dynamic iconData;
    switch (task.status) {
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
      child: InkWell(
         hoverColor: Colors.transparent,
         splashColor: Colors.transparent,
         highlightColor: Colors.transparent,
         onLongPress: () {
            HapticFeedback.heavyImpact();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              builder: (context) => TaskStatusPickerSheet(
                task: task,
                recurringDate: task.dueDate,
              ),
            );
         },
         child: HugeIcon(icon: iconData, size: 24, color: color.withValues(alpha: 0.8)),
      ),
    );
  }

  void _showStatusPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => TaskStatusPickerSheet(
        task: task,
        recurringDate: task.dueDate,
      ),
    );
  }

  // Removed inline _buildStatusAction logic as it is now in TaskStatusPickerSheet
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
      physics: _shouldScroll ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.children,
      ),
    );
  }
}

