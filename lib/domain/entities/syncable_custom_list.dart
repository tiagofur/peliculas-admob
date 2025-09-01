import '../../core/sync/conflict_resolution/soft_delete_manager.dart';
import 'custom_list.dart';

/// Versión sincronizable de CustomList que implementa SoftDeletable
/// para el sistema de resolución de conflictos multiplataforma
class SyncableCustomList implements SoftDeletable {
  const SyncableCustomList({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
    required this.movieIds,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  /// Crea desde CustomList
  factory SyncableCustomList.fromCustomList(
    CustomList customList, {
    bool isDeleted = false,
    DateTime? deletedAt,
  }) {
    return SyncableCustomList(
      id: customList.id,
      userId: customList.userId ?? '',
      name: customList.name,
      description: customList.description,
      emoji: customList.emoji,
      color: customList.color,
      movieIds: customList.movieIds,
      isPublic: customList.isPublic,
      createdAt: customList.createdAt,
      updatedAt: customList.updatedAt,
      isDeleted: isDeleted,
      deletedAt: deletedAt,
    );
  }

  /// Deserialización desde JSON
  factory SyncableCustomList.fromJson(Map<String, dynamic> json) {
    return SyncableCustomList(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '📝',
      color: json['color'] as String? ?? 'blue',
      movieIds: (json['movie_ids'] as List<dynamic>?)?.cast<int>() ?? [],
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }
  @override
  final String id;
  final String userId;
  final String name;
  final String description;
  final String emoji;
  final String color;
  final List<int> movieIds;
  final bool isPublic;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool isDeleted;
  final DateTime? deletedAt;

  /// Convierte a CustomList para uso en la aplicación
  CustomList toCustomList() {
    return CustomList(
      id: id,
      userId: userId.isEmpty ? null : userId,
      name: name,
      description: description,
      emoji: emoji,
      color: color,
      movieIds: movieIds,
      isPublic: isPublic,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Implementa SoftDeletable - crea copia marcada como eliminada
  @override
  SoftDeletable copyWithDeleted(bool isDeleted, DateTime updatedAt) {
    return copyWith(
      isDeleted: isDeleted,
      updatedAt: updatedAt,
    );
  }

  /// Crea una copia con campos modificados
  SyncableCustomList copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? emoji,
    String? color,
    List<int>? movieIds,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return SyncableCustomList(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      movieIds: movieIds ?? this.movieIds,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Serialización a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'emoji': emoji,
      'color': color,
      'movie_ids': movieIds,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SyncableCustomList) return false;

    return id == other.id &&
        userId == other.userId &&
        name == other.name &&
        description == other.description &&
        emoji == other.emoji &&
        color == other.color &&
        _listEquals(movieIds, other.movieIds) &&
        isPublic == other.isPublic &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        isDeleted == other.isDeleted &&
        deletedAt == other.deletedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      name,
      description,
      emoji,
      color,
      Object.hashAll(movieIds),
      isPublic,
      createdAt,
      updatedAt,
      isDeleted,
      deletedAt,
    );
  }

  @override
  String toString() {
    return 'SyncableCustomList('
        'id: $id, '
        'name: $name, '
        'movieCount: ${movieIds.length}, '
        'isPublic: $isPublic, '
        'isDeleted: $isDeleted, '
        'updatedAt: $updatedAt'
        ')';
  }

  /// Implementación de SoftDeletable
  @override
  String get entityId => id;

  @override
  DateTime get lastModified => updatedAt;

  /// Función auxiliar para comparar listas
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
