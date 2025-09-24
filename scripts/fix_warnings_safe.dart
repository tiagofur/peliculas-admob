import 'dart:io';

import 'package:peliculas/core/logging/logger_factory.dart';

void main() async {
  LoggerFactory.info('🔧 Iniciando arreglo conservador de warnings...');

  // Directorio lib
  final libDir = Directory('lib');

  // Contadores
  int printStatementsFixed = 0;
  int filesModified = 0;

  await for (final file in libDir.list(recursive: true, followLinks: false)) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = await file.readAsString();
      String newContent = content;
      bool fileModified = false;

      // Solo convertir print statements muy simples en archivos que no sean de test
      if (!file.path.contains('test/')) {
        // Buscar print statements muy específicos y seguros
        final lines = newContent.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();

          // Solo procesar líneas que son claramente print statements simples
          if (line.startsWith('print(') &&
              line.endsWith(');') &&
              !line.contains('LoggerFactory') &&
              !line.contains('==') &&
              !line.contains('operator') &&
              line.length < 100) {
            // Evitar líneas muy largas que podrían ser complejas

            // Extraer el contenido del print
            final printContent =
                line.substring(6, line.length - 2); // Quitar 'print(' y ');'

            // Validar que el contenido es seguro (no contiene sintaxis compleja)
            if (!printContent.contains('==') &&
                !printContent.contains('operator') &&
                !printContent.contains('{') &&
                !printContent.contains('}')) {
              // Determinar el nivel de log
              String logLevel = 'info';
              final lowerContent = printContent.toLowerCase();
              if (lowerContent.contains('"error') ||
                  lowerContent.contains("'error")) {
                logLevel = 'error';
              } else if (lowerContent.contains('"debug') ||
                  lowerContent.contains("'debug")) {
                logLevel = 'debug';
              } else if (lowerContent.contains('"warning') ||
                  lowerContent.contains("'warning")) {
                logLevel = 'warning';
              }

              // Obtener la indentación original
              final originalLine = lines[i];
              final indentation =
                  originalLine.substring(0, originalLine.indexOf('print('));

              // Reemplazar la línea
              lines[i] =
                  '${indentation}LoggerFactory.getLogger(runtimeType).$logLevel($printContent);';
              printStatementsFixed++;
              fileModified = true;
            }
          }
        }

        if (fileModified) {
          newContent = lines.join('\n');

          // Agregar import si no existe y se hicieron cambios
          if (!content.contains('LoggerFactory')) {
            // Buscar la primera línea de import
            final importLines = <String>[];
            final otherLines = <String>[];
            bool foundFirstImport = false;
            bool addedLoggerImport = false;

            for (final line in newContent.split('\n')) {
              if (line.startsWith('import ')) {
                foundFirstImport = true;
                importLines.add(line);
                // Agregar el import del logger después del primer import
                if (!addedLoggerImport) {
                  importLines.add(
                      'import \'package:peliculas_admob/core/utils/logger_factory.dart\';');
                  addedLoggerImport = true;
                }
              } else {
                if (foundFirstImport &&
                    line.trim().isEmpty &&
                    importLines.isNotEmpty) {
                  // Esta es la línea vacía después de los imports
                  importLines.add(line);
                } else {
                  otherLines.add(line);
                }
              }
            }

            if (addedLoggerImport) {
              newContent = [...importLines, ...otherLines].join('\n');
            }
          }

          await file.writeAsString(newContent);
          filesModified++;
          LoggerFactory.info(
              '✅ Arreglado: ${file.path} ($printStatementsFixed prints)');
        }
      }
    }
  }

  LoggerFactory.info('');
  LoggerFactory.info('📊 Resumen de arreglos conservadores:');
  LoggerFactory.info(
      '   📝 Print statements convertidos: $printStatementsFixed');
  LoggerFactory.info('   📁 Archivos modificados: $filesModified');
  LoggerFactory.info('');
  LoggerFactory.info('🎉 ¡Arreglo conservador completado!');
}
