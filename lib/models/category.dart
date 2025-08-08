class Category {
  final int? categoryId;
  final String name;
  final String icon;
  final String color;
  final String? description;
  final bool isDefault;
  final int? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  Category({
    this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    this.description,
    this.isDefault = false,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'category_id': categoryId,
      'name': name,
      'icon': icon,
      'color': color,
      'description': description,
      'is_default': isDefault ? 1 : 0,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      categoryId: map['category_id'],
      name: map['name'],
      icon: map['icon'],
      color: map['color'],
      description: map['description'],
      isDefault: map['is_default'] == 1,
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      isActive: map['is_active'] == 1,
    );
  }
}
