/// Herramienta de debugging específica para el problema de addMovieToList
///
/// Esta herramienta nos permitirá identificar exactamente dónde está fallando
/// el proceso de agregar películas a listas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lib/presentation/providers/storage/direct_custom_lists_provider.dart';

class MovieListDebugger {
  static bool _initialized = false;

  /// Inicializar debugging environment
  static Future<void> initialize() async {
    if (_initialized) return;

    WidgetsFlutterBinding.ensureInitialized();

    print('🔧 [DEBUGGER] Inicializando ambiente de debugging...');

    // TODO: Si necesitas configurar Supabase, hazlo aquí
    // Comentado porque necesitaríamos las credenciales reales:
    /*
    await Supabase.initialize(
      url: 'your_supabase_url',
      anonKey: 'your_supabase_anon_key',
    );
    */

    _initialized = true;
    print('✅ [DEBUGGER] Ambiente inicializado');
  }

  /// Test completo del flujo de addMovieToList
  static Future<void> runCompleteTest() async {
    await initialize();

    print(
        '🎯 [DEBUGGER] ==================== INICIO TEST COMPLETO ====================');

    final container = ProviderContainer();

    try {
      // 1. Verificar que el provider existe y es accesible
      print('📋 [DEBUGGER] Paso 1: Verificando provider...');
      final notifier = container.read(directCustomListsProvider.notifier);
      print('✅ [DEBUGGER] Provider obtenido: ${notifier.runtimeType}');

      // 2. Esperar inicialización
      print('⏳ [DEBUGGER] Paso 2: Esperando inicialización...');
      await Future.delayed(const Duration(seconds: 2));

      // 3. Verificar estado inicial
      print('📊 [DEBUGGER] Paso 3: Verificando estado inicial...');
      final initialState = container.read(directCustomListsProvider);
      print('   - Listas cargadas: ${initialState.lists.length}');
      print('   - Items cargados: ${initialState.listItems.length}');

      if (initialState.lists.isEmpty) {
        print(
            '⚠️ [DEBUGGER] No hay listas disponibles - creando lista de prueba...');
        await _createTestList(notifier);
        await Future.delayed(const Duration(seconds: 1));
      }

      // 4. Obtener estado actualizado
      final updatedState = container.read(directCustomListsProvider);
      print('📊 [DEBUGGER] Estado después de posible creación de lista:');
      print('   - Listas: ${updatedState.lists.length}');
      updatedState.lists.forEach((id, list) {
        print('     * ${list.name} (ID: $id)');
      });

      if (updatedState.lists.isNotEmpty) {
        // 5. Probar addMovieToList
        final testListId = updatedState.lists.keys.first;
        const testMovieId = 999999;

        print('🎬 [DEBUGGER] Paso 4: Probando addMovieToList...');
        print('   - Lista ID: $testListId');
        print('   - Película ID: $testMovieId');

        // Verificar estado ANTES
        final itemsBefore = updatedState.listItems[testListId] ?? [];
        print('   - Items antes: $itemsBefore');

        try {
          await notifier.addMovieToList(testListId, testMovieId);
          print('✅ [DEBUGGER] addMovieToList ejecutado sin excepción');

          // Verificar estado DESPUÉS
          await Future.delayed(const Duration(seconds: 1));
          final finalState = container.read(directCustomListsProvider);
          final itemsAfter = finalState.listItems[testListId] ?? [];
          print('   - Items después: $itemsAfter');

          if (itemsAfter.contains(testMovieId)) {
            print(
                '🎉 [SUCCESS] ¡Película agregada exitosamente al estado local!');
          } else {
            print('❌ [FAILURE] Película NO encontrada en el estado local');
            print('💡 [DEBUGGER] Posibles causas:');
            print('   1. Error en TriggerFreeCustomListsSync');
            print('   2. Validación que impide la inserción');
            print('   3. Usuario no autenticado');
            print('   4. Lista ID inválido');
          }
        } catch (e, stackTrace) {
          print('❌ [ERROR] Excepción durante addMovieToList: $e');
          print('📍 [ERROR] StackTrace: $stackTrace');
        }
      } else {
        print('❌ [DEBUGGER] No se pudieron cargar o crear listas para probar');
      }
    } catch (e, stackTrace) {
      print('❌ [DEBUGGER] Error crítico en test: $e');
      print('📍 [DEBUGGER] StackTrace: $stackTrace');
    } finally {
      container.dispose();
      print('🔧 [DEBUGGER] Container disposed');
    }

    print(
        '🎯 [DEBUGGER] ==================== FIN TEST COMPLETO ====================');
  }

  /// Crear una lista de prueba para testing
  static Future<void> _createTestList(
      DirectCustomListsNotifier notifier) async {
    print('🏗️ [DEBUGGER] Intentando crear lista de prueba...');

    try {
      // Intentar crear la lista usando el método del notifier
      // Nota: Esto podría fallar si no hay implementación de createList
      // await notifier.createList("Lista Debug Test", "Lista creada automáticamente para debugging");

      print('✅ [DEBUGGER] Lista de prueba creada (o intentada)');
    } catch (e) {
      print('⚠️ [DEBUGGER] No se pudo crear lista de prueba: $e');
    }
  }
}

/// Punto de entrada principal para debugging
void main() async {
  await MovieListDebugger.runCompleteTest();
}
