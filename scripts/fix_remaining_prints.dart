import 'dart:io';

import 'package:peliculas/core/logging/logger_factory.dart';

void main() async {
  LoggerFactory.info('🔧 Arreglando print statements restantes...');

  final libDir = Directory('lib');
  int printStatementsFixed = 0;
  int filesModified = 0;

  await for (final file in libDir.list(recursive: true, followLinks: false)) {
    if (file is File &&
        file.path.endsWith('.dart') &&
        !file.path.contains('test/') &&
        !file.path.contains('scripts/')) {
      final content = await file.readAsString();
      final lines = content.split('\n');
      bool fileModified = false;
      bool needsImport = !content.contains('LoggerFactory');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        // Buscar print statements más específicamente
        if (RegExp(r'^\s*print\s*\(').hasMatch(line) &&
            line.contains(');') &&
            !line.contains('LoggerFactory') &&
            !line.contains('//') && // Skip commented prints
            line.length < 150) {
          // Obtener indentación original
          final indentation = line.substring(0, line.indexOf('print('));

          // Extraer contenido del print usando regex más robusto
          final printMatch = RegExp(r'print\s*\((.+?)\);').firstMatch(line);
          if (printMatch != null) {
            final printContent = printMatch.group(1)!;

            // Determinar nivel basado en contenido
            String logMethod = 'info';
            final lowerContent = printContent.toLowerCase();

            if (lowerContent.contains('error') ||
                lowerContent.contains('exception') ||
                lowerContent.contains('failed')) {
              logMethod = 'error';
            } else if (lowerContent.contains('debug') ||
                lowerContent.contains('trace')) {
              logMethod = 'debug';
            } else if (lowerContent.contains('warning') ||
                lowerContent.contains('warn')) {
              logMethod = 'warning';
            }

            // Reemplazar con LoggerFactory
            lines[i] = '${indentation}LoggerFactory.$logMethod($printContent);';
            printStatementsFixed++;
            fileModified = true;
          }
        }
      }

      if (fileModified) {
        String newContent = lines.join('\n');

        // Agregar import si no existe y se hicieron cambios
        if (needsImport) {
          // Calcular ruta relativa correcta
          final relativePath = file.path.replaceAll(
              r'c:\Users\tfurt\source\repos\peliculas-admob\lib\', '');
          final pathParts = relativePath.split(r'\');
          final depth = pathParts.length - 1;

          String relativeImport = '';
          for (int i = 0; i < depth; i++) {
            relativeImport += '../';
          }
          relativeImport += 'core/logging/logger_factory.dart';

          // Buscar donde insertar el import
          final contentLines = newContent.split('\n');
          int insertIndex = 0;

          // Buscar la última línea de import
          for (int i = 0; i < contentLines.length; i++) {
            if (contentLines[i].startsWith('import ')) {
              insertIndex = i + 1;
            }
            if (contentLines[i].trim().isEmpty && insertIndex > 0) {
              break;
            }
          }

          // Insertar el import
          contentLines.insert(insertIndex, 'import \'$relativeImport\';');
          newContent = contentLines.join('\n');
        }

        await file.writeAsString(newContent);
        filesModified++;
        LoggerFactory.info(
            '✅ ${file.path.split('\\').last} (+$printStatementsFixed prints)');
      }
    }
  }

  LoggerFactory.info('');
  LoggerFactory.info('📊 Resumen Round 2:');
  LoggerFactory.info(
      '   📝 Print statements convertidos: $printStatementsFixed');
  LoggerFactory.info('   📁 Archivos modificados: $filesModified');
  LoggerFactory.info('🎉 ¡Segunda ronda completada!');
}
