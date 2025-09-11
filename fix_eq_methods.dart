import 'dart:io';

void main() async {
  // Lista de archivos que necesitan corrección
  final filesToFix = [
    'lib/infrastructure/repositories/auth_repository_impl.dart',
    'lib/core/sync/silent_favorites_sync_service.dart',
    'lib/core/sync/ratings_sync_manager.dart',
    'lib/core/sync/trigger_free_favorites_sync.dart',
    'lib/core/sync/watchlist_sync_manager.dart',
    'lib/services/database_verification_service.dart',
    'lib/core/sync/simple_polling_sync.dart',
    'lib/core/sync/trigger_free_watched_sync.dart',
    'lib/services/lists_migration_service.dart',
    'lib/core/sync/simple_watched_sync.dart',
    'lib/core/sync/favorites_sync_manager.dart',
    'lib/core/sync/simple_favorites_sync.dart',
    'lib/infrastructure/services/device_sync_manager.dart',
    'lib/core/sync/trigger_free_custom_lists_sync.dart',
    'lib/services/migration_rollback_service.dart',
    'lib/infrastructure/repositories/user_movie_ratings_repository_impl.dart',
    'lib/core/sync/trigger_free_watchlist_sync.dart',
    'lib/core/sync/watched_sync_manager.dart',
  ];

  for (final filePath in filesToFix) {
    await fixEqMethodsInFile(filePath);
  }

  print('Corrección completada para ${filesToFix.length} archivos.');
}

Future<void> fixEqMethodsInFile(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      print('Archivo no encontrado: $filePath');
      return;
    }

    String content = await file.readAsString();
    
    // Patrones de reemplazo para diferentes casos de .eq()
    final Map<RegExp, String> replacements = {
      // Caso simple: .eq('campo', valor)
      RegExp(r'\.eq\(([^,]+),\s*([^)]+)\)'): r'.filter(\1, "eq", \2)',
    };
    
    // Casos específicos adicionales
    final Map<String, String> specificReplacements = {
      '.eq(\'user_id\', userId)': '.filter(\'user_id\', \'eq\', userId)',
      '.eq(\'movie_id\', movieId)': '.filter(\'movie_id\', \'eq\', movieId)',
      '.eq(\'is_deleted\', false)': '.filter(\'is_deleted\', \'eq\', false)',
      '.eq(\'is_deleted\', true)': '.filter(\'is_deleted\', \'eq\', true)',
      '.eq(\'id\', userId)': '.filter(\'id\', \'eq\', userId)',
      '.eq(\'id\', listId)': '.filter(\'id\', \'eq\', listId)',
      '.eq(\'list_id\', listId)': '.filter(\'list_id\', \'eq\', listId)',
    };

    bool hasChanges = false;
    
    // Aplicar reemplazos con RegExp
    for (final entry in replacements.entries) {
      if (entry.key is RegExp) {
        final newContent = content.replaceAll(entry.key as RegExp, entry.value);
        if (newContent != content) {
          content = newContent;
          hasChanges = true;
        }
      }
    }
    
    // Aplicar reemplazos específicos
    for (final entry in specificReplacements.entries) {
      final newContent = content.replaceAll(entry.key, entry.value);
      if (newContent != content) {
        content = newContent;
        hasChanges = true;
      }
    }

    if (hasChanges) {
      await file.writeAsString(content);
      print('Corregido: $filePath');
    } else {
      print('Sin cambios necesarios: $filePath');
    }
  } catch (e) {
    print('Error procesando $filePath: $e');
  }
}