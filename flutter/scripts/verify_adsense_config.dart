#!/usr/bin/env dart
// ignore: dangling_library_doc_comments
/// Script de verificación de configuración AdSense
/// Verifica que el Publisher ID esté configurado correctamente

import 'dart:io';

void main() {
  stdout.writeln('🔍 Verificando configuración de AdSense...\n');

  // Verificar AdSenseService
  checkAdSenseService();

  // Verificar web/index.html
  checkIndexHtml();

  stdout.writeln('\n✅ Verificación completada!');
  stdout.writeln('📋 Resumen de configuración:');
  stdout.writeln('   Publisher ID: ca-pub-4576016092724628');
  stdout.writeln('   Plataforma: Web/Desktop (AdSense)');
  stdout.writeln('   Móvil: AdMob (separado)');
}

void checkAdSenseService() {
  stdout.writeln(
      '📂 Verificando lib/services/monetization/adsense_service.dart...');

  final file = File('lib/services/monetization/adsense_service.dart');
  if (!file.existsSync()) {
    stdout.writeln('❌ Archivo AdSenseService no encontrado');
    return;
  }

  final content = file.readAsStringSync();

  if (content.contains('ca-pub-4576016092724628')) {
    stdout
        .writeln('✅ Publisher ID configurado correctamente en AdSenseService');
  } else {
    stdout.writeln('❌ Publisher ID no encontrado en AdSenseService');
    stdout.writeln('   Buscar: static const String _defaultPublisherId');
  }

  if (content.contains('XXXXXXXXXX')) {
    stdout.writeln('⚠️  Advertencia: Aún hay placeholders en el código');
  }
}

void checkIndexHtml() {
  stdout.writeln('📂 Verificando web/index.html...');

  final file = File('web/index.html');
  if (!file.existsSync()) {
    stdout.writeln('❌ Archivo web/index.html no encontrado');
    return;
  }

  final content = file.readAsStringSync();

  if (content.contains('ca-pub-4576016092724628')) {
    stdout.writeln('✅ Publisher ID configurado correctamente en index.html');
  } else {
    stdout.writeln('❌ Publisher ID no encontrado en index.html');
    stdout.writeln('   Script AdSense faltante');
  }

  if (content.contains('adsbygoogle.js')) {
    stdout.writeln('✅ Script AdSense encontrado en index.html');
  } else {
    stdout.writeln('❌ Script AdSense no encontrado en index.html');
  }
}
