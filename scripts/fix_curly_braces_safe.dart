import 'dart:io';

import 'package:peliculas/core/logging/logger_factory.dart';

void main() async {
  LoggerFactory.info('🔧 Arreglando curly braces de manera conservadora...');

  // Directorio lib
  final libDir = Directory('lib');

  // Contadores
  int curlyBracesFixed = 0;
  int filesModified = 0;

  await for (final file in libDir.list(recursive: true, followLinks: false)) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = await file.readAsString();
      final lines = content.split('\n');
      bool fileModified = false;

      for (int i = 0; i < lines.length; i++) {
        String line = lines[i];

        // Solo procesar líneas que claramente necesitan curly braces
        // Patrón: if (condition) statement;
        if (RegExp(r'^(\s*)if\s*\([^)]+\)\s*[^{][^;]*;$').hasMatch(line)) {
          final match = RegExp(r'^(\s*)if\s*\(([^)]+)\)\s*([^{][^;]*;)$')
              .firstMatch(line);
          if (match != null) {
            final indentation = match.group(1)!;
            final condition = match.group(2)!;
            final statement = match.group(3)!.trim();

            // Verificar que no sea código complejo
            if (!statement.contains('{') &&
                !statement.contains('}') &&
                statement.length < 80) {
              lines[i] = '${indentation}if ($condition) {';
              // Insertar el statement en la siguiente línea con más indentación
              lines.insert(i + 1, '$indentation  $statement');
              lines.insert(i + 2, '$indentation}');
              i += 2; // Skip the inserted lines
              curlyBracesFixed++;
              fileModified = true;
            }
          }
        }

        // Patrón: else statement;
        else if (RegExp(r'^(\s*)else\s*[^{][^;]*;$').hasMatch(line)) {
          final match = RegExp(r'^(\s*)else\s*([^{][^;]*;)$').firstMatch(line);
          if (match != null) {
            final indentation = match.group(1)!;
            final statement = match.group(2)!.trim();

            // Verificar que no sea código complejo
            if (!statement.contains('{') &&
                !statement.contains('}') &&
                statement.length < 80) {
              lines[i] = '${indentation}else {';
              lines.insert(i + 1, '$indentation  $statement');
              lines.insert(i + 2, '$indentation}');
              i += 2; // Skip the inserted lines
              curlyBracesFixed++;
              fileModified = true;
            }
          }
        }
      }

      if (fileModified) {
        await file.writeAsString(lines.join('\n'));
        filesModified++;
        LoggerFactory.info('✅ Arreglado: ${file.path}');
      }
    }
  }

  LoggerFactory.info('');
  LoggerFactory.info('📊 Resumen de arreglos:');
  LoggerFactory.info('   🔧 Curly braces arreglados: $curlyBracesFixed');
  LoggerFactory.info('   📁 Archivos modificados: $filesModified');
  LoggerFactory.info('');
  LoggerFactory.info('🎉 ¡Arreglo de curly braces completado!');
}
