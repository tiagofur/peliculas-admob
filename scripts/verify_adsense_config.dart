#!/usr/bin/env dart

/// Script de verificación de configuración AdSense
/// Verifica que el Publisher ID esté configurado correctamente

import 'dart:io';

void main() {
  print('🔍 Verificando configuración de AdSense...\n');

  // Verificar AdSenseService
  checkAdSenseService();

  // Verificar web/index.html
  checkIndexHtml();

  print('\n✅ Verificación completada!');
  print('📋 Resumen de configuración:');
  print('   Publisher ID: ca-pub-4576016092724628');
  print('   Plataforma: Web/Desktop (AdSense)');
  print('   Móvil: AdMob (separado)');
}

void checkAdSenseService() {
  print('📂 Verificando lib/services/monetization/adsense_service.dart...');

  final file = File('lib/services/monetization/adsense_service.dart');
  if (!file.existsSync()) {
    print('❌ Archivo AdSenseService no encontrado');
    return;
  }

  final content = file.readAsStringSync();

  if (content.contains('ca-pub-4576016092724628')) {
    print('✅ Publisher ID configurado correctamente en AdSenseService');
  } else {
    print('❌ Publisher ID no encontrado en AdSenseService');
    print('   Buscar: static const String _defaultPublisherId');
  }

  if (content.contains('XXXXXXXXXX')) {
    print('⚠️  Advertencia: Aún hay placeholders en el código');
  }
}

void checkIndexHtml() {
  print('📂 Verificando web/index.html...');

  final file = File('web/index.html');
  if (!file.existsSync()) {
    print('❌ Archivo web/index.html no encontrado');
    return;
  }

  final content = file.readAsStringSync();

  if (content.contains('ca-pub-4576016092724628')) {
    print('✅ Publisher ID configurado correctamente en index.html');
  } else {
    print('❌ Publisher ID no encontrado en index.html');
    print('   Script AdSense faltante');
  }

  if (content.contains('adsbygoogle.js')) {
    print('✅ Script AdSense encontrado en index.html');
  } else {
    print('❌ Script AdSense no encontrado en index.html');
  }
}
