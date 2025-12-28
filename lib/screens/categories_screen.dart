import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:uuid/uuid.dart';
import '../models/category_data.dart';
import '../providers/category_provider.dart';
import '../constants/duck_emojis.dart';
import '../widgets/lottie_category_icon.dart';

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
    
    final List<Color> colors = [
      Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
      Colors.yellow, Colors.orange, Colors.deepOrange,
      Colors.brown, Colors.grey, Colors.blueGrey,
    ];

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
                  // Pull handle
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
                  
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
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
                                style: const ButtonStyle(
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Name Input
                          TextField(
                            controller: nameController,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                          const SizedBox(height: 24),

                          // Icon Section
                          Text(
                            'انتخاب آیکون',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white,
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 0.8, 1.0],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn,
                            child: SizedBox(
                              height: 180,
                              child: GridView.builder(
                                padding: const EdgeInsets.only(bottom: 20),
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
                                      setModalState(() => selectedEmoji = emojiPath);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? selectedColor.withValues(alpha: 0.1)
                                            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? selectedColor : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      child: LottieCategoryIcon(
                                        assetPath: emojiPath,
                                        fit: BoxFit.contain,
                                        repeat: false,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Color Section
                          Text(
                            'انتخاب رنگ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.spaceBetween,
                              children: colors.map((color) {
                                final isSelected = selectedColor == color;
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() => selectedColor = color);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                                        width: 2.5,
                                      ),
                                      boxShadow: isSelected ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        )
                                      ] : null,
                                    ),
                                    child: isSelected 
                                        ? const Icon(Icons.check, color: Colors.white, size: 22)
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Action Button
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (nameController.text.isNotEmpty) {
                            try {
                              final newCategory = CategoryData(
                                id: isEditing ? category.id : const Uuid().v4(),
                                label: nameController.text.trim(),
                                emoji: selectedEmoji,
                                color: selectedColor,
                              );
                              
                              if (isEditing) {
                                await ref.read(categoryProvider.notifier).updateCategory(newCategory);
                              } else {
                                await ref.read(categoryProvider.notifier).addCategory(newCategory);
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                final errorMessage = e.toString().contains('دسته‌بندی با این نام')
                                    ? 'دسته‌بندی با این نام از قبل وجود دارد'
                                    : 'خطا: ${e.toString()}';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMessage),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        icon: HugeIcon(
                          icon: isEditing ? HugeIcons.strokeRoundedCheckmarkSquare04 : HugeIcons.strokeRoundedAddSquare, 
                          size: 20, 
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        label: Text(
                          isEditing ? 'ذخیره تغییرات' : 'ثبت دسته‌بندی جدید',
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: Theme.of(context).colorScheme.onPrimary
                          ),
                        ),
                      ),
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
          // Filter out deleted categories for display in categories screen
          final activeCategories = categories.where((c) => !c.isDeleted).toList();
          if (activeCategories.isEmpty) {
            return const Center(child: Text('هیچ دسته‌بندی وجود ندارد'));
          }
          // Sort explicitly just in case, though provider returns sorted list from DB
          final sortedCategories = List<CategoryData>.from(activeCategories)
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
                  color: Theme.of(context).colorScheme.surfaceContainer,
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
                    child: LottieCategoryIcon(
                      assetPath: category.emoji,
                      width: 32,
                      height: 32,
                      repeat: false,
                    ),
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
