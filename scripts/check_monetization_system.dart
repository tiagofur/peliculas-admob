#!/usr/bin/env dart

import 'dart:io';

/// Script para verificar que el sistema de monetización esté configurado correctamente
/// Verifica AdMob para móviles y AdSense para web
void main() {
  print('🔍 Verificando sistema de monetización...\n');

  var allChecksPass = true;

  // Verificar archivos de configuración
  allChecksPass = checkConfigurationFiles() && allChecksPass;

  // Verificar widgets de anuncios
  allChecksPass = checkAdWidgets() && allChecksPass;

  // Verificar servicios
  allChecksPass = checkServices() && allChecksPass;

  // Mostrar resultado final
  print('\n${'=' * 50}');
  if (allChecksPass) {
    print('✅ SISTEMA DE MONETIZACIÓN CONFIGURADO CORRECTAMENTE');
    print('   • AdMob configurado para Android/iOS');
    print('   • AdSense configurado para Web');
    print('   • Widgets web-safe implementados');
  } else {
    print('❌ PROBLEMAS DETECTADOS EN EL SISTEMA');
    print('   • Revisa los errores anteriores');
    print('   • Asegúrate de seguir las correcciones sugeridas');
  }
  print('=' * 50);
}

bool checkConfigurationFiles() {
  print('📋 Verificando archivos de configuración...');
  var passed = true;

  final files = [
    'lib/config/helpers/ad_helper.dart',
    'lib/services/monetization/adsense_service.dart',
    'lib/presentation/widgets/admob/web_safe_ad_widgets.dart',
  ];

  for (final file in files) {
    if (File(file).existsSync()) {
      print('   ✅ $file');
    } else {
      print('   ❌ $file - ARCHIVO FALTANTE');
      passed = false;
    }
  }

  return passed;
}

bool checkAdWidgets() {
  print('\n🎨 Verificando widgets de anuncios...');
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
        print('   ✅ $widget - Web-safe implementado');
      } else {
        print('   ⚠️  $widget - Falta implementación web-safe');
        passed = false;
      }
    } else {
      print('   ❌ $widget - ARCHIVO FALTANTE');
      passed = false;
    }
  }

  return passed;
}

bool checkServices() {
  print('\n🔧 Verificando servicios...');
  var passed = true;

  // Verificar AdHelper
  final adHelper = File('lib/config/helpers/ad_helper.dart');
  if (adHelper.existsSync()) {
    final content = adHelper.readAsStringSync();
    if (content.contains('isAdMobSupported') &&
        content.contains('isAdSenseSupported') &&
        !content.contains('throw UnsupportedError')) {
      print('   ✅ AdHelper - Configurado correctamente');
    } else {
      print('   ❌ AdHelper - Problemas de configuración');
      passed = false;
    }
  }

  // Verificar AdSense Service
  final adsenseService = File('lib/services/monetization/adsense_service.dart');
  if (adsenseService.existsSync()) {
    final content = adsenseService.readAsStringSync();
    if (content.contains('ca-pub-') && content.contains('dart:js_interop')) {
      print('   ✅ AdSenseService - Configurado correctamente');
    } else {
      print('   ❌ AdSenseService - Problemas de configuración');
      passed = false;
    }
  }

  return passed;
}
