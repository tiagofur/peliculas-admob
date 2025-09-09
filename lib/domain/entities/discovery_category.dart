import 'package:flutter/material.dart';

class DiscoveryCategory {
  const DiscoveryCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
    required this.associatedGenres,
    required this.filters,
    this.mood,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final String emoji;
  final Color color;
  final List<String> associatedGenres;
  final Map<String, dynamic> filters;
  final String? mood;
  final IconData icon;

  DiscoveryCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? emoji,
    Color? color,
    List<String>? associatedGenres,
    Map<String, dynamic>? filters,
    String? mood,
    IconData? icon,
  }) {
    return DiscoveryCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      associatedGenres: associatedGenres ?? this.associatedGenres,
      filters: filters ?? this.filters,
      mood: mood ?? this.mood,
      icon: icon ?? this.icon,
    );
  }
}

class DiscoverySection {
  const DiscoverySection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.categories,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<DiscoveryCategory> categories;
  final IconData icon;
  final Color color;
}

class MovieCollection {
  const MovieCollection({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
    required this.movieIds,
    required this.createdAt,
    required this.updatedAt,
    this.isCustom = false,
    this.userId,
  });

  factory MovieCollection.fromJson(Map<String, dynamic> json) {
    return MovieCollection(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      emoji: json['emoji'] ?? '🎬',
      color: json['color'] != null ? Color(json['color']) : Colors.blue,
      movieIds: json['movieIds'] != null
          ? List<String>.from(json['movieIds'])
          : <String>[],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isCustom: json['isCustom'] ?? false,
      userId: json['userId'],
    );
  }

  final String id;
  final String name;
  final String description;
  final String emoji;
  final Color color;
  final List<String> movieIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isCustom;
  final String? userId;

  MovieCollection copyWith({
    String? id,
    String? name,
    String? description,
    String? emoji,
    Color? color,
    List<String>? movieIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCustom,
    String? userId,
  }) {
    return MovieCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      movieIds: movieIds ?? this.movieIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCustom: isCustom ?? this.isCustom,
      userId: userId ?? this.userId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'emoji': emoji,
      'color': color.toARGB32(),
      'movieIds': movieIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isCustom': isCustom,
      'userId': userId,
    };
  }
}
