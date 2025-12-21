import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/category_data.dart';
import '../providers/category_provider.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  void _showCategoryDialog([CategoryData? category]) {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.label ?? '');
    final emojiController = TextEditingController(text: category?.emoji ?? '');
    Color selectedColor = category?.color ?? Colors.blue;
    
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
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'نام دسته',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emojiController,
                    decoration: const InputDecoration(
                      labelText: 'ایموجی',
                      border: OutlineInputBorder(),
                      helperText: 'یک ایموجی وارد کنید',
                    ),
                    maxLength: 2,
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
                              ? const Icon(Icons.check, size: 20, color: Colors.white)
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
                  if (nameController.text.isNotEmpty && emojiController.text.isNotEmpty) {
                    final newCategory = CategoryData(
                      id: isEditing ? category.id : const Uuid().v4(),
                      label: nameController.text,
                      emoji: emojiController.text,
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
                child: Text(isEditing ? 'ذخیره' : 'افزودن'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت دسته‌بندی‌ها'),
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
                    child: Text(category.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                  title: Text(
                    category.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () => _showCategoryDialog(category),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: Theme.of(context).colorScheme.error,
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
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
