import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';
import 'auth_provider.dart';

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
          'ℹ️ Listas predeterminadas deshabilitadas - nada por crear para ${currentUser.email}');
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
    await ensureDefaultListsExist();
    return 'ℹ️ Las listas predeterminadas están deshabilitadas; no se realizaron cambios';
  }
}
