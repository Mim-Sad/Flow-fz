import 'package:flutter/material.dart';

class CategoryData {
  final String id;
  final String label;
  final String emoji;
  final Color color;

  const CategoryData({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'emoji': emoji,
      'color': color.toARGB32(),
    };
  }

  factory CategoryData.fromMap(Map<String, dynamic> map) {
    return CategoryData(
      id: map['id'],
      label: map['label'],
      emoji: map['emoji'],
      color: Color(map['color']),
    );
  }
}

const List<CategoryData> defaultCategories = [
  CategoryData(id: 'work', label: 'کار', emoji: '💼', color: Color(0xFF4CAF50)),
  CategoryData(id: 'personal', label: 'شخصی', emoji: '👤', color: Color(0xFF2196F3)),
  CategoryData(id: 'sport', label: 'ورزش', emoji: '🏋️', color: Color(0xFFFF9800)),
  CategoryData(id: 'study', label: 'مطالعه', emoji: '📚', color: Color(0xFF9C27B0)),
  CategoryData(id: 'shopping', label: 'خرید', emoji: '🛒', color: Color(0xFFE91E63)),
  CategoryData(id: 'health', label: 'سلامت', emoji: '🩺', color: Color(0xFF00BCD4)),
  CategoryData(id: 'finance', label: 'مالی', emoji: '💰', color: Color(0xFFFFC107)),
  CategoryData(id: 'travel', label: 'سفر', emoji: '✈️', color: Color(0xFF3F51B5)),
];

// Helper to get category by ID (will be replaced by provider logic later)
CategoryData getCategoryById(String id, [List<CategoryData>? categories]) {
  final list = categories ?? defaultCategories;
  return list.firstWhere(
    (c) => c.id == id || c.label == id,
    orElse: () => CategoryData(id: 'other', label: id, emoji: '🔖', color: Colors.grey),
  );
}
