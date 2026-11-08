import 'dart:async';

import 'package:flutter/material.dart';

import '../logging/logger_factory.dart';
import '../../domain/entities/syncable_entity.dart';
import '../../presentation/widgets/sync/conflict_resolution_dialog.dart';
import 'entity_sync_manager.dart';
import 'sync_utilities.dart';
import 'conflict_resolution/strategies/conflict_strategy.dart';
import 'conflict_resolution/advanced_conflict_resolver.dart';

/// Motor de resolución de conflictos para entidades sincronizables
class ConflictResolver {
  ConflictResolver({
    Map<String, ConflictStrategy>? defaultStrategies,
    ConflictStrategyConfig? advancedConfig,
  })  : _defaultStrategies = defaultStrategies ?? _getDefaultStrategies(),
        _advancedResolver =
            AdvancedConflictResolver(strategyConfig: advancedConfig);

  final Map<String, ConflictStrategy> _defaultStrategies;
  final Map<String, int> _resolutionStats = {};
  final AdvancedConflictResolver _advancedResolver;

  /// Estrategias por defecto para diferentes tipos de entidades
  static Map<String, ConflictStrategy> _getDefaultStrategies() {
    return {
      'favorite': ConflictStrategy.localWins, // Favoritos: preferencia local
      'watchlist': ConflictStrategy.merge, // Watchlist: fusionar listas
      'custom_list':
          ConflictStrategy.userChoice, // Listas: decisión del usuario
      'watched_movie':
          ConflictStrategy.localWins, // Visto: info local más reciente
      'rating': ConflictStrategy.localWins, // Calificaciones: opinión local
    };
  }

  /// Resuelve un conflicto usando la estrategia apropiada
  Future<ConflictResolution> resolveConflict<T extends SyncableEntity>(
    ConflictInfo<T> conflict, {
    ConflictStrategy? overrideStrategy,
  }) async {
    final strategy = overrideStrategy ??
        _defaultStrategies[conflict.localEntity.entityType] ??
        ConflictStrategy.remoteWins;

    LoggerFactory.info(
        '⚖️ Resolving ${conflict.conflictType.name} conflict for ${conflict.localEntity.entityType} using ${strategy.name}');

    final resolvedEntity = await _applyStrategy(conflict, strategy);
    _updateStats(conflict.localEntity.entityType, strategy);

    return ConflictResolution(
      strategy: strategy,
      resolvedAt: SyncUtilities.utcNow(),
      resolvedEntity: resolvedEntity,
      reason: _getResolutionReason(conflict.conflictType, strategy),
    );
  }

  /// Aplica la estrategia de resolución específica
  Future<SyncableEntity> _applyStrategy<T extends SyncableEntity>(
    ConflictInfo<T> conflict,
    ConflictStrategy strategy,
  ) async {
    switch (strategy) {
      case ConflictStrategy.localWins:
        return _resolveLocalWins(conflict);

      case ConflictStrategy.remoteWins:
        return _resolveRemoteWins(conflict);

      case ConflictStrategy.merge:
        return _resolveMerge(conflict);

      case ConflictStrategy.userChoice:
        return await _resolveUserChoice(conflict);
    }
  }

  /// Estrategia: Local wins
  SyncableEntity _resolveLocalWins<T extends SyncableEntity>(
      ConflictInfo<T> conflict) {
    LoggerFactory.debug(
        '🏠 Local wins resolution for ${conflict.localEntity.entityType}');

    // Actualizar metadatos de sync para reflejar la resolución
    return conflict.localEntity.copyWith(
      lastModifiedAt: SyncUtilities.utcNow(),
      syncVersion: conflict.localEntity.syncVersion + 1,
      deviceId: null, // Will be set by sync manager
    );
  }

  /// Estrategia: Remote wins
  SyncableEntity _resolveRemoteWins<T extends SyncableEntity>(
      ConflictInfo<T> conflict) {
    LoggerFactory.debug(
        '🌐 Remote wins resolution for ${conflict.remoteEntity.entityType}');

    // Usar la entidad remota pero actualizar campos de tracking local
    return conflict.remoteEntity.copyWith(
      lastModifiedAt: SyncUtilities.utcNow(),
      syncVersion: conflict.remoteEntity.syncVersion,
    );
  }

  /// Estrategia: Merge
  SyncableEntity _resolveMerge<T extends SyncableEntity>(
      ConflictInfo<T> conflict) {
    LoggerFactory.debug(
        '🔀 Merge resolution for ${conflict.localEntity.entityType}');

    try {
      // Usar el método mergeWith de la entidad
      final merged = conflict.localEntity.mergeWith(conflict.remoteEntity);

      // Actualizar metadatos de sync
      return merged.copyWith(
        lastModifiedAt: SyncUtilities.utcNow(),
        syncVersion: (conflict.localEntity.syncVersion >
                    conflict.remoteEntity.syncVersion
                ? conflict.localEntity.syncVersion
                : conflict.remoteEntity.syncVersion) +
            1,
      );
    } catch (e) {
      LoggerFactory.warning('⚠️ Merge failed, falling back to local wins: $e');
      return _resolveLocalWins(conflict);
    }
  }

  /// Estrategia: User choice (por ahora fallback a local wins)
  Future<SyncableEntity> _resolveUserChoice<T extends SyncableEntity>(
      ConflictInfo<T> conflict) async {
    LoggerFactory.debug(
        '👤 User choice resolution requested for ${conflict.localEntity.entityType}');

    try {
      // Importar el contexto de navegación si está disponible
      final context = _getCurrentContext();
      if (context == null) {
        LoggerFactory.warning(
            '⚠️ No navigation context available, falling back to local wins');
        return _resolveLocalWins(conflict);
      }

      // Mostrar diálogo de resolución de conflictos
      final completer = Completer<ConflictResolution>();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return ConflictResolutionDialog<T>(
            conflict: conflict,
            onResolved: (resolution) {
              completer.complete(resolution);
              Navigator.of(dialogContext).pop();
            },
            allowMerge: true,
            showPreview: true,
          );
        },
      );

      // Esperar la resolución del usuario
      final resolution = await completer.future;

      LoggerFactory.info(
          '✅ User resolved conflict using strategy: ${resolution.strategy.name}');

      return resolution.resolvedEntity;
    } catch (e) {
      LoggerFactory.error('❌ Error showing conflict resolution UI: $e');
      LoggerFactory.info('ℹ️ Falling back to local wins due to UI error');
      return _resolveLocalWins(conflict);
    }
  }

  /// Detecta conflictos entre dos entidades
  ConflictInfo<T>? detectConflict<T extends SyncableEntity>(T local, T remote) {
    if (local.id != remote.id || local.entityType != remote.entityType) {
      throw ArgumentError('Cannot compare different entities');
    }

    // Si ambas tienen el mismo checksum, no hay conflicto
    if (local.hasSameContentAs(remote)) {
      return null;
    }

    // Determinar tipo de conflicto
    final conflictType = _determineConflictType(local, remote);

    return ConflictInfo<T>(
      localEntity: local,
      remoteEntity: remote,
      conflictType: conflictType,
      detectedAt: SyncUtilities.utcNow(),
      metadata: {
        'local_version': local.syncVersion,
        'remote_version': remote.syncVersion,
        'local_modified': local.lastModifiedAt.toIso8601String(),
        'remote_modified': remote.lastModifiedAt.toIso8601String(),
        'local_checksum': local.generateChecksum(),
        'remote_checksum': remote.generateChecksum(),
      },
    );
  }

  /// Determina el tipo de conflicto
  ConflictType _determineConflictType<T extends SyncableEntity>(
      T local, T remote) {
    // Conflicto de eliminación vs modificación
    if (local.isDeleted != remote.isDeleted) {
      return ConflictType.deleteVsModify;
    }

    // Conflicto de modificación concurrente
    if (!local.isDeleted && !remote.isDeleted) {
      // Verificar si las modificaciones se solapan en tiempo
      final timeDiff =
          local.lastModifiedAt.difference(remote.lastModifiedAt).abs();
      if (timeDiff < const Duration(minutes: 5)) {
        // Umbral de concurrencia
        return ConflictType.concurrentModification;
      }
    }

    // Por defecto, asumir modificación concurrente
    return ConflictType.concurrentModification;
  }

  /// Detecta múltiples conflictos en una lista de entidades
  Future<List<ConflictInfo<T>>> detectConflicts<T extends SyncableEntity>(
    List<T> localEntities,
    List<T> remoteEntities,
  ) async {
    final conflicts = <ConflictInfo<T>>[];

    // Crear mapa para búsqueda eficiente
    final remoteMap = {for (var entity in remoteEntities) entity.id: entity};

    // Buscar conflictos en entidades que existen en ambos lados
    for (final localEntity in localEntities) {
      final remoteEntity = remoteMap[localEntity.id];
      if (remoteEntity != null) {
        final conflict = detectConflict(localEntity, remoteEntity);
        if (conflict != null) {
          conflicts.add(conflict);
        }
      }
    }

    if (conflicts.isNotEmpty) {
      LoggerFactory.info(
          '🔍 Detected ${conflicts.length} conflicts for ${T.toString()}');
    }

    return conflicts;
  }

  /// Resuelve múltiples conflictos en lote
  Future<List<ConflictResolution>> resolveConflicts<T extends SyncableEntity>(
    List<ConflictInfo<T>> conflicts, {
    ConflictStrategy? overrideStrategy,
  }) async {
    final resolutions = <ConflictResolution>[];

    LoggerFactory.info('⚖️ Resolving ${conflicts.length} conflicts in batch');

    for (final conflict in conflicts) {
      try {
        final resolution =
            await resolveConflict(conflict, overrideStrategy: overrideStrategy);
        resolutions.add(resolution);
      } catch (e) {
        LoggerFactory.error(
            '❌ Failed to resolve conflict for ${conflict.localEntity.id}: $e');

        // Fallback a remote wins en caso de error
        final fallback = ConflictResolution(
          strategy: ConflictStrategy.remoteWins,
          resolvedAt: SyncUtilities.utcNow(),
          resolvedEntity: conflict.remoteEntity,
          reason: 'Fallback due to resolution error: $e',
        );
        resolutions.add(fallback);
      }
    }

    LoggerFactory.info('✅ Resolved ${resolutions.length} conflicts');
    return resolutions;
  }

  /// Configura la estrategia por defecto para un tipo de entidad
  void setDefaultStrategy(String entityType, ConflictStrategy strategy) {
    _defaultStrategies[entityType] = strategy;
    LoggerFactory.info(
        '🔧 Set default conflict strategy for $entityType: ${strategy.name}');
  }

  /// Obtiene estadísticas de resolución
  Map<String, int> getResolutionStats() {
    return Map.from(_resolutionStats);
  }

  /// Limpia estadísticas
  void clearStats() {
    _resolutionStats.clear();
    _advancedResolver.clearStats();
    LoggerFactory.info('🧹 Cleared conflict resolution stats');
  }

  // =============================================
  // RESOLUCIÓN AVANZADA DE CONFLICTOS
  // =============================================

  /// Resuelve un conflicto usando estrategias avanzadas
  Future<DetailedConflictResolution>
      resolveConflictAdvanced<T extends SyncableEntity>(
    ConflictInfo<T> conflict, {
    ConflictContext? context,
    ConflictResolutionStrategy? overrideStrategy,
  }) async {
    LoggerFactory.info(
        '🔍 Using advanced conflict resolution for ${conflict.localEntity.entityType}');
    return await _advancedResolver.resolveConflictAdvanced(
      conflict,
      context: context,
      overrideStrategy: overrideStrategy,
    );
  }

  /// Configura estrategia para un tipo de entidad
  void configureEntityStrategy(
      String entityType, ConflictResolutionStrategy strategy) {
    _advancedResolver.config.setEntityStrategy(entityType, strategy);
    LoggerFactory.info(
        '⚙️ Configured entity strategy for $entityType: ${strategy.value}');
  }

  /// Configura estrategia para un campo específico
  void configureFieldStrategy(String entityType, String fieldName,
      ConflictResolutionStrategy strategy) {
    _advancedResolver.config.setFieldStrategy(entityType, fieldName, strategy);
    LoggerFactory.info(
        '⚙️ Configured field strategy for $entityType.$fieldName: ${strategy.value}');
  }

  /// Obtiene estadísticas combinadas
  Map<String, dynamic> getCombinedStats() {
    return {
      'basic_resolutions': getResolutionStats(),
      'advanced_resolutions': _advancedResolver.getResolutionStats(),
      'total_resolutions':
          getResolutionStats().values.fold(0, (a, b) => a + b) +
              _advancedResolver
                  .getResolutionStats()
                  .values
                  .fold(0, (a, b) => a + b),
    };
  }

  /// Obtiene la configuración avanzada actual
  ConflictStrategyConfig get advancedConfig => _advancedResolver.config;

  // =============================================
  // MÉTODOS PRIVADOS
  // =============================================

  /// Actualiza estadísticas de resolución
  void _updateStats(String entityType, ConflictStrategy strategy) {
    final key = '${entityType}_${strategy.name}';
    _resolutionStats[key] = (_resolutionStats[key] ?? 0) + 1;
  }

  /// Obtiene razón de resolución según tipo y estrategia
  String _getResolutionReason(
      ConflictType conflictType, ConflictStrategy strategy) {
    switch (strategy) {
      case ConflictStrategy.localWins:
        return 'Local version chosen for ${conflictType.name}';
      case ConflictStrategy.remoteWins:
        return 'Remote version chosen for ${conflictType.name}';
      case ConflictStrategy.merge:
        return 'Entities merged to resolve ${conflictType.name}';
      case ConflictStrategy.userChoice:
        return 'User manually resolved ${conflictType.name}';
    }
  }

  /// Obtiene el contexto de navegación actual
  /// En una implementación real, esto debería obtenerse del NavigatorKey global
  /// o del contexto de la aplicación
  BuildContext? _getCurrentContext() {
    // Implementación con fallback automático para evitar dependencias circulares
    LoggerFactory.debug('🔍 Attempting to get current navigation context');

    // En una implementación completa, esto podría usar:
    // - Un NavigatorKey global configurado en MaterialApp
    // - Un servicio de navegación inyectado
    // - El contexto pasado como parámetro al ConflictResolver

    return null; // Fallback a estrategia automática
  }
}
