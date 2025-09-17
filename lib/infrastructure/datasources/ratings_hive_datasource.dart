import 'package:hive_flutter/hive_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/user_movie_rating.dart';

/// Datasource para almacenar ratings de películas usando Hive
class RatingsHiveDatasource {
  static const String _ratingsBoxName = 'user_movie_ratings';
  Box<Map>? _ratingsBox;

  /// Inicializa la base de datos Hive para ratings
  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_ratingsBoxName)) {
        _ratingsBox = await Hive.openBox<Map>(_ratingsBoxName);
        LoggerFactory.info('✅ [RatingsHive] Box abierto: $_ratingsBoxName');
      } else {
        _ratingsBox = Hive.box<Map>(_ratingsBoxName);
        LoggerFactory.info(
            '📦 [RatingsHive] Box ya estaba abierto: $_ratingsBoxName');
      }
    } catch (e) {
      LoggerFactory.error('❌ [RatingsHive] Error inicializando: $e');
      rethrow;
    }
  }

  /// Asegura que el box esté inicializado
  Future<Box<Map>> _ensureBox() async {
    if (_ratingsBox == null || !_ratingsBox!.isOpen) {
      await init();
    }
    return _ratingsBox!;
  }

  /// Genera clave única para un rating
  String _generateRatingKey(int movieId, String userId) {
    return '${userId}_$movieId';
  }

  /// Guarda un rating en el storage local
  Future<void> saveRating(UserMovieRating rating) async {
    try {
      final box = await _ensureBox();
      final key = _generateRatingKey(rating.movieId, rating.userId);

      await box.put(key, rating.toJson());

      LoggerFactory.debug(
          '💾 [RatingsHive] Rating guardado: ${rating.movieTitle} (${rating.rating}/10)');
    } catch (e) {
      LoggerFactory.error('❌ [RatingsHive] Error guardando rating: $e');
      rethrow;
    }
  }

  /// Obtiene un rating específico por movieId y userId
  Future<UserMovieRating?> getRating(int movieId, String userId) async {
    try {
      final box = await _ensureBox();
      final key = _generateRatingKey(movieId, userId);

      final data = box.get(key);
      if (data != null) {
        final rating =
            UserMovieRating.fromJson(Map<String, dynamic>.from(data));
        LoggerFactory.debug(
            '🔍 [RatingsHive] Rating encontrado: ${rating.movieTitle} (${rating.rating}/10)');
        return rating;
      }

      LoggerFactory.debug(
          '📭 [RatingsHive] No se encontró rating para movie: $movieId');
      return null;
    } catch (e) {
      LoggerFactory.error('❌ [RatingsHive] Error obteniendo rating: $e');
      return null;
    }
  }

  /// Obtiene todos los ratings de un usuario
  Future<List<UserMovieRating>> getAllRatings(String userId) async {
    try {
      final box = await _ensureBox();
      final ratings = <UserMovieRating>[];

      for (final key in box.keys) {
        if (key.toString().startsWith('${userId}_')) {
          final data = box.get(key);
          if (data != null) {
            try {
              final rating =
                  UserMovieRating.fromJson(Map<String, dynamic>.from(data));
              ratings.add(rating);
            } catch (e) {
              LoggerFactory.warning(
                  '⚠️ [RatingsHive] Error parseando rating con key $key: $e');
              // Continuar con otros ratings
            }
          }
        }
      }

      // Ordenar por fecha de creación (más recientes primero)
      ratings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      LoggerFactory.info(
          '📱 [RatingsHive] Cargados ${ratings.length} ratings para user: $userId');
      return ratings;
    } catch (e) {
      LoggerFactory.error(
          '❌ [RatingsHive] Error obteniendo todos los ratings: $e');
      return [];
    }
  }

  /// Obtiene ratings paginados
  Future<List<UserMovieRating>> getPaginatedRatings(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final allRatings = await getAllRatings(userId);

      final startIndex = offset;
      final endIndex = (startIndex + limit < allRatings.length)
          ? startIndex + limit
          : allRatings.length;

      if (startIndex >= allRatings.length) return [];

      final paginatedRatings = allRatings.sublist(startIndex, endIndex);

      LoggerFactory.debug(
          '📄 [RatingsHive] Obtenidos ${paginatedRatings.length} ratings (página ${offset ~/ limit + 1})');
      return paginatedRatings;
    } catch (e) {
      LoggerFactory.error(
          '❌ [RatingsHive] Error obteniendo ratings paginados: $e');
      return [];
    }
  }

  /// Obtiene ratings ordenados por calificación
  Future<List<UserMovieRating>> getRatingsSortedByRating(
    String userId, {
    bool ascending = false,
    int limit = 50,
  }) async {
    try {
      final allRatings = await getAllRatings(userId);

      // Ordenar por rating y fecha
      allRatings.sort((a, b) {
        final ratingComparison = ascending
            ? a.rating.compareTo(b.rating)
            : b.rating.compareTo(a.rating);
        return ratingComparison != 0
            ? ratingComparison
            : b.createdAt.compareTo(a.createdAt);
      });

      final result = allRatings.take(limit).toList();

      LoggerFactory.debug(
          '⭐ [RatingsHive] Obtenidos ${result.length} ratings ordenados por calificación');
      return result;
    } catch (e) {
      LoggerFactory.error(
          '❌ [RatingsHive] Error obteniendo ratings ordenados: $e');
      return [];
    }
  }

  /// Obtiene ratings en un rango de calificación
  Future<List<UserMovieRating>> getRatingsByRange(
    String userId, {
    double? minRating,
    double? maxRating,
    int limit = 50,
  }) async {
    try {
      final allRatings = await getAllRatings(userId);

      final filteredRatings = allRatings.where((rating) {
        bool matchesMin = minRating == null || rating.rating >= minRating;
        bool matchesMax = maxRating == null || rating.rating <= maxRating;
        return matchesMin && matchesMax;
      }).toList();

      final result = filteredRatings.take(limit).toList();

      LoggerFactory.debug(
          '🎯 [RatingsHive] Obtenidos ${result.length} ratings en rango [$minRating-$maxRating]');
      return result;
    } catch (e) {
      LoggerFactory.error(
          '❌ [RatingsHive] Error obteniendo ratings por rango: $e');
      return [];
    }
  }

  /// Obtiene ratings que tienen comentarios
  Future<List<UserMovieRating>> getRatingsWithReviews(String userId,
      {int limit = 50}) async {
    try {
      final allRatings = await getAllRatings(userId);

      final ratingsWithReviews = allRatings.where((rating) {
        return rating.review != null && rating.review!.trim().isNotEmpty;
      }).toList();

      final result = ratingsWithReviews.take(limit).toList();

      LoggerFactory.debug(
          '📝 [RatingsHive] Obtenidos ${result.length} ratings con comentarios');
      return result;
    } catch (e) {
      LoggerFactory.error(
          '❌ [RatingsHive] Error obteniendo ratings con comentarios: $e');
      return [];
    }
  }

  /// Busca ratings por título de película
  Future<List<UserMovieRating>> searchRatingsByTitle(
    String userId,
    String query, {
    int limit = 50,
  }) async {
    try {
      final allRatings = await getAllRatings(userId);
      final queryLower = query.toLowerCase();

      final matchingRatings = allRatings.where((rating) {
        return rating.movieTitle.toLowerCase().contains(queryLower);
      }).toList();

      final result = matchingRatings.take(limit).toList();

      LoggerFactory.debug(
          '🔍 [RatingsHive] Encontrados ${result.length} ratings con query: "$query"');
      return result;
    } catch (e) {
      LoggerFactory.error('❌ [RatingsHive] Error buscando ratings: $e');
      return [];
    }
  }

  /// Busca ratings por texto del comentario
  Future<List<UserMovieRating>> searchRatingsByReview(
    String userId,
    String query, {
    int limit = 50,
  }) async {
    try {
      final allRatings = await getAllRatings(userId);
      final queryLower = query.toLowerCase();

      final matchingRatings = allRatings.where((rating) {
        return rating.review != null &&
            rating.review!.toLowerCase().contains(queryLower);
      }).toList();

      final result = matchingRatings.take(limit).toList();

      LoggerFactory.debug(
          '💬 [RatingsHive] Encontrados ${result.length} ratings con comentario que contiene: "$query"');
      return result;
    } catch (e) {
      LoggerFactory.error('❌ [RatingsHive] Error buscando por comentario: $e');
      return [];
    }
  }

  /// Obtiene ratings recientes (últimos N días)
  Future<List<UserMovieRating>> getRecentRatings(
    String userId, {
    int days = 30,
    int limit = 20,
  }) async {
    try {
      final allRatings = await getAllRatings(userId);
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final recentRatings = allRatings.where((rating) {
        return rating.createdAt.isAfter(cutoffDate);
      }).toList();

      final result = recentRatings.take(limit).toList();

      LoggerFactory.debug(
          '🕒 [RatingsHive] Obtenidos ${result.length} ratings de los últimos $days días');
      return result;
    } catch (e) {
      LoggerFactory.error(
          '❌ [RatingsHive] Error obteniendo ratings recientes: $e');
      return [];
    }
  }

  /// Obtiene estadísticas de ratings del usuario
  Future<Map<String, dynamic>> getRatingStats(String userId) async {
    try {
      final allRatings = await getAllRatings(userId);

      if (allRatings.isEmpty) {
        return {
          'totalRatings': 0,
          'averageRating': 0.0,
          'highestRating': 0.0,
          'lowestRating': 0.0,
          'ratingsWithReview': 0,
          'recentRatingsCount': 0,
        };
      }

      final totalRatings = allRatings.length;
      final averageRating =
          allRatings.map((r) => r.rating).reduce((a, b) => a + b) /
              totalRatings;
      final highestRating =
          allRatings.map((r) => r.rating).reduce((a, b) => a > b ? a : b);
      final lowestRating =
          allRatings.map((r) => r.rating).reduce((a, b) => a < b ? a : b);
      final ratingsWithReview = allRatings
          .where((r) => r.review != null && r.review!.isNotEmpty)
          .length;

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentRatingsCount =
          allRatings.where((r) => r.createdAt.isAfter(thirtyDaysAgo)).length;

      final stats = {
        'totalRatings': totalRatings,
        'averageRating': double.parse(averageRating.toStringAsFixed(1)),
        'highestRating': highestRating,
        'lowestRating': lowestRating,
        'ratingsWithReview': ratingsWithReview,
        'recentRatingsCount': recentRatingsCount,
      };

      LoggerFactory.debug('📊 [RatingsHive] Estadísticas calculadas: $stats');
      return stats;
    } catch (e) {
      LoggerFactory.error('❌ [RatingsHive] Error calculando estadísticas: $e');
      return {
        'totalRatings': 0,
        'averageRating': 0.0,
        'highestRating': 0.0,
        'lowestRating': 0.0,
        'ratingsWithReview': 0,
        'recentRatingsCount': 0,
      };
    }
  }

  /// Elimina un rating específico
  Future<void> removeRating(int movieId, String userId) async {
    try {
      final box = await _ensureBox();
      final key = _generateRatingKey(movieId, userId);

      await box.delete(key);

      LoggerFactory.debug(
          '🗑️ [RatingsHive] Rating eliminado para movie: $movieId');
    } catch (e) {
      LoggerFactory.error('❌ [RatingsHive] Error eliminando rating: $e');
      rethrow;
    }
  }

  /// Elimina todos los ratings de un usuario
  Future<void> removeAllUserRatings(String userId) async {
    try {
      final box = await _ensureBox();
      final keysToDelete = <String>[];

      for (final key in box.keys) {
        if (key.toString().startsWith('${userId}_')) {
          keysToDelete.add(key.toString());
        }
      }

      for (final key in keysToDelete) {
        await box.delete(key);
      }

      LoggerFactory.info(
          '🗑️ [RatingsHive] Eliminados ${keysToDelete.length} ratings del usuario: $userId');
    } catch (e) {
      LoggerFactory.error(
          '❌ [RatingsHive] Error eliminando ratings del usuario: $e');
      rethrow;
    }
  }

  /// Verifica si existe un rating para una película
  Future<bool> hasRating(int movieId, String userId) async {
    try {
      final rating = await getRating(movieId, userId);
      return rating != null;
    } catch (e) {
      LoggerFactory.error('❌ [RatingsHive] Error verificando rating: $e');
      return false;
    }
  }

  /// Cuenta el total de ratings de un usuario
  Future<int> countUserRatings(String userId) async {
    try {
      final box = await _ensureBox();
      int count = 0;

      for (final key in box.keys) {
        if (key.toString().startsWith('${userId}_')) {
          count++;
        }
      }

      LoggerFactory.debug(
          '📊 [RatingsHive] Total de ratings para $userId: $count');
      return count;
    } catch (e) {
      LoggerFactory.error('❌ [RatingsHive] Error contando ratings: $e');
      return 0;
    }
  }

  /// Exporta todos los ratings a formato JSON
  Future<List<Map<String, dynamic>>> exportAllRatings(String userId) async {
    try {
      final allRatings = await getAllRatings(userId);
      final exportData = allRatings.map((rating) => rating.toJson()).toList();

      LoggerFactory.info(
          '📤 [RatingsHive] Exportados ${exportData.length} ratings');
      return exportData;
    } catch (e) {
      LoggerFactory.error('❌ [RatingsHive] Error exportando ratings: $e');
      return [];
    }
  }

  /// Importa ratings desde formato JSON
  Future<void> importRatings(List<Map<String, dynamic>> ratingsData) async {
    try {
      int imported = 0;
      int errors = 0;

      for (final ratingData in ratingsData) {
        try {
          final rating = UserMovieRating.fromJson(ratingData);
          await saveRating(rating);
          imported++;
        } catch (e) {
          LoggerFactory.warning('⚠️ [RatingsHive] Error importando rating: $e');
          errors++;
        }
      }

      LoggerFactory.info(
          '📥 [RatingsHive] Importados $imported ratings, $errors errores');
    } catch (e) {
      LoggerFactory.error('❌ [RatingsHive] Error en importación masiva: $e');
      rethrow;
    }
  }

  /// Limpia y compacta la base de datos
  Future<void> compact() async {
    try {
      final box = await _ensureBox();
      await box.compact();

      LoggerFactory.info('🧹 [RatingsHive] Base de datos compactada');
    } catch (e) {
      LoggerFactory.error(
          '❌ [RatingsHive] Error compactando base de datos: $e');
    }
  }

  /// Cierra la conexión con la base de datos
  Future<void> close() async {
    try {
      if (_ratingsBox != null && _ratingsBox!.isOpen) {
        await _ratingsBox!.close();
        LoggerFactory.info('🔒 [RatingsHive] Box cerrado correctamente');
      }
    } catch (e) {
      LoggerFactory.error('❌ [RatingsHive] Error cerrando box: $e');
    }
  }
}
