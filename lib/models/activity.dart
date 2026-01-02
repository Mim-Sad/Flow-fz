
class ActivityCategory {
  final int? id;
  final String name;
  final String iconName; // Using HugeIcons names or custom logic
  final int sortOrder;
  final bool isSystem; // To prevent deleting default categories if needed

  ActivityCategory({
    this.id,
    required this.name,
    required this.iconName,
    this.sortOrder = 0,
    this.isSystem = false,
  });

  ActivityCategory copyWith({
    int? id,
    String? name,
    String? iconName,
    int? sortOrder,
    bool? isSystem,
  }) {
    return ActivityCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      sortOrder: sortOrder ?? this.sortOrder,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'sortOrder': sortOrder,
      'isSystem': isSystem ? 1 : 0,
    };
  }

  factory ActivityCategory.fromMap(Map<String, dynamic> map) {
    return ActivityCategory(
      id: map['id'],
      name: map['name'],
      iconName: map['iconName'],
      sortOrder: map['sortOrder'] ?? 0,
      isSystem: (map['isSystem'] ?? 0) == 1,
    );
  }
}

class Activity {
  final int? id;
  final String name;
  final String iconName;
  final int categoryId;
  final int sortOrder;
  final bool isSystem;

  Activity({
    this.id,
    required this.name,
    required this.iconName,
    required this.categoryId,
    this.sortOrder = 0,
    this.isSystem = false,
  });

  Activity copyWith({
    int? id,
    String? name,
    String? iconName,
    int? categoryId,
    int? sortOrder,
    bool? isSystem,
  }) {
    return Activity(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      categoryId: categoryId ?? this.categoryId,
      sortOrder: sortOrder ?? this.sortOrder,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'categoryId': categoryId,
      'sortOrder': sortOrder,
      'isSystem': isSystem ? 1 : 0,
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'],
      name: map['name'],
      iconName: map['iconName'],
      categoryId: map['categoryId'],
      sortOrder: map['sortOrder'] ?? 0,
      isSystem: (map['isSystem'] ?? 0) == 1,
    );
  }
}
