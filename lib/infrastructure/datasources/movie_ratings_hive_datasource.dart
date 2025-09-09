import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/syncable_movie_rating.dart';

/// Datasource para almacenamiento local de calificaciones de películas usando Hive
class MovieRatingsHiveDatasource {
  static const String _boxName = 'movie_ratings';
  Box<Map<dynamic, dynamic>>? _box;

  /// Obtiene o abre la caja de Hive
  Future<Box<Map<dynamic, dynamic>>> _getBox() async {
    _box ??= await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
    return _box!;
  }

  /// Carga todas las calificaciones del usuario
  Future<List<SyncableMovieRating>> loadUserRatings({
    String? userId,
    int limit = 1000,
    int offset = 0,
  }) async {
    try {
      final box = await _getBox();

      if (kDebugMode) {
        LoggerFactory.debug(
            '📊 Loading user ratings from Hive box: ${box.length} total items');
      }

      final List<SyncableMovieRating> ratings = [];
      var processed = 0;
      var skipped = 0;

      for (final value in box.values) {
        if (processed >= offset + limit) break;
        if (processed < offset) {
          processed++;
          continue;
        }

        try {
          final rating =
              SyncableMovieRating.fromJson(Map<String, dynamic>.from(value));

          // Filtrar por usuario si se especifica
          if (userId == null || rating.userId == userId) {
            // Solo incluir calificaciones no eliminadas
            if (!rating.isDeleted) {
              ratings.add(rating);
            }
          } else {
            skipped++;
          }
        } catch (e) {
          if (kDebugMode) {
            LoggerFactory.error('❌ Failed to deserialize rating: $e');
          }
          skipped++;
        }
        processed++;
      }

      if (kDebugMode) {
        LoggerFactory.debug(
            '✅ Loaded ${ratings.length} ratings, skipped $skipped');
      }

      return ratings;
    } catch (e) {
      LoggerFactory.error('❌ Failed to load user ratings from Hive: $e');
      return [];
    }
  }

  /// Obtiene una calificación específica por movie ID y user ID
  Future<SyncableMovieRating?> getUserRating(int movieId, String userId) async {
    try {
      final ratings = await loadUserRatings(userId: userId);
      final matches = ratings.where((rating) =>
          rating.movieId == movieId &&
          rating.userId == userId &&
          !rating.isDeleted);
      return matches.isNotEmpty ? matches.first : null;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get user rating: $e');
      return null;
    }
  }

  /// Verifica si un usuario ya calificó una película
  Future<bool> hasUserRatedMovie(int movieId, String userId) async {
    try {
      final rating = await getUserRating(movieId, userId);
      return rating != null;
    } catch (e) {
      LoggerFactory.error('❌ Failed to check if user rated movie: $e');
      return false;
    }
  }

  /// Guarda una calificación
  Future<void> saveRating(SyncableMovieRating rating) async {
    try {
      final box = await _getBox();
      final key = '${rating.userId}_${rating.movieId}';

      await box.put(key, rating.toLocalStorage());

      if (kDebugMode) {
        LoggerFactory.debug(
            '💾 Saved rating locally: ${rating.movieId} (rating: ${rating.rating})');
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to save rating to Hive: $e');
      rethrow;
    }
  }

  /// Actualiza una calificación existente
  Future<void> updateRating(SyncableMovieRating rating) async {
    // En Hive, update y save son la misma operación
    await saveRating(rating);
  }

  /// Elimina una calificación (marca como eliminada)
  Future<void> deleteRating(int movieId, String userId) async {
    try {
      final existingRating = await getUserRating(movieId, userId);
      if (existingRating != null) {
        final deletedRating = existingRating.copyWith(
          isDeleted: true,
          lastModifiedAt: DateTime.now(),
        );
        await saveRating(deletedRating);

        if (kDebugMode) {
          LoggerFactory.debug('🗑️ Marked rating as deleted: $movieId');
        }
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to delete rating from Hive: $e');
      rethrow;
    }
  }

  /// Elimina físicamente una calificación
  Future<void> removeRating(int movieId, String userId) async {
    try {
      final box = await _getBox();
      final key = '${userId}_$movieId';

      await box.delete(key);

      if (kDebugMode) {
        LoggerFactory.debug('🗑️ Physically removed rating: $movieId');
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to remove rating from Hive: $e');
      rethrow;
    }
  }

  /// Obtiene calificaciones ordenadas por fecha
  Future<List<SyncableMovieRating>> getUserRatingsSorted({
    required String userId,
    bool ascending = false,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final ratings = await loadUserRatings(userId: userId, limit: 10000);
      final sortedRatings = ratings.toList();

      sortedRatings.sort((a, b) {
        final comparison = a.ratedAt.compareTo(b.ratedAt);
        return ascending ? comparison : -comparison;
      });

      final startIndex = offset;
      final endIndex = (startIndex + limit < sortedRatings.length)
          ? startIndex + limit
          : sortedRatings.length;

      if (startIndex >= sortedRatings.length) return [];

      return sortedRatings.sublist(startIndex, endIndex);
    } catch (e) {
      LoggerFactory.error('❌ Failed to get sorted ratings: $e');
      return [];
    }
  }

  /// Obtiene calificaciones filtradas por rating
  Future<List<SyncableMovieRating>> getUserRatingsByRating({
    required String userId,
    double? minRating,
    double? maxRating,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final ratings = await loadUserRatings(userId: userId, limit: 10000);
      var filteredRatings = ratings.where((rating) {
        if (minRating != null && rating.rating < minRating) return false;
        if (maxRating != null && rating.rating > maxRating) return false;
        return true;
      }).toList();

      final startIndex = offset;
      final endIndex = (startIndex + limit < filteredRatings.length)
          ? startIndex + limit
          : filteredRatings.length;

      if (startIndex >= filteredRatings.length) return [];

      return filteredRatings.sublist(startIndex, endIndex);
    } catch (e) {
      LoggerFactory.error('❌ Failed to get ratings by rating: $e');
      return [];
    }
  }

  /// Obtiene calificaciones que tienen reseña
  Future<List<SyncableMovieRating>> getUserRatingsWithReviews({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final ratings = await loadUserRatings(userId: userId, limit: 10000);
      var filteredRatings =
          ratings.where((rating) => rating.hasReview).toList();

      final startIndex = offset;
      final endIndex = (startIndex + limit < filteredRatings.length)
          ? startIndex + limit
          : filteredRatings.length;

      if (startIndex >= filteredRatings.length) return [];

      return filteredRatings.sublist(startIndex, endIndex);
    } catch (e) {
      LoggerFactory.error('❌ Failed to get ratings with reviews: $e');
      return [];
    }
  }

  /// Obtiene estadísticas de calificaciones del usuario
  Future<Map<String, dynamic>> getUserRatingStats(String userId) async {
    try {
      final ratings = await loadUserRatings(userId: userId, limit: 10000);

      if (ratings.isEmpty) {
        return {
          'totalRatings': 0,
          'averageRating': 0.0,
          'highestRating': 0.0,
          'lowestRating': 0.0,
          'ratingsWithReview': 0,
          'publicRatings': 0,
          'recentRatingsCount': 0,
          'ratingDistribution': {
            '1-2': 0,
            '3-4': 0,
            '5-6': 0,
            '7-8': 0,
            '9-10': 0,
          },
        };
      }

      final totalRatings = ratings.length;
      final averageRating =
          ratings.map((r) => r.rating).reduce((a, b) => a + b) / totalRatings;
      final highestRating =
          ratings.map((r) => r.rating).reduce((a, b) => a > b ? a : b);
      final lowestRating =
          ratings.map((r) => r.rating).reduce((a, b) => a < b ? a : b);
      final ratingsWithReview = ratings.where((r) => r.hasReview).length;
      final publicRatings = ratings.where((r) => r.isPublic).length;

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentRatingsCount =
          ratings.where((r) => r.ratedAt.isAfter(thirtyDaysAgo)).length;

      // Distribución de ratings
      final ratingDistribution = {
        '1-2': ratings.where((r) => r.rating >= 1.0 && r.rating < 3.0).length,
        '3-4': ratings.where((r) => r.rating >= 3.0 && r.rating < 5.0).length,
        '5-6': ratings.where((r) => r.rating >= 5.0 && r.rating < 7.0).length,
        '7-8': ratings.where((r) => r.rating >= 7.0 && r.rating < 9.0).length,
        '9-10':
            ratings.where((r) => r.rating >= 9.0 && r.rating <= 10.0).length,
      };

      return {
        'totalRatings': totalRatings,
        'averageRating': double.parse(averageRating.toStringAsFixed(2)),
        'highestRating': highestRating,
        'lowestRating': lowestRating,
        'ratingsWithReview': ratingsWithReview,
        'publicRatings': publicRatings,
        'recentRatingsCount': recentRatingsCount,
        'ratingDistribution': ratingDistribution,
      };
    } catch (e) {
      LoggerFactory.error('❌ Failed to get user rating stats: $e');
      return {
        'totalRatings': 0,
        'averageRating': 0.0,
        'highestRating': 0.0,
        'lowestRating': 0.0,
        'ratingsWithReview': 0,
        'publicRatings': 0,
        'recentRatingsCount': 0,
        'ratingDistribution': {
          '1-2': 0,
          '3-4': 0,
          '5-6': 0,
          '7-8': 0,
          '9-10': 0,
        },
      };
    }
  }

  /// Busca calificaciones por tags
  Future<List<SyncableMovieRating>> searchRatingsByTags({
    required String userId,
    required List<String> tags,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final ratings = await loadUserRatings(userId: userId, limit: 10000);
      var filteredRatings = ratings.where((rating) {
        return tags.any((tag) => rating.tags.contains(tag.toLowerCase()));
      }).toList();

      final startIndex = offset;
      final endIndex = (startIndex + limit < filteredRatings.length)
          ? startIndex + limit
          : filteredRatings.length;

      if (startIndex >= filteredRatings.length) return [];

      return filteredRatings.sublist(startIndex, endIndex);
    } catch (e) {
      LoggerFactory.error('❌ Failed to search ratings by tags: $e');
      return [];
    }
  }

  /// Busca calificaciones por texto en reseña
  Future<List<SyncableMovieRating>> searchRatingsByReviewText({
    required String userId,
    required String query,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final ratings = await loadUserRatings(userId: userId, limit: 10000);
      final lowerQuery = query.toLowerCase();

      var filteredRatings = ratings.where((rating) {
        if (rating.review == null) return false;
        return rating.review!.toLowerCase().contains(lowerQuery) ||
            rating.movieTitle.toLowerCase().contains(lowerQuery);
      }).toList();

      final startIndex = offset;
      final endIndex = (startIndex + limit < filteredRatings.length)
          ? startIndex + limit
          : filteredRatings.length;

      if (startIndex >= filteredRatings.length) return [];

      return filteredRatings.sublist(startIndex, endIndex);
    } catch (e) {
      LoggerFactory.error('❌ Failed to search ratings by review text: $e');
      return [];
    }
  }

  /// Limpia todos los datos de calificaciones
  Future<void> clearAllRatings() async {
    try {
      final box = await _getBox();
      await box.clear();

      if (kDebugMode) {
        LoggerFactory.debug('🧹 Cleared all movie ratings from local storage');
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to clear movie ratings: $e');
      rethrow;
    }
  }

  /// Cierra la caja de Hive
  Future<void> close() async {
    try {
      if (_box != null && _box!.isOpen) {
        await _box!.close();
        _box = null;
      }

      if (kDebugMode) {
        LoggerFactory.debug('🔒 Closed movie ratings Hive box');
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to close movie ratings box: $e');
      rethrow;
    }
  }
}
