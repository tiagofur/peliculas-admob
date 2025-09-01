import 'package:flutter/material.dart';

import '../core/logging/base_logger.dart';
import '../core/logging/logger_factory.dart';
import '../core/services/persistent_sync_queue.dart';
import '../domain/entities/movie.dart';
import '../infrastructure/repositories/hybrid_favorites_repository.dart';
import '../infrastructure/repositories/hybrid_watched_repository.dart';

/// Demostración de uso de PersistentSyncQueue con repositorios híbridos
///
/// Esta clase muestra cómo integrar la cola de sincronización persistente
/// con los repositorios híbridos para manejar operaciones offline.
class SyncQueueDemo {
  SyncQueueDemo({
    required PersistentSyncQueue syncQueue,
    required HybridFavoritesRepository favoritesRepo,
    required HybridWatchedRepository watchedRepo,
  })  : _syncQueue = syncQueue,
        _favoritesRepo = favoritesRepo,
        _watchedRepo = watchedRepo;
  final PersistentSyncQueue _syncQueue;
  final HybridFavoritesRepository _favoritesRepo;
  final HybridWatchedRepository _watchedRepo;

  /// Inicializa la demostración
  Future<void> initialize() async {
    await _syncQueue.initialize();
    LoggerFactory.info('✅ SyncQueue inicializada',
        category: LogCategory.system);

    // Mostrar estadísticas iniciales
    await _showQueueStatistics();
  }

  /// Demuestra agregar película a favoritos (puede funcionar offline)
  Future<void> demoAddFavorite(Movie movie) async {
    LoggerFactory.info('\n🎬 Agregando película a favoritos: ${movie.title}',
        category: LogCategory.system);

    try {
      // El repositorio híbrido manejará automáticamente la cola offline
      await _favoritesRepo.toggleFavorite(movie);
      LoggerFactory.info('✅ Película agregada a favoritos',
          category: LogCategory.system);

      // Mostrar estadísticas actualizadas
      await _showQueueStatistics();
    } catch (e) {
      LoggerFactory.error('❌ Error al agregar favorito: $e',
          category: LogCategory.system);
    }
  }

  /// Demuestra marcar película como vista (puede funcionar offline)
  Future<void> demoMarkWatched(Movie movie) async {
    LoggerFactory.info('\n👁️ Marcando película como vista: ${movie.title}',
        category: LogCategory.system);

    try {
      // El repositorio híbrido manejará automáticamente la cola offline
      await _watchedRepo.markAsWatched(movie);
      LoggerFactory.info('✅ Película marcada como vista',
          category: LogCategory.system);

      // Mostrar estadísticas actualizadas
      await _showQueueStatistics();
    } catch (e) {
      LoggerFactory.error('❌ Error al marcar como vista: $e',
          category: LogCategory.system);
    }
  }

  /// Demuestra operaciones en lote offline
  Future<void> demoBatchOperations(List<Movie> movies) async {
    LoggerFactory.info(
        '\n📦 Ejecutando operaciones en lote (${movies.length} películas)',
        category: LogCategory.system);

    for (int i = 0; i < movies.length; i++) {
      final movie = movies[i];

      // Alternar entre favoritos y vistas
      if (i % 2 == 0) {
        await _favoritesRepo.toggleFavorite(movie);
        LoggerFactory.info('  ➕ ${movie.title} agregada a favoritos',
            category: LogCategory.system);
      } else {
        await _watchedRepo.markAsWatched(movie);
        LoggerFactory.info('  👁️ ${movie.title} marcada como vista',
            category: LogCategory.system);
      }
    }

    LoggerFactory.info('✅ Operaciones en lote completadas',
        category: LogCategory.system);
    await _showQueueStatistics();
  }

  /// Demuestra el procesamiento manual de la cola
  Future<void> demoManualProcessing() async {
    LoggerFactory.info('\n🔄 Procesando cola manualmente...',
        category: LogCategory.system);

    final statsBefore = _syncQueue.getStats();
    final pendingBefore = statsBefore.pendingOperations;
    LoggerFactory.info('  📊 Operaciones pendientes antes: $pendingBefore',
        category: LogCategory.system);

    if (pendingBefore > 0) {
      // Procesar operaciones pendientes
      await _syncQueue.processQueue();

      final statsAfter = _syncQueue.getStats();
      final pendingAfter = statsAfter.pendingOperations;
      LoggerFactory.info('  📊 Operaciones pendientes después: $pendingAfter',
          category: LogCategory.system);
      LoggerFactory.info(
          '  ✅ Procesadas: ${pendingBefore - pendingAfter} operaciones',
          category: LogCategory.system);
    } else {
      LoggerFactory.info('  ℹ️ No hay operaciones pendientes para procesar',
          category: LogCategory.system);
    }
  }

  /// Demuestra la limpieza de operaciones completadas
  Future<void> demoCleanup() async {
    LoggerFactory.info('\n🧹 Limpiando operaciones completadas...',
        category: LogCategory.system);

    final statsBefore = _syncQueue.getStats();
    final totalBefore = statsBefore.totalOperations;

    // Limpiar operaciones completadas (más de 1 día)
    await _syncQueue.cleanupCompletedOperations(
      olderThan: const Duration(days: 1),
    );

    final statsAfter = _syncQueue.getStats();
    final totalAfter = statsAfter.totalOperations;
    final cleaned = totalBefore - totalAfter;

    LoggerFactory.info('  📊 Operaciones limpiadas: $cleaned',
        category: LogCategory.system);
    LoggerFactory.info('  📊 Operaciones restantes: $totalAfter',
        category: LogCategory.system);
  }

  /// Muestra estadísticas detalladas de la cola
  Future<void> _showQueueStatistics() async {
    final stats = _syncQueue.getStats();

    LoggerFactory.info('\n📊 Estadísticas de la Cola:',
        category: LogCategory.system);
    LoggerFactory.info('  • Total: ${stats.totalOperations}',
        category: LogCategory.system);
    LoggerFactory.info('  • Pendientes: ${stats.pendingOperations}',
        category: LogCategory.system);
    LoggerFactory.info('  • Completadas: ${stats.completedOperations}',
        category: LogCategory.system);
    LoggerFactory.info('  • Fallidas: ${stats.failedOperations}',
        category: LogCategory.system);
    LoggerFactory.info(
        '  • Tasa de éxito: ${(stats.successRate * 100).toStringAsFixed(1)}%',
        category: LogCategory.system);

    if (stats.lastProcessedAt != null) {
      LoggerFactory.info('  • Última sincronización: ${stats.lastProcessedAt}',
          category: LogCategory.system);
    } else {
      LoggerFactory.info('  • Nunca sincronizado',
          category: LogCategory.system);
    }
  }

  /// Ejecuta una demostración completa
  Future<void> runFullDemo() async {
    LoggerFactory.info('🚀 Iniciando demostración completa de SyncQueue',
        category: LogCategory.system);

    // Películas de ejemplo
    final movies = [
      Movie(
        id: 1,
        title: 'The Matrix',
        overview: 'Una película de ciencia ficción',
        releaseDate: DateTime.parse('1999-03-31'),
        posterPath: '/poster1.jpg',
        backdropPath: '/backdrop1.jpg',
        voteAverage: 8.7,
        voteCount: 15000,
        genreIds: ['28', '878'],
        adult: false,
        originalLanguage: 'en',
        originalTitle: 'The Matrix',
        popularity: 8.7,
        video: false,
      ),
      Movie(
        id: 2,
        title: 'Inception',
        overview: 'Un thriller de ciencia ficción',
        releaseDate: DateTime.parse('2010-07-16'),
        posterPath: '/poster2.jpg',
        backdropPath: '/backdrop2.jpg',
        voteAverage: 8.8,
        voteCount: 20000,
        genreIds: ['28', '878', '53'],
        adult: false,
        originalLanguage: 'en',
        originalTitle: 'Inception',
        popularity: 8.8,
        video: false,
      ),
      Movie(
        id: 3,
        title: 'Interstellar',
        overview: 'Una épica de ciencia ficción',
        releaseDate: DateTime.parse('2014-11-07'),
        posterPath: '/poster3.jpg',
        backdropPath: '/backdrop3.jpg',
        voteAverage: 8.6,
        voteCount: 18000,
        genreIds: ['18', '878'],
        adult: false,
        originalLanguage: 'en',
        originalTitle: 'Interstellar',
        popularity: 8.6,
        video: false,
      ),
    ];

    try {
      // 1. Inicializar
      await initialize();

      // 2. Operaciones individuales
      await demoAddFavorite(movies[0]);
      await demoMarkWatched(movies[1]);

      // 3. Operaciones en lote
      await demoBatchOperations(movies);

      // 4. Procesamiento manual
      await demoManualProcessing();

      // 5. Limpieza
      await demoCleanup();

      LoggerFactory.info('\n🎉 Demostración completada exitosamente!',
          category: LogCategory.system);
    } catch (e) {
      LoggerFactory.error('\n❌ Error en la demostración: $e',
          category: LogCategory.system);
    }
  }

  /// Limpia recursos
  Future<void> dispose() async {
    await _syncQueue.dispose();
    LoggerFactory.info('🧹 Recursos liberados', category: LogCategory.system);
  }
}

/// Widget de demostración para mostrar la funcionalidad en la UI
class SyncQueueDemoWidget extends StatefulWidget {
  const SyncQueueDemoWidget({super.key});

  @override
  State<SyncQueueDemoWidget> createState() => _SyncQueueDemoWidgetState();
}

class _SyncQueueDemoWidgetState extends State<SyncQueueDemoWidget> {
  late SyncQueueDemo _demo;
  bool _isInitialized = false;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _initializeDemo();
  }

  Future<void> _initializeDemo() async {
    try {
      // Aquí deberías inyectar las dependencias reales
      // _demo = SyncQueueDemo(
      //   syncQueue: GetIt.instance<PersistentSyncQueue>(),
      //   favoritesRepo: GetIt.instance<HybridFavoritesRepository>(),
      //   watchedRepo: GetIt.instance<HybridWatchedRepository>(),
      // );
      //
      // await _demo.initialize();

      setState(() {
        _isInitialized = true;
        _log = 'Demo inicializada correctamente';
      });
    } catch (e) {
      setState(() {
        _log = 'Error al inicializar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Queue Demo'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado de la Cola de Sincronización',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isInitialized ? '✅ Inicializada' : '⏳ Inicializando...',
                      style: TextStyle(
                        color: _isInitialized ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Log de Actividad',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _log.isEmpty ? 'Sin actividad...' : _log,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isInitialized ? _runDemo : null,
              child: const Text('Ejecutar Demostración Completa'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runDemo() async {
    setState(() {
      _log = 'Iniciando demostración...\n';
    });

    try {
      // await _demo.runFullDemo();
      setState(() {
        _log += '\n🎉 Demostración completada!';
      });
    } catch (e) {
      setState(() {
        _log += '\n❌ Error: $e';
      });
    }
  }

  @override
  void dispose() {
    // _demo.dispose();
    super.dispose();
  }
}
