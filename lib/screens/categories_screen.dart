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
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: category.color.withValues(alpha: 0.2),
                    child: Text(category.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  title: Text(category.label),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showCategoryDialog(category),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
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
