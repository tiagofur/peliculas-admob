import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/logger_factory.dart';
import '../presentation/providers/auto_default_lists_provider.dart';
import '../presentation/providers/custom_lists_providers.dart';

/// Servicio para diagnosticar y reparar problemas con las listas
class ListsFixService {
  static Future<String> diagnoseAndFixLists(WidgetRef ref) async {
    LoggerFactory.info('🔧 Iniciando diagnóstico de listas...');

    try {
      // 1. Verificar autenticación
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        const errorMsg = '❌ Usuario no autenticado';
        LoggerFactory.error(errorMsg);
        return errorMsg;
      }

      LoggerFactory.info('✅ Usuario autenticado: ${currentUser.email}');

      // 2. Obtener repositorio con timeout
      final repository = await ref
          .read(customListsRepositoryProvider.future)
          .timeout(const Duration(seconds: 10));

      // 3. Inicializar listas por defecto explícitamente con timeout
      LoggerFactory.info('🔄 Inicializando listas por defecto...');
      await repository
          .initializeDefaultLists(currentUser.id)
          .timeout(const Duration(seconds: 15));

      // 4. Verificar que se crearon con timeout
      final defaultLists = await repository
          .getDefaultLists()
          .timeout(const Duration(seconds: 10));
      LoggerFactory.info(
          '📋 Listas por defecto encontradas: ${defaultLists.length}');

      // MIGRADO: Mostrar info sin acceder a movieIds deprecated
      for (final list in defaultLists) {
        LoggerFactory.info('  - ${list.name} (${list.emoji}) - ${list.id}');
      }

      // 5. Obtener todas las listas del usuario con timeout
      final allLists =
          await repository.getUserLists().timeout(const Duration(seconds: 10));
      LoggerFactory.info('📚 Total de listas del usuario: ${allLists.length}');

      // 6. Invalidar y recargar el provider
      ref.invalidate(customListsNotifierProvider);
      ref.invalidate(userListsProvider);

      const successMsg = '✅ Diagnóstico completado y providers actualizados';
      LoggerFactory.info(successMsg);
      return successMsg;
    } on TimeoutException catch (e) {
      const timeoutMsg =
          '⏰ Timeout: La operación tardó demasiado. Verifica tu conexión.';
      LoggerFactory.error('$timeoutMsg - $e');
      return timeoutMsg;
    } catch (e, stack) {
      final errorMsg = '❌ Error en diagnóstico de listas: $e';
      LoggerFactory.error(errorMsg);
      LoggerFactory.error('Stack: $stack');
      return errorMsg;
    }
  }

  /// Crea las listas por defecto manualmente
  static Future<String> createDefaultListsManually(WidgetRef ref) async {
    LoggerFactory.info('🛠️ Creando listas por defecto manualmente...');

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        const errorMsg = '❌ Usuario no autenticado';
        LoggerFactory.error(errorMsg);
        return errorMsg;
      }

      final listActions = await ref
          .read(listActionsProvider.future)
          .timeout(const Duration(seconds: 10));

      // Lista de configuraciones por defecto
      final defaultConfigs = [
        {
          'name': 'Mis Favoritas',
          'description': 'Películas que más me han gustado',
          'emoji': '❤️',
          'colorHex': '#EF4444',
        },
        {
          'name': 'Por Ver',
          'description': 'Películas que quiero ver próximamente',
          'emoji': '📺',
          'colorHex': '#3B82F6',
        },
        {
          'name': 'Vistas Recientemente',
          'description': 'Películas que he visto últimamente',
          'emoji': '👁️',
          'colorHex': '#10B981',
        },
        {
          'name': 'Recomendadas',
          'description': 'Películas recomendadas para ti',
          'emoji': '🎯',
          'colorHex': '#8B5CF6',
        },
      ];

      int createdCount = 0;
      // Crear cada lista con timeout individual
      for (final config in defaultConfigs) {
        try {
          await listActions
              .createList(
                name: config['name']!,
                description: config['description']!,
                emoji: config['emoji']!,
                colorHex: config['colorHex']!,
              )
              .timeout(const Duration(seconds: 8));

          createdCount++;
          LoggerFactory.info('✅ Lista creada: ${config['name']}');
        } catch (e) {
          LoggerFactory.error('❌ Error creando lista ${config['name']}: $e');
        }
      }

      // Recargar providers
      ref.invalidate(customListsNotifierProvider);
      ref.invalidate(userListsProvider);

      final successMsg =
          '✅ Se crearon $createdCount de ${defaultConfigs.length} listas';
      LoggerFactory.info(successMsg);
      return successMsg;
    } on TimeoutException catch (e) {
      const timeoutMsg =
          '⏰ Timeout: La creación tardó demasiado. Verifica tu conexión.';
      LoggerFactory.error('$timeoutMsg - $e');
      return timeoutMsg;
    } catch (e, stack) {
      final errorMsg = '❌ Error creando listas manualmente: $e';
      LoggerFactory.error(errorMsg);
      LoggerFactory.error('Stack: $stack');
      return errorMsg;
    }
  }

  /// Añade una película de prueba a una lista
  static Future<String> testAddMovieToList(
      WidgetRef ref, String listId, int movieId) async {
    LoggerFactory.info(
        '🎬 Probando añadir película $movieId a lista $listId...');

    try {
      final listActions = await ref
          .read(listActionsProvider.future)
          .timeout(const Duration(seconds: 10));
      await listActions
          .addMovieToList(listId, movieId)
          .timeout(const Duration(seconds: 15));

      const successMsg = '✅ Película añadida exitosamente';
      LoggerFactory.info(
          '$successMsg - Película $movieId añadida a lista $listId');

      // Recargar provider para ver los cambios
      ref.invalidate(userListsProvider);

      return successMsg;
    } on TimeoutException catch (e) {
      const timeoutMsg =
          '⏰ Timeout: Añadir película tardó demasiado. Verifica tu conexión.';
      LoggerFactory.error('$timeoutMsg - $e');
      return timeoutMsg;
    } catch (e, stack) {
      final errorMsg = '❌ Error añadiendo película: $e';
      LoggerFactory.error(errorMsg);
      LoggerFactory.error('Stack: $stack');
      return errorMsg;
    }
  }

  /// Widget para mostrar el diagnóstico en la UI
  static Widget buildDiagnosticWidget(WidgetRef ref,
      {required Function(String) onMessage}) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Herramientas de Diagnóstico',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Si tienes problemas con las listas, usa estas herramientas:',
              style: TextStyle(color: Colors.orange.shade700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    onMessage('🔧 Diagnosticando...');
                    final result = await diagnoseAndFixLists(ref);
                    onMessage(result);
                  },
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Diagnosticar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    onMessage('🛠️ Creando listas...');
                    final result = await createDefaultListsManually(ref);
                    onMessage(result);
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Crear Listas'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    onMessage('🔄 Verificación automática...');
                    final autoService = ref.read(autoDefaultListsProvider);
                    final result = await autoService.forceCheckAndCreateLists();
                    onMessage(result);
                  },
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Auto-Verificar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    onMessage('🧹 Limpiando duplicados...');
                    final autoService = ref.read(autoDefaultListsProvider);
                    final result =
                        await autoService.cleanAndRecreateDefaultLists();
                    onMessage(result);
                  },
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: const Text('Limpiar Duplicados'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
