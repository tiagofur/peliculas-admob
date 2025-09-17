import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/list_item.dart';
import 'auth_provider.dart';
import 'custom_lists_providers.dart';

/// Provider que maneja la creación automática de listas predeterminadas
final autoDefaultListsProvider = Provider<AutoDefaultListsService>((ref) {
  return AutoDefaultListsService(ref);
});

/// Provider que maneja la inicialización automática de listas cuando el usuario se autentica
final authDefaultListsListenerProvider = Provider<void>((ref) {
  // Obtener el estado actual de autenticación
  final authState = ref.watch(authStateProvider);

  // Si hay un usuario autenticado, verificar listas predeterminadas
  authState.whenData((user) async {
    if (user != null) {
      LoggerFactory.info(
          '🔧 Usuario autenticado - iniciando verificación de listas predeterminadas');

      final autoService = ref.read(autoDefaultListsProvider);
      await autoService.ensureDefaultListsExist();
    }
  });
});

/// Servicio que maneja la creación automática de listas predeterminadas
class AutoDefaultListsService {
  AutoDefaultListsService(this.ref);

  final Ref ref;
  bool _isInitializing = false;

  /// Configuraciones de las listas predeterminadas
  static const List<DefaultListConfig> _defaultConfigs = [
    DefaultListConfig.withType(
      name: 'Mis Favoritas',
      description: 'Películas que más me han gustado',
      emoji: '❤️',
      colorHex: '#EF4444',
      defaultType: 'favorites',
    ),
    DefaultListConfig.withType(
      name: 'Por Ver',
      description: 'Películas que quiero ver próximamente',
      emoji: '📺',
      colorHex: '#3B82F6',
      defaultType: 'watchlist',
    ),
    DefaultListConfig.withType(
      name: 'Vistas Recientemente',
      description: 'Películas que he visto últimamente',
      emoji: '👁️',
      colorHex: '#10B981',
      defaultType: 'watched',
    ),
    DefaultListConfig.withType(
      name: 'Recomendadas',
      description: 'Películas recomendadas para ti',
      emoji: '🎯',
      colorHex: '#8B5CF6',
      defaultType: 'trending',
    ),
  ];

  /// Verifica y crea las listas predeterminadas si no existen
  Future<void> ensureDefaultListsExist() async {
    if (_isInitializing) {
      LoggerFactory.info('⏳ Ya hay una inicialización de listas en progreso');
      return;
    }

    try {
      _isInitializing = true;

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        LoggerFactory.info(
            '❌ No hay usuario autenticado - cancelando creación de listas predeterminadas');
        return;
      }

      // Validar que el userId del usuario sea válido
      if (currentUser.id.isEmpty) {
        LoggerFactory.error(
            '❌ ID de usuario vacío o inválido - cancelando creación de listas predeterminadas');
        return;
      }

      LoggerFactory.info(
          '🔍 Verificando listas predeterminadas para usuario: ${currentUser.email} (ID: ${currentUser.id})');

      // Obtener repositorio
      final repository = await ref
          .read(customListsRepositoryProvider.future)
          .timeout(const Duration(seconds: 10));

      // Verificar listas existentes
      final existingLists = await repository
          .getDefaultLists()
          .timeout(const Duration(seconds: 10));

      LoggerFactory.info(
          '📋 Listas predeterminadas existentes: ${existingLists.length}');

      // Verificar qué listas faltan
      final missingLists = <DefaultListConfig>[];

      for (final config in _defaultConfigs) {
        // Verificar por defaultType en lugar de solo por nombre para evitar duplicados
        final exists = existingLists.any((list) => 
          list.defaultType == config.defaultType && 
          list.isDefault == true);
        if (!exists) {
          missingLists.add(config);
          LoggerFactory.info('❌ Lista faltante: ${config.name} (tipo: ${config.defaultType})');
        } else {
          LoggerFactory.info('✅ Lista existe: ${config.name} (tipo: ${config.defaultType})');
        }
      }

      // Crear listas faltantes
      if (missingLists.isNotEmpty) {
        LoggerFactory.info(
            '🛠️ Creando ${missingLists.length} listas predeterminadas faltantes...');
        await _createMissingDefaultLists(missingLists);
      } else {
        LoggerFactory.info('✅ Todas las listas predeterminadas ya existen');
      }

      // Invalidar providers para refrescar la UI
      ref.invalidate(userListsProvider);
      ref.invalidate(customListsNotifierProvider);
    } on TimeoutException catch (e) {
      LoggerFactory.error('⏰ Timeout verificando listas predeterminadas: $e');
    } catch (e, stack) {
      LoggerFactory.error('❌ Error verificando listas predeterminadas: $e');
      LoggerFactory.error('Stack: $stack');
    } finally {
      _isInitializing = false;
    }
  }

  /// Crea las listas predeterminadas faltantes
  Future<void> _createMissingDefaultLists(
      List<DefaultListConfig> missingConfigs) async {
    try {
      final listActions = await ref
          .read(listActionsProvider.future)
          .timeout(const Duration(seconds: 10));

      int createdCount = 0;
      int failedCount = 0;

      for (final config in missingConfigs) {
        try {
          LoggerFactory.info('📝 Creando lista: ${config.name}');

          await listActions
              .createList(
                name: config.name,
                description: config.description,
                emoji: config.emoji,
                colorHex: config.color,
                isDefault: true,
                defaultType: config.defaultType,
              )
              .timeout(const Duration(seconds: 8));

          createdCount++;
          LoggerFactory.info('✅ Lista creada exitosamente: ${config.name}');

          // Pequeña pausa entre creaciones para evitar saturar la API
          if (createdCount < missingConfigs.length) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          failedCount++;
          LoggerFactory.error('❌ Error creando lista ${config.name}: $e');

          // Si es un error de autenticación, no continuar con las demás
          if (e.toString().contains('Usuario no autenticado') ||
              e.toString().contains('ID de usuario inválido')) {
            LoggerFactory.error(
                '🛑 Error de autenticación detectado, cancelando creación de listas restantes');
            break;
          }
        }
      }

      LoggerFactory.info(
          '✅ Proceso completado: $createdCount creadas, $failedCount fallidas de ${missingConfigs.length} listas');
    } catch (e, stack) {
      LoggerFactory.error('❌ Error en proceso de creación de listas: $e');
      LoggerFactory.error('Stack: $stack');
    }
  }

  /// Fuerza la verificación y creación de listas (para usar manualmente)
  Future<String> forceCheckAndCreateLists() async {
    try {
      await ensureDefaultListsExist();
      return '✅ Verificación de listas predeterminadas completada';
    } catch (e) {
      final errorMsg = '❌ Error forzando verificación de listas: $e';
      LoggerFactory.error(errorMsg);
      return errorMsg;
    }
  }
}
