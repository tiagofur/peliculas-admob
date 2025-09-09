import 'package:hive_flutter/hive_flutter.dart';

import '../logging/logger_factory.dart';

/// Servicio para limpiar cajas de Hive corruptas y resolver conflictos
class HiveCleanupService {
  /// Limpia solo la caja de favoritos corruptos
  static Future<void> clearFavoritesBox() async {
    LoggerFactory.warning('🧹 Limpiando caja de favoritos corruptos...');

    try {
      if (await Hive.boxExists('favorite_movies')) {
        final box = await Hive.openBox('favorite_movies');
        final itemCount = box.length;
        await box.clear();
        await box.close();

        LoggerFactory.info(
            '✅ Limpiada caja de favoritos ($itemCount elementos)');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error limpiando favoritos: $e');
      try {
        await Hive.deleteBoxFromDisk('favorite_movies');
        LoggerFactory.info('🗑️ Eliminada caja de favoritos del disco');
      } catch (e2) {
        LoggerFactory.error('❌ Error eliminando favoritos del disco: $e2');
      }
    }
  }

  /// Limpia todas las cajas relacionadas con favoritos y watchlist
  static Future<void> clearCorruptedBoxes() async {
    LoggerFactory.warning('🧹 Iniciando limpieza de cajas Hive corruptas...');

    final boxesToClear = [
      'favorite_movies',
      'watchlist_movies',
      'isar_watchlist_cache',
      'movies',
      // Fallbacks también
      'movies_fallback',
      'watchlist_movies_fallback',
      'isar_watchlist_cache_fallback',
    ];

    int clearedBoxes = 0;

    for (final boxName in boxesToClear) {
      try {
        if (await Hive.boxExists(boxName)) {
          final box = await Hive.openBox(boxName);
          final itemCount = box.length;
          await box.clear();
          await box.close();

          LoggerFactory.info(
              '✅ Limpiada caja "$boxName" ($itemCount elementos)');
          clearedBoxes++;
        }
      } catch (e) {
        LoggerFactory.error('❌ Error limpiando caja "$boxName": $e');
        // Intentar eliminar el archivo directamente si falla
        try {
          await Hive.deleteBoxFromDisk(boxName);
          LoggerFactory.info('🗑️ Eliminada caja "$boxName" del disco');
          clearedBoxes++;
        } catch (e2) {
          LoggerFactory.error(
              '❌ Error eliminando caja "$boxName" del disco: $e2');
        }
      }
    }

    LoggerFactory.info(
        '🎉 Limpieza completada: $clearedBoxes cajas procesadas');
  }

  /// Valida la integridad de las cajas de datos
  static Future<Map<String, int>> validateDataIntegrity() async {
    LoggerFactory.info('🔍 Validando integridad de datos...');

    final results = <String, int>{};

    try {
      // Validar favoritos
      if (await Hive.boxExists('favorite_movies')) {
        final favBox = await Hive.openBox('favorite_movies');
        var validCount = 0;
        for (var item in favBox.values) {
          if (item != null && item is Map) {
            // Verificar campos básicos de Movie
            if (item.containsKey('id') && item.containsKey('title')) {
              validCount++;
            }
          }
        }
        results['favorite_movies'] = validCount;
        await favBox.close();
      }

      // Validar watchlist
      if (await Hive.boxExists('watchlist_movies')) {
        final watchBox = await Hive.openBox('watchlist_movies');
        var validCount = 0;
        for (var item in watchBox.values) {
          if (item != null && item is Map) {
            // Verificar campos básicos de WatchlistMovie
            if (item.containsKey('id') && item.containsKey('movieId')) {
              validCount++;
            }
          }
        }
        results['watchlist_movies'] = validCount;
        await watchBox.close();
      }
    } catch (e) {
      LoggerFactory.error('❌ Error validando integridad: $e');
    }

    LoggerFactory.info('📊 Resultados de validación: $results');
    return results;
  }

  /// Repara automáticamente problemas detectados (versión segura)
  static Future<bool> autoRepair() async {
    LoggerFactory.info('🔧 Validando integridad de datos (modo seguro)...');

    try {
      // Solo validar, no limpiar automáticamente para evitar loops
      final integrity = await validateDataIntegrity();

      bool hasCorruption = false;
      for (final entry in integrity.entries) {
        if (entry.value == 0) {
          LoggerFactory.info('⚠️ Caja "${entry.key}" parece vacía o corrupta');
          hasCorruption = true;
        }
      }

      if (hasCorruption) {
        LoggerFactory.info(
            'ℹ️ Corrupción detectada pero será manejada por el flujo normal de la app');
      } else {
        LoggerFactory.info('✅ Integridad de datos validada correctamente');
      }

      return false; // No ejecutar limpieza automática
    } catch (e) {
      LoggerFactory.info(
          'ℹ️ Error en validación (normal en primera ejecución): $e');
      return false;
    }
  }

  /// Resetea completamente el almacenamiento local
  static Future<void> resetLocalStorage() async {
    LoggerFactory.warning('🚨 RESET COMPLETO de almacenamiento local...');

    try {
      // Cerrar todas las cajas abiertas
      await Hive.close();

      // Eliminar cajas conocidas del disco
      try {
        final knownBoxes = [
          'favorite_movies',
          'watchlist_movies',
          'isar_watchlist_cache',
          'movies',
          'watched_movies',
          'cache_metadata',
          'health_check',
        ];

        for (final boxName in knownBoxes) {
          await Hive.deleteBoxFromDisk(boxName);
        }
      } catch (e) {
        LoggerFactory.warning(
            '⚠️ Algunas cajas no se pudieron eliminar (normal en web): $e');
      }

      // Reinicializar Hive
      await Hive.initFlutter();

      LoggerFactory.info('🎉 Reset completo de almacenamiento finalizado');
    } catch (e) {
      LoggerFactory.error('❌ Error en reset completo: $e');
      rethrow;
    }
  }
}
