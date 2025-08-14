class CustomList {
  CustomList({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.movieIds,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
    this.color = 'blue',
  });

  factory CustomList.fromJson(Map<String, dynamic> json) {
    return CustomList(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      emoji: json['emoji'] ?? '📝',
      movieIds: json['movieIds'] != null 
          ? List<int>.from(json['movieIds'])
          : <int>[],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isDefault: json['isDefault'] ?? false,
      color: json['color'] ?? 'blue',
    );
  }

  final int id;
  final String name;
  final String description;
  final String emoji;
  final List<int> movieIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDefault;
  final String color;

  CustomList copyWith({
    int? id,
    String? name,
    String? description,
    String? emoji,
    List<int>? movieIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
    String? color,
  }) {
    return CustomList(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      movieIds: movieIds ?? this.movieIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDefault: isDefault ?? this.isDefault,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'emoji': emoji,
      'movieIds': movieIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDefault': isDefault,
      'color': color,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomList && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CustomList(id: $id, name: $name, movieCount: ${movieIds.length})';
  }
}

class ListCategory {
  ListCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
    required this.lists,
  });

  factory ListCategory.fromJson(Map<String, dynamic> json) {
    return ListCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      emoji: json['emoji'] ?? '📂',
      color: json['color'] ?? 'blue',
      lists: json['lists'] != null
          ? (json['lists'] as List<dynamic>)
              .map((listJson) => CustomList.fromJson(listJson))
              .toList()
          : <CustomList>[],
    );
  }

  final String id;
  final String name;
  final String description;
  final String emoji;
  final String color;
  final List<CustomList> lists;

  ListCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? emoji,
    String? color,
    List<CustomList>? lists,
  }) {
    return ListCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      lists: lists ?? this.lists,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'emoji': emoji,
      'color': color,
      'lists': lists.map((list) => list.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ListCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ListCategory(id: $id, name: $name, listsCount: ${lists.length})';
  }
}