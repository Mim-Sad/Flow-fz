import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../models/activity.dart';
import '../../providers/mood_provider.dart';
import '../../utils/emoji_suggester.dart';
import '../widgets/flow_toast.dart';

class MoodSettingsScreen extends ConsumerWidget {
  const MoodSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityState = ref.watch(activityProvider);
    final theme = Theme.of(context);
    final navigationBarColor = theme.brightness == Brightness.light
        ? ElevationOverlay.applySurfaceTint(
            theme.colorScheme.surface,
            theme.colorScheme.surfaceTint,
            3,
          )
        : ElevationOverlay.applySurfaceTint(
            theme.colorScheme.surface,
            theme.colorScheme.surfaceTint,
            3,
          );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        backgroundColor: navigationBarColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'مدیریت حالات و فعالیت‌ها',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              color: theme.colorScheme.primary,
            ),
            onPressed: () => _showCategoryDialog(context, ref),
          ),
        ],
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
                          onEditCategory: () => _showCategoryDialog(context, ref, category),
                          onAddActivity: () => _showActivityDialog(context, ref, category.id!),
                          onEditActivity: (activity) => _showActivityDialog(context, ref, category.id!, activity),
                        );
                      },
                      childCount: activityState.categories.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
    );
  }

  void _showCategoryDialog(BuildContext context, WidgetRef ref, [ActivityCategory? category]) {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final emojiController = TextEditingController(text: category?.iconName ?? '🗄️');
    String selectedEmoji = category?.iconName ?? '🗄️';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedArchive02,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              isEditing ? 'ویرایش دسته‌بندی' : 'دسته‌بندی جدید',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedCancel01,
                                size: 22,
                                color: Colors.grey,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: TextField(
                                controller: emojiController,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 26),
                                decoration: const InputDecoration(
                                  hintText: '🗄️',
                                  hintStyle: TextStyle(fontSize: 26),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  setModalState(() {
                                    if (value.characters.isNotEmpty) {
                                      selectedEmoji = value.characters.last;
                                      emojiController.text = selectedEmoji;
                                      emojiController.selection = TextSelection.fromPosition(
                                        TextPosition(offset: emojiController.text.length),
                                      );
                                    } else {
                                      selectedEmoji = '🗄️';
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextField(
                                controller: nameController,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                onChanged: (value) {
                                  final suggested = EmojiSuggester.suggestEmoji(value);
                                  if (suggested != null) {
                                    setModalState(() {
                                      selectedEmoji = suggested;
                                      emojiController.text = suggested;
                                    });
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'نام دسته‌بندی',
                                  hintStyle: const TextStyle(fontSize: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: () {
                              if (nameController.text.trim().isNotEmpty) {
                                final emoji = selectedEmoji.isEmpty ? '🗄️' : selectedEmoji;
                                if (isEditing) {
                                  ref.read(activityProvider.notifier).updateCategory(
                                    category.copyWith(
                                      name: nameController.text.trim(),
                                      iconName: emoji,
                                    ),
                                  );
                                } else {
                                  ref.read(activityProvider.notifier).addCategory(
                                    nameController.text.trim(),
                                    iconName: emoji,
                                  );
                                }
                                Navigator.pop(context);
                                FlowToast.show(
                                  context,
                                  message: isEditing ? 'تغییرات ذخیره شد' : 'دسته‌بندی اضافه شد',
                                );
                              }
                            },
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            child: Text(isEditing ? 'ذخیره تغییرات' : 'افزودن دسته‌بندی'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showActivityDialog(BuildContext context, WidgetRef ref, int categoryId, [Activity? activity]) {
    final isEditing = activity != null;
    final nameController = TextEditingController(text: activity?.name ?? '');
    final emojiController = TextEditingController(text: activity?.iconName ?? '✨');
    String selectedEmoji = activity?.iconName ?? '✨';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedStar,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              isEditing ? 'ویرایش فعالیت' : 'فعالیت جدید',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedCancel01,
                                size: 22,
                                color: Colors.grey,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: TextField(
                                controller: emojiController,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 26),
                                decoration: const InputDecoration(
                                  hintText: '✨',
                                  hintStyle: TextStyle(fontSize: 26),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  setModalState(() {
                                    if (value.characters.isNotEmpty) {
                                      selectedEmoji = value.characters.last;
                                      emojiController.text = selectedEmoji;
                                      emojiController.selection = TextSelection.fromPosition(
                                        TextPosition(offset: emojiController.text.length),
                                      );
                                    } else {
                                      selectedEmoji = '✨';
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextField(
                                controller: nameController,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                onChanged: (value) {
                                  final suggested = EmojiSuggester.suggestEmoji(value);
                                  if (suggested != null) {
                                    setModalState(() {
                                      selectedEmoji = suggested;
                                      emojiController.text = suggested;
                                    });
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'نام فعالیت (مثلاً: مطالعه)',
                                  hintStyle: const TextStyle(fontSize: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: () {
                              if (nameController.text.trim().isNotEmpty) {
                                final emoji = selectedEmoji.isEmpty ? '✨' : selectedEmoji;
                                if (isEditing) {
                                  ref.read(activityProvider.notifier).updateActivity(
                                    activity.copyWith(
                                      name: nameController.text.trim(),
                                      iconName: emoji,
                                    ),
                                  );
                                } else {
                                  ref.read(activityProvider.notifier).addActivity(
                                    nameController.text.trim(),
                                    categoryId,
                                    emoji,
                                  );
                                }
                                Navigator.pop(context);
                                FlowToast.show(
                                  context,
                                  message: isEditing ? 'تغییرات ذخیره شد' : 'فعالیت اضافه شد',
                                );
                              }
                            },
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            child: Text(isEditing ? 'ذخیره تغییرات' : 'افزودن فعالیت'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryExpandableTile extends ConsumerWidget {
  final ActivityCategory category;
  final List<Activity> activities;
  final VoidCallback onEditCategory;
  final VoidCallback onAddActivity;
  final Function(Activity) onEditActivity;

  const _CategoryExpandableTile({
    required this.category,
    required this.activities,
    required this.onEditCategory,
    required this.onAddActivity,
    required this.onEditActivity,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          title: Text(
            category.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            '${activities.length} فعالیت',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
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
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedEdit02,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: onEditCategory,
              ),
              IconButton(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedDelete02,
                  size: 20,
                  color: Colors.redAccent,
                ),
                onPressed: () => _showDeleteCategoryDialog(context, ref),
              ),
              const Icon(Icons.expand_more, size: 20),
            ],
          ),
          children: [
            if (activities.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: activities.map((activity) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        leading: _buildIconOrEmoji(
                          _getIconData(activity.iconName),
                          size: 18,
                        ),
                        title: Text(
                          activity.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const HugeIcon(icon: HugeIcons.strokeRoundedEdit02, size: 16, color: Colors.grey),
                              onPressed: () => onEditActivity(activity),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                            ),
                            IconButton(
                              icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete02, size: 16, color: Colors.grey),
                              onPressed: () {
                                ref.read(activityProvider.notifier).deleteActivity(activity.id!);
                                FlowToast.show(context, message: 'فعالیت حذف شد');
                              },
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: InkWell(
                onTap: onAddActivity,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedAdd01,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'افزودن فعالیت جدید',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteCategoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف دسته‌بندی؟', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('با حذف این دسته‌بندی، تمام فعالیت‌های زیرمجموعه آن نیز حذف خواهند شد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('لغو', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () {
              ref.read(activityProvider.notifier).deleteCategory(category.id!);
              Navigator.pop(context);
              FlowToast.show(context, message: 'دسته‌بندی حذف شد');
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  dynamic _getIconData(String name) {
    if (name.characters.length <= 2) return name;
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
