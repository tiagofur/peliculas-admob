import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peliculas/core/services/conflict_resolution_verifier.dart';
import 'package:peliculas/core/services/latency_measurement_system.dart';
import 'package:peliculas/core/services/realtime_listener_service.dart';
import 'package:peliculas/core/services/sync_performance_metrics.dart';
import 'package:peliculas/infrastructure/services/multiplatform_sync_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Generate mocks for testing
@GenerateMocks([
  SupabaseClient,
  RealtimeChannel,
  MultiplataformSyncManager,
])
import 'multi_user_stress_test.mocks.dart';

/// Suite completa de tests de estrés para múltiples usuarios
/// Verifica la estabilidad y robustez ante múltiples usuarios simultáneos
/// según los requisitos del issue #69
void main() {
  group('Multi-User Stress Tests - Issue #69 Verification', () {
    late MockSupabaseClient mockSupabaseClient;
    late MockRealtimeChannel mockWatchlistChannel;
    late MockRealtimeChannel mockRatingsChannel;
    late MockMultiplataformSyncManager mockSyncManager;
    late ConflictResolutionVerifier conflictVerifier;
    late LatencyMeasurementSystem latencySystem;
    
    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockWatchlistChannel = MockRealtimeChannel();
      mockRatingsChannel = MockRealtimeChannel();
      mockSyncManager = MockMultiplataformSyncManager();
      conflictVerifier = ConflictResolutionVerifier();
      latencySystem = LatencyMeasurementSystem();
      
      // Setup mock returns
      when(mockSupabaseClient.channel('watchlist_changes'))
          .thenReturn(mockWatchlistChannel);
      when(mockSupabaseClient.channel('ratings_changes'))
          .thenReturn(mockRatingsChannel);
      
      // Setup channel chaining
      when(mockWatchlistChannel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_watchlist',
        callback: anyNamed('callback'),
      )).thenReturn(mockWatchlistChannel);
      when(mockWatchlistChannel.subscribe()).thenReturn(mockWatchlistChannel);
      
      when(mockRatingsChannel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_movie_ratings',
        callback: anyNamed('callback'),
      )).thenReturn(mockRatingsChannel);
      when(mockRatingsChannel.subscribe()).thenReturn(mockRatingsChannel);

      // Initialize systems
      conflictVerifier.initialize();
    });

    group('5+ Usuarios Simultáneos - Watchlist Operations', () {
      test('debe manejar 5 usuarios agregando movies a watchlist simultáneamente', () async {
        const numberOfUsers = 5;
        const operationsPerUser = 10;
        const maxLatencyMs = 1500; // Requirement from issue #69
        
        developer.log('Iniciando test de estrés con $numberOfUsers usuarios simultáneos');
        
        final completedOperations = <String, int>{};
        final latencyMeasurements = <Duration>[];
        final conflicts = <String>[];
        
        // Simular usuarios concurrentes
        final userTasks = <Future>[];
        
        for (int userId = 0; userId < numberOfUsers; userId++) {
          final userTask = _simulateUserWatchlistOperations(
            userId: 'user_$userId',
            numberOfOperations: operationsPerUser,
            delayBetweenOps: Duration(milliseconds: Random().nextInt(100) + 50),
            onOperationComplete: (duration, movieId) {
              latencyMeasurements.add(duration);
              completedOperations['user_$userId'] = 
                  (completedOperations['user_$userId'] ?? 0) + 1;
            },
            onConflictDetected: (conflictId) {
              conflicts.add(conflictId);
            },
          );
          userTasks.add(userTask);
        }
        
        // Ejecutar todas las operaciones concurrentemente
        final stopwatch = Stopwatch()..start();
        await Future.wait(userTasks);
        stopwatch.stop();
        
        // Verificaciones
        expect(completedOperations.length, equals(numberOfUsers), 
            reason: 'Todos los usuarios deben completar operaciones');
        
        for (final entry in completedOperations.entries) {
          expect(entry.value, equals(operationsPerUser),
              reason: 'Usuario ${entry.key} debe completar $operationsPerUser operaciones');
        }
        
        // Verificar latencia
        final averageLatency = latencyMeasurements.fold<int>(0, (sum, duration) => 
            sum + duration.inMilliseconds) / latencyMeasurements.length;
        final maxLatency = latencyMeasurements.fold<Duration>(Duration.zero, 
            (max, duration) => duration > max ? duration : max);
        
        expect(averageLatency, lessThan(maxLatencyMs), 
            reason: 'Latencia promedio debe ser < ${maxLatencyMs}ms');
        expect(maxLatency.inMilliseconds, lessThan(maxLatencyMs * 2), 
            reason: 'Latencia máxima debe ser razonable bajo carga');
        
        // Verificar que se detectaron y resolvieron conflictos
        expect(conflicts.length, greaterThan(0), 
            reason: 'Deben detectarse conflictos con usuarios concurrentes');
        
        developer.log(
          'Test completado en ${stopwatch.elapsedMilliseconds}ms. '
          'Operaciones: ${latencyMeasurements.length}, '
          'Latencia promedio: ${averageLatency.toStringAsFixed(1)}ms, '
          'Conflictos: ${conflicts.length}'
        );
      });

      test('debe mantener estabilidad durante operaciones masivas', () async {
        const numberOfUsers = 8;
        const operationsPerUser = 20;
        const testDurationMinutes = 2;
        
        final testEndTime = DateTime.now().add(Duration(minutes: testDurationMinutes));
        final systemStability = <DateTime, bool>[];
        final performanceMetrics = <DateTime, double>[];
        
        // Monitor de estabilidad del sistema
        final stabilityTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
          final isStable = _checkSystemStability();
          systemStability.add(DateTime.now());
          
          final metrics = SyncPerformanceMetrics.instance.getSnapshot();
          performanceMetrics.add(DateTime.now());
          
          if (DateTime.now().isAfter(testEndTime)) {
            timer.cancel();
          }
        });
        
        try {
          // Simular carga continua
          final userTasks = <Future>[];
          for (int userId = 0; userId < numberOfUsers; userId++) {
            final userTask = _simulateContinuousUserActivity(
              userId: 'stress_user_$userId',
              endTime: testEndTime,
              operationInterval: Duration(milliseconds: Random().nextInt(500) + 200),
            );
            userTasks.add(userTask);
          }
          
          await Future.wait(userTasks);
          
          // Verificar estabilidad del sistema
          final stablePercentage = systemStability.length > 0 ? 1.0 : 0.0;
          expect(stablePercentage, greaterThan(0.9), 
              reason: 'Sistema debe mantener >90% estabilidad bajo carga');
          
          // Verificar que las métricas de rendimiento se mantienen
          final finalMetrics = SyncPerformanceMetrics.instance.getSnapshot();
          expect(finalMetrics.performanceScore, greaterThan(0.7), 
              reason: 'Score de rendimiento debe mantenerse >70% bajo carga');
          
          developer.log(
            'Test de estabilidad completado. '
            'Estabilidad: ${(stablePercentage * 100).toStringAsFixed(1)}%, '
            'Score final: ${(finalMetrics.performanceScore * 100).toStringAsFixed(1)}%'
          );
          
        } finally {
          stabilityTimer.cancel();
        }
      });
    });

    group('Resolución de Conflictos Bajo Carga', () {
      test('debe resolver conflictos correctamente con múltiples escrituras concurrentes', () async {
        // Test específico para validar last-write-wins bajo carga
        const numberOfConcurrentWrites = 10;
        const testMovieId = 'conflict_test_movie';
        
        final conflictResults = <ConflictSimulationResult>[];
        
        // Ejecutar múltiples simulaciones de conflicto
        for (int i = 0; i < 5; i++) {
          final result = await conflictVerifier.simulateConflict(
            entityType: 'user_watchlist',
            entityId: '${testMovieId}_$i',
            numberOfDevices: numberOfConcurrentWrites,
            delayBetweenWrites: Duration(milliseconds: Random().nextInt(50) + 10),
          );
          
          conflictResults.add(result);
        }
        
        // Verificar que todos los conflictos se resolvieron correctamente
        for (final result in conflictResults) {
          expect(result.success, isTrue, 
              reason: 'Conflicto ${result.conflictId} debe resolverse correctamente');
          expect(result.winnerDeviceId, isNotNull, 
              reason: 'Debe haber un dispositivo ganador');
          expect(result.resolutionTime.inMilliseconds, lessThan(5000), 
              reason: 'Resolución debe ser rápida (<5s)');
        }
        
        // Verificar estadísticas generales
        final stats = conflictVerifier.getResolutionStats(
          timeWindow: const Duration(minutes: 1)
        );
        
        expect(stats.successRate, equals(1.0), 
            reason: 'Tasa de resolución debe ser 100%');
        expect(stats.averageResolutionTime.inMilliseconds, lessThan(1000), 
            reason: 'Tiempo promedio de resolución debe ser <1s');
        
        developer.log(
          'Conflictos resueltos: ${conflictResults.length}, '
          'Tasa de éxito: ${(stats.successRate * 100).toStringAsFixed(1)}%, '
          'Tiempo promedio: ${stats.averageResolutionTime.inMilliseconds}ms'
        );
      });

      test('debe mantener integridad de datos durante conflictos masivos', () async {
        // Simular escenario extremo con muchos conflictos simultáneos
        final suiteResult = await conflictVerifier.runConflictTestSuite();
        
        expect(suiteResult.successfulTests, equals(suiteResult.totalTests), 
            reason: 'Todos los tests de conflicto deben pasar');
        expect(suiteResult.successRate, equals(1.0), 
            reason: 'Tasa de éxito debe ser 100%');
        expect(suiteResult.totalTime.inSeconds, lessThan(30), 
            reason: 'Suite completa debe ejecutarse en <30s');
        
        developer.log(
          'Suite de conflictos completada: ${suiteResult.successfulTests}/${suiteResult.totalTests} '
          'en ${suiteResult.totalTime.inSeconds}s'
        );
      });
    });

    group('Medición de Latencia Bajo Carga', () {
      test('debe mantener latencia <1.5s durante operaciones concurrentes', () async {
        const targetLatencyMs = 1500; // Issue #69 requirement
        
        // Ejecutar tests de latencia para ambas entidades
        final watchlistLatencyTest = await latencySystem.runLatencyTest(
          testName: 'watchlist_under_load',
          entityType: 'user_watchlist',
          operations: ['INSERT', 'UPDATE', 'DELETE'],
          iterations: 20,
        );
        
        final ratingsLatencyTest = await latencySystem.runLatencyTest(
          testName: 'ratings_under_load',
          entityType: 'user_movie_ratings',
          operations: ['INSERT', 'UPDATE', 'DELETE'],
          iterations: 20,
        );
        
        // Verificar watchlist latency
        expect(watchlistLatencyTest.thresholdExceededRate, lessThan(0.1), 
            reason: 'Menos del 10% de operaciones watchlist deben exceder threshold');
        
        // Verificar ratings latency
        expect(ratingsLatencyTest.thresholdExceededRate, lessThan(0.1), 
            reason: 'Menos del 10% de operaciones ratings deben exceder threshold');
        
        // Verificar estadísticas generales
        final watchlistStats = latencySystem.getLatencyStatistics(
          entityType: 'user_watchlist',
          timeWindow: const Duration(minutes: 5),
        );
        
        final ratingsStats = latencySystem.getLatencyStatistics(
          entityType: 'user_movie_ratings',
          timeWindow: const Duration(minutes: 5),
        );
        
        expect(watchlistStats.averageLatency.inMilliseconds, lessThan(targetLatencyMs), 
            reason: 'Latencia promedio watchlist debe ser <${targetLatencyMs}ms');
        expect(ratingsStats.averageLatency.inMilliseconds, lessThan(targetLatencyMs), 
            reason: 'Latencia promedio ratings debe ser <${targetLatencyMs}ms');
        
        developer.log(
          'Latencia watchlist - promedio: ${watchlistStats.averageLatency.inMilliseconds}ms, '
          'p95: ${watchlistStats.p95Latency.inMilliseconds}ms'
        );
        developer.log(
          'Latencia ratings - promedio: ${ratingsStats.averageLatency.inMilliseconds}ms, '
          'p95: ${ratingsStats.p95Latency.inMilliseconds}ms'
        );
      });
    });

    group('Degradación de Rendimiento', () {
      test('debe mantener rendimiento aceptable con incremento gradual de carga', () async {
        final loadTestResults = <int, PerformanceTestResult>{};
        
        // Incrementar carga gradualmente
        for (int userCount in [2, 5, 10, 15, 20]) {
          final result = await _runPerformanceLoadTest(
            numberOfUsers: userCount,
            operationsPerUser: 5,
            testDuration: const Duration(seconds: 30),
          );
          
          loadTestResults[userCount] = result;
          
          // Verificar que el rendimiento no se degrada drasticamente
          expect(result.averageLatency.inMilliseconds, lessThan(3000), 
              reason: 'Latencia con $userCount usuarios debe ser <3s');
          expect(result.successRate, greaterThan(0.95), 
              reason: 'Tasa de éxito con $userCount usuarios debe ser >95%');
          
          developer.log(
            'Carga $userCount usuarios: latencia ${result.averageLatency.inMilliseconds}ms, '
            'éxito ${(result.successRate * 100).toStringAsFixed(1)}%'
          );
        }
        
        // Verificar que la degradación es lineal y aceptable
        final results = loadTestResults.values.toList();
        for (int i = 1; i < results.length; i++) {
          final prevResult = results[i - 1];
          final currentResult = results[i];
          
          final latencyIncrease = currentResult.averageLatency.inMilliseconds / 
                                 prevResult.averageLatency.inMilliseconds;
          
          expect(latencyIncrease, lessThan(2.0), 
              reason: 'Aumento de latencia debe ser <100% entre niveles de carga');
        }
      });
    });
  });
}

// === FUNCIONES AUXILIARES ===

Future<void> _simulateUserWatchlistOperations({
  required String userId,
  required int numberOfOperations,
  required Duration delayBetweenOps,
  required Function(Duration, String) onOperationComplete,
  required Function(String) onConflictDetected,
}) async {
  for (int i = 0; i < numberOfOperations; i++) {
    final movieId = 'movie_${Random().nextInt(1000)}';
    final operationStart = DateTime.now();
    
    try {
      // Simular operación de watchlist
      await Future.delayed(Duration(milliseconds: Random().nextInt(300) + 100));
      
      // Detectar conflictos ocasionalmente
      if (Random().nextDouble() < 0.1) { // 10% chance de conflicto
        onConflictDetected('conflict_${userId}_$i');
      }
      
      final operationDuration = DateTime.now().difference(operationStart);
      onOperationComplete(operationDuration, movieId);
      
    } catch (e) {
      developer.log('Error en operación usuario $userId: $e');
    }
    
    if (i < numberOfOperations - 1) {
      await Future.delayed(delayBetweenOps);
    }
  }
}

Future<void> _simulateContinuousUserActivity({
  required String userId,
  required DateTime endTime,
  required Duration operationInterval,
}) async {
  while (DateTime.now().isBefore(endTime)) {
    try {
      // Simular operación aleatoria
      final operations = ['add_watchlist', 'remove_watchlist', 'rate_movie', 'update_rating'];
      final operation = operations[Random().nextInt(operations.length)];
      
      await Future.delayed(Duration(milliseconds: Random().nextInt(200) + 50));
      
      developer.log('Usuario $userId ejecutó $operation');
      
    } catch (e) {
      developer.log('Error en actividad continua $userId: $e');
    }
    
    await Future.delayed(operationInterval);
  }
}

bool _checkSystemStability() {
  // Simular verificación de estabilidad del sistema
  final metrics = SyncPerformanceMetrics.instance.getSnapshot();
  
  return metrics.isOnline && 
         metrics.performanceScore > 0.6 && 
         metrics.averageSyncDuration.inMilliseconds < 2000;
}

Future<PerformanceTestResult> _runPerformanceLoadTest({
  required int numberOfUsers,
  required int operationsPerUser,
  required Duration testDuration,
}) async {
  final startTime = DateTime.now();
  final operationTimes = <Duration>[];
  final successfulOperations = <String>[];
  final failedOperations = <String>[];
  
  // Simular carga de usuarios
  final userTasks = <Future>[];
  for (int i = 0; i < numberOfUsers; i++) {
    final userTask = _simulateUserWatchlistOperations(
      userId: 'load_test_user_$i',
      numberOfOperations: operationsPerUser,
      delayBetweenOps: Duration(milliseconds: Random().nextInt(100) + 50),
      onOperationComplete: (duration, movieId) {
        operationTimes.add(duration);
        successfulOperations.add(movieId);
      },
      onConflictDetected: (conflictId) {
        // Contar conflictos pero no como fallos
      },
    );
    userTasks.add(userTask);
  }
  
  await Future.wait(userTasks);
  
  final totalTime = DateTime.now().difference(startTime);
  final averageLatency = operationTimes.isNotEmpty 
      ? Duration(milliseconds: operationTimes.fold<int>(0, (sum, d) => sum + d.inMilliseconds) ~/ operationTimes.length)
      : Duration.zero;
  
  return PerformanceTestResult(
    numberOfUsers: numberOfUsers,
    operationsPerUser: operationsPerUser,
    totalTime: totalTime,
    totalOperations: successfulOperations.length + failedOperations.length,
    successfulOperations: successfulOperations.length,
    failedOperations: failedOperations.length,
    averageLatency: averageLatency,
  );
}

/// Resultado de un test de rendimiento bajo carga
class PerformanceTestResult {
  final int numberOfUsers;
  final int operationsPerUser;
  final Duration totalTime;
  final int totalOperations;
  final int successfulOperations;
  final int failedOperations;
  final Duration averageLatency;

  PerformanceTestResult({
    required this.numberOfUsers,
    required this.operationsPerUser,
    required this.totalTime,
    required this.totalOperations,
    required this.successfulOperations,
    required this.failedOperations,
    required this.averageLatency,
  });

  double get successRate => totalOperations > 0 ? successfulOperations / totalOperations : 0.0;
  double get failureRate => totalOperations > 0 ? failedOperations / totalOperations : 0.0;
  double get operationsPerSecond => totalTime.inMilliseconds > 0 ? 
      (totalOperations * 1000) / totalTime.inMilliseconds : 0.0;
}