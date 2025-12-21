import 'package:flutter/material.dart';

class CategoryData {
  final String id;
  final String label;
  final String emoji;
  final Color color;
  final int position;

  const CategoryData({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
    this.position = 0,
  });

  CategoryData copyWith({
    String? id,
    String? label,
    String? emoji,
    Color? color,
    int? position,
  }) {
    return CategoryData(
      id: id ?? this.id,
      label: label ?? this.label,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'emoji': emoji,
      'color': color.toARGB32(),
      'position': position,
    };
  }

  factory CategoryData.fromMap(Map<String, dynamic> map) {
    return CategoryData(
      id: map['id'],
      label: map['label'],
      emoji: map['emoji'],
      color: Color(map['color']),
      position: map['position'] ?? 0,
    );
  }
}

const List<CategoryData> defaultCategories = [
  CategoryData(id: 'work', label: 'کار', emoji: '💼', color: Color(0xFF4CAF50), position: 0),
  CategoryData(id: 'personal', label: 'شخصی', emoji: '👤', color: Color(0xFF2196F3), position: 1),
  CategoryData(id: 'sport', label: 'ورزش', emoji: '🏋️', color: Color(0xFFFF9800), position: 2),
  CategoryData(id: 'study', label: 'مطالعه', emoji: '📚', color: Color(0xFF9C27B0), position: 3),
  CategoryData(id: 'shopping', label: 'خرید', emoji: '🛒', color: Color(0xFFE91E63), position: 4),
  CategoryData(id: 'health', label: 'سلامت', emoji: '🩺', color: Color(0xFF00BCD4), position: 5),
  CategoryData(id: 'finance', label: 'مالی', emoji: '💰', color: Color(0xFFFFC107), position: 6),
  CategoryData(id: 'travel', label: 'سفر', emoji: '✈️', color: Color(0xFF3F51B5), position: 7),
];

// Helper to get category by ID (will be replaced by provider logic later)
CategoryData getCategoryById(String id, [List<CategoryData>? categories]) {
  final list = categories ?? defaultCategories;
  return list.firstWhere(
    (c) => c.id == id || c.label == id,
    orElse: () => CategoryData(id: 'other', label: id, emoji: '🔖', color: Colors.grey),
  );
}
