#!/usr/bin/env dart
// ignore: dangling_library_doc_comments
/// Script para verificar AdSense en tiempo real durante el desarrollo web
/// Ejecutar junto con la aplicación web para monitorear el estado de AdSense

import 'dart:convert';
import 'dart:io';

void main() async {
  // ignore: avoid_print
  print('🔍 Verificador de AdSense en Tiempo Real');
  // ignore: avoid_print
  print('=' * 50);

  // Verificar que la aplicación esté ejecutándose
  await checkWebServer();

  // Verificar configuración de archivos
  await verifyConfiguration();

  // Instrucciones para verificar AdSense en el navegador
  printBrowserInstructions();
}

Future<void> checkWebServer() async {
  // ignore: avoid_print
  print('\n📡 Verificando servidor web...');

  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('http://localhost:8080'));
    final response = await request.close();

    if (response.statusCode == 200) {
      // ignore: avoid_print
      print('✅ Servidor web activo en http://localhost:8080');

      // Leer el contenido HTML
      final html = await response.transform(utf8.decoder).join();

      if (html.contains('ca-pub-4576016092724628')) {
        // ignore: avoid_print
        print('✅ Publisher ID encontrado en el HTML servido');
      } else {
        // ignore: avoid_print
        print('⚠️  Publisher ID NO encontrado en el HTML servido');
      }

      if (html.contains('pagead/js/adsbygoogle.js')) {
        // ignore: avoid_print
        print('✅ Script de AdSense encontrado en el HTML');
      } else {
        // ignore: avoid_print
        print('⚠️  Script de AdSense NO encontrado en el HTML');
      }
    } else {
      // ignore: avoid_print
      print('❌ Error del servidor: ${response.statusCode}');
    }

    client.close();
  } catch (e) {
    // ignore: avoid_print
    print('❌ No se puede conectar al servidor web: $e');
    // ignore: avoid_print
    print(
        '   Asegúrate de que "flutter run -d chrome --web-port 8080" esté ejecutándose');
  }
}

Future<void> verifyConfiguration() async {
  // ignore: avoid_print
  print('\n🔧 Verificando configuración de archivos...');

  // Verificar web/index.html
  final indexFile = File('web/index.html');
  if (await indexFile.exists()) {
    final content = await indexFile.readAsString();

    if (content.contains('ca-pub-4576016092724628')) {
      // ignore: avoid_print
      print('✅ Publisher ID configurado en web/index.html');
    } else {
      // ignore: avoid_print
      print('❌ Publisher ID NO configurado en web/index.html');
    }

    if (content.contains('pagead/js/adsbygoogle.js')) {
      // ignore: avoid_print
      print('✅ Script de AdSense configurado en web/index.html');
    } else {
      // ignore: avoid_print
      print('❌ Script de AdSense NO configurado en web/index.html');
    }
  } else {
    // ignore: avoid_print
    print('❌ Archivo web/index.html no encontrado');
  }

  // Verificar servicio AdSense
  final adsenseFile = File('lib/services/monetization/adsense_service.dart');
  if (await adsenseFile.exists()) {
    final content = await adsenseFile.readAsString();

    if (content.contains('ca-pub-4576016092724628')) {
      // ignore: avoid_print
      print('✅ Publisher ID configurado en AdSenseService');
    } else {
      // ignore: avoid_print
      print('❌ Publisher ID NO configurado en AdSenseService');
    }
  } else {
    // ignore: avoid_print
    print('❌ AdSenseService no encontrado');
  }
}

void printBrowserInstructions() {
  // ignore: avoid_print
  print('\n🌐 Instrucciones para verificar AdSense en el navegador:');
  // ignore: avoid_print
  print('=' * 60);

  // ignore: avoid_print
  print('\n1. Abre las Herramientas de Desarrollador (F12)');

  // ignore: avoid_print
  print('\n2. Ve a la pestaña Console y ejecuta este comando:');
  // ignore: avoid_print
  print(
      '   console.log("AdSense Script:", document.querySelector(\'script[src*="adsbygoogle"]\'));');

  // ignore: avoid_print
  print('\n3. Ve a la pestaña Network y filtra por "adsbygoogle":');
  // ignore: avoid_print
  print('   - Deberías ver requests a pagead/js/adsbygoogle.js');
  // ignore: avoid_print
  print('   - Si hay errores, revisa el status code');

  // ignore: avoid_print
  print('\n4. En Console, verifica si AdSense está cargado:');
  // ignore: avoid_print
  print(
      '   console.log("AdSense loaded:", typeof window.adsbygoogle !== "undefined");');

  // ignore: avoid_print
  print('\n5. Busca elementos de anuncios en el DOM:');
  // ignore: avoid_print
  print(
      '   console.log("Ad containers:", document.querySelectorAll(\'.adsbygoogle\'));');

  // ignore: avoid_print
  print('\n6. Para verificar errores de AdSense:');
  // ignore: avoid_print
  print('   window.addEventListener("message", (e) => {');
  // ignore: avoid_print
  print('     if (e.data && e.data.type === "adsense") {');
  // ignore: avoid_print
  print('       console.log("AdSense message:", e.data);');
  // ignore: avoid_print
  print('     }');
  // ignore: avoid_print
  print('   });');

  // ignore: avoid_print
  print('\n📋 Checklist de verificación:');
  // ignore: avoid_print
  print('   □ Script de AdSense se carga sin errores (Network tab)');
  // ignore: avoid_print
  print('   □ Publisher ID está presente en el HTML');
  // ignore: avoid_print
  print('   □ No hay errores de CORS en Console');
  // ignore: avoid_print
  print('   □ AdSense está disponible globalmente (window.adsbygoogle)');
  // ignore: avoid_print
  print('   □ Los contenedores de anuncios se crean correctamente');

  // ignore: avoid_print
  print('\n🎯 URLs importantes para verificar:');
  // ignore: avoid_print
  print('   - Aplicación: http://localhost:8080');
  // ignore: avoid_print
  print('   - AdSense Console: https://www.google.com/adsense/');
  // ignore: avoid_print
  print(
      '   - Test de anuncios: https://www.google.com/adsense/new/u/0/pub-4576016092724628/home');

  // ignore: avoid_print
  print('\n💡 Troubleshooting:');
  // ignore: avoid_print
  print('   - Si no ves anuncios inmediatamente, es normal');
  // ignore: avoid_print
  print('   - AdSense puede tardar 24-48h en mostrar anuncios reales');
  // ignore: avoid_print
  print('   - Usa modo de prueba durante el desarrollo');
  // ignore: avoid_print
  print('   - Verifica que el dominio esté aprobado en AdSense Console');
}
