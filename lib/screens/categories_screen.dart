import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:uuid/uuid.dart';
import '../models/category_data.dart';
import '../providers/category_provider.dart';
import '../constants/duck_emojis.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  void _showCategoryDialog([CategoryData? category]) {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.label ?? '');
    String selectedEmoji = category?.emoji ?? DuckEmojis.all.first;
    Color selectedColor = category?.color ?? Theme.of(context).colorScheme.primary;
    
    // Simple color palette
    final List<Color> colors = [
      Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
      Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
      Colors.brown, Colors.grey, Colors.blueGrey, Colors.black,
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEditing ? 'ویرایش دسته‌بندی' : 'افزودن دسته‌بندی'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'نام دسته',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('آیکون', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    width: double.maxFinite,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: DuckEmojis.all.length,
                      itemBuilder: (context, index) {
                        final emojiPath = DuckEmojis.all[index];
                        final isSelected = selectedEmoji == emojiPath;
                        return GestureDetector(
                          onTap: () {
                            setState(() => selectedEmoji = emojiPath);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                            ),
                            child: Lottie.asset(emojiPath, fit: BoxFit.contain),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('رنگ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colors.map((color) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selectedColor == color
                                ? Border.all(color: Colors.black, width: 2)
                                : null,
                          ),
                          child: selectedColor == color
                              ? const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle03, size: 20, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    final newCategory = CategoryData(
                      id: isEditing ? category.id : const Uuid().v4(),
                      label: nameController.text,
                      emoji: selectedEmoji,
                      color: selectedColor,
                    );
                    
                    if (isEditing) {
                      ref.read(categoryProvider.notifier).updateCategory(newCategory);
                    } else {
                      ref.read(categoryProvider.notifier).addCategory(newCategory);
                    }
                    Navigator.pop(context);
                  }
                },
                child: Text(isEditing ? 'بروزرسانی' : 'افزودن'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryProvider);
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
          'مدیریت دسته‌بندی‌ها',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Theme.of(context).colorScheme.primary),
            onPressed: () => _showCategoryDialog(),
          ),
        ],
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('هیچ دسته‌بندی وجود ندارد'));
          }
          // Sort explicitly just in case, though provider returns sorted list from DB
          final sortedCategories = List<CategoryData>.from(categories)
            ..sort((a, b) => a.position.compareTo(b.position));

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedCategories.length,
            onReorder: (oldIndex, newIndex) {
               if (newIndex > oldIndex) newIndex -= 1;
               final items = List<CategoryData>.from(sortedCategories);
               final item = items.removeAt(oldIndex);
               items.insert(newIndex, item);
               ref.read(categoryProvider.notifier).reorderCategories(items);
            },
            itemBuilder: (context, index) {
              final category = sortedCategories[index];
              return Container(
                key: ValueKey(category.id),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: category.color.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Lottie.asset(category.emoji, width: 32, height: 32),
                  ),
                  title: Text(
                    category.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: HugeIcon(icon: HugeIcons.strokeRoundedEdit02, size: 20, color: Theme.of(context).colorScheme.primary),
                        onPressed: () => _showCategoryDialog(category),
                      ),
                      IconButton(
                        icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete02, size: 20, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('حذف دسته‌بندی'),
                              content: Text('آیا از حذف "${category.label}" مطمئن هستید؟'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('خیر'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () {
                                    ref.read(categoryProvider.notifier).deleteCategory(category.id);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('بله'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ReorderableDragStartListener(
                        index: index,
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedMove,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطا: $err')),
      ),
    );
  }
}
