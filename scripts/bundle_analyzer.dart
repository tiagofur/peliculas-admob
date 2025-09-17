#!/usr/bin/env dart

/// Script para análisis y optimización del bundle size de la aplicación Flutter
///
/// Uso:
/// dart scripts/bundle_analyzer.dart [--analyze-only] [--output-format=json|text]

import 'dart:convert';
import 'dart:io';
import 'dart:math';

class BundleAnalyzer {
  BundleAnalyzer({
    this.analyzeOnly = false,
    this.outputFormat = 'text',
  });
  static const String _buildDir = 'build/web';
  static const String _outputFile = 'bundle_analysis.json';

  final bool analyzeOnly;
  final String outputFormat;
  final Map<String, dynamic> analysisResults = {};

  Future<void> run() async {
    print('🔍 Iniciando análisis de bundle size...\n');

    if (!analyzeOnly) {
      await _buildWebRelease();
    }

    await _analyzeBundleSize();
    await _analyzeUnusedImports();
    await _analyzeAssetUsage();
    await _generateRecommendations();
    await _outputResults();

    print('\n✅ Análisis completado!');
  }

  Future<void> _buildWebRelease() async {
    print('📦 Construyendo release web...');

    final result = await Process.run(
      'flutter',
      ['build', 'web', '--release', '--analyze-size'],
      workingDirectory: '.',
    );

    if (result.exitCode != 0) {
      print('❌ Error en build: ${result.stderr}');
      exit(1);
    }

    print('✅ Build completado\n');
  }

  Future<void> _analyzeBundleSize() async {
    print('📊 Analizando tamaños de archivos...');

    final buildDir = Directory(_buildDir);
    if (!buildDir.existsSync()) {
      print('❌ Directorio de build no encontrado: $_buildDir');
      return;
    }

    final files = await _getFilesSizes(buildDir);
    final totalSize = files.values.fold<int>(0, (sum, size) => sum + size);

    analysisResults['bundle_size'] = {
      'total_bytes': totalSize,
      'total_mb': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      'files': files.map((path, size) => MapEntry(
            path.replaceFirst(_buildDir + Platform.pathSeparator, ''),
            {
              'bytes': size,
              'kb': (size / 1024).toStringAsFixed(2),
              'percentage': ((size / totalSize) * 100).toStringAsFixed(1),
            },
          )),
    };

    _printBundleAnalysis(files, totalSize);
  }

  Future<Map<String, int>> _getFilesSizes(Directory dir) async {
    final files = <String, int>{};

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final stat = await entity.stat();
        files[entity.path] = stat.size;
      }
    }

    return files;
  }

  void _printBundleAnalysis(Map<String, int> files, int totalSize) {
    print('📦 Bundle Size Analysis:');
    print('Total: ${_formatBytes(totalSize)}\n');

    // Top 10 archivos más grandes
    final sortedFiles = files.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    print('🔝 Top 10 archivos más grandes:');
    for (int i = 0; i < min(10, sortedFiles.length); i++) {
      final entry = sortedFiles[i];
      final fileName = entry.key.split(Platform.pathSeparator).last;
      final size = _formatBytes(entry.value);
      final percentage = ((entry.value / totalSize) * 100).toStringAsFixed(1);

      print('   $fileName: $size ($percentage%)');
    }
    print('');
  }

  Future<void> _analyzeUnusedImports() async {
    print('🔍 Analizando imports no utilizados...');

    final result = await Process.run(
      'flutter',
      ['analyze', '--fatal-infos'],
      workingDirectory: '.',
    );

    final output = result.stdout.toString();
    final unusedImports = <String>[];

    // Buscar patrones de imports no usados
    final lines = output.split('\n');
    for (final line in lines) {
      if (line.contains('unused_import') || line.contains('Unused import')) {
        unusedImports.add(line.trim());
      }
    }

    analysisResults['unused_imports'] = {
      'count': unusedImports.length,
      'imports': unusedImports,
    };

    if (unusedImports.isNotEmpty) {
      print('⚠️  Encontrados ${unusedImports.length} imports no utilizados');
      for (final import in unusedImports.take(5)) {
        print('   $import');
      }
      if (unusedImports.length > 5) {
        print('   ... y ${unusedImports.length - 5} más');
      }
    } else {
      print('✅ No se encontraron imports no utilizados');
    }
    print('');
  }

  Future<void> _analyzeAssetUsage() async {
    print('🖼️  Analizando uso de assets...');

    final assetsDir = Directory('assets');
    final assetFiles = <String>[];
    final usedAssets = <String>[];
    final unusedAssets = <String>[];

    if (assetsDir.existsSync()) {
      await for (final entity in assetsDir.list(recursive: true)) {
        if (entity is File) {
          assetFiles.add(entity.path);
        }
      }

      // Buscar referencias a assets en el código
      final libDir = Directory('lib');
      final dartFiles = <File>[];

      if (libDir.existsSync()) {
        await for (final entity in libDir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            dartFiles.add(entity);
          }
        }
      }

      for (final assetPath in assetFiles) {
        final assetName = assetPath.replaceAll('\\', '/');
        bool isUsed = false;

        for (final dartFile in dartFiles) {
          final content = await dartFile.readAsString();
          if (content.contains(assetName) ||
              content.contains(assetName.split('/').last)) {
            isUsed = true;
            break;
          }
        }

        if (isUsed) {
          usedAssets.add(assetName);
        } else {
          unusedAssets.add(assetName);
        }
      }
    }

    analysisResults['assets'] = {
      'total': assetFiles.length,
      'used': usedAssets,
      'unused': unusedAssets,
    };

    print(
        '📊 Assets: ${assetFiles.length} total, ${usedAssets.length} usados, ${unusedAssets.length} sin usar');

    if (unusedAssets.isNotEmpty) {
      print('⚠️  Assets potencialmente no utilizados:');
      for (final asset in unusedAssets.take(5)) {
        print('   $asset');
      }
      if (unusedAssets.length > 5) {
        print('   ... y ${unusedAssets.length - 5} más');
      }
    }
    print('');
  }

  Future<void> _generateRecommendations() async {
    print('💡 Generando recomendaciones...');

    final recommendations = <String>[];
    final bundleData = analysisResults['bundle_size'];
    final unusedImports = analysisResults['unused_imports'];
    final assets = analysisResults['assets'];

    // Recomendaciones de bundle size
    if (bundleData != null) {
      final totalMB = double.parse(bundleData['total_mb']);
      if (totalMB > 5.0) {
        recommendations.add(
            'Bundle size grande (${totalMB}MB): Considerar lazy loading y code splitting');
      }

      final files = bundleData['files'] as Map<String, dynamic>;
      final jsFiles = files.entries.where((e) => e.key.endsWith('.js')).toList()
        ..sort((a, b) =>
            (b.value['bytes'] as int).compareTo(a.value['bytes'] as int));

      if (jsFiles.isNotEmpty) {
        final mainJs = jsFiles.first;
        final mainJsMB = (mainJs.value['bytes'] as int) / (1024 * 1024);
        if (mainJsMB > 2.0) {
          recommendations.add(
              'Archivo JS principal grande (${mainJsMB.toStringAsFixed(2)}MB): Revisar dependencias');
        }
      }
    }

    // Recomendaciones de imports
    if (unusedImports != null && unusedImports['count'] > 0) {
      recommendations.add(
          'Eliminar ${unusedImports['count']} imports no utilizados para reducir bundle');
    }

    // Recomendaciones de assets
    if (assets != null && (assets['unused'] as List).isNotEmpty) {
      recommendations.add(
          'Eliminar ${(assets['unused'] as List).length} assets no utilizados');
    }

    analysisResults['recommendations'] = recommendations;

    if (recommendations.isNotEmpty) {
      print('📝 Recomendaciones:');
      for (int i = 0; i < recommendations.length; i++) {
        print('   ${i + 1}. ${recommendations[i]}');
      }
    } else {
      print('✅ No se encontraron optimizaciones evidentes');
    }
    print('');
  }

  Future<void> _outputResults() async {
    if (outputFormat == 'json') {
      final file = File(_outputFile);
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(analysisResults));
      print('📄 Resultados guardados en: $_outputFile');
    }

    // Generar resumen de comandos de optimización
    _generateOptimizationCommands();
  }

  void _generateOptimizationCommands() {
    print('🛠️  Comandos de optimización sugeridos:');
    print('');

    // Comando para eliminar imports no usados
    final unusedImports = analysisResults['unused_imports'];
    if (unusedImports != null && unusedImports['count'] > 0) {
      print('# Corregir imports no utilizados:');
      print('dart fix --apply');
      print('');
    }

    // Comando para análisis de dependencias
    print('# Revisar dependencias no utilizadas:');
    print('flutter pub deps');
    print('flutter pub outdated');
    print('');

    // Comando para optimizar assets
    final assets = analysisResults['assets'];
    if (assets != null && (assets['unused'] as List).isNotEmpty) {
      print('# Eliminar assets no utilizados:');
      for (final asset in (assets['unused'] as List).take(3)) {
        print('rm "$asset"');
      }
      print('');
    }

    // Comandos de build optimizado
    print('# Build optimizado:');
    print('flutter build web --release --dart2js-optimization=O4');
    print('flutter build web --release --split-debug-info=debug_symbols/');
    print('');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }
}

void main(List<String> args) async {
  bool analyzeOnly = args.contains('--analyze-only');
  String outputFormat = 'text';

  for (final arg in args) {
    if (arg.startsWith('--output-format=')) {
      outputFormat = arg.split('=')[1];
    }
  }

  final analyzer = BundleAnalyzer(
    analyzeOnly: analyzeOnly,
    outputFormat: outputFormat,
  );

  await analyzer.run();
}
