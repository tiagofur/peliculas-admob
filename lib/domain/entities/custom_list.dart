import 'package:flutter/foundation.dart';

class CustomList {
  CustomList({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.movieIds,
    required this.createdAt,
    required this.lastModifiedAt,
    this.userId,
    this.isDefault = false,
    this.isPublic = false,
    this.color = 'blue',
    this.isDeleted = false,
    this.syncStatus = 'synced',
  });

  factory CustomList.fromJson(Map<String, dynamic> json) {
    return CustomList(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      emoji: json['emoji'] ?? '📝',
      movieIds: json['movieIds'] != null 
          ? List<int>.from(json['movieIds'])
          : <int>[],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastModifiedAt: json['lastModifiedAt'] != null 
          ? DateTime.parse(json['lastModifiedAt'])
          : DateTime.now(),
      userId: json['userId'],
      isDefault: json['isDefault'] ?? false,
      isPublic: json['isPublic'] ?? false,
      color: json['color'] ?? 'blue',
      isDeleted: json['isDeleted'] ?? false,
      syncStatus: json['syncStatus'] ?? 'synced',
    );
  }

  final String id;
  final String name;
  final String description;
  final String emoji;
  final List<int> movieIds;
  final DateTime createdAt;
  final DateTime lastModifiedAt;
  final String? userId;
  final bool isDefault;
  final bool isPublic;
  final String color;
  final bool isDeleted;
  final String syncStatus;

  CustomList copyWith({
    String? id,
    String? name,
    String? description,
    String? emoji,
    List<int>? movieIds,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? userId,
    bool? isDefault,
    bool? isPublic,
    String? color,
    bool? isDeleted,
    String? syncStatus,
  }) {
    return CustomList(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      movieIds: movieIds ?? this.movieIds,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      userId: userId ?? this.userId,
      isDefault: isDefault ?? this.isDefault,
      isPublic: isPublic ?? this.isPublic,
      color: color ?? this.color,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
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
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
      'userId': userId,
      'isDefault': isDefault,
      'isPublic': isPublic,
      'color': color,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomList &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.emoji == emoji &&
        listEquals(other.movieIds, movieIds) && // Use listEquals for List comparison
        other.createdAt == createdAt &&
        other.lastModifiedAt == lastModifiedAt &&
        other.userId == userId &&
        other.isDefault == isDefault &&
        other.isPublic == isPublic &&
        other.color == color &&
        other.isDeleted == isDeleted &&
        other.syncStatus == syncStatus;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        emoji,
        Object.hashAll(movieIds),
        createdAt,
        lastModifiedAt,
        userId,
        isDefault,
        isPublic,
        color,
        isDeleted,
        syncStatus,
      );

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