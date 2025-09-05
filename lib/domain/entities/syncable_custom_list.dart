import '../../core/sync/sync_utilities.dart';
import 'custom_list.dart';
import 'syncable_entity.dart';

/// Entidad de lista personalizada que implementa SyncableEntity
/// para el sistema de sincronización offline-first
class SyncableCustomList extends SyncableEntity {
  SyncableCustomList({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.lastModifiedAt,
    this.isDeleted = false,
    this.syncVersion = 0,
    this.deviceId,
    required this.name,
    this.description,
    this.emoji,
    this.movieIds = const [],
    this.isPublic = false,
    this.category,
    this.tags = const [],
    this.collaboratorIds = const [],
  });

  /// Factory constructor básico
  factory SyncableCustomList.create({
    required String userId,
    required String name,
    String? customId,
    String? description,
    String? emoji,
    List<int> movieIds = const [],
    bool isPublic = false,
    String? category,
    List<String> tags = const [],
    List<String> collaboratorIds = const [],
    String? deviceId,
  }) {
    final now = SyncUtilities.utcNow();
    return SyncableCustomList(
      id: customId ?? SyncUtilities.generateUuid(),
      userId: userId,
      name: name,
      description: description,
      emoji: emoji,
      movieIds: movieIds,
      isPublic: isPublic,
      category: category,
      tags: tags,
      collaboratorIds: collaboratorIds,
      createdAt: now,
      lastModifiedAt: now,
      deviceId: deviceId,
    );
  }

  /// Factory constructor desde CustomList existente
  factory SyncableCustomList.fromCustomList({
    required String userId,
    required CustomList customList,
    String? deviceId,
  }) {
    final now = SyncUtilities.utcNow();
    return SyncableCustomList(
      id: customList.id,
      userId: userId,
      name: customList.name,
      description: customList.description,
      emoji: customList.emoji,
      movieIds: customList.movieIds,
      createdAt: customList.createdAt,
      lastModifiedAt: customList.lastModifiedAt ?? now,
      isDeleted: customList.isDeleted ?? false,
      deviceId: deviceId,
    );
  }

  /// Factory constructor desde JSON
  factory SyncableCustomList.fromJson(Map<String, dynamic> json) {
    return SyncableCustomList(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      emoji: json['emoji'] as String?,
      movieIds: (json['movie_ids'] as List<dynamic>?)?.cast<int>() ?? [],
      isPublic: json['is_public'] as bool? ?? false,
      category: json['category'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      collaboratorIds:
          (json['collaborator_ids'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      lastModifiedAt: DateTime.parse(json['last_modified_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      syncVersion: json['sync_version'] as int? ?? 0,
      deviceId: json['device_id'] as String?,
    );
  }

  /// Factory constructor desde string JSON
  factory SyncableCustomList.fromJsonString(String jsonString) {
    final json = SyncUtilities.decodeJson(jsonString);
    return SyncableCustomList.fromJson(json);
  }

  // Implementación de getters de SyncableEntity
  @override
  final String id;

  @override
  final String userId;

  @override
  final DateTime createdAt;

  @override
  final DateTime lastModifiedAt;

  @override
  final bool isDeleted;

  @override
  final int syncVersion;

  @override
  final String? deviceId;

  /// Nombre de la lista
  final String name;

  /// Descripción de la lista
  final String? description;

  /// Emoji representativo de la lista
  final String? emoji;

  /// IDs de las películas en la lista
  final List<int> movieIds;

  /// Si la lista es pública o privada
  final bool isPublic;

  /// Categoría de la lista
  final String? category;

  /// Tags personalizados de la lista
  final List<String> tags;

  /// IDs de usuarios colaboradores
  final List<String> collaboratorIds;

  @override
  String get entityType => 'custom_list';

  @override
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'emoji': emoji,
      'movie_ids': movieIds,
      'is_public': isPublic,
      'category': category,
      'tags': tags,
      'collaborator_ids': collaboratorIds,
      'created_at': createdAt.toIso8601String(),
      'last_modified_at': lastModifiedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'sync_version': syncVersion,
      'device_id': deviceId,
    };
  }

  @override
  Map<String, dynamic> toLocalStorage() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'emoji': emoji,
      'movieIds': movieIds,
      'isPublic': isPublic,
      'category': category,
      'tags': tags,
      'collaboratorIds': collaboratorIds,
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
      'isDeleted': isDeleted,
      'syncVersion': syncVersion,
      'deviceId': deviceId,
    };
  }

  @override
  String generateChecksum() {
    final contentData = {
      'name': name,
      'description': description,
      'emoji': emoji,
      'movieIds': movieIds,
      'isPublic': isPublic,
      'category': category,
      'tags': tags,
      'collaboratorIds': collaboratorIds,
    };
    return SyncUtilities.generateChecksum(contentData);
  }

  @override
  bool hasSameContentAs(SyncableEntity other) {
    if (other is! SyncableCustomList) return false;
    return name == other.name &&
        description == other.description &&
        emoji == other.emoji &&
        _listEquals(movieIds, other.movieIds) &&
        isPublic == other.isPublic &&
        category == other.category &&
        _listEquals(tags, other.tags) &&
        _listEquals(collaboratorIds, other.collaboratorIds);
  }

  @override
  SyncableEntity mergeWith(SyncableEntity other) {
    if (other is! SyncableCustomList) {
      throw ArgumentError(
          'Cannot merge SyncableCustomList with ${other.runtimeType}');
    }

    // Usar la versión más reciente como base
    final newer = lastModifiedAt.isAfter(other.lastModifiedAt) ? this : other;
    final older = lastModifiedAt.isAfter(other.lastModifiedAt) ? other : this;

    return SyncableCustomList(
      id: id,
      userId: userId,
      name: newer.name,
      description: newer.description ?? older.description,
      emoji: newer.emoji ?? older.emoji,
      // Combinar movieIds únicos manteniendo el orden
      movieIds: _mergeMovieIds(older.movieIds, newer.movieIds),
      isPublic: newer.isPublic,
      category: newer.category ?? older.category,
      // Combinar tags únicos
      tags: {...older.tags, ...newer.tags}.toList(),
      // Combinar colaboradores únicos
      collaboratorIds:
          {...older.collaboratorIds, ...newer.collaboratorIds}.toList(),
      createdAt: createdAt,
      lastModifiedAt: SyncUtilities.utcNow(),
      isDeleted: newer.isDeleted,
      syncVersion: syncVersion + 1,
      deviceId: deviceId,
    );
  }

  @override
  List<String> getValidationErrors() {
    final errors = <String>[];

    if (name.trim().isEmpty) {
      errors.add('name cannot be empty');
    }

    if (name.length > 100) {
      errors.add('name cannot exceed 100 characters');
    }

    if (description != null && description!.length > 500) {
      errors.add('description cannot exceed 500 characters');
    }

    if (movieIds.any((id) => id <= 0)) {
      errors.add('movieIds must contain only positive values');
    }

    if (tags.any((tag) => tag.trim().isEmpty)) {
      errors.add('tags cannot contain empty strings');
    }

    if (collaboratorIds.any((id) => id.trim().isEmpty)) {
      errors.add('collaboratorIds cannot contain empty strings');
    }

    return errors;
  }

  @override
  int get syncPriority {
    // Prioridad basada en el número de películas y si es pública
    int basePriority = 5;

    // Listas públicas tienen mayor prioridad
    if (isPublic) basePriority += 2;

    // Listas con más películas tienen mayor prioridad
    if (movieIds.length > 10) basePriority += 1;
    if (movieIds.length > 50) basePriority += 1;

    // Listas con colaboradores tienen mayor prioridad
    if (collaboratorIds.isNotEmpty) basePriority += 1;

    return basePriority.clamp(1, 10);
  }

  /// Crea una copia con campos modificados (implementación de SyncableEntity)
  @override
  SyncableCustomList copyWith({
    DateTime? lastModifiedAt,
    int? syncVersion,
    String? deviceId,
    bool? isDeleted,
  }) {
    return SyncableCustomList(
      id: id,
      userId: userId,
      name: name,
      description: description,
      emoji: emoji,
      movieIds: movieIds,
      isPublic: isPublic,
      category: category,
      tags: tags,
      collaboratorIds: collaboratorIds,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  /// Método copyWith extendido para uso interno
  SyncableCustomList copyWithData({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? emoji,
    List<int>? movieIds,
    bool? isPublic,
    String? category,
    List<String>? tags,
    List<String>? collaboratorIds,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    bool? isDeleted,
    int? syncVersion,
    String? deviceId,
  }) {
    return SyncableCustomList(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      movieIds: movieIds ?? this.movieIds,
      isPublic: isPublic ?? this.isPublic,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      collaboratorIds: collaboratorIds ?? this.collaboratorIds,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  /// Convierte a CustomList para compatibilidad
  CustomList toCustomList() {
    return CustomList(
      id: id,
      name: name,
      description: description ?? '',
      emoji: emoji ?? '',
      movieIds: movieIds,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt,
      isDeleted: isDeleted,
    );
  }

  /// Agrega una película a la lista
  SyncableCustomList addMovie(int movieId) {
    if (movieIds.contains(movieId)) return this;

    return copyWithData(
      movieIds: [...movieIds, movieId],
      lastModifiedAt: SyncUtilities.utcNow(),
      syncVersion: syncVersion + 1,
    );
  }

  /// Remueve una película de la lista
  SyncableCustomList removeMovie(int movieId) {
    if (!movieIds.contains(movieId)) return this;

    return copyWithData(
      movieIds: movieIds.where((id) => id != movieId).toList(),
      lastModifiedAt: SyncUtilities.utcNow(),
      syncVersion: syncVersion + 1,
    );
  }

  /// Reordena las películas en la lista
  SyncableCustomList reorderMovies(List<int> newOrder) {
    // Validar que todos los IDs estén presentes
    if (newOrder.length != movieIds.length ||
        !newOrder.every((id) => movieIds.contains(id))) {
      throw ArgumentError('Invalid movie order');
    }

    return copyWithData(
      movieIds: newOrder,
      lastModifiedAt: SyncUtilities.utcNow(),
      syncVersion: syncVersion + 1,
    );
  }

  /// Agrega un colaborador a la lista
  SyncableCustomList addCollaborator(String userId) {
    if (collaboratorIds.contains(userId)) return this;

    return copyWithData(
      collaboratorIds: [...collaboratorIds, userId],
      lastModifiedAt: SyncUtilities.utcNow(),
      syncVersion: syncVersion + 1,
    );
  }

  /// Remueve un colaborador de la lista
  SyncableCustomList removeCollaborator(String userId) {
    if (!collaboratorIds.contains(userId)) return this;

    return copyWithData(
      collaboratorIds: collaboratorIds.where((id) => id != userId).toList(),
      lastModifiedAt: SyncUtilities.utcNow(),
      syncVersion: syncVersion + 1,
    );
  }

  /// Combina dos listas de movieIds manteniendo el orden y eliminando duplicados
  List<int> _mergeMovieIds(List<int> older, List<int> newer) {
    final result = <int>[];
    final seen = <int>{};

    // Primero agregar los de la lista más nueva
    for (final id in newer) {
      if (!seen.contains(id)) {
        result.add(id);
        seen.add(id);
      }
    }

    // Luego agregar los de la lista más antigua que no estén ya
    for (final id in older) {
      if (!seen.contains(id)) {
        result.add(id);
        seen.add(id);
      }
    }

    return result;
  }

  /// Utilidad para comparar listas
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncableCustomList &&
        other.id == id &&
        other.userId == userId &&
        other.name == name &&
        other.description == description &&
        other.emoji == emoji &&
        _listEquals(other.movieIds, movieIds) &&
        other.isPublic == isPublic &&
        other.category == category &&
        _listEquals(other.tags, tags) &&
        _listEquals(other.collaboratorIds, collaboratorIds) &&
        other.createdAt == createdAt &&
        other.lastModifiedAt == lastModifiedAt &&
        other.isDeleted == isDeleted &&
        other.syncVersion == syncVersion &&
        other.deviceId == deviceId;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      name,
      description,
      emoji,
      Object.hashAll(movieIds),
      isPublic,
      category,
      Object.hashAll(tags),
      Object.hashAll(collaboratorIds),
      createdAt,
      lastModifiedAt,
      isDeleted,
      syncVersion,
      deviceId,
    );
  }

  @override
  String toString() {
    return 'SyncableCustomList(id: $id, userId: $userId, name: $name, '
        'movieCount: ${movieIds.length}, isPublic: $isPublic, '
        'isDeleted: $isDeleted, syncVersion: $syncVersion, lastModifiedAt: $lastModifiedAt)';
  }

  // =============================================
  // CONVERSIÓN PARA REPOSITORIOS HÍBRIDOS
  // =============================================

  /// Convierte a string JSON para almacenamiento local
  String toJsonString() {
    return SyncUtilities.encodeJson(toLocalStorage());
  }

  // Propiedades de conveniencia
  int get movieCount => movieIds.length;
  bool get isEmpty => movieIds.isEmpty;
  bool get isNotEmpty => movieIds.isNotEmpty;
  bool get hasCollaborators => collaboratorIds.isNotEmpty;
}
