import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lib/presentation/providers/storage/direct_custom_lists_provider.dart';

/// Script de diagnóstico mejorado para debugging de addMovieToList
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🔍 [DIAGNOSTIC] Iniciando diagnóstico completo de addMovieToList...');

  // Simular un container de Riverpod
  final container = ProviderContainer();

  try {
    // Obtener el notifier
    final notifier = container.read(directCustomListsProvider.notifier);
    print('✅ [DIAGNOSTIC] DirectCustomListsNotifier obtenido');

    // Esperar inicialización
    await Future.delayed(const Duration(seconds: 3));

    // Obtener el estado actual
    final currentState = container.read(directCustomListsProvider);
    print('📊 [DIAGNOSTIC] Estado actual:');
    print('   - Listas: ${currentState.lists.length}');
    print('   - Items: ${currentState.listItems.length}');

    // Mostrar listas disponibles
    if (currentState.lists.isNotEmpty) {
      print('📋 [DIAGNOSTIC] Listas disponibles:');
      currentState.lists.forEach((id, list) {
        final itemCount = currentState.listItems[id]?.length ?? 0;
        print('   - ${list.name} (ID: $id) - $itemCount películas');
      });

      // Usar la primera lista disponible para la prueba
      final firstListId = currentState.lists.keys.first;
      const testMovieId = 999999; // ID de película de prueba

      print(
          '🎬 [DIAGNOSTIC] Intentando agregar película $testMovieId a lista $firstListId');

      // Realizar la prueba real
      try {
        await notifier.addMovieToList(firstListId, testMovieId);
        print('✅ [DIAGNOSTIC] addMovieToList ejecutado sin errores');

        // Verificar el estado después
        await Future.delayed(const Duration(seconds: 1));
        final newState = container.read(directCustomListsProvider);
        final newItems = newState.listItems[firstListId] ?? [];

        if (newItems.contains(testMovieId)) {
          print('🎉 [SUCCESS] Película agregada correctamente al estado local');
        } else {
          print('❌ [FAILURE] Película NO encontrada en el estado local');
        }
        print('� [DIAGNOSTIC] Items en lista después: $newItems');
      } catch (addError, stackTrace) {
        print('❌ [ERROR] Error al ejecutar addMovieToList: $addError');
        print('📍 [ERROR] StackTrace: $stackTrace');
      }
    } else {
      print('⚠️ [DIAGNOSTIC] No hay listas disponibles para probar');
      print(
          '💡 [DIAGNOSTIC] Sugerencia: Crear listas primero o verificar la carga inicial');
    }
  } catch (e, stackTrace) {
    print('❌ [DIAGNOSTIC] Error crítico durante diagnóstico: $e');
    print('📍 [DIAGNOSTIC] StackTrace: $stackTrace');
  } finally {
    container.dispose();
    print('🔧 [DIAGNOSTIC] Container disposed');
  }

  print('� [DIAGNOSTIC] Diagnóstico completo terminado');
}
