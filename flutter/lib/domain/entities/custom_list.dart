import 'package:flutter/foundation.dart';

class CustomList {
  CustomList({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.movieIds,
    required this.createdAt,
    DateTime? lastModifiedAt,
    DateTime? updatedAt,
    this.userId,
    this.isDefault = false,
    this.isPublic = false,
    this.color = 'blue',
    this.isDeleted = false,
    this.syncStatus = 'synced',
    this.defaultType,
    String? colorHex,
  })  : colorHex = _resolveColorHex(colorName: color, explicitHex: colorHex),
        lastModifiedAt = lastModifiedAt ?? updatedAt ?? DateTime.now();

  factory CustomList.fromJson(Map<String, dynamic> json) {
    return CustomList(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      emoji: json['emoji'] ?? '📝',
      movieIds:
          json['movieIds'] != null ? List<int>.from(json['movieIds']) : <int>[],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.parse(json['lastModifiedAt'])
          : json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now(),
      userId: json['userId'] ?? json['user_id'],
      isDefault: json['isDefault'] ?? json['is_default'] ?? false,
      isPublic: json['isPublic'] ?? json['is_public'] ?? false,
      color: json['color'] ?? 'blue',
      isDeleted: json['isDeleted'] ?? json['is_deleted'] ?? false,
      syncStatus: json['syncStatus'] ?? json['sync_status'] ?? 'synced',
      defaultType: json['defaultType'] ?? json['default_type'],
      colorHex: json['colorHex'] ?? json['color_hex'],
    );
  }

  final String id;
  final String name;
  final String description;
  final String emoji;

  /// **DEPRECATED**: Este campo será eliminado en versiones futuras.
  ///
  /// **Razón**: El modelo de datos está siendo refactorizado para usar una
  /// tabla relacional separada (`user_list_items`) que refleja correctamente
  /// la estructura de la base de datos.
  ///
  /// **Alternativa**: Usa `listItemsProvider(listId)` para obtener las películas
  /// de una lista en tiempo real.
  ///
  /// ```dart
  /// // ❌ Forma antigua (deprecated)
  /// final movieIds = list.movieIds;
  ///
  /// // ✅ Forma nueva (recomendada)
  /// final items = ref.watch(listItemsProvider(listId));
  /// ```
  ///
  /// Ver: `lib/presentation/providers/list_items_provider.dart`
  ///
  /// **Fecha de deprecación**: Octubre 2025
  /// **Eliminación planeada**: Noviembre 2025
  @Deprecated(
    'Usa listItemsProvider(listId) en lugar de acceder directamente a movieIds. '
    'Este campo será eliminado en la próxima versión mayor.',
  )
  final List<int> movieIds;

  final DateTime createdAt;
  final DateTime lastModifiedAt;
  final String? userId;
  final bool isDefault;
  final bool isPublic;
  final String color;
  final bool isDeleted;
  final String syncStatus;
  final String? defaultType;
  final String? colorHex;

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
    String? defaultType,
    String? colorHex,
  }) {
    return CustomList(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      // ignore: deprecated_member_use_from_same_package
      movieIds: movieIds ??
          // ignore: deprecated_member_use_from_same_package
          this.movieIds,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      userId: userId ?? this.userId,
      isDefault: isDefault ?? this.isDefault,
      isPublic: isPublic ?? this.isPublic,
      color: color ?? this.color,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      defaultType: defaultType ?? this.defaultType,
      colorHex: colorHex ?? (color != null ? null : this.colorHex),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'emoji': emoji,
      // ignore: deprecated_member_use_from_same_package
      'movieIds': movieIds,
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
      'userId': userId,
      'isDefault': isDefault,
      'isPublic': isPublic,
      'color': color,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus,
      'defaultType': defaultType,
      'colorHex': colorHex,
    };
  }

  /// Convierte a JSON para Supabase (usando snake_case)
  Map<String, dynamic> toSupabaseJson() {
    final data = <String, dynamic>{
      'name': name,
      'description': description,
      'emoji': emoji,
      'user_id': userId,
      'is_default': isDefault,
      'is_public': isPublic,
      // Usar color_hex (nombre correcto de columna en DB)
      'color_hex': _resolveColorHex(colorName: color, explicitHex: colorHex),
      'is_deleted': isDeleted,
      // NO enviar created_at y last_modified_at en INSERT/UPDATE
      // Supabase los genera automáticamente con DEFAULT NOW()
    };

    if (defaultType != null && defaultType!.isNotEmpty) {
      data['default_type'] = defaultType;
    }

    // Solo incluir el ID si es un UUID válido (para evitar errores de Supabase)
    if (_isValidUuid(id)) {
      data['id'] = id;
    }

    // Eliminar campos sin valor para evitar errores en PostgREST
    data.removeWhere((key, value) => value == null);

    return data;
  }

  /// Verifica si una cadena es un UUID válido
  bool _isValidUuid(String value) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(value);
  }

  static const String _defaultColorHex = '#2196F3';

  static const Map<String, String> _colorNameToHexMap = {
    'red': '#F44336',
    'pink': '#E91E63',
    'purple': '#9C27B0',
    'deep_purple': '#673AB7',
    'indigo': '#3F51B5',
    'blue': '#2196F3',
    'light_blue': '#03A9F4',
    'cyan': '#00BCD4',
    'teal': '#009688',
    'green': '#4CAF50',
    'light_green': '#8BC34A',
    'lime': '#CDDC39',
    'yellow': '#FFEB3B',
    'amber': '#FFC107',
    'orange': '#FF9800',
    'deep_orange': '#FF5722',
    'brown': '#795548',
    'grey': '#9E9E9E',
    'gray': '#9E9E9E',
    'blue_grey': '#607D8B',
    'blue_gray': '#607D8B',
  };

  static String _resolveColorHex({
    required String colorName,
    String? explicitHex,
  }) {
    if (explicitHex != null && explicitHex.trim().isNotEmpty) {
      if (_looksLikeHex(explicitHex)) {
        return _normalizeHex(explicitHex);
      }
    }

    if (_looksLikeHex(colorName)) {
      return _normalizeHex(colorName);
    }

    final mappedHex = _colorNameToHexMap[colorName.toLowerCase()];
    if (mappedHex != null) {
      return mappedHex;
    }

    return _defaultColorHex;
  }

  static bool _looksLikeHex(String value) {
    final trimmed = value.trim();
    final hexOnly = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    final hexRegex = RegExp(r'^[0-9a-fA-F]{6}$');
    return hexRegex.hasMatch(hexOnly);
  }

  static String _normalizeHex(String value) {
    final trimmed = value.trim();
    final hexOnly = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    return '#${hexOnly.toUpperCase()}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomList &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.emoji == emoji &&
        // ignore: deprecated_member_use_from_same_package
        listEquals(
            // ignore: deprecated_member_use_from_same_package
            other.movieIds,
            // ignore: deprecated_member_use_from_same_package
            movieIds) && // Use listEquals for List comparison
        other.createdAt == createdAt &&
        other.lastModifiedAt == lastModifiedAt &&
        other.userId == userId &&
        other.isDefault == isDefault &&
        other.isPublic == isPublic &&
        other.color == color &&
        other.isDeleted == isDeleted &&
        other.syncStatus == syncStatus &&
        other.defaultType == defaultType &&
        other.colorHex == colorHex;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        emoji,
        // ignore: deprecated_member_use_from_same_package
        Object.hashAll(movieIds),
        createdAt,
        lastModifiedAt,
        userId,
        isDefault,
        isPublic,
        color,
        isDeleted,
        syncStatus,
        defaultType,
        colorHex,
      );

  /// Helper para obtener el conteo de películas.
  ///
  /// **NOTA**: Este método retorna `movieIds.length` por compatibilidad,
  /// pero será deprecado.
  ///
  /// **Recomendado**: Usa `listMovieCountProvider(listId)` en su lugar:
  /// ```dart
  /// final count = ref.watch(listMovieCountProvider(listId));
  /// ```
  @Deprecated('Usa listMovieCountProvider(listId) en lugar de este getter')
  // ignore: deprecated_member_use_from_same_package
  int get movieCount => movieIds.length;

  @override
  String toString() {
    // ignore: deprecated_member_use_from_same_package
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
