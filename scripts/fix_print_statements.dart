import 'dart:io';

import 'package:peliculas/core/services/logger_factory.dart';

void main() async {
  LoggerFactory.info('🔧 Arreglando print statements con LoggerFactory...');

  final libDir = Directory('lib');
  int printStatementsFixed = 0;
  int filesModified = 0;

  await for (final file in libDir.list(recursive: true, followLinks: false)) {
    if (file is File &&
        file.path.endsWith('.dart') &&
        !file.path.contains('test/') &&
        !file.path.contains('logger') && // Evitar archivos de logging
        !file.path.contains('noop_logger')) {
      final content = await file.readAsString();
      final lines = content.split('\n');
      bool fileModified = false;
      bool needsImport = false;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmedLine = line.trim();

        // Solo procesar print statements muy simples y seguros
        if (trimmedLine.startsWith('print(') &&
            trimmedLine.endsWith(');') &&
            !trimmedLine.contains('LoggerFactory') &&
            !trimmedLine.contains('==') &&
            !trimmedLine.contains('operator') &&
            !trimmedLine.contains('{') &&
            !trimmedLine.contains('}') &&
            trimmedLine.length < 100) {
          // Obtener indentación original
          final indentation = line.substring(0, line.indexOf('print('));

          // Extraer contenido del print
          final printContent = trimmedLine.substring(6, trimmedLine.length - 2);

          // Determinar nivel basado en contenido
          String logMethod = 'info';
          if (printContent.toLowerCase().contains('"error') ||
              printContent.toLowerCase().contains("'error")) {
            logMethod = 'error';
          } else if (printContent.toLowerCase().contains('"debug') ||
              printContent.toLowerCase().contains("'debug")) {
            logMethod = 'debug';
          } else if (printContent.toLowerCase().contains('"warning') ||
              printContent.toLowerCase().contains("'warning")) {
            logMethod = 'warning';
          }

          // Reemplazar con LoggerFactory
          lines[i] = '${indentation}LoggerFactory.$logMethod($printContent);';
          printStatementsFixed++;
          fileModified = true;
          needsImport = true;
        }
      }

      if (fileModified) {
        String newContent = lines.join('\n');

        // Agregar import si no existe
        if (needsImport && !content.contains('LoggerFactory')) {
          // Buscar donde insertar el import
          final contentLines = newContent.split('\n');
          int insertIndex = 0;

          // Buscar la última línea de import
          for (int i = 0; i < contentLines.length; i++) {
            if (contentLines[i].startsWith('import ')) {
              insertIndex = i + 1;
            }
            if (contentLines[i].trim().isEmpty && insertIndex > 0) {
              break; // Encontramos la línea vacía después de imports
            }
          }

          // Insertar el import
          contentLines.insert(insertIndex,
              'import \'package:peliculas_admob/core/logging/logger_factory.dart\';');

          newContent = contentLines.join('\n');
        }

        await file.writeAsString(newContent);
        filesModified++;
        LoggerFactory.info(
            '✅ ${file.path.split('\\').last} ($printStatementsFixed total)');
      }
    }
  }

  LoggerFactory.info('');
  LoggerFactory.info('📊 Resumen:');
  LoggerFactory.info(
      '   📝 Print statements arreglados: $printStatementsFixed');
  LoggerFactory.info('   📁 Archivos modificados: $filesModified');
  LoggerFactory.info('🎉 ¡Completado!');
}
