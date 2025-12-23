import 'package:flutter/material.dart';
import '../constants/duck_emojis.dart';

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
    String emoji = map['emoji'];
    // Migration for legacy emojis
    if (!emoji.startsWith('assets/')) {
       switch (emoji) {
         case '💼': emoji = DuckEmojis.work; break;
         case '👤': emoji = DuckEmojis.personal; break;
         case '🏋️': emoji = DuckEmojis.sport; break;
         case '📚': emoji = DuckEmojis.study; break;
         case '🛒': emoji = DuckEmojis.shopping; break;
         case '🩺': emoji = DuckEmojis.health; break;
         case '💰': emoji = DuckEmojis.finance; break;
         case '✈️': emoji = DuckEmojis.travel; break;
         default: emoji = DuckEmojis.other;
       }
    }

    return CategoryData(
      id: map['id'],
      label: map['label'],
      emoji: emoji,
      color: Color(map['color']),
      position: map['position'] ?? 0,
    );
  }
}

const List<CategoryData> defaultCategories = [
  CategoryData(id: 'work', label: 'کار', emoji: DuckEmojis.work, color: Color(0xFF4CAF50), position: 0),
  CategoryData(id: 'personal', label: 'شخصی', emoji: DuckEmojis.personal, color: Color(0xFF2196F3), position: 1),
  CategoryData(id: 'sport', label: 'ورزش', emoji: DuckEmojis.sport, color: Color(0xFFFF9800), position: 2),
  CategoryData(id: 'study', label: 'مطالعه', emoji: DuckEmojis.study, color: Color(0xFF9C27B0), position: 3),
  CategoryData(id: 'shopping', label: 'خرید', emoji: DuckEmojis.shopping, color: Color(0xFFE91E63), position: 4),
  CategoryData(id: 'health', label: 'سلامت', emoji: DuckEmojis.health, color: Color(0xFF00BCD4), position: 5),
  CategoryData(id: 'finance', label: 'مالی', emoji: DuckEmojis.finance, color: Color(0xFFFFC107), position: 6),
  CategoryData(id: 'travel', label: 'سفر', emoji: DuckEmojis.travel, color: Color(0xFF3F51B5), position: 7),
];

// Helper to get category by ID (will be replaced by provider logic later)
CategoryData getCategoryById(String id, [List<CategoryData>? categories]) {
  final list = categories ?? defaultCategories;
  return list.firstWhere(
    (c) => c.id == id || c.label == id,
    orElse: () {
      // Prevent showing long UUIDs as labels while categories are loading
      final fallbackLabel = id.length > 20 ? '...' : id;
      return CategoryData(id: 'other', label: fallbackLabel, emoji: DuckEmojis.other, color: Colors.grey);
    },
  );
}
