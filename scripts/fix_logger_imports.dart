import 'dart:io';

import 'package:peliculas/core/logging/logger_factory.dart';

void main() async {
  LoggerFactory.info('🔧 Arreglando imports de LoggerFactory...');

  final libDir = Directory('lib');
  int importsFixed = 0;

  await for (final file in libDir.list(recursive: true, followLinks: false)) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = await file.readAsString();

      if (content.contains(
          "import 'package:peliculas_admob/core/logging/logger_factory.dart';")) {
        // Calcular la ruta relativa correcta
        final relativePath = file.path.replaceAll(
            r'c:\Users\tfurt\source\repos\peliculas-admob\lib\', '');
        final pathParts = relativePath.split(r'\');
        final depth =
            pathParts.length - 1; // -1 porque el archivo actual no cuenta

        String relativeImport = '';
        for (int i = 0; i < depth; i++) {
          relativeImport += '../';
        }
        relativeImport += 'core/logging/logger_factory.dart';

        final newContent = content.replaceAll(
            "import 'package:peliculas_admob/core/logging/logger_factory.dart';",
            "import '$relativeImport';");

        await file.writeAsString(newContent);
        importsFixed++;
        LoggerFactory.info(
            '✅ Arreglado: ${file.path.split('\\').last} -> $relativeImport');
      }
    }
  }

  LoggerFactory.info('');
  LoggerFactory.info('📊 Imports arreglados: $importsFixed');
  LoggerFactory.info('🎉 ¡Completado!');
}
