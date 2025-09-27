#!/usr/bin/env dart

import 'dart:io';

/// Script para verificar que el sistema de monetización esté configurado correctamente
/// Verifica AdMob para móviles y AdSense para web
void main() {
  stdout.writeln('🔍 Verificando sistema de monetización...\n');

  var allChecksPass = true;

  // Verificar archivos de configuración
  allChecksPass = checkConfigurationFiles() && allChecksPass;

  // Verificar widgets de anuncios
  allChecksPass = checkAdWidgets() && allChecksPass;

  // Verificar servicios
  allChecksPass = checkServices() && allChecksPass;

  // Mostrar resultado final
  stdout.writeln('\n${'=' * 50}');
  if (allChecksPass) {
    stdout.writeln('✅ SISTEMA DE MONETIZACIÓN CONFIGURADO CORRECTAMENTE');
    stdout.writeln('   • AdMob configurado para Android/iOS');
    stdout.writeln('   • AdSense configurado para Web');
    stdout.writeln('   • Widgets web-safe implementados');
  } else {
    stdout.writeln('❌ PROBLEMAS DETECTADOS EN EL SISTEMA');
    stdout.writeln('   • Revisa los errores anteriores');
    stdout.writeln('   • Asegúrate de seguir las correcciones sugeridas');
  }
  stdout.writeln('=' * 50);
}

bool checkConfigurationFiles() {
  stdout.writeln('📋 Verificando archivos de configuración...');
  var passed = true;

  final files = [
    'lib/config/helpers/ad_helper.dart',
    'lib/services/monetization/adsense_service.dart',
    'lib/presentation/widgets/admob/web_safe_ad_widgets.dart',
  ];

  for (final file in files) {
    if (File(file).existsSync()) {
      stdout.writeln('   ✅ $file');
    } else {
      stdout.writeln('   ❌ $file - ARCHIVO FALTANTE');
      passed = false;
    }
  }

  return passed;
}

bool checkAdWidgets() {
  stdout.writeln('\n🎨 Verificando widgets de anuncios...');
  var passed = true;

  final widgets = [
    'lib/presentation/widgets/admob/banner_ad_widget.dart',
    'lib/presentation/widgets/admob/native_ad_widget.dart',
    'lib/presentation/widgets/admob/full_width_ad_widget.dart',
    'lib/presentation/widgets/admob/grid_ad_widget.dart',
  ];

  for (final widget in widgets) {
    if (File(widget).existsSync()) {
      final content = File(widget).readAsStringSync();

      // Verificar que use web-safe patterns
      if (content.contains('web_safe_ad_widgets.dart') &&
          content.contains('AdHelper.isAdMobSupported') &&
          content.contains('LoggerFactory')) {
        stdout.writeln('   ✅ $widget - Web-safe implementado');
      } else {
        stdout.writeln('   ⚠️  $widget - Falta implementación web-safe');
        passed = false;
      }
    } else {
      stdout.writeln('   ❌ $widget - ARCHIVO FALTANTE');
      passed = false;
    }
  }

  return passed;
}

bool checkServices() {
  stdout.writeln('\n🔧 Verificando servicios...');
  var passed = true;

  // Verificar AdHelper
  final adHelper = File('lib/config/helpers/ad_helper.dart');
  if (adHelper.existsSync()) {
    final content = adHelper.readAsStringSync();
    if (content.contains('isAdMobSupported') &&
        content.contains('isAdSenseSupported') &&
        !content.contains('throw UnsupportedError')) {
      stdout.writeln('   ✅ AdHelper - Configurado correctamente');
    } else {
      stdout.writeln('   ❌ AdHelper - Problemas de configuración');
      passed = false;
    }
  }

  // Verificar AdSense Service
  final adsenseService = File('lib/services/monetization/adsense_service.dart');
  if (adsenseService.existsSync()) {
    final content = adsenseService.readAsStringSync();
    if (content.contains('ca-pub-') && content.contains('dart:js_interop')) {
      stdout.writeln('   ✅ AdSenseService - Configurado correctamente');
    } else {
      stdout.writeln('   ❌ AdSenseService - Problemas de configuración');
      passed = false;
    }
  }

  return passed;
}
