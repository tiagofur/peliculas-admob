#!/usr/bin/env dart
// ignore: dangling_library_doc_comments
/// Script para análisis y optimización del bundle size de la aplicación Flutter
///
/// Uso:
/// dart scripts/bundle_analyzer.dart [--analyze-only] [--output-format=json|text]

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:peliculas/core/logging/logger_factory.dart';

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
    await LoggerFactory.info('🔍 Iniciando análisis de bundle size...');

    if (!analyzeOnly) {
      await _buildWebRelease();
    }

    await _analyzeBundleSize();
    await _analyzeUnusedImports();
    await _analyzeAssetUsage();
    await _generateRecommendations();
    await _outputResults();

    await LoggerFactory.info('✅ Análisis completado!');
  }

  Future<void> _buildWebRelease() async {
    await LoggerFactory.info('📦 Construyendo release web...');

    final result = await Process.run(
      'flutter',
      ['build', 'web', '--release', '--analyze-size'],
      workingDirectory: '.',
    );

    if (result.exitCode != 0) {
      await LoggerFactory.info('❌ Error en build: ${result.stderr}');
      exit(1);
    }

    await LoggerFactory.info('✅ Build completado');
  }

  Future<void> _analyzeBundleSize() async {
    await LoggerFactory.info('📊 Analizando tamaños de archivos...');

    final buildDir = Directory(_buildDir);
    if (!buildDir.existsSync()) {
      await LoggerFactory.info(
          '❌ Directorio de build no encontrado: $_buildDir');
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

  Future<void> _printBundleAnalysis(
      Map<String, int> files, int totalSize) async {
    await LoggerFactory.info('📦 Bundle Size Analysis:');
    await LoggerFactory.info('Total: ${_formatBytes(totalSize)}');

    // Top 10 archivos más grandes
    final sortedFiles = files.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    await LoggerFactory.info('🔝 Top 10 archivos más grandes:');
    for (int i = 0; i < min(10, sortedFiles.length); i++) {
      final entry = sortedFiles[i];
      final fileName = entry.key.split(Platform.pathSeparator).last;
      final size = _formatBytes(entry.value);
      final percentage = ((entry.value / totalSize) * 100).toStringAsFixed(1);

      await LoggerFactory.info('   $fileName: $size ($percentage%)');
    }
  }

  Future<void> _analyzeUnusedImports() async {
    await LoggerFactory.info('🔍 Analizando imports no utilizados...');

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
      await LoggerFactory.info(
          '⚠️  Encontrados ${unusedImports.length} imports no utilizados');
      for (final import in unusedImports.take(5)) {
        await LoggerFactory.info('   $import');
      }
      if (unusedImports.length > 5) {
        await LoggerFactory.info('   ... y ${unusedImports.length - 5} más');
      }
    } else {
      await LoggerFactory.info('✅ No se encontraron imports no utilizados');
    }
  }

  Future<void> _analyzeAssetUsage() async {
    await LoggerFactory.info('🖼️  Analizando uso de assets...');

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

    await LoggerFactory.info(
        '📊 Assets: ${assetFiles.length} total, ${usedAssets.length} usados, ${unusedAssets.length} sin usar');

    if (unusedAssets.isNotEmpty) {
      await LoggerFactory.info('⚠️  Assets potencialmente no utilizados:');
      for (final asset in unusedAssets.take(5)) {
        await LoggerFactory.info('   $asset');
      }
      if (unusedAssets.length > 5) {
        await LoggerFactory.info('   ... y ${unusedAssets.length - 5} más');
      }
    }
  }

  Future<void> _generateRecommendations() async {
    await LoggerFactory.info('💡 Generando recomendaciones...');

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
      await LoggerFactory.info('📝 Recomendaciones:');
      for (int i = 0; i < recommendations.length; i++) {
        await LoggerFactory.info('   ${i + 1}. ${recommendations[i]}');
      }
    } else {
      await LoggerFactory.info('✅ No se encontraron optimizaciones evidentes');
    }
  }

  Future<void> _outputResults() async {
    if (outputFormat == 'json') {
      final file = File(_outputFile);
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(analysisResults));
      await LoggerFactory.info('📄 Resultados guardados en: $_outputFile');
    }

    // Generar resumen de comandos de optimización
    _generateOptimizationCommands();
  }

  void _generateOptimizationCommands() {
    LoggerFactory.info('🛠️  Comandos de optimización sugeridos:');

    // Comando para eliminar imports no usados
    final unusedImports = analysisResults['unused_imports'];
    if (unusedImports != null && unusedImports['count'] > 0) {
      LoggerFactory.info('# Corregir imports no utilizados:');
      LoggerFactory.info('dart fix --apply');
    }

    // Comando para análisis de dependencias
    LoggerFactory.info('# Revisar dependencias no utilizadas:');
    LoggerFactory.info('flutter pub deps');
    LoggerFactory.info('flutter pub outdated');

    // Comando para optimizar assets
    final assets = analysisResults['assets'];
    if (assets != null && (assets['unused'] as List).isNotEmpty) {
      LoggerFactory.info('# Eliminar assets no utilizados:');
      for (final asset in (assets['unused'] as List).take(3)) {
        LoggerFactory.info('rm "$asset"');
      }
    }

    // Comandos de build optimizado
    LoggerFactory.info('# Build optimizado:');
    LoggerFactory.info('flutter build web --release --dart2js-optimization=O4');
    LoggerFactory.info(
        'flutter build web --release --split-debug-info=debug_symbols/');
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
