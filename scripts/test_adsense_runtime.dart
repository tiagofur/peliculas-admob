#!/usr/bin/env dart

/// Script para verificar AdSense en tiempo real durante el desarrollo web
/// Ejecutar junto con la aplicación web para monitorear el estado de AdSense

import 'dart:convert';
import 'dart:io';

void main() async {
  print('🔍 Verificador de AdSense en Tiempo Real');
  print('=' * 50);

  // Verificar que la aplicación esté ejecutándose
  await checkWebServer();

  // Verificar configuración de archivos
  await verifyConfiguration();

  // Instrucciones para verificar AdSense en el navegador
  printBrowserInstructions();
}

Future<void> checkWebServer() async {
  print('\n📡 Verificando servidor web...');

  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('http://localhost:8080'));
    final response = await request.close();

    if (response.statusCode == 200) {
      print('✅ Servidor web activo en http://localhost:8080');

      // Leer el contenido HTML
      final html = await response.transform(utf8.decoder).join();

      if (html.contains('ca-pub-4576016092724628')) {
        print('✅ Publisher ID encontrado en el HTML servido');
      } else {
        print('⚠️  Publisher ID NO encontrado en el HTML servido');
      }

      if (html.contains('pagead/js/adsbygoogle.js')) {
        print('✅ Script de AdSense encontrado en el HTML');
      } else {
        print('⚠️  Script de AdSense NO encontrado en el HTML');
      }
    } else {
      print('❌ Error del servidor: ${response.statusCode}');
    }

    client.close();
  } catch (e) {
    print('❌ No se puede conectar al servidor web: $e');
    print(
        '   Asegúrate de que "flutter run -d chrome --web-port 8080" esté ejecutándose');
  }
}

Future<void> verifyConfiguration() async {
  print('\n🔧 Verificando configuración de archivos...');

  // Verificar web/index.html
  final indexFile = File('web/index.html');
  if (await indexFile.exists()) {
    final content = await indexFile.readAsString();

    if (content.contains('ca-pub-4576016092724628')) {
      print('✅ Publisher ID configurado en web/index.html');
    } else {
      print('❌ Publisher ID NO configurado en web/index.html');
    }

    if (content.contains('pagead/js/adsbygoogle.js')) {
      print('✅ Script de AdSense configurado en web/index.html');
    } else {
      print('❌ Script de AdSense NO configurado en web/index.html');
    }
  } else {
    print('❌ Archivo web/index.html no encontrado');
  }

  // Verificar servicio AdSense
  final adsenseFile = File('lib/services/monetization/adsense_service.dart');
  if (await adsenseFile.exists()) {
    final content = await adsenseFile.readAsString();

    if (content.contains('ca-pub-4576016092724628')) {
      print('✅ Publisher ID configurado en AdSenseService');
    } else {
      print('❌ Publisher ID NO configurado en AdSenseService');
    }
  } else {
    print('❌ AdSenseService no encontrado');
  }
}

void printBrowserInstructions() {
  print('\n🌐 Instrucciones para verificar AdSense en el navegador:');
  print('=' * 60);

  print('\n1. Abre las Herramientas de Desarrollador (F12)');

  print('\n2. Ve a la pestaña Console y ejecuta este comando:');
  print(
      '   console.log("AdSense Script:", document.querySelector(\'script[src*="adsbygoogle"]\'));');

  print('\n3. Ve a la pestaña Network y filtra por "adsbygoogle":');
  print('   - Deberías ver requests a pagead/js/adsbygoogle.js');
  print('   - Si hay errores, revisa el status code');

  print('\n4. En Console, verifica si AdSense está cargado:');
  print(
      '   console.log("AdSense loaded:", typeof window.adsbygoogle !== "undefined");');

  print('\n5. Busca elementos de anuncios en el DOM:');
  print(
      '   console.log("Ad containers:", document.querySelectorAll(\'.adsbygoogle\'));');

  print('\n6. Para verificar errores de AdSense:');
  print('   window.addEventListener("message", (e) => {');
  print('     if (e.data && e.data.type === "adsense") {');
  print('       console.log("AdSense message:", e.data);');
  print('     }');
  print('   });');

  print('\n📋 Checklist de verificación:');
  print('   □ Script de AdSense se carga sin errores (Network tab)');
  print('   □ Publisher ID está presente en el HTML');
  print('   □ No hay errores de CORS en Console');
  print('   □ AdSense está disponible globalmente (window.adsbygoogle)');
  print('   □ Los contenedores de anuncios se crean correctamente');

  print('\n🎯 URLs importantes para verificar:');
  print('   - Aplicación: http://localhost:8080');
  print('   - AdSense Console: https://www.google.com/adsense/');
  print(
      '   - Test de anuncios: https://www.google.com/adsense/new/u/0/pub-4576016092724628/home');

  print('\n💡 Troubleshooting:');
  print('   - Si no ves anuncios inmediatamente, es normal');
  print('   - AdSense puede tardar 24-48h en mostrar anuncios reales');
  print('   - Usa modo de prueba durante el desarrollo');
  print('   - Verifica que el dominio esté aprobado en AdSense Console');
}
