import 'dart:io';

void main() async {
  // Lista de archivos que necesitan corrección
  final filesToFix = [
    'lib/infrastructure/services/device_sync_manager.dart',
    'lib/core/sync/trigger_free_watched_sync.dart',
    'lib/core/sync/watched_sync_manager.dart',
    'lib/core/sync/trigger_free_favorites_sync.dart',
    'lib/infrastructure/repositories/auth_repository_impl.dart',
    'lib/services/lists_migration_service.dart',
    'lib/core/sync/simple_favorites_sync.dart',
    'lib/services/database_verification_service.dart',
    'lib/core/sync/simple_polling_sync.dart',
    'lib/core/sync/ratings_sync_manager.dart',
    'lib/core/sync/silent_favorites_sync_service.dart',
    'lib/core/sync/simple_watched_sync.dart',
    'lib/services/migration_rollback_service.dart',
    'lib/infrastructure/repositories/user_movie_ratings_repository_impl.dart',
    'lib/core/sync/trigger_free_custom_lists_sync.dart',
    'lib/core/sync/watchlist_sync_manager.dart',
    'lib/core/sync/trigger_free_watchlist_sync.dart',
  ];

  int correctedFiles = 0;

  for (final filePath in filesToFix) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        print('Archivo no encontrado: $filePath');
        continue;
      }

      String content = await file.readAsString();
      String originalContent = content;

      // Reemplazar los patrones problemáticos más específicos primero
      content = content.replaceAll(
          r'.filter(\1, "eq", \2)', '.filter("user_id", "eq", userId)');
      content = content.replaceAll(
          r'.filter(\1, "eq", \2);', '.filter("user_id", "eq", userId);');

      if (content != originalContent) {
        await file.writeAsString(content);
        print('Corregido: $filePath');
        correctedFiles++;
      }
    } catch (e) {
      print('Error procesando $filePath: $e');
    }
  }

  print('Corrección completada para $correctedFiles archivos.');
}
