/// Enum para tipos de listas por defecto
enum DefaultListType {
  favorites,
  watchlist,
  watched,
  trending,
  classics,
  actionAdventure,
  comedy,
  drama,
  horror,
  scifi,
  romance,
  documentary,
  animation,
}

/// Representa un elemento individual dentro de una lista personalizada
/// Corresponde a la tabla user_list_items en Supabase
class ListItem {
  const ListItem({
    required this.id,
    required this.listId,
    required this.movieId,
    required this.movieTitle,
    required this.position,
    required this.addedAt,
    required this.updatedAt,
    this.moviePosterPath,
    this.syncStatus = 'synced',
    this.isDeleted = false,
  });

  factory ListItem.fromJson(Map<String, dynamic> json) {
    return ListItem(
      id: json['id'] ?? '',
      listId: json['list_id'] ?? json['listId'] ?? '',
      movieId: json['movie_id'] ?? json['movieId'] ?? 0,
      movieTitle: json['movie_title'] ?? json['movieTitle'] ?? '',
      moviePosterPath: json['movie_poster_path'] ?? json['moviePosterPath'],
      position: json['position'] ?? 0,
      addedAt: json['added_at'] != null
          ? DateTime.parse(json['added_at'])
          : json['addedAt'] != null
              ? DateTime.parse(json['addedAt'])
              : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'])
              : DateTime.now(),
      syncStatus: json['syncStatus'] ?? json['sync_status'] ?? 'synced',
      isDeleted: json['isDeleted'] ?? json['is_deleted'] ?? false,
    );
  }

  /// ID único del elemento (UUID)
  final String id;

  /// ID de la lista a la que pertenece este elemento
  final String listId;

  /// ID de la película en TMDB
  final int movieId;

  /// Título de la película (para mostrar sin consultar TMDB)
  final String movieTitle;

  /// Ruta del poster de la película (opcional)
  final String? moviePosterPath;

  /// Posición del elemento en la lista (para ordenamiento)
  final int position;

  /// Fecha cuando se agregó el elemento a la lista
  final DateTime addedAt;

  /// Fecha de última actualización
  final DateTime updatedAt;

  /// Estado de sincronización: 'synced', 'pending', 'error'
  final String syncStatus;

  /// Indica si el elemento está marcado para eliminación
  final bool isDeleted;

  ListItem copyWith({
    String? id,
    String? listId,
    int? movieId,
    String? movieTitle,
    String? moviePosterPath,
    int? position,
    DateTime? addedAt,
    DateTime? updatedAt,
    String? syncStatus,
    bool? isDeleted,
  }) {
    return ListItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Convierte a JSON para Supabase (usando snake_case)
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'list_id': listId,
      'movie_id': movieId,
      'movie_title': movieTitle,
      'movie_poster_path': moviePosterPath,
      'position': position,
      'added_at': addedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convierte a JSON local (usando camelCase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listId': listId,
      'movieId': movieId,
      'movieTitle': movieTitle,
      'moviePosterPath': moviePosterPath,
      'position': position,
      'addedAt': addedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus,
      'isDeleted': isDeleted,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ListItem &&
        other.id == id &&
        other.listId == listId &&
        other.movieId == movieId &&
        other.movieTitle == movieTitle &&
        other.moviePosterPath == moviePosterPath &&
        other.position == position &&
        other.addedAt == addedAt &&
        other.updatedAt == updatedAt &&
        other.syncStatus == syncStatus &&
        other.isDeleted == isDeleted;
  }

  @override
  int get hashCode => Object.hash(
        id,
        listId,
        movieId,
        movieTitle,
        moviePosterPath,
        position,
        addedAt,
        updatedAt,
        syncStatus,
        isDeleted,
      );

  @override
  String toString() {
    return 'ListItem(id: $id, listId: $listId, movieId: $movieId, title: $movieTitle, position: $position)';
  }
}

/// Configuración para listas por defecto
class DefaultListConfig {
  /// Constructor principal
  const DefaultListConfig({
    required this.localId,
    required this.name,
    required this.emoji,
    required this.description,
    required this.color,
    this.defaultType,
    this.type,
  });
  const DefaultListConfig._internal({
    required this.localId,
    required this.name,
    required this.emoji,
    required this.description,
    required this.color,
    this.defaultType,
    this.type,
  });

  /// Constructor alternativo para tests
  const DefaultListConfig.withType({
    required DefaultListType type,
    required this.name,
    required this.emoji,
    required this.description,
    required String colorHex,
  })  : localId = '',
        color = colorHex,
        defaultType = null,
        type = type;

  /// ID local usado en SharedPreferences
  final String localId;

  /// Nombre de la lista
  final String name;

  /// Emoji de la lista
  final String emoji;

  /// Descripción de la lista
  final String description;

  /// Color de la lista
  final String color;

  /// Tipo de lista por defecto (para identificación en Supabase)
  final String? defaultType;

  /// Tipo de lista por defecto (enum)
  final DefaultListType? type;

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'name': name,
      'emoji': emoji,
      'description': description,
      'color': color,
      'defaultType': defaultType,
    };
  }

  @override
  String toString() {
    return 'DefaultListConfig(localId: $localId, name: $name, emoji: $emoji)';
  }
}
