import 'dart:io';

import 'package:peliculas/core/logging/logger_factory.dart';

void main() async {
  LoggerFactory.info('🔧 Arreglando withOpacity deprecated API...');

  final libDir = Directory('lib');
  int replacements = 0;
  int filesModified = 0;

  await for (final file in libDir.list(recursive: true, followLinks: false)) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = await file.readAsString();
      String newContent = content;

      // Reemplazar .withOpacity(value) con .withValues(alpha: value)
      final withOpacityRegex = RegExp(r'\.withOpacity\(([^)]+)\)');

      newContent = newContent.replaceAllMapped(withOpacityRegex, (match) {
        final opacityValue = match.group(1)!;
        replacements++;
        return '.withValues(alpha: $opacityValue)';
      });

      if (newContent != content) {
        await file.writeAsString(newContent);
        filesModified++;
        LoggerFactory.info('✅ ${file.path.split('\\').last}');
      }
    }
  }

  LoggerFactory.info('');
  LoggerFactory.info('📊 Resumen withOpacity:');
  LoggerFactory.info('   🔄 Reemplazos realizados: $replacements');
  LoggerFactory.info('   📁 Archivos modificados: $filesModified');
  LoggerFactory.info('🎉 ¡Completado!');
}
