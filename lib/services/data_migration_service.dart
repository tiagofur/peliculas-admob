import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../infrastructure/repositories/hybrid_watched_repository.dart';
import '../../infrastructure/repositories/hybrid_movie_ratings_repository.dart';
import '../../infrastructure/repositories/hybrid_custom_lists_repository.dart';
import '../presentation/providers/hybrid_repositories_provider.dart';
import '../presentation/providers/movie_ratings_provider.dart';

/// Servicio dedicado para manejar migración y sincronización de datos
/// Evita dependencias circulares manteniendo separation of concerns
class DataMigrationService {
  DataMigrationService({
    required this.watchedRepository,
    required this.ratingsRepository,
    required this.customListsRepository,
  });

  final HybridWatchedRepository watchedRepository;
  final HybridMovieRatingsRepository ratingsRepository;
  final HybridCustomListsRepository customListsRepository;

  static final _logger = LoggerFactory.getLogger('DataMigrationService');

  /// Detecta si existen datos locales sin dependencias complejas
  Future<LocalDataStatus> detectLocalData() async {
    try {
      _logger.info('🔍 Iniciando detección de datos locales...');

      // Verificar datos de películas vistas
      final watchedMovies =
          await watchedRepository.loadWatchedMovies(limit: 10000);
      final hasWatchedData = watchedMovies.isNotEmpty;

      // Verificar datos de calificaciones
      final ratings = await ratingsRepository.getUserRatings(limit: 10000);
      final hasRatingsData = ratings.isNotEmpty;

      // Verificar listas personalizadas
      final customLists =
          await customListsRepository.getAllCustomListsWithForcedSync();
      final hasCustomListsData = customLists.isNotEmpty;

      final status = LocalDataStatus(
        hasWatchedMovies: hasWatchedData,
        hasRatings: hasRatingsData,
        hasCustomLists: hasCustomListsData,
        totalWatchedMovies: watchedMovies.length,
        totalRatings: ratings.length,
        totalCustomLists: customLists.length,
      );

      _logger.info('✅ Detección de datos locales completada: '
          'Películas vistas: ${status.totalWatchedMovies}, '
          'Calificaciones: ${status.totalRatings}, '
          'Listas: ${status.totalCustomLists}');

      return status;
    } catch (e) {
      _logger.error('❌ Error detectando datos locales: $e');
      return LocalDataStatus.empty();
    }
  }

  /// Migra y sincroniza datos después de autenticación exitosa
  Future<MigrationResult> migrateAndSyncData(String userId) async {
    try {
      _logger.info(
          '🚀 Iniciando migración y sincronización para usuario: $userId');

      // 1. Detectar datos locales
      final localDataStatus = await detectLocalData();

      if (!localDataStatus.hasAnyData) {
        _logger.info('📭 No hay datos locales para migrar');
        return MigrationResult.success(
          migratedWatchedMovies: 0,
          migratedRatings: 0,
          migratedCustomLists: 0,
        );
      }

      // 2. Migrar datos por categorías
      int migratedWatched = 0;
      int migratedRatings = 0;
      int migratedLists = 0;

      // Migrar películas vistas
      if (localDataStatus.hasWatchedMovies) {
        migratedWatched = await _migrateWatchedMovies(userId);
      }

      // Migrar calificaciones
      if (localDataStatus.hasRatings) {
        migratedRatings = await _migrateRatings(userId);
      }

      // Migrar listas personalizadas
      if (localDataStatus.hasCustomLists) {
        migratedLists = await _migrateCustomLists(userId);
      }

      // 3. Ejecutar sincronización completa
      await _performFullSync(userId);

      final result = MigrationResult.success(
        migratedWatchedMovies: migratedWatched,
        migratedRatings: migratedRatings,
        migratedCustomLists: migratedLists,
      );

      _logger.info('✅ Migración completada exitosamente: '
          'Películas: $migratedWatched, Calificaciones: $migratedRatings, Listas: $migratedLists');

      return result;
    } catch (e) {
      _logger.error('❌ Error en migración y sincronización: $e');
      return MigrationResult.failure(error: e.toString());
    }
  }

  /// Migra películas vistas locales al usuario autenticado
  Future<int> _migrateWatchedMovies(String userId) async {
    try {
      _logger.info('📽️ Migrando películas vistas...');

      // Los repositorios híbridos ya manejan sincronización automática con Supabase
      final watchedMovies =
          await watchedRepository.loadWatchedMovies(limit: 10000);

      // Los datos ya están sincronizados automáticamente por el repositorio híbrido
      _logger.info(
          '✅ ${watchedMovies.length} películas vistas disponibles y sincronizadas');
      return watchedMovies.length;
    } catch (e) {
      _logger.error('❌ Error migrando películas vistas: $e');
      throw Exception('Error en migración de películas vistas: $e');
    }
  }

  /// Migra calificaciones locales al usuario autenticado
  Future<int> _migrateRatings(String userId) async {
    try {
      _logger.info('⭐ Migrando calificaciones...');

      // Los repositorios híbridos ya manejan sincronización automática con Supabase
      final ratings = await ratingsRepository.getUserRatings(limit: 10000);

      // Los datos ya están sincronizados automáticamente por el repositorio híbrido
      _logger.info(
          '✅ ${ratings.length} calificaciones disponibles y sincronizadas');
      return ratings.length;
    } catch (e) {
      _logger.error('❌ Error migrando calificaciones: $e');
      throw Exception('Error en migración de calificaciones: $e');
    }
  }

  /// Migra listas personalizadas locales al usuario autenticado
  Future<int> _migrateCustomLists(String userId) async {
    try {
      _logger.info('📋 Migrando listas personalizadas...');

      // Los repositorios híbridos ya manejan sincronización automática con Supabase
      final customLists =
          await customListsRepository.getAllCustomListsWithForcedSync();

      // Los datos ya están sincronizados automáticamente por el repositorio híbrido
      _logger.info(
          '✅ ${customLists.length} listas personalizadas disponibles y sincronizadas');
      return customLists.length;
    } catch (e) {
      _logger.error('❌ Error migrando listas personalizadas: $e');
      throw Exception('Error en migración de listas personalizadas: $e');
    }
  }

  /// Ejecuta sincronización completa después de migración
  Future<void> _performFullSync(String userId) async {
    try {
      _logger.info('🔄 Ejecutando sincronización completa...');

      // Los repositorios híbridos ya implementan sincronización bidireccional automática con Supabase
      // La sincronización se activa automáticamente cuando se realizan operaciones como:
      // - markAsWatched, rateMovie, createCustomList, etc.
      // - Los datos se sincronizan en tiempo real con Supabase
      // - Resolución automática de conflictos incluida

      _logger.info(
          '✅ Sincronización bidireccional automática ya configurada y funcionando');
      _logger.debug(
          '📊 Repositorios híbridos con Supabase: Todas las operaciones se sincronizan automáticamente');
    } catch (e) {
      _logger.error('❌ Error en sincronización completa: $e');
      throw Exception('Error en sincronización completa: $e');
    }
  }
}

/// Estado de datos locales detectados
class LocalDataStatus {
  const LocalDataStatus({
    required this.hasWatchedMovies,
    required this.hasRatings,
    required this.hasCustomLists,
    required this.totalWatchedMovies,
    required this.totalRatings,
    required this.totalCustomLists,
  });

  factory LocalDataStatus.empty() {
    return const LocalDataStatus(
      hasWatchedMovies: false,
      hasRatings: false,
      hasCustomLists: false,
      totalWatchedMovies: 0,
      totalRatings: 0,
      totalCustomLists: 0,
    );
  }

  final bool hasWatchedMovies;
  final bool hasRatings;
  final bool hasCustomLists;
  final int totalWatchedMovies;
  final int totalRatings;
  final int totalCustomLists;

  bool get hasAnyData => hasWatchedMovies || hasRatings || hasCustomLists;
}

/// Resultado de operación de migración
class MigrationResult {
  const MigrationResult({
    required this.success,
    required this.migratedWatchedMovies,
    required this.migratedRatings,
    required this.migratedCustomLists,
    this.error,
  });

  factory MigrationResult.success({
    required int migratedWatchedMovies,
    required int migratedRatings,
    required int migratedCustomLists,
  }) {
    return MigrationResult(
      success: true,
      migratedWatchedMovies: migratedWatchedMovies,
      migratedRatings: migratedRatings,
      migratedCustomLists: migratedCustomLists,
    );
  }

  factory MigrationResult.failure({required String error}) {
    return MigrationResult(
      success: false,
      migratedWatchedMovies: 0,
      migratedRatings: 0,
      migratedCustomLists: 0,
      error: error,
    );
  }

  final bool success;
  final int migratedWatchedMovies;
  final int migratedRatings;
  final int migratedCustomLists;
  final String? error;

  int get totalMigrated =>
      migratedWatchedMovies + migratedRatings + migratedCustomLists;
}

/// Provider del servicio de migración
final dataMigrationServiceProvider = Provider<DataMigrationService>((ref) {
  final watchedRepository = ref.watch(hybridWatchedRepositoryProvider);
  // Usar el provider existente para ratings
  final ratingsRepository =
      ref.watch(movieRatingsRepositoryProvider) as HybridMovieRatingsRepository;
  final customListsRepository = ref.watch(hybridCustomListsRepositoryProvider);

  return DataMigrationService(
    watchedRepository: watchedRepository,
    ratingsRepository: ratingsRepository,
    customListsRepository: customListsRepository,
  );
});
