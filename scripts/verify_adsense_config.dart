#!/usr/bin/env dart
// ignore: dangling_library_doc_comments
/// Script de verificación de configuración AdSense
/// Verifica que el Publisher ID esté configurado correctamente

import 'dart:io';

void main() {
  // ignore: avoid_print
  print('🔍 Verificando configuración de AdSense...\n');

  // Verificar AdSenseService
  checkAdSenseService();

  // Verificar web/index.html
  checkIndexHtml();

  // ignore: avoid_print
  print('\n✅ Verificación completada!');
  // ignore: avoid_print
  print('📋 Resumen de configuración:');
  // ignore: avoid_print
  print('   Publisher ID: ca-pub-4576016092724628');
  // ignore: avoid_print
  print('   Plataforma: Web/Desktop (AdSense)');
  // ignore: avoid_print
  print('   Móvil: AdMob (separado)');
}

void checkAdSenseService() {
  // ignore: avoid_print
  print('📂 Verificando lib/services/monetization/adsense_service.dart...');

  final file = File('lib/services/monetization/adsense_service.dart');
  if (!file.existsSync()) {
    // ignore: avoid_print
    print('❌ Archivo AdSenseService no encontrado');
    return;
  }

  final content = file.readAsStringSync();

  if (content.contains('ca-pub-4576016092724628')) {
    // ignore: avoid_print
    print('✅ Publisher ID configurado correctamente en AdSenseService');
  } else {
    // ignore: avoid_print
    print('❌ Publisher ID no encontrado en AdSenseService');
    // ignore: avoid_print
    print('   Buscar: static const String _defaultPublisherId');
  }

  if (content.contains('XXXXXXXXXX')) {
    // ignore: avoid_print
    print('⚠️  Advertencia: Aún hay placeholders en el código');
  }
}

void checkIndexHtml() {
  // ignore: avoid_print
  print('📂 Verificando web/index.html...');

  final file = File('web/index.html');
  if (!file.existsSync()) {
    // ignore: avoid_print
    print('❌ Archivo web/index.html no encontrado');
    return;
  }

  final content = file.readAsStringSync();

  if (content.contains('ca-pub-4576016092724628')) {
    // ignore: avoid_print
    print('✅ Publisher ID configurado correctamente en index.html');
  } else {
    // ignore: avoid_print
    print('❌ Publisher ID no encontrado en index.html');
    // ignore: avoid_print
    print('   Script AdSense faltante');
  }

  if (content.contains('adsbygoogle.js')) {
    // ignore: avoid_print
    print('✅ Script AdSense encontrado en index.html');
  } else {
    // ignore: avoid_print
    print('❌ Script AdSense no encontrado en index.html');
  }
}
