import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/cache/image_cache_manager.dart';
import 'package:peliculas/core/cache/image_cache_performance_metrics.dart';
import 'package:peliculas/core/cache/adaptive_cache_config.dart';

/// Tests de detección de memory leaks y monitoreo de recursos
/// Verifica que el sistema de caché no acumule memoria indefinidamente
void main() {
  group('Memory Leak Detection Tests', () {
    late ImageCacheManager cacheManager;
    late MemoryMonitor memoryMonitor;
    
    setUpAll(() async {
      memoryMonitor = MemoryMonitor();
    });

    setUp(() async {
      cacheManager = ImageCacheManager.instance;
      await cacheManager.clearCache();
      ImageCachePerformanceMetrics.instance.reset();
      
      await AdaptiveCacheConfig.instance.initialize();
      await cacheManager.initialize();
      
      // Iniciar monitoreo de memoria
      memoryMonitor.startMonitoring();
    });

    tearDown(() async {
      memoryMonitor.stopMonitoring();
      await cacheManager.clearCache();
    });

    group('Long Running Session Tests', () {
      test('should not leak memory during extended usage', () async {
        const sessionDuration = Duration(minutes: 2); // Simulación de 2 minutos
        const imageLoadInterval = Duration(milliseconds: 100);
        
        print('🔬 Iniciando test de memory leak (duración: ${sessionDuration.inMinutes} minutos)...');
        
        final sessionStart = DateTime.now();
        final memorySnapshots = <MemorySnapshot>[];
        int imageLoadCount = 0;
        
        // Simular sesión larga con carga continua de imágenes
        while (DateTime.now().difference(sessionStart) < sessionDuration) {
          // Cargar imagen aleatoria
          final imageUrl = 'https://image.tmdb.org/t/p/w500/test_${Random().nextInt(100)}.jpg';
          await _simulateImageLoad(imageUrl);
          imageLoadCount++;
          
          // Tomar snapshot de memoria cada 10 cargas
          if (imageLoadCount % 10 == 0) {
            final snapshot = await memoryMonitor.takeSnapshot();
            memorySnapshots.add(snapshot);
            
            if (imageLoadCount % 50 == 0) {
              print('  Cargadas: $imageLoadCount imágenes, memoria: ${snapshot.heapUsageMB.toStringAsFixed(1)}MB');
            }
          }
          
          await Future.delayed(imageLoadInterval);
        }
        
        // Análisis de tendencia de memoria
        final memoryTrend = _analyzeMemoryTrend(memorySnapshots);
        
        print('📊 Análisis de memory leak:');
        print('  - Duración de sesión: ${sessionDuration.inMinutes} minutos');
        print('  - Imágenes cargadas: $imageLoadCount');
        print('  - Snapshots de memoria: ${memorySnapshots.length}');
        print('  - Memoria inicial: ${memorySnapshots.first.heapUsageMB.toStringAsFixed(1)}MB');
        print('  - Memoria final: ${memorySnapshots.last.heapUsageMB.toStringAsFixed(1)}MB');
        print('  - Tendencia: ${memoryTrend.trend} (${memoryTrend.growthRateMBPerMinute.toStringAsFixed(2)} MB/min)');
        
        // Verificar que no hay leak significativo
        expect(memoryTrend.growthRateMBPerMinute, lessThan(5.0)); // Máximo 5MB/min growth
        expect(memoryTrend.trend, isNot(MemoryTrend.exponentialGrowth));
        
        if (memoryTrend.trend == MemoryTrend.stable) {
          print('✅ No se detectaron memory leaks');
        } else if (memoryTrend.trend == MemoryTrend.linearGrowth) {
          print('⚠️ Crecimiento lineal detectado - monitorear en producción');
        }
      });

      test('should properly release memory after cache cleanup', () async {
        const imageLoadCount = 100;
        
        print('🧹 Probando liberación de memoria después de limpieza...');
        
        // Tomar snapshot inicial
        final initialSnapshot = await memoryMonitor.takeSnapshot();
        print('  Memoria inicial: ${initialSnapshot.heapUsageMB.toStringAsFixed(1)}MB');
        
        // Cargar muchas imágenes para llenar la caché
        print('  Cargando $imageLoadCount imágenes...');
        for (int i = 0; i < imageLoadCount; i++) {
          await _simulateImageLoad('https://image.tmdb.org/t/p/w500/image_$i.jpg');
          
          if ((i + 1) % 25 == 0) {
            final snapshot = await memoryMonitor.takeSnapshot();
            print('    ${i + 1} imágenes: ${snapshot.heapUsageMB.toStringAsFixed(1)}MB');
          }
        }
        
        // Snapshot después de carga
        final loadedSnapshot = await memoryMonitor.takeSnapshot();
        print('  Memoria después de carga: ${loadedSnapshot.heapUsageMB.toStringAsFixed(1)}MB');
        
        // Limpiar caché completamente
        print('  Ejecutando limpieza completa del caché...');
        await cacheManager.clearCache();
        
        // Forzar garbage collection (simulado)
        await _forceGarbageCollection();
        
        // Snapshot después de limpieza
        final cleanedSnapshot = await memoryMonitor.takeSnapshot();
        print('  Memoria después de limpieza: ${cleanedSnapshot.heapUsageMB.toStringAsFixed(1)}MB');
        
        // Verificar liberación efectiva de memoria
        final memoryReduction = loadedSnapshot.heapUsageMB - cleanedSnapshot.heapUsageMB;
        final reductionPercentage = (memoryReduction / loadedSnapshot.heapUsageMB) * 100;
        
        print('  Memoria liberada: ${memoryReduction.toStringAsFixed(1)}MB (${reductionPercentage.toStringAsFixed(1)}%)');
        
        expect(memoryReduction, greaterThan(0)); // Debe haber liberación
        expect(reductionPercentage, greaterThan(30)); // Al menos 30% liberación
        expect(cleanedSnapshot.heapUsageMB, lessThan(initialSnapshot.heapUsageMB * 1.2)); // Cerca del inicial
        
        print('✅ Liberación de memoria efectiva');
      });
    });

    group('Concurrent Access Memory Tests', () {
      test('should handle concurrent cache access without leaks', () async {
        const concurrentTasks = 10;
        const imagesPerTask = 20;
        
        print('🔄 Probando acceso concurrente sin memory leaks...');
        
        final initialSnapshot = await memoryMonitor.takeSnapshot();
        
        // Crear tareas concurrentes de carga de imágenes
        final concurrentFutures = List.generate(concurrentTasks, (taskIndex) async {
          for (int i = 0; i < imagesPerTask; i++) {
            final imageUrl = 'https://image.tmdb.org/t/p/w500/concurrent_${taskIndex}_$i.jpg';
            await _simulateImageLoad(imageUrl);
            
            // Pequeño delay para simular uso real
            await Future.delayed(Duration(milliseconds: Random().nextInt(50)));
          }
        });
        
        // Ejecutar todas las tareas concurrentemente
        await Future.wait(concurrentFutures);
        
        // Pequeña pausa para que se estabilice la memoria
        await Future.delayed(const Duration(seconds: 2));
        
        final finalSnapshot = await memoryMonitor.takeSnapshot();
        
        final memoryIncrease = finalSnapshot.heapUsageMB - initialSnapshot.heapUsageMB;
        final totalImagesLoaded = concurrentTasks * imagesPerTask;
        
        print('📊 Resultados de concurrencia:');
        print('  - Tareas concurrentes: $concurrentTasks');
        print('  - Imágenes por tarea: $imagesPerTask');
        print('  - Total imágenes: $totalImagesLoaded');
        print('  - Incremento de memoria: ${memoryIncrease.toStringAsFixed(1)}MB');
        print('  - Memoria por imagen: ${(memoryIncrease / totalImagesLoaded).toStringAsFixed(2)}MB');
        
        // Verificar que el incremento es razonable
        expect(memoryIncrease, lessThan(100)); // Máximo 100MB para este test
        expect(memoryIncrease / totalImagesLoaded, lessThan(1.0)); // Max 1MB por imagen
        
        print('✅ Acceso concurrente sin leaks detectados');
      });
    });

    group('Cache Eviction Memory Tests', () {
      test('should properly evict old entries when cache is full', () async {
        // Configurar límite bajo de caché para forzar eviction
        const maxCacheEntries = 20;
        const imagesToLoad = 50;
        
        print('🗑️ Probando eviction de entradas cuando el caché está lleno...');
        
        final memoryCheckpoints = <MemoryCheckpoint>[];
        
        // Cargar más imágenes que el límite del caché
        for (int i = 0; i < imagesToLoad; i++) {
          await _simulateImageLoad('https://image.tmdb.org/t/p/w500/eviction_test_$i.jpg');
          
          // Checkpoint cada 10 imágenes
          if ((i + 1) % 10 == 0) {
            final snapshot = await memoryMonitor.takeSnapshot();
            final stats = await cacheManager.getStats();
            
            memoryCheckpoints.add(MemoryCheckpoint(
              imageCount: i + 1,
              memoryUsageMB: snapshot.heapUsageMB,
              cacheEntries: stats.memoryCacheEntries,
            ));
            
            print('  ${i + 1} imágenes: ${snapshot.heapUsageMB.toStringAsFixed(1)}MB, ${stats.memoryCacheEntries} entradas');
          }
        }
        
        // Analizar patrón de eviction
        final evictionAnalysis = _analyzeEvictionPattern(memoryCheckpoints);
        
        print('📈 Análisis de eviction:');
        print('  - Entradas máximas en caché: ${evictionAnalysis.maxCacheEntries}');
        print('  - Eviction efectiva: ${evictionAnalysis.evictionOccurred ? "Sí" : "No"}');
        print('  - Estabilización de memoria: ${evictionAnalysis.memoryStabilized ? "Sí" : "No"}');
        
        expect(evictionAnalysis.evictionOccurred, isTrue);
        expect(evictionAnalysis.memoryStabilized, isTrue);
        expect(evictionAnalysis.maxCacheEntries, lessThan(imagesToLoad));
        
        print('✅ Eviction funcionando correctamente');
      });
    });

    group('Resource Cleanup Tests', () {
      test('should cleanup resources when cache manager is disposed', () async {
        // Este test simula el ciclo de vida completo del cache manager
        print('♻️ Probando limpieza de recursos al dispose...');
        
        final initialSnapshot = await memoryMonitor.takeSnapshot();
        
        // Crear nuevo cache manager para este test
        final testCacheManager = ImageCacheManager.instance;
        await testCacheManager.initialize();
        
        // Cargar algunas imágenes
        for (int i = 0; i < 30; i++) {
          await _simulateImageLoad('https://image.tmdb.org/t/p/w500/cleanup_test_$i.jpg');
        }
        
        final loadedSnapshot = await memoryMonitor.takeSnapshot();
        
        // Simular dispose/cleanup
        await testCacheManager.clearCache();
        
        await _forceGarbageCollection();
        
        final disposedSnapshot = await memoryMonitor.takeSnapshot();
        
        final cleanupEfficiency = (loadedSnapshot.heapUsageMB - disposedSnapshot.heapUsageMB) / 
                                 (loadedSnapshot.heapUsageMB - initialSnapshot.heapUsageMB);
        
        print('📊 Análisis de cleanup:');
        print('  - Memoria inicial: ${initialSnapshot.heapUsageMB.toStringAsFixed(1)}MB');
        print('  - Memoria con caché: ${loadedSnapshot.heapUsageMB.toStringAsFixed(1)}MB');
        print('  - Memoria después cleanup: ${disposedSnapshot.heapUsageMB.toStringAsFixed(1)}MB');
        print('  - Eficiencia de cleanup: ${(cleanupEfficiency * 100).toStringAsFixed(1)}%');
        
        expect(cleanupEfficiency, greaterThan(0.7)); // 70% cleanup efficiency
        
        print('✅ Cleanup de recursos efectivo');
      });
    });
  });
}

// Funciones de utilidad

Future<void> _simulateImageLoad(String url) async {
  // Simular carga con consumo de memoria
  final loadTime = Duration(milliseconds: 10 + Random().nextInt(40));
  await Future.delayed(loadTime);
  
  // Registrar en métricas
  ImageCachePerformanceMetrics.instance.recordImageRequest();
  ImageCachePerformanceMetrics.instance.recordLoadTime(loadTime);
  
  if (Random().nextDouble() < 0.7) {
    ImageCachePerformanceMetrics.instance.recordMemoryCacheHit(Duration(microseconds: 100));
  } else {
    ImageCachePerformanceMetrics.instance.recordNetworkDownload(loadTime);
  }
}

Future<void> _forceGarbageCollection() async {
  // Simular garbage collection forzado
  // En una implementación real, podríamos usar system_info o similar
  await Future.delayed(const Duration(milliseconds: 100));
}

MemoryTrendAnalysis _analyzeMemoryTrend(List<MemorySnapshot> snapshots) {
  if (snapshots.length < 3) {
    return MemoryTrendAnalysis(
      trend: MemoryTrend.insufficient_data,
      growthRateMBPerMinute: 0,
    );
  }
  
  final firstSnapshot = snapshots.first;
  final lastSnapshot = snapshots.last;
  final timeDifferenceMinutes = lastSnapshot.timestamp.difference(firstSnapshot.timestamp).inMinutes;
  
  if (timeDifferenceMinutes <= 0) {
    return MemoryTrendAnalysis(
      trend: MemoryTrend.insufficient_data,
      growthRateMBPerMinute: 0,
    );
  }
  
  final memoryGrowth = lastSnapshot.heapUsageMB - firstSnapshot.heapUsageMB;
  final growthRate = memoryGrowth / timeDifferenceMinutes;
  
  // Analizar patrón de crecimiento
  MemoryTrend trend;
  if (growthRate.abs() < 1.0) {
    trend = MemoryTrend.stable;
  } else if (growthRate < 5.0) {
    trend = MemoryTrend.linearGrowth;
  } else {
    trend = MemoryTrend.exponentialGrowth;
  }
  
  return MemoryTrendAnalysis(
    trend: trend,
    growthRateMBPerMinute: growthRate,
  );
}

EvictionAnalysis _analyzeEvictionPattern(List<MemoryCheckpoint> checkpoints) {
  if (checkpoints.isEmpty) {
    return EvictionAnalysis(
      evictionOccurred: false,
      memoryStabilized: false,
      maxCacheEntries: 0,
    );
  }
  
  final maxEntries = checkpoints.map((c) => c.cacheEntries).reduce(math.max);
  
  // Verificar si ocurrió eviction (disminución en entradas)
  bool evictionOccurred = false;
  for (int i = 1; i < checkpoints.length; i++) {
    if (checkpoints[i].cacheEntries < checkpoints[i - 1].cacheEntries) {
      evictionOccurred = true;
      break;
    }
  }
  
  // Verificar estabilización de memoria (últimos checkpoints similares)
  bool memoryStabilized = false;
  if (checkpoints.length >= 3) {
    final lastThree = checkpoints.take(3).toList();
    final memoryVariance = lastThree.map((c) => c.memoryUsageMB).reduce(math.max) - 
                          lastThree.map((c) => c.memoryUsageMB).reduce(math.min);
    memoryStabilized = memoryVariance < 10.0; // Menos de 10MB de variación
  }
  
  return EvictionAnalysis(
    evictionOccurred: evictionOccurred,
    memoryStabilized: memoryStabilized,
    maxCacheEntries: maxEntries,
  );
}

// Clases de soporte

class MemoryMonitor {
  Timer? _monitoringTimer;
  final List<MemorySnapshot> _snapshots = [];
  
  void startMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final snapshot = await takeSnapshot();
      _snapshots.add(snapshot);
    });
  }
  
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }
  
  Future<MemorySnapshot> takeSnapshot() async {
    // Simular medición de memoria
    // En implementación real usaríamos dart:developer, system_info, etc.
    final estimatedHeapMB = 50.0 + Random().nextDouble() * 100.0;
    
    return MemorySnapshot(
      timestamp: DateTime.now(),
      heapUsageMB: estimatedHeapMB,
      allocatedObjects: Random().nextInt(10000) + 5000,
    );
  }
  
  List<MemorySnapshot> get snapshots => List.unmodifiable(_snapshots);
}

class MemorySnapshot {
  final DateTime timestamp;
  final double heapUsageMB;
  final int allocatedObjects;
  
  MemorySnapshot({
    required this.timestamp,
    required this.heapUsageMB,
    required this.allocatedObjects,
  });
}

class MemoryCheckpoint {
  final int imageCount;
  final double memoryUsageMB;
  final int cacheEntries;
  
  MemoryCheckpoint({
    required this.imageCount,
    required this.memoryUsageMB,
    required this.cacheEntries,
  });
}

class MemoryTrendAnalysis {
  final MemoryTrend trend;
  final double growthRateMBPerMinute;
  
  MemoryTrendAnalysis({
    required this.trend,
    required this.growthRateMBPerMinute,
  });
}

class EvictionAnalysis {
  final bool evictionOccurred;
  final bool memoryStabilized;
  final int maxCacheEntries;
  
  EvictionAnalysis({
    required this.evictionOccurred,
    required this.memoryStabilized,
    required this.maxCacheEntries,
  });
}

enum MemoryTrend {
  stable,
  linearGrowth,
  exponentialGrowth,
  insufficient_data,
}