import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';
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
            'ℹ️ Sin usuario autenticado - no se crean listas predeterminadas');
        return;
      }

      if (currentUser.id.isEmpty) {
        LoggerFactory.error(
            'ℹ️ ID de usuario inválido - omitiendo listas predeterminadas');
        return;
      }

      LoggerFactory.info(
          '🎬 Verificando listas predeterminadas para ${currentUser.email}...');

      // Obtener el DefaultListsManager del provider
      final defaultListsManager = await ref
          .read(defaultListsManagerProvider.future)
          .timeout(const Duration(seconds: 10));

      // Inicializar listas predeterminadas (con caché integrado para rendimiento)
      await defaultListsManager
          .initializeDefaultLists(userId: currentUser.id)
          .timeout(const Duration(seconds: 15));

      LoggerFactory.info(
          '✅ Listas predeterminadas verificadas exitosamente para ${currentUser.email}');
    } on TimeoutException catch (e) {
      LoggerFactory.error(
          '⏰ Timeout en verificación de listas predeterminadas: $e');
    } catch (e, stack) {
      LoggerFactory.error('❌ Error al verificar listas predeterminadas: $e');
      LoggerFactory.error('Stack: $stack');
    } finally {
      _isInitializing = false;
    }
  }

  /// Fuerza la verificación y creación de listas (para usar manualmente)
  Future<String> forceCheckAndCreateLists() async {
    try {
      await ensureDefaultListsExist();
      return '✅ Verificación de listas predeterminadas completada';
    } catch (e) {
      return '❌ Error en verificación: $e';
    }
  }

  /// Limpia y recrea todas las listas predefinidas para resolver duplicados
  Future<String> cleanAndRecreateDefaultLists() async {
    try {
      LoggerFactory.info('🧹 Limpiando listas predefinidas duplicadas...');

      final defaultListsManager = await ref
          .read(defaultListsManagerProvider.future)
          .timeout(const Duration(seconds: 10));

      await defaultListsManager
          .cleanAndRecreateDefaultLists()
          .timeout(const Duration(seconds: 30));

      LoggerFactory.info('✅ Listas predefinidas limpiadas y recreadas');
      return '✅ Listas predefinidas limpiadas y recreadas correctamente';
    } catch (e) {
      LoggerFactory.error('❌ Error limpiando listas predefinidas: $e');
      return '❌ Error limpiando listas: $e';
    }
  }
}
