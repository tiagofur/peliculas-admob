import 'dart:io';

import 'package:peliculas/core/services/logger_factory.dart';

void main() async {
  LoggerFactory.info('🔧 Iniciando arreglo masivo de warnings...');

  // Directorio lib
  final libDir = Directory('lib');

  // Contadores
  int curlyBracesFixed = 0;
  int printStatementsFixed = 0;

  await for (final file in libDir.list(recursive: true, followLinks: false)) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = await file.readAsString();
      String newContent = content;

      // 1. Arreglar curly braces en if statements
      final curlyBracesRegex =
          RegExp(r'if\s*\([^)]+\)\s*([^{}\s][^;]*;)', multiLine: true);

      newContent = newContent.replaceAllMapped(curlyBracesRegex, (match) {
        final condition = '${match.group(0)!.split(')')[0]})';
        final statement = match.group(1)!.trim();
        curlyBracesFixed++;
        return '$condition {\n    $statement\n  }';
      });

      // 2. Arreglar else if sin curly braces
      final elseIfRegex =
          RegExp(r'else\s+if\s*\([^)]+\)\s*([^{}\s][^;]*;)', multiLine: true);

      newContent = newContent.replaceAllMapped(elseIfRegex, (match) {
        final condition = '${match.group(0)!.split(')')[0]})';
        final statement = match.group(1)!.trim();
        curlyBracesFixed++;
        return '$condition {\n    $statement\n  }';
      });

      // 3. Arreglar else sin curly braces
      final elseRegex = RegExp(r'else\s*([^{}\s][^;]*;)', multiLine: true);

      newContent = newContent.replaceAllMapped(elseRegex, (match) {
        final statement = match.group(1)!.trim();
        curlyBracesFixed++;
        return 'else {\n    $statement\n  }';
      });

      // 4. Convertir print() a logger calls
      // Solo en archivos que no sean de test
      if (!file.path.contains('test/')) {
        final printRegex = RegExp(r'print\s*\([^)]+\);');

        newContent = newContent.replaceAllMapped(printRegex, (match) {
          final printCall = match.group(0)!;
          final message = printCall
              .replaceAll(RegExp(r'print\s*\(\s*'), '')
              .replaceAll(RegExp(r'\s*\);'), '');

          // Decidir el nivel del log basado en el contenido
          String logLevel = 'info';
          if (message.toLowerCase().contains('error') ||
              message.toLowerCase().contains('exception')) {
            logLevel = 'error';
          } else if (message.toLowerCase().contains('warning') ||
              message.toLowerCase().contains('warn')) {
            logLevel = 'warning';
          } else if (message.toLowerCase().contains('debug')) {
            logLevel = 'debug';
          }

          printStatementsFixed++;
          return 'LoggerFactory.getLogger(runtimeType).$logLevel($message);';
        });

        // Agregar import si se hicieron cambios y no existe
        if (printStatementsFixed > 0 && !content.contains('LoggerFactory')) {
          final importInsertIndex = content.indexOf('import \'package:');
          if (importInsertIndex != -1) {
            newContent =
                '${content.substring(0, importInsertIndex)}import \'package:peliculas_admob/core/utils/logger_factory.dart\';\n${content.substring(importInsertIndex)}';
          }
        }
      }

      // Escribir archivo solo si hay cambios
      if (newContent != content) {
        await file.writeAsString(newContent);
        LoggerFactory.info('✅ Arreglado: ${file.path}');
      }
    }
  }

  LoggerFactory.info('');
  LoggerFactory.info('📊 Resumen de arreglos:');
  LoggerFactory.info('   🔧 Curly braces arreglados: $curlyBracesFixed');
  LoggerFactory.info(
      '   📝 Print statements convertidos: $printStatementsFixed');
  LoggerFactory.info('');
  LoggerFactory.info('🎉 ¡Arreglo masivo completado!');
}
