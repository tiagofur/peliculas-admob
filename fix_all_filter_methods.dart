import 'dart:io';

void main() async {
  final filesToFix = [
    'lib/core/sync/trigger_free_watchlist_sync.dart',
    'lib/infrastructure/services/sync_performance_optimizer.dart',
    'lib/infrastructure/repositories/auth_repository_impl.dart',
    'lib/core/notifications/notification_initialization_service.dart',
    'lib/core/sync/simple_watched_sync.dart',
    'lib/services/lists_migration_service.dart',
    'lib/infrastructure/datasources/supabase_custom_lists_datasource.dart',
    'lib/core/sync/ratings_sync_manager.dart',
    'lib/core/sync/trigger_free_watched_sync.dart',
    'lib/core/sync/trigger_free_favorites_sync.dart',
    'lib/core/sync/simple_polling_sync.dart',
    'lib/core/sync/simple_favorites_sync.dart',
    'lib/services/database_verification_service.dart',
    'lib/core/sync/trigger_free_custom_lists_sync.dart',
    'lib/core/sync/watched_sync_manager.dart',
    'lib/infrastructure/services/device_sync_manager.dart',
    'lib/core/sync/silent_favorites_sync_service.dart',
    'lib/core/sync/watchlist_sync_manager.dart',
    'lib/infrastructure/repositories/user_movie_ratings_repository_impl.dart',
    'lib/services/migration_rollback_service.dart',
  ];

  int totalFixed = 0;

  for (final filePath in filesToFix) {
    final file = File(filePath);

    if (!await file.exists()) {
      print('⚠️  Archivo no encontrado: $filePath');
      continue;
    }

    String content = await file.readAsString();
    final originalContent = content;
    int changesInFile = 0;

    // Corregir casos con comillas dobles
    content = content.replaceAllMapped(
        RegExp(r'\.filter\("([^"]+)",\s*"eq",\s*([^)]+)\)'),
        (match) => '.eq("${match.group(1)}", ${match.group(2)})');

    // Corregir casos con comillas simples
    content = content.replaceAllMapped(
        RegExp(r"\.filter\('([^']+)',\s*'eq',\s*([^)]+)\)"),
        (match) => ".eq('${match.group(1)}', ${match.group(2)})");

    // Contar cambios
    final originalMatches =
        RegExp(r'\.filter\(').allMatches(originalContent).length;
    final newMatches = RegExp(r'\.filter\(').allMatches(content).length;
    changesInFile = originalMatches - newMatches;

    if (content != originalContent) {
      await file.writeAsString(content);
      totalFixed++;
      print('✅ Corregido: $filePath');
      print(
          '   - Reemplazados ${filterPattern.allMatches(originalContent).length} usos de .filter() con .eq()');
    }
  }

  print('\n🎉 Corrección completada:');
  print('   - Archivos procesados: ${filesToFix.length}');
  print('   - Archivos corregidos: $totalFixed');
  print('   - Método .filter() reemplazado con .eq() en todos los archivos');
}
