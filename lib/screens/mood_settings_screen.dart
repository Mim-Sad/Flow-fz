import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../models/activity.dart';
import '../../providers/mood_provider.dart';
import '../widgets/flow_toast.dart';

class MoodSettingsScreen extends ConsumerWidget {
  const MoodSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityState = ref.watch(activityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت حالات و فعالیت‌ها'),
        centerTitle: true,
      ),
      body: activityState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final category = activityState.categories[index];
                        final categoryActivities = activityState.activities
                            .where((a) => a.categoryId == category.id)
                            .toList();

                        return _CategoryExpandableTile(
                          category: category,
                          activities: categoryActivities,
                        );
                      },
                      childCount: activityState.categories.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context, ref),
        label: const Text('دسته‌بندی جدید'),
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 20, color: Colors.white),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دسته‌بندی جدید'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'نام دسته‌بندی (مثلاً: ورزش، تغذیه)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(activityProvider.notifier).addCategory(controller.text);
                Navigator.pop(context);
                FlowToast.show(context, message: 'دسته‌بندی با موفقیت اضافه شد');
              }
            },
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
  }
}

class _CategoryExpandableTile extends ConsumerWidget {
  final ActivityCategory category;
  final List<Activity> activities;

  const _CategoryExpandableTile({
    required this.category,
    required this.activities,
  });

  Widget _buildIconOrEmoji(dynamic iconData, {required double size, Color? color}) {
    if (iconData is String) {
      return Text(iconData, style: TextStyle(fontSize: size));
    }
    return HugeIcon(icon: iconData, size: size, color: color);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Text(
          category.name,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${activities.length} فعالیت',
          style: theme.textTheme.bodySmall,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: _buildIconOrEmoji(
            _getIconData(category.iconName),
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedEdit02, size: 18, color: Colors.grey),
              onPressed: () => _showEditCategoryDialog(context, ref),
            ),
            IconButton(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete02, size: 18, color: Colors.red),
              onPressed: () => _showDeleteCategoryDialog(context, ref),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...activities.map((activity) => ListTile(
                      title: Text(activity.name),
                      leading: _buildIconOrEmoji(
                        _getIconData(activity.iconName),
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                      trailing: IconButton(
                        icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete02, size: 16, color: Colors.grey),
                        onPressed: () {
                          ref.read(activityProvider.notifier).deleteActivity(activity.id!);
                          FlowToast.show(context, message: 'فعالیت حذف شد');
                        },
                      ),
                    )),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add, color: Colors.blue),
                  title: const Text('افزودن فعالیت جدید', style: TextStyle(color: Colors.blue)),
                  onTap: () => _showAddActivityDialog(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ویرایش دسته‌بندی'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(activityProvider.notifier).updateCategory(category.copyWith(name: controller.text));
                Navigator.pop(context);
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCategoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف دسته‌بندی؟'),
        content: const Text('با حذف این دسته‌بندی، تمام فعالیت‌های زیرمجموعه آن نیز حذف خواهند شد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
          TextButton(
            onPressed: () {
              ref.read(activityProvider.notifier).deleteCategory(category.id!);
              Navigator.pop(context);
              FlowToast.show(context, message: 'دسته‌بندی حذف شد');
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddActivityDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فعالیت جدید'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'نام فعالیت (مثلاً: مطالعه، پیاده‌روی)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(activityProvider.notifier).addActivity(
                      controller.text,
                      category.id!,
                      'strokeRoundedStar', // Default icon
                    );
                Navigator.pop(context);
                FlowToast.show(context, message: 'فعالیت با موفقیت اضافه شد');
              }
            },
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
  }

  dynamic _getIconData(String name) {
    if (name.length <= 2) return name;
    switch (name) {
      case 'strokeRoundedFavourite':
        return HugeIcons.strokeRoundedFavourite;
      case 'strokeRoundedGameController02':
        return HugeIcons.strokeRoundedGameController02;
      case 'strokeRoundedSleep':
        return HugeIcons.strokeRoundedTick02;
      case 'strokeRoundedHealth':
        return HugeIcons.strokeRoundedHealth;
      case 'strokeRoundedHappy':
        return HugeIcons.strokeRoundedSent;
      case 'strokeRoundedEnergy':
        return HugeIcons.strokeRoundedFlash;
      case 'strokeRoundedGiveLove':
        return HugeIcons.strokeRoundedFavourite;
      case 'strokeRoundedMoon02':
        return HugeIcons.strokeRoundedMoon02;
      case 'strokeRoundedBored':
        return HugeIcons.strokeRoundedNote01;
      case 'strokeRoundedBubbleChatDelay':
        return HugeIcons.strokeRoundedBubbleChatDelay;
      case 'strokeRoundedAngry':
        return HugeIcons.strokeRoundedAlertCircle;
      case 'strokeRoundedSad01':
        return HugeIcons.strokeRoundedSent;
      case 'strokeRoundedGameController03':
        return HugeIcons.strokeRoundedGameController03;
      case 'strokeRoundedClapperboard':
        return HugeIcons.strokeRoundedPlay;
      case 'strokeRoundedBookOpen01':
        return HugeIcons.strokeRoundedBookOpen01;
      case 'strokeRoundedAirplane01':
        return HugeIcons.strokeRoundedAirplane01;
      case 'strokeRoundedMusicNote01':
        return HugeIcons.strokeRoundedMusicNote01;
      case 'strokeRoundedCheers':
        return HugeIcons.strokeRoundedStar;
      case 'strokeRoundedAlert02':
        return HugeIcons.strokeRoundedAlert02;
      case 'strokeRoundedRunning':
        return HugeIcons.strokeRoundedStar;
      case 'strokeRoundedOrganicFood':
        return HugeIcons.strokeRoundedApple;
      case 'strokeRoundedWaterDrop':
        return HugeIcons.strokeRoundedDroplet;
      case 'strokeRoundedWalking':
        return HugeIcons.strokeRoundedUser;
      default:
        return HugeIcons.strokeRoundedStar;
    }
  }
}
