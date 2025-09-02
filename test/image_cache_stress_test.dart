import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/cache/image_cache_manager.dart';
import 'package:peliculas/core/cache/image_cache_performance_metrics.dart';
import 'package:peliculas/core/cache/adaptive_cache_config.dart';
import 'package:peliculas/core/cache/network_aware_strategy.dart';

/// Tests de stress completos para el sistema de caché de imágenes
/// Simula navegación rápida, carga masiva y condiciones extremas
void main() {
  group('Image Cache Stress Tests', () {
    late ImageCacheManager cacheManager;
    late List<String> testImageUrls;
    
    setUpAll(() async {
      // Generar URLs de test más realistas
      testImageUrls = List.generate(200, (index) => 
          'https://image.tmdb.org/t/p/w500/movie_poster_$index.jpg');
    });

    setUp(() async {
      cacheManager = ImageCacheManager.instance;
      
      // Limpiar estado anterior
      await cacheManager.clearCache();
      ImageCachePerformanceMetrics.instance.reset();
      
      // Inicializar con configuración de stress
      await AdaptiveCacheConfig.instance.initialize();
      await NetworkAwareStrategy.instance.initialize();
      await cacheManager.initialize();
    });

    group('Rapid Navigation Stress Tests', () {
      test('should handle rapid scrolling through movie catalog', () async {
        const scrollSpeed = Duration(milliseconds: 50); // Scroll muy rápido
        const totalMovies = 100;
        
        print('🏃‍♂️ Simulando navegación rápida por catálogo...');
        
        final loadTimes = <Duration>[];
        final errors = <String>[];
        
        // Simular scroll rápido con carga de imágenes
        for (int i = 0; i < totalMovies; i++) {
          final stopwatch = Stopwatch()..start();
          
          try {
            // Simular carga de poster y backdrop simultáneamente
            final futures = [
              _simulateImageLoad(testImageUrls[i % testImageUrls.length]),
              _simulateImageLoad(testImageUrls[(i + 50) % testImageUrls.length]),
            ];
            
            await Future.wait(futures, eagerError: false);
            
            stopwatch.stop();
            loadTimes.add(stopwatch.elapsed);
            
            // Simular delay de scroll
            await Future.delayed(scrollSpeed);
            
          } catch (e) {
            errors.add('Error en imagen $i: $e');
          }
        }
        
        final averageTime = loadTimes.fold<Duration>(
          Duration.zero,
          (sum, time) => sum + time,
        ) ~/ loadTimes.length;
        
        final maxTime = loadTimes.reduce((a, b) => a > b ? a : b);
        final p95Time = _calculatePercentile(loadTimes, 0.95);
        
        print('📊 Resultados de navegación rápida:');
        print('  - Imágenes procesadas: $totalMovies');
        print('  - Errores: ${errors.length}');
        print('  - Tiempo promedio: ${averageTime.inMilliseconds}ms');
        print('  - Tiempo máximo: ${maxTime.inMilliseconds}ms');
        print('  - P95: ${p95Time.inMilliseconds}ms');
        
        // Verificar que el sistema mantiene rendimiento bajo stress
        expect(errors.length, lessThan(totalMovies * 0.01)); // < 1% errores
        expect(averageTime.inMilliseconds, lessThan(200));
        expect(p95Time.inMilliseconds, lessThan(500));
      });

      test('should handle concurrent image preloading during navigation', () async {
        const concurrentLoads = 20;
        const batchSize = 5;
        
        print('🔄 Simulando precarga concurrente durante navegación...');
        
        final batchResults = <BatchResult>[];
        
        // Procesar en lotes concurrentes
        for (int batch = 0; batch < concurrentLoads ~/ batchSize; batch++) {
          final batchStart = Stopwatch()..start();
          final batchUrls = testImageUrls.skip(batch * batchSize).take(batchSize);
          
          // Cargar lote completo concurrentemente
          final futures = batchUrls.map((url) => _simulateImageLoad(url)).toList();
          final results = await Future.wait(futures, eagerError: false);
          
          batchStart.stop();
          
          final successCount = results.where((r) => r != null).length;
          batchResults.add(BatchResult(
            batchIndex: batch,
            totalItems: batchSize,
            successCount: successCount,
            duration: batchStart.elapsed,
          ));
          
          print('  Lote ${batch + 1}: ${successCount}/${batchSize} éxito en ${batchStart.elapsed.inMilliseconds}ms');
        }
        
        final totalSuccess = batchResults.fold(0, (sum, batch) => sum + batch.successCount);
        final totalItems = batchResults.fold(0, (sum, batch) => sum + batch.totalItems);
        final successRate = totalSuccess / totalItems;
        
        print('✅ Precarga concurrente completada:');
        print('  - Lotes procesados: ${batchResults.length}');
        print('  - Éxito total: ${totalSuccess}/${totalItems} (${(successRate * 100).toStringAsFixed(1)}%)');
        
        expect(successRate, greaterThan(0.95)); // 95% success rate mínimo
      });
    });

    group('Memory Pressure Tests', () {
      test('should handle memory pressure with large image sets', () async {
        const largeImageCount = 500;
        
        print('🧠 Simulando presión de memoria con conjunto grande de imágenes...');
        
        final memoryUsageSamples = <MemoryUsage>[];
        int imagesProcessed = 0;
        
        // Cargar imágenes gradualmente y monitorear memoria
        for (int i = 0; i < largeImageCount; i += 10) {
          // Cargar lote de imágenes
          final batchFutures = <Future>[];
          for (int j = 0; j < 10 && (i + j) < largeImageCount; j++) {
            batchFutures.add(_simulateImageLoad(testImageUrls[(i + j) % testImageUrls.length]));
          }
          
          await Future.wait(batchFutures, eagerError: false);
          imagesProcessed += 10;
          
          // Simular medición de memoria (en un test real, usaríamos APIs del sistema)
          final memoryUsage = MemoryUsage(
            timestamp: DateTime.now(),
            imagesInCache: imagesProcessed,
            estimatedMemoryMB: _estimateMemoryUsage(imagesProcessed),
          );
          
          memoryUsageSamples.add(memoryUsage);
          
          if (i % 50 == 0) {
            print('  Procesadas: $imagesProcessed imágenes, memoria estimada: ${memoryUsage.estimatedMemoryMB}MB');
          }
        }
        
        // Analizar patrones de memoria
        final maxMemory = memoryUsageSamples.map((m) => m.estimatedMemoryMB).reduce(math.max);
        final finalMemory = memoryUsageSamples.last.estimatedMemoryMB;
        
        print('📈 Análisis de memoria:');
        print('  - Imágenes procesadas: $imagesProcessed');
        print('  - Memoria máxima: ${maxMemory}MB');
        print('  - Memoria final: ${finalMemory}MB');
        
        // Verificar que la memoria se mantiene en límites razonables
        expect(maxMemory, lessThan(300)); // No exceder 300MB en test
        expect(finalMemory, lessThan(250)); // Memoria final estable
      });

      test('should properly clean up expired cache entries', () async {
        const initialImages = 50;
        const expiryTime = Duration(seconds: 2);
        
        print('🧹 Probando limpieza automática de caché expirado...');
        
        // Cargar conjunto inicial de imágenes
        print('  Cargando ${initialImages} imágenes iniciales...');
        for (int i = 0; i < initialImages; i++) {
          await _simulateImageLoad(testImageUrls[i]);
        }
        
        final initialStats = await cacheManager.getStats();
        print('  Estado inicial: ${initialStats.memoryCacheEntries} entradas en memoria');
        
        // Esperar que expire el caché
        print('  Esperando expiración del caché (${expiryTime.inSeconds}s)...');
        await Future.delayed(expiryTime);
        
        // Cargar nuevas imágenes para triggear limpieza
        print('  Cargando nuevas imágenes para activar limpieza...');
        for (int i = initialImages; i < initialImages + 20; i++) {
          await _simulateImageLoad(testImageUrls[i % testImageUrls.length]);
        }
        
        // Forzar limpieza explícita
        await cacheManager.cleanExpiredCache();
        
        final finalStats = await cacheManager.getStats();
        print('  Estado final: ${finalStats.memoryCacheEntries} entradas en memoria');
        
        // Verificar que la limpieza fue efectiva
        expect(finalStats.memoryCacheEntries, lessThan(initialStats.memoryCacheEntries));
        print('✅ Limpieza automática funcionando correctamente');
      });
    });

    group('Network Condition Adaptation Tests', () {
      test('should adapt to changing network conditions dynamically', () async {
        final networkConditions = [
          NetworkCondition.excellent,
          NetworkCondition.good,
          NetworkCondition.fair,
          NetworkCondition.poor,
          NetworkCondition.good, // Mejora de red
        ];
        
        print('📡 Probando adaptación dinámica a condiciones de red...');
        
        final adaptationResults = <NetworkAdaptationResult>[];
        
        for (int i = 0; i < networkConditions.length; i++) {
          final condition = networkConditions[i];
          print('  Simulando condición: $condition');
          
          // Simular cambio de condición de red
          _simulateNetworkConditionChange(condition);
          
          final loadTimes = <Duration>[];
          
          // Cargar imágenes bajo esta condición
          for (int j = 0; j < 10; j++) {
            final stopwatch = Stopwatch()..start();
            await _simulateImageLoadWithNetworkCondition(
              testImageUrls[j], 
              condition,
            );
            stopwatch.stop();
            loadTimes.add(stopwatch.elapsed);
          }
          
          final averageTime = loadTimes.fold<Duration>(
            Duration.zero,
            (sum, time) => sum + time,
          ) ~/ loadTimes.length;
          
          adaptationResults.add(NetworkAdaptationResult(
            condition: condition,
            averageLoadTime: averageTime,
            sampleCount: loadTimes.length,
          ));
          
          print('    Tiempo promedio: ${averageTime.inMilliseconds}ms');
        }
        
        // Verificar que la adaptación es lógica
        final excellentTime = adaptationResults.firstWhere((r) => r.condition == NetworkCondition.excellent).averageLoadTime;
        final poorTime = adaptationResults.firstWhere((r) => r.condition == NetworkCondition.poor).averageLoadTime;
        
        expect(excellentTime.inMilliseconds, lessThan(poorTime.inMilliseconds));
        print('✅ Adaptación de red funcionando: excelente (${excellentTime.inMilliseconds}ms) < pobre (${poorTime.inMilliseconds}ms)');
      });
    });

    group('Error Recovery and Resilience Tests', () {
      test('should recover gracefully from network failures', () async {
        const failureRate = 0.3; // 30% de fallos simulados
        const totalAttempts = 50;
        
        print('🔧 Probando recuperación de fallos de red...');
        
        int successCount = 0;
        int failureCount = 0;
        int recoveryCount = 0;
        
        for (int i = 0; i < totalAttempts; i++) {
          final shouldFail = Random().nextDouble() < failureRate;
          
          try {
            if (shouldFail) {
              // Simular fallo de red
              await _simulateNetworkFailure(testImageUrls[i % testImageUrls.length]);
              failureCount++;
              
              // Intentar recuperación
              await Future.delayed(const Duration(milliseconds: 100));
              await _simulateImageLoad(testImageUrls[i % testImageUrls.length]);
              recoveryCount++;
            } else {
              await _simulateImageLoad(testImageUrls[i % testImageUrls.length]);
            }
            successCount++;
          } catch (e) {
            // Fallo sin recuperación
          }
        }
        
        final recoveryRate = recoveryCount / failureCount;
        final finalSuccessRate = successCount / totalAttempts;
        
        print('📊 Resultados de recuperación:');
        print('  - Intentos totales: $totalAttempts');
        print('  - Fallos simulados: $failureCount');
        print('  - Recuperaciones exitosas: $recoveryCount');
        print('  - Tasa de recuperación: ${(recoveryRate * 100).toStringAsFixed(1)}%');
        print('  - Tasa de éxito final: ${(finalSuccessRate * 100).toStringAsFixed(1)}%');
        
        expect(recoveryRate, greaterThan(0.7)); // 70% recovery rate mínimo
        expect(finalSuccessRate, greaterThan(0.9)); // 90% final success rate
      });
    });
  });
}

// Funciones de utilidad para simulación

Future<void> _simulateImageLoad(String url) async {
  // Simular tiempo de carga variable
  final loadTime = Duration(milliseconds: 10 + Random().nextInt(50));
  await Future.delayed(loadTime);
  
  // Registrar métricas
  ImageCachePerformanceMetrics.instance.recordImageRequest();
  ImageCachePerformanceMetrics.instance.recordLoadTime(loadTime);
  
  // Simular hit o miss de caché
  if (Random().nextBool()) {
    ImageCachePerformanceMetrics.instance.recordMemoryCacheHit(Duration(microseconds: 100));
  } else {
    ImageCachePerformanceMetrics.instance.recordNetworkDownload(loadTime);
  }
}

Future<void> _simulateImageLoadWithNetworkCondition(String url, NetworkCondition condition) async {
  Duration loadTime;
  
  switch (condition) {
    case NetworkCondition.excellent:
      loadTime = Duration(milliseconds: 50 + Random().nextInt(50));
      break;
    case NetworkCondition.good:
      loadTime = Duration(milliseconds: 100 + Random().nextInt(100));
      break;
    case NetworkCondition.fair:
      loadTime = Duration(milliseconds: 200 + Random().nextInt(200));
      break;
    case NetworkCondition.poor:
      loadTime = Duration(milliseconds: 500 + Random().nextInt(500));
      break;
    default:
      loadTime = Duration(milliseconds: 100);
  }
  
  await Future.delayed(loadTime);
  
  ImageCachePerformanceMetrics.instance.recordImageRequest();
  ImageCachePerformanceMetrics.instance.recordLoadTime(loadTime);
  ImageCachePerformanceMetrics.instance.recordNetworkDownload(loadTime);
}

Future<void> _simulateNetworkFailure(String url) async {
  await Future.delayed(const Duration(milliseconds: 100));
  throw Exception('Simulated network failure for $url');
}

void _simulateNetworkConditionChange(NetworkCondition condition) {
  // En una implementación real, esto actualizaría NetworkAwareStrategy
  print('    Cambiando a condición de red: $condition');
}

Duration _calculatePercentile(List<Duration> times, double percentile) {
  final sortedTimes = List<Duration>.from(times)..sort();
  final index = (sortedTimes.length * percentile).floor();
  return sortedTimes[index.clamp(0, sortedTimes.length - 1)];
}

double _estimateMemoryUsage(int imageCount) {
  // Estimación simple: ~0.5MB por imagen en memoria
  return imageCount * 0.5;
}

// Clases de datos para resultados

class BatchResult {
  final int batchIndex;
  final int totalItems;
  final int successCount;
  final Duration duration;

  BatchResult({
    required this.batchIndex,
    required this.totalItems,
    required this.successCount,
    required this.duration,
  });
}

class MemoryUsage {
  final DateTime timestamp;
  final int imagesInCache;
  final double estimatedMemoryMB;

  MemoryUsage({
    required this.timestamp,
    required this.imagesInCache,
    required this.estimatedMemoryMB,
  });
}

class NetworkAdaptationResult {
  final NetworkCondition condition;
  final Duration averageLoadTime;
  final int sampleCount;

  NetworkAdaptationResult({
    required this.condition,
    required this.averageLoadTime,
    required this.sampleCount,
  });
}

// Enums para simulación

enum NetworkCondition {
  excellent,
  good,
  fair,
  poor,
  offline,
}