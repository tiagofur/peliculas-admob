import 'dart:io';

import 'package:peliculas/core/logging/logger_factory.dart';

void main() async {
  LoggerFactory.info('🔧 Arreglando Share deprecated API...');

  final file = File('lib/services/social_sharing_service.dart');
  if (!file.existsSync()) {
    LoggerFactory.info('❌ Archivo no encontrado');
    return;
  }

  final content = await file.readAsString();
  String newContent = content;
  int replacements = 0;

  // Reemplazar Share.share( con Share.share(
  // El warning indica que 'Share' class está deprecated, pero al usar share_plus
  // el Share class de share_plus no debería estar deprecated

  // Verificar que no hay otro import de Share conflictivo
  if (newContent.contains("import 'package:share/share.dart';")) {
    // Reemplazar import viejo
    newContent = newContent.replaceAll("import 'package:share/share.dart';",
        "import 'package:share_plus/share_plus.dart';");
    replacements++;
    LoggerFactory.info('✅ Reemplazado import de share a share_plus');
  }

  await file.writeAsString(newContent);

  LoggerFactory.info('');
  LoggerFactory.info('📊 Resumen:');
  LoggerFactory.info('   🔄 Reemplazos realizados: $replacements');
  LoggerFactory.info('🎉 ¡Completado!');
}
