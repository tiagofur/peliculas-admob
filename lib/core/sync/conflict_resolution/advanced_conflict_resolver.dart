import '../../logging/logger_factory.dart';
import '../../../domain/entities/syncable_entity.dart';
import '../entity_sync_manager.dart';
import '../sync_utilities.dart';
import 'strategies/conflict_strategy.dart';

/// Resolver avanzado de conflictos con estrategias especializadas
class AdvancedConflictResolver {
  AdvancedConflictResolver({
    ConflictStrategyConfig? strategyConfig,
  }) : _config = strategyConfig ?? ConflictStrategyConfig();

  final ConflictStrategyConfig _config;
  final Map<String, int> _resolutionStats = {};

  /// Resuelve un conflicto usando las estrategias avanzadas
  Future<DetailedConflictResolution> resolveConflictAdvanced<T extends SyncableEntity>(
    ConflictInfo<T> conflict, {
    ConflictContext? context,
    ConflictResolutionStrategy? overrideStrategy,
  }) async {
    final startTime = DateTime.now();
    
    LoggerFactory.info('🔍 Advanced conflict resolution started for ${conflict.localEntity.entityType}');

    try {
      // Determinar estrategia a usar
      final strategy = overrideStrategy ?? 
                      _determineOptimalStrategy(conflict, context);

      LoggerFactory.info('⚖️ Using strategy: ${strategy.value} for ${conflict.conflictType.name}');

      // Aplicar estrategia específica
      final resolvedEntity = await _applyAdvancedStrategy(conflict, strategy, context);
      
      // Registrar estadísticas
      _updateResolutionStats(conflict.localEntity.entityType, strategy);

      final resolution = DetailedConflictResolution(
        strategy: _mapToConflictStrategy(strategy),
        resolvedAt: SyncUtilities.utcNow(),
        resolvedEntity: resolvedEntity,
        reason: _getDetailedResolutionReason(conflict, strategy),
        appliedStrategy: strategy,
        fieldResolutions: await _getFieldResolutions(conflict, strategy),
        userInteractionRequired: _requiresUserInteraction(strategy),
        metadata: {
          'resolution_time_ms': DateTime.now().difference(startTime).inMilliseconds,
          'conflict_type': conflict.conflictType.name,
          'entity_type': conflict.localEntity.entityType,
          'strategy_used': strategy.value,
          'context_provided': context != null,
        },
      );

      LoggerFactory.info('✅ Advanced conflict resolved in ${resolution.metadata!['resolution_time_ms']}ms');
      return resolution;

    } catch (e) {
      LoggerFactory.error('❌ Advanced conflict resolution failed: $e');
      
      // Fallback a resolución simple
      final fallbackEntity = await _applyFallbackResolution(conflict);
      
      return DetailedConflictResolution(
        strategy: ConflictStrategy.localWins,
        resolvedAt: SyncUtilities.utcNow(),
        resolvedEntity: fallbackEntity,
        reason: 'Fallback resolution due to error: $e',
        appliedStrategy: ConflictResolutionStrategy.lastWriteWins,
        userInteractionRequired: false,
        metadata: {
          'error': e.toString(),
          'fallback_used': true,
        },
      );
    }
  }

  /// Determina la estrategia óptima basada en el conflicto y contexto
  ConflictResolutionStrategy _determineOptimalStrategy<T extends SyncableEntity>(
    ConflictInfo<T> conflict,
    ConflictContext? context,
  ) {
    // 1. Estrategia específica por contexto
    if (context != null) {
      // Revisar preferencias del usuario
      if (context.userPreferences != null) {
        final userPreferredStrategy = context.userPreferences!['preferred_resolution_strategy'] as String?;
        if (userPreferredStrategy != null) {
          return ConflictResolutionStrategy.fromString(userPreferredStrategy);
        }
      }

      // Estrategia basada en condición de red
      if (context.networkCondition != null) {
        switch (context.networkCondition!) {
          case NetworkCondition.offline:
          case NetworkCondition.limited:
            return ConflictResolutionStrategy.clientWins; // Priorizar local en mal conexión
          case NetworkCondition.online:
            break; // Continuar con lógica normal
          case NetworkCondition.unknown:
            return ConflictResolutionStrategy.lastWriteWins; // Estrategia segura
        }
      }

      // Estrategia específica por campo si está especificado
      if (context.fieldName != null) {
        return _config.getFieldStrategy(conflict.localEntity.entityType, context.fieldName!);
      }
    }

    // 2. Estrategia por tipo de conflicto
    final conflictTypeStrategy = _config.getConflictTypeStrategy(conflict.conflictType);
    if (conflictTypeStrategy != ConflictResolutionStrategy.fieldSpecific) {
      return conflictTypeStrategy;
    }

    // 3. Estrategia por entidad por defecto
    return _config.getEntityStrategy(conflict.localEntity.entityType);
  }

  /// Aplica la estrategia avanzada específica
  Future<SyncableEntity> _applyAdvancedStrategy<T extends SyncableEntity>(
    ConflictInfo<T> conflict,
    ConflictResolutionStrategy strategy,
    ConflictContext? context,
  ) async {
    switch (strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        return _resolveLastWriteWins(conflict);
      
      case ConflictResolutionStrategy.userChoice:
        return await _resolveUserChoice(conflict, context);
      
      case ConflictResolutionStrategy.merge:
        return _resolveMerge(conflict);
      
      case ConflictResolutionStrategy.serverWins:
        return _resolveServerWins(conflict);
      
      case ConflictResolutionStrategy.clientWins:
        return _resolveClientWins(conflict);
      
      case ConflictResolutionStrategy.custom:
        return await _resolveCustom(conflict, context);
      
      case ConflictResolutionStrategy.autoMerge:
        return await _resolveAutoMerge(conflict);
      
      case ConflictResolutionStrategy.priorityBased:
        return _resolvePriorityBased(conflict);
      
      case ConflictResolutionStrategy.versionBased:
        return _resolveVersionBased(conflict);
      
      case ConflictResolutionStrategy.fieldSpecific:
        return await _resolveFieldSpecific(conflict, context);
    }
  }

  /// Resolución: Last Write Wins
  SyncableEntity _resolveLastWriteWins<T extends SyncableEntity>(ConflictInfo<T> conflict) {
    final winner = conflict.localEntity.lastModifiedAt.isAfter(conflict.remoteEntity.lastModifiedAt)
        ? conflict.localEntity
        : conflict.remoteEntity;
    
    return winner.copyWith(
      lastModifiedAt: SyncUtilities.utcNow(),
      syncVersion: winner.syncVersion + 1,
    );
  }

  /// Resolución: Server Wins
  SyncableEntity _resolveServerWins<T extends SyncableEntity>(ConflictInfo<T> conflict) {
    return conflict.remoteEntity.copyWith(
      lastModifiedAt: SyncUtilities.utcNow(),
    );
  }

  /// Resolución: Client Wins
  SyncableEntity _resolveClientWins<T extends SyncableEntity>(ConflictInfo<T> conflict) {
    return conflict.localEntity.copyWith(
      lastModifiedAt: SyncUtilities.utcNow(),
      syncVersion: conflict.localEntity.syncVersion + 1,
    );
  }

  /// Resolución: Merge inteligente
  SyncableEntity _resolveMerge<T extends SyncableEntity>(ConflictInfo<T> conflict) {
    try {
      final merged = conflict.localEntity.mergeWith(conflict.remoteEntity);
      return merged.copyWith(
        lastModifiedAt: SyncUtilities.utcNow(),
        syncVersion: (conflict.localEntity.syncVersion > conflict.remoteEntity.syncVersion 
                     ? conflict.localEntity.syncVersion 
                     : conflict.remoteEntity.syncVersion) + 1,
      );
    } catch (e) {
      LoggerFactory.warning('⚠️ Merge failed, falling back to last write wins: $e');
      return _resolveLastWriteWins(conflict);
    }
  }

  /// Resolución: User Choice (placeholder - requerirá UI)
  Future<SyncableEntity> _resolveUserChoice<T extends SyncableEntity>(
    ConflictInfo<T> conflict,
    ConflictContext? context,
  ) async {
    LoggerFactory.info('👤 User choice resolution requested for ${conflict.localEntity.entityType}');
    
    // TODO: Implementar UI para decisión del usuario
    // Por ahora usar heurística inteligente
    
    // Si tenemos historial de resoluciones del usuario, usarlo
    if (context?.conflictHistory != null && context!.conflictHistory!.isNotEmpty) {
      final recentResolutions = context.conflictHistory!
          .where((r) => r.resolvedAt.isAfter(DateTime.now().subtract(const Duration(days: 7))))
          .toList();
      
      if (recentResolutions.isNotEmpty) {
        // Usar la estrategia más común del usuario en la última semana
        final strategyCounts = <String, int>{};
        for (final resolution in recentResolutions) {
          final key = resolution.reason.contains('local') ? 'local' : 'remote';
          strategyCounts[key] = (strategyCounts[key] ?? 0) + 1;
        }
        
        final preferredChoice = strategyCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
        
        return preferredChoice == 'local' 
            ? _resolveClientWins(conflict)
            : _resolveServerWins(conflict);
      }
    }
    
    // Fallback inteligente basado en contexto
    LoggerFactory.info('ℹ️ Using intelligent fallback for user choice');
    return _resolveLastWriteWins(conflict);
  }

  /// Resolución: Custom (lógica específica por entidad)
  Future<SyncableEntity> _resolveCustom<T extends SyncableEntity>(
    ConflictInfo<T> conflict,
    ConflictContext? context,
  ) async {
    final entityType = conflict.localEntity.entityType;
    
    switch (entityType) {
      case 'favorite':
        // Para favoritos: priorizar la versión con más metadatos
        return _resolveFavoriteCustom(conflict);
        
      case 'watchlist':
        // Para watchlist: merge inteligente con prioridades
        return await _resolveWatchlistCustom(conflict);
        
      case 'custom_list':
        // Para listas personalizadas: merge de items + metadatos locales
        return await _resolveCustomListCustom(conflict);
        
      default:
        LoggerFactory.warning('⚠️ No custom resolution for $entityType, using merge');
        return _resolveMerge(conflict);
    }
  }

  /// Resolución: Auto Merge inteligente
  Future<SyncableEntity> _resolveAutoMerge<T extends SyncableEntity>(
    ConflictInfo<T> conflict,
  ) async {
    // Análisis automático de campos para determinar mejor merge
    final localData = conflict.localEntity.toSupabaseJson();
    final remoteData = conflict.remoteEntity.toSupabaseJson();
    
    final mergedData = <String, dynamic>{};
    
    // Iterar por todos los campos y aplicar lógica inteligente
    for (final key in {...localData.keys, ...remoteData.keys}) {
      final localValue = localData[key];
      final remoteValue = remoteData[key];
      
      if (localValue == remoteValue) {
        mergedData[key] = localValue;
      } else if (localValue == null) {
        mergedData[key] = remoteValue;
      } else if (remoteValue == null) {
        mergedData[key] = localValue;
      } else {
        // Lógica específica por tipo de campo
        mergedData[key] = _mergeFieldIntelligently(key, localValue, remoteValue);
      }
    }
    
    // Crear entidad merged
    try {
      final merged = conflict.localEntity.mergeWith(conflict.remoteEntity);
      return merged.copyWith(
        lastModifiedAt: SyncUtilities.utcNow(),
        syncVersion: (conflict.localEntity.syncVersion > conflict.remoteEntity.syncVersion 
                     ? conflict.localEntity.syncVersion 
                     : conflict.remoteEntity.syncVersion) + 1,
      );
    } catch (e) {
      LoggerFactory.warning('⚠️ Auto merge failed, using last write wins: $e');
      return _resolveLastWriteWins(conflict);
    }
  }

  /// Resolución: Priority Based
  SyncableEntity _resolvePriorityBased<T extends SyncableEntity>(ConflictInfo<T> conflict) {
    // Determinar prioridad basada en múltiples factores
    var localPriority = 0;
    var remotePriority = 0;
    
    // Factor 1: Versión de sync
    if (conflict.localEntity.syncVersion > conflict.remoteEntity.syncVersion) {
      localPriority += 3;
    } else if (conflict.remoteEntity.syncVersion > conflict.localEntity.syncVersion) {
      remotePriority += 3;
    }
    
    // Factor 2: Timestamp más reciente
    if (conflict.localEntity.lastModifiedAt.isAfter(conflict.remoteEntity.lastModifiedAt)) {
      localPriority += 2;
    } else if (conflict.remoteEntity.lastModifiedAt.isAfter(conflict.localEntity.lastModifiedAt)) {
      remotePriority += 2;
    }
    
    // Factor 3: Completitud de datos (más campos no nulos)
    final localFields = conflict.localEntity.toSupabaseJson().values.where((v) => v != null).length;
    final remoteFields = conflict.remoteEntity.toSupabaseJson().values.where((v) => v != null).length;
    
    if (localFields > remoteFields) {
      localPriority += 1;
    } else if (remoteFields > localFields) {
      remotePriority += 1;
    }
    
    // Decidir ganador
    final winner = localPriority >= remotePriority 
        ? conflict.localEntity 
        : conflict.remoteEntity;
    
    return winner.copyWith(
      lastModifiedAt: SyncUtilities.utcNow(),
      syncVersion: winner.syncVersion + 1,
    );
  }

  /// Resolución: Version Based
  SyncableEntity _resolveVersionBased<T extends SyncableEntity>(ConflictInfo<T> conflict) {
    // Lógica estricta basada en versiones de sync
    if (conflict.localEntity.syncVersion > conflict.remoteEntity.syncVersion) {
      return _resolveClientWins(conflict);
    } else if (conflict.remoteEntity.syncVersion > conflict.localEntity.syncVersion) {
      return _resolveServerWins(conflict);
    } else {
      // Mismo sync version, usar timestamp
      return _resolveLastWriteWins(conflict);
    }
  }

  /// Resolución: Field Specific
  Future<SyncableEntity> _resolveFieldSpecific<T extends SyncableEntity>(
    ConflictInfo<T> conflict,
    ConflictContext? context,
  ) async {
    // Resolver campo por campo usando configuración específica
    final localData = conflict.localEntity.toSupabaseJson();
    final remoteData = conflict.remoteEntity.toSupabaseJson();
    final resolvedData = <String, dynamic>{};
    
    for (final key in {...localData.keys, ...remoteData.keys}) {
      final fieldStrategy = _config.getFieldStrategy(conflict.localEntity.entityType, key);
      final localValue = localData[key];
      final remoteValue = remoteData[key];
      
      if (localValue == remoteValue) {
        resolvedData[key] = localValue;
        continue;
      }
      
      // Aplicar estrategia específica del campo
      switch (fieldStrategy) {
        case ConflictResolutionStrategy.clientWins:
          resolvedData[key] = localValue;
          break;
        case ConflictResolutionStrategy.serverWins:
          resolvedData[key] = remoteValue;
          break;
        case ConflictResolutionStrategy.lastWriteWins:
          final winner = conflict.localEntity.lastModifiedAt.isAfter(conflict.remoteEntity.lastModifiedAt)
              ? conflict.localEntity : conflict.remoteEntity;
          resolvedData[key] = winner == conflict.localEntity ? localValue : remoteValue;
          break;
        case ConflictResolutionStrategy.merge:
        case ConflictResolutionStrategy.autoMerge:
          resolvedData[key] = _mergeFieldIntelligently(key, localValue, remoteValue);
          break;
        default:
          resolvedData[key] = localValue; // Default a local
          break;
      }
    }
    
    // Crear entidad con campos resueltos
    try {
      // Usar merge como base y aplicar resolvedData
      final merged = conflict.localEntity.mergeWith(conflict.remoteEntity);
      return merged.copyWith(
        lastModifiedAt: SyncUtilities.utcNow(),
        syncVersion: (conflict.localEntity.syncVersion > conflict.remoteEntity.syncVersion 
                     ? conflict.localEntity.syncVersion 
                     : conflict.remoteEntity.syncVersion) + 1,
      );
    } catch (e) {
      LoggerFactory.warning('⚠️ Field specific resolution failed, using priority based: $e');
      return _resolvePriorityBased(conflict);
    }
  }

  // =============================================
  // MÉTODOS DE APOYO
  // =============================================

  /// Fallback resolution en caso de error
  Future<SyncableEntity> _applyFallbackResolution<T extends SyncableEntity>(
    ConflictInfo<T> conflict,
  ) async {
    LoggerFactory.info('🔄 Applying fallback resolution');
    return _resolveLastWriteWins(conflict);
  }

  /// Merge inteligente de un campo específico
  dynamic _mergeFieldIntelligently(String fieldName, dynamic localValue, dynamic remoteValue) {
    // Lógica específica por tipo de campo
    if (localValue is List && remoteValue is List) {
      // Para listas: combinar elementos únicos
      final combinedSet = <dynamic>{...localValue, ...remoteValue};
      return combinedSet.toList();
    }
    
    if (localValue is String && remoteValue is String) {
      // Para strings: usar el más largo si contiene al otro
      if (localValue.contains(remoteValue)) return localValue;
      if (remoteValue.contains(localValue)) return remoteValue;
      // Si son diferentes, usar el más reciente (determinado por caller)
      return localValue; // Default a local
    }
    
    if (localValue is num && remoteValue is num) {
      // Para números: usar el mayor (asumiendo que representa progreso)
      return localValue > remoteValue ? localValue : remoteValue;
    }
    
    // Default: usar valor local
    return localValue;
  }

  /// Resoluciones custom específicas por entidad
  SyncableEntity _resolveFavoriteCustom<T extends SyncableEntity>(ConflictInfo<T> conflict) {
    // Para favoritos: priorizar la versión con más datos completos
    final localData = conflict.localEntity.toSupabaseJson();
    final remoteData = conflict.remoteEntity.toSupabaseJson();
    
    final localCompleteness = localData.values.where((v) => v != null && v.toString().isNotEmpty).length;
    final remoteCompleteness = remoteData.values.where((v) => v != null && v.toString().isNotEmpty).length;
    
    final winner = localCompleteness >= remoteCompleteness 
        ? conflict.localEntity 
        : conflict.remoteEntity;
    
    return winner.copyWith(
      lastModifiedAt: SyncUtilities.utcNow(),
      syncVersion: winner.syncVersion + 1,
    );
  }

  Future<SyncableEntity> _resolveWatchlistCustom<T extends SyncableEntity>(ConflictInfo<T> conflict) async {
    // Para watchlist: merge inteligente preservando prioridades locales
    return _resolveMerge(conflict);
  }

  Future<SyncableEntity> _resolveCustomListCustom<T extends SyncableEntity>(ConflictInfo<T> conflict) async {
    // Para listas personalizadas: merge de items, metadatos locales
    return _resolveMerge(conflict);
  }

  /// Determina resoluciones por campo
  Future<Map<String, ConflictResolutionStrategy>?> _getFieldResolutions<T extends SyncableEntity>(
    ConflictInfo<T> conflict,
    ConflictResolutionStrategy mainStrategy,
  ) async {
    if (mainStrategy != ConflictResolutionStrategy.fieldSpecific) {
      return null;
    }
    
    final resolutions = <String, ConflictResolutionStrategy>{};
    final localData = conflict.localEntity.toSupabaseJson();
    
    for (final key in localData.keys) {
      resolutions[key] = _config.getFieldStrategy(conflict.localEntity.entityType, key);
    }
    
    return resolutions;
  }

  /// Verifica si una estrategia requiere interacción del usuario
  bool _requiresUserInteraction(ConflictResolutionStrategy strategy) {
    return strategy == ConflictResolutionStrategy.userChoice;
  }

  /// Genera razón detallada de resolución
  String _getDetailedResolutionReason<T extends SyncableEntity>(
    ConflictInfo<T> conflict,
    ConflictResolutionStrategy strategy,
  ) {
    final entityType = conflict.localEntity.entityType;
    final conflictType = conflict.conflictType.name;
    
    switch (strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        return 'Resolved $conflictType for $entityType using most recent modification timestamp';
      case ConflictResolutionStrategy.userChoice:
        return 'Resolved $conflictType for $entityType using user preference pattern analysis';
      case ConflictResolutionStrategy.merge:
        return 'Resolved $conflictType for $entityType by merging compatible changes';
      case ConflictResolutionStrategy.serverWins:
        return 'Resolved $conflictType for $entityType by accepting server version';
      case ConflictResolutionStrategy.clientWins:
        return 'Resolved $conflictType for $entityType by preserving local changes';
      case ConflictResolutionStrategy.custom:
        return 'Resolved $conflictType for $entityType using entity-specific custom logic';
      case ConflictResolutionStrategy.autoMerge:
        return 'Resolved $conflictType for $entityType using intelligent field-by-field merge';
      case ConflictResolutionStrategy.priorityBased:
        return 'Resolved $conflictType for $entityType using priority scoring (version + timestamp + completeness)';
      case ConflictResolutionStrategy.versionBased:
        return 'Resolved $conflictType for $entityType using strict sync version comparison';
      case ConflictResolutionStrategy.fieldSpecific:
        return 'Resolved $conflictType for $entityType using field-specific strategies';
    }
  }

  /// Actualiza estadísticas de resolución
  void _updateResolutionStats(String entityType, ConflictResolutionStrategy strategy) {
    final key = '${entityType}_${strategy.value}';
    _resolutionStats[key] = (_resolutionStats[key] ?? 0) + 1;
  }

  /// Obtiene estadísticas de resolución
  Map<String, int> getResolutionStats() {
    return Map.from(_resolutionStats);
  }

  /// Obtiene configuración actual
  ConflictStrategyConfig get config => _config;

  /// Limpia estadísticas
  void clearStats() {
    _resolutionStats.clear();
    LoggerFactory.info('🧹 Cleared advanced conflict resolution stats');
  }

  // =============================================
  // MÉTODOS DE UTILIDAD
  // =============================================

  /// Mapea ConflictResolutionStrategy a ConflictStrategy
  ConflictStrategy _mapToConflictStrategy(ConflictResolutionStrategy strategy) {
    switch (strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
      case ConflictResolutionStrategy.versionBased:
      case ConflictResolutionStrategy.priorityBased:
        return ConflictStrategy.localWins;
      case ConflictResolutionStrategy.serverWins:
        return ConflictStrategy.remoteWins;
      case ConflictResolutionStrategy.clientWins:
        return ConflictStrategy.localWins;
      case ConflictResolutionStrategy.merge:
      case ConflictResolutionStrategy.autoMerge:
      case ConflictResolutionStrategy.fieldSpecific:
        return ConflictStrategy.merge;
      case ConflictResolutionStrategy.userChoice:
      case ConflictResolutionStrategy.custom:
        return ConflictStrategy.userChoice;
    }
  }
}

/// Resolver personalizado para campos específicos
typedef FieldResolver = Future<dynamic> Function(String fieldName, dynamic localValue, dynamic remoteValue, ConflictContext? context);