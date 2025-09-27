#!/usr/bin/env dart
// ignore: dangling_library_doc_comments
/// Script simple para suprimir warnings de print en scripts
/// agregando // ignore: avoid_print antes de cada print statement

import 'dart:io';

void main() async {
  stdout.writeln('🔄 Suprimiendo warnings de print en scripts...');

  final scriptsDir = Directory('scripts');
  final dartFiles = scriptsDir
      .listSync()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !file.path.contains('fix_print_warnings.dart'))
      .cast<File>();

  var totalIgnores = 0;

  for (final file in dartFiles) {
    try {
      final lines = await file.readAsLines();
      final newLines = <String>[];
      var ignoresAdded = 0;

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trim();

        // Si la línea contiene print() y no tiene ya el ignore
        if (trimmed.startsWith('print(') &&
            (i == 0 || !lines[i - 1].trim().contains('ignore: avoid_print'))) {
          // Agregar el ignore con la misma indentación que la línea print
          final indentation = line.substring(0, line.indexOf(trimmed));
          newLines.add('$indentation// ignore: avoid_print');
          ignoresAdded++;
        }
        newLines.add(line);
      }

      if (ignoresAdded > 0) {
        await file.writeAsString('${newLines.join('\n')}\n');
        stdout.writeln('✅ ${file.path}: $ignoresAdded ignore comments added');
        totalIgnores += ignoresAdded;
      }
    } catch (e) {
      stdout.writeln('❌ Error processing ${file.path}: $e');
    }
  }

  stdout.writeln('✅ Total: $totalIgnores ignore comments added');
  stdout.writeln(
      '📋 Los scripts ahora pueden usar print() sin warnings del analyzer');
}
