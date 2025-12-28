import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_data.dart';
import '../services/database_service.dart';

class CategoryNotifier extends AsyncNotifier<List<CategoryData>> {
  @override
  Future<List<CategoryData>> build() async {
    return await _loadCategories();
  }

  Future<List<CategoryData>> _loadCategories() async {
    // Load all categories including deleted ones for task display
    final categories = await DatabaseService().getAllCategories(includeDeleted: true);
    if (categories.isEmpty) {
      // If DB is empty, it might be first run or cleared. 
      // The DatabaseService._createCategoriesTable handles defaults on creation.
      // But if we are here and it's empty, maybe we should re-insert defaults?
      // For now, assume DB service handles defaults on create/upgrade.
      // If it returns empty, it means no categories.
      // But we know we inserted defaults in DB service.
      return [];
    }
    return categories;
  }
  
  // Get only active (non-deleted) categories for the categories screen
  List<CategoryData> getActiveCategories() {
    return state.valueOrNull?.where((c) => !c.isDeleted).toList() ?? [];
  }

  Future<void> addCategory(CategoryData category) async {
    try {
      await DatabaseService().insertCategory(category);
      state = AsyncValue.data(await _loadCategories());
    } catch (e) {
      // Re-throw to let UI handle the error
      rethrow;
    }
  }

  Future<void> updateCategory(CategoryData category) async {
    await DatabaseService().updateCategory(category);
    state = AsyncValue.data(await _loadCategories());
  }

  Future<void> reorderCategories(List<CategoryData> reorderedCategories) async {
    // Update positions
    final updatedCategories = <CategoryData>[];
    for (int i = 0; i < reorderedCategories.length; i++) {
      updatedCategories.add(reorderedCategories[i].copyWith(position: i));
    }
    
    // Optimistic update
    state = AsyncValue.data(updatedCategories);
    
    // Persist
    for (var cat in updatedCategories) {
      await DatabaseService().updateCategory(cat);
    }
  }

  Future<void> deleteCategory(String id) async {
    await DatabaseService().deleteCategory(id);
    state = AsyncValue.data(await _loadCategories());
  }
}

final categoryProvider = AsyncNotifierProvider<CategoryNotifier, List<CategoryData>>(() {
  return CategoryNotifier();
});
