import '../../entity_sync_manager.dart';

/// Estrategias avanzadas de resolución de conflictos para diferentes tipos de entidades
enum ConflictResolutionStrategy {
  /// ⏰ Last Write Wins - Para favoritos, watchlist básica
  lastWriteWins('last_write_wins'),
  
  /// 👤 User Choice - Para listas personalizadas importantes
  userChoice('user_choice'),
  
  /// 🔀 Merge - Para listas con elementos diferentes
  merge('merge'),
  
  /// 🌐 Server Wins - Para metadatos del sistema
  serverWins('server_wins'),
  
  /// 📱 Client Wins - Para preferencias locales
  clientWins('client_wins'),
  
  /// ⚙️ Custom - Lógica específica por entidad
  custom('custom'),
  
  /// 🔄 Auto Merge - Fusión automática inteligente
  autoMerge('auto_merge'),
  
  /// ⚖️ Priority Based - Basado en prioridades de campo
  priorityBased('priority_based'),
  
  /// 📊 Version Based - Basado en versiones y timestamps
  versionBased('version_based'),
  
  /// 🎯 Field Specific - Estrategia específica por campo
  fieldSpecific('field_specific');

  const ConflictResolutionStrategy(this.value);
  final String value;

  static ConflictResolutionStrategy fromString(String value) {
    return ConflictResolutionStrategy.values.firstWhere(
      (strategy) => strategy.value == value,
      orElse: () => ConflictResolutionStrategy.lastWriteWins,
    );
  }
}

/// Contexto adicional para resolución de conflictos
class ConflictContext {
  const ConflictContext({
    required this.entityType,
    required this.conflictType,
    this.fieldName,
    this.userPreferences,
    this.networkCondition,
    this.deviceInfo,
    this.conflictHistory,
  });

  final String entityType;
  final ConflictType conflictType;
  final String? fieldName;
  final Map<String, dynamic>? userPreferences;
  final NetworkCondition? networkCondition;
  final Map<String, dynamic>? deviceInfo;
  final List<DetailedConflictResolution>? conflictHistory;
}

/// Condición de red al momento del conflicto
enum NetworkCondition {
  online,
  offline,
  limited,
  unknown
}

/// Resultado detallado de resolución de conflicto
class DetailedConflictResolution {
  const DetailedConflictResolution({
    required this.strategy,
    required this.resolvedAt,
    required this.resolvedEntity,
    required this.reason,
    this.appliedStrategy,
    this.fieldResolutions,
    this.userInteractionRequired,
    this.metadata,
  });

  final ConflictStrategy strategy;
  final DateTime resolvedAt;
  final dynamic resolvedEntity;
  final String reason;

  /// Estrategia específica aplicada
  final ConflictResolutionStrategy? appliedStrategy;
  
  /// Resoluciones específicas por campo
  final Map<String, ConflictResolutionStrategy>? fieldResolutions;
  
  /// Si requirió interacción del usuario
  final bool? userInteractionRequired;
  
  /// Metadatos adicionales de la resolución
  final Map<String, dynamic>? metadata;

  @override
  String toString() {
    return 'DetailedConflictResolution(strategy: ${appliedStrategy?.value}, '
        'userInteraction: $userInteractionRequired, '
        'fieldResolutions: ${fieldResolutions?.length ?? 0})';
  }
}

/// Configuración de estrategias por entidad y campo
class ConflictStrategyConfig {
  ConflictStrategyConfig({
    Map<String, ConflictResolutionStrategy>? entityStrategies,
    Map<String, Map<String, ConflictResolutionStrategy>>? fieldStrategies,
    Map<ConflictType, ConflictResolutionStrategy>? conflictTypeStrategies,
  }) : _entityStrategies = entityStrategies ?? _getDefaultEntityStrategies(),
       _fieldStrategies = fieldStrategies ?? _getDefaultFieldStrategies(),
       _conflictTypeStrategies = conflictTypeStrategies ?? _getDefaultConflictTypeStrategies();

  final Map<String, ConflictResolutionStrategy> _entityStrategies;
  final Map<String, Map<String, ConflictResolutionStrategy>> _fieldStrategies;
  final Map<ConflictType, ConflictResolutionStrategy> _conflictTypeStrategies;

  /// Estrategias por defecto para entidades
  static Map<String, ConflictResolutionStrategy> _getDefaultEntityStrategies() {
    return {
      'favorite': ConflictResolutionStrategy.lastWriteWins,
      'watchlist': ConflictResolutionStrategy.userChoice,
      'custom_list': ConflictResolutionStrategy.merge,
      'watched_movie': ConflictResolutionStrategy.lastWriteWins,
      'user_rating': ConflictResolutionStrategy.clientWins,
      'user_preference': ConflictResolutionStrategy.clientWins,
    };
  }

  /// Estrategias por defecto para campos específicos
  static Map<String, Map<String, ConflictResolutionStrategy>> _getDefaultFieldStrategies() {
    return {
      'watchlist': {
        'priority': ConflictResolutionStrategy.userChoice,
        'category': ConflictResolutionStrategy.merge,
        'notes': ConflictResolutionStrategy.lastWriteWins,
      },
      'custom_list': {
        'name': ConflictResolutionStrategy.userChoice,
        'description': ConflictResolutionStrategy.lastWriteWins,
        'items': ConflictResolutionStrategy.autoMerge,
        'public': ConflictResolutionStrategy.clientWins,
      },
      'watched_movie': {
        'rating': ConflictResolutionStrategy.lastWriteWins,
        'review': ConflictResolutionStrategy.merge,
        'watched_at': ConflictResolutionStrategy.priorityBased,
        'tags': ConflictResolutionStrategy.autoMerge,
      },
    };
  }

  /// Estrategias por defecto para tipos de conflicto
  static Map<ConflictType, ConflictResolutionStrategy> _getDefaultConflictTypeStrategies() {
    return {
      ConflictType.concurrentModification: ConflictResolutionStrategy.fieldSpecific,
      ConflictType.deleteVsModify: ConflictResolutionStrategy.userChoice,
      ConflictType.duplicateCreation: ConflictResolutionStrategy.merge,
    };
  }

  /// Obtiene la estrategia para una entidad
  ConflictResolutionStrategy getEntityStrategy(String entityType) {
    return _entityStrategies[entityType] ?? ConflictResolutionStrategy.lastWriteWins;
  }

  /// Obtiene la estrategia para un campo específico
  ConflictResolutionStrategy getFieldStrategy(String entityType, String fieldName) {
    return _fieldStrategies[entityType]?[fieldName] ?? getEntityStrategy(entityType);
  }

  /// Obtiene la estrategia para un tipo de conflicto
  ConflictResolutionStrategy getConflictTypeStrategy(ConflictType conflictType) {
    return _conflictTypeStrategies[conflictType] ?? ConflictResolutionStrategy.lastWriteWins;
  }

  /// Configura estrategia para una entidad
  void setEntityStrategy(String entityType, ConflictResolutionStrategy strategy) {
    _entityStrategies[entityType] = strategy;
  }

  /// Configura estrategia para un campo
  void setFieldStrategy(String entityType, String fieldName, ConflictResolutionStrategy strategy) {
    _fieldStrategies.putIfAbsent(entityType, () => {})[fieldName] = strategy;
  }

  /// Configura estrategia para un tipo de conflicto
  void setConflictTypeStrategy(ConflictType conflictType, ConflictResolutionStrategy strategy) {
    _conflictTypeStrategies[conflictType] = strategy;
  }

  /// Obtiene todas las configuraciones como mapa
  Map<String, dynamic> toJson() {
    return {
      'entity_strategies': _entityStrategies.map((k, v) => MapEntry(k, v.value)),
      'field_strategies': _fieldStrategies.map((entityType, fields) => 
          MapEntry(entityType, fields.map((field, strategy) => 
              MapEntry(field, strategy.value)))),
      'conflict_type_strategies': _conflictTypeStrategies.map((k, v) => 
          MapEntry(k.name, v.value)),
    };
  }

  /// Crea configuración desde JSON
  factory ConflictStrategyConfig.fromJson(Map<String, dynamic> json) {
    final entityStrategies = <String, ConflictResolutionStrategy>{};
    final fieldStrategies = <String, Map<String, ConflictResolutionStrategy>>{};
    final conflictTypeStrategies = <ConflictType, ConflictResolutionStrategy>{};

    // Parse entity strategies
    if (json['entity_strategies'] is Map<String, dynamic>) {
      for (final entry in (json['entity_strategies'] as Map<String, dynamic>).entries) {
        entityStrategies[entry.key] = ConflictResolutionStrategy.fromString(entry.value as String);
      }
    }

    // Parse field strategies
    if (json['field_strategies'] is Map<String, dynamic>) {
      for (final entityEntry in (json['field_strategies'] as Map<String, dynamic>).entries) {
        if (entityEntry.value is Map<String, dynamic>) {
          final entityFields = <String, ConflictResolutionStrategy>{};
          for (final fieldEntry in (entityEntry.value as Map<String, dynamic>).entries) {
            entityFields[fieldEntry.key] = ConflictResolutionStrategy.fromString(fieldEntry.value as String);
          }
          fieldStrategies[entityEntry.key] = entityFields;
        }
      }
    }

    // Parse conflict type strategies
    if (json['conflict_type_strategies'] is Map<String, dynamic>) {
      for (final entry in (json['conflict_type_strategies'] as Map<String, dynamic>).entries) {
        final conflictType = ConflictType.values.where((ct) => ct.name == entry.key).firstOrNull;
        if (conflictType != null) {
          conflictTypeStrategies[conflictType] = ConflictResolutionStrategy.fromString(entry.value as String);
        }
      }
    }

    return ConflictStrategyConfig(
      entityStrategies: entityStrategies,
      fieldStrategies: fieldStrategies,
      conflictTypeStrategies: conflictTypeStrategies,
    );
  }
}

/// Extension para ConflictType enum
extension ConflictTypeExtension on ConflictType {
  String get name {
    switch (this) {
      case ConflictType.concurrentModification:
        return 'concurrent_modification';
      case ConflictType.deleteVsModify:
        return 'delete_vs_modify';
      case ConflictType.duplicateCreation:
        return 'duplicate_creation';
    }
  }
}

/// Extension para listas
extension ListExtensions<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}