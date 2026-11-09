#!/usr/bin/env dart
// ignore: dangling_library_doc_comments
/// Script para verificar AdSense en tiempo real durante el desarrollo web
/// Ejecutar junto con la aplicación web para monitorear el estado de AdSense

import 'dart:convert';
import 'dart:io';

void main() async {
  stdout.writeln('🔍 Verificador de AdSense en Tiempo Real');
  stdout.writeln('=' * 50);

  // Verificar que la aplicación esté ejecutándose
  await checkWebServer();

  // Verificar configuración de archivos
  await verifyConfiguration();

  // Instrucciones para verificar AdSense en el navegador
  printBrowserInstructions();
}

Future<void> checkWebServer() async {
  stdout.writeln('\n📡 Verificando servidor web...');

  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('http://localhost:8080'));
    final response = await request.close();

    if (response.statusCode == 200) {
      stdout.writeln('✅ Servidor web activo en http://localhost:8080');

      // Leer el contenido HTML
      final html = await response.transform(utf8.decoder).join();

      if (html.contains('ca-pub-4576016092724628')) {
        stdout.writeln('✅ Publisher ID encontrado en el HTML servido');
      } else {
        stdout.writeln('⚠️  Publisher ID NO encontrado en el HTML servido');
      }

      if (html.contains('pagead/js/adsbygoogle.js')) {
        stdout.writeln('✅ Script de AdSense encontrado en el HTML');
      } else {
        stdout.writeln('⚠️  Script de AdSense NO encontrado en el HTML');
      }
    } else {
      stdout.writeln('❌ Error del servidor: ${response.statusCode}');
    }

    client.close();
  } catch (e) {
    stdout.writeln('❌ No se puede conectar al servidor web: $e');
    stdout.writeln(
        '   Asegúrate de que "flutter run -d chrome --web-port 8080" esté ejecutándose');
  }
}

Future<void> verifyConfiguration() async {
  stdout.writeln('\n🔧 Verificando configuración de archivos...');

  // Verificar web/index.html
  final indexFile = File('web/index.html');
  if (await indexFile.exists()) {
    final content = await indexFile.readAsString();

    if (content.contains('ca-pub-4576016092724628')) {
      stdout.writeln('✅ Publisher ID configurado en web/index.html');
    } else {
      stdout.writeln('❌ Publisher ID NO configurado en web/index.html');
    }

    if (content.contains('pagead/js/adsbygoogle.js')) {
      stdout.writeln('✅ Script de AdSense configurado en web/index.html');
    } else {
      stdout.writeln('❌ Script de AdSense NO configurado en web/index.html');
    }
  } else {
    stdout.writeln('❌ Archivo web/index.html no encontrado');
  }

  // Verificar servicio AdSense
  final adsenseFile = File('lib/services/monetization/adsense_service.dart');
  if (await adsenseFile.exists()) {
    final content = await adsenseFile.readAsString();

    if (content.contains('ca-pub-4576016092724628')) {
      stdout.writeln('✅ Publisher ID configurado en AdSenseService');
    } else {
      stdout.writeln('❌ Publisher ID NO configurado en AdSenseService');
    }
  } else {
    stdout.writeln('❌ AdSenseService no encontrado');
  }
}

void printBrowserInstructions() {
  stdout.writeln('\n🌐 Instrucciones para verificar AdSense en el navegador:');
  stdout.writeln('=' * 60);

  stdout.writeln('\n1. Abre las Herramientas de Desarrollador (F12)');

  stdout.writeln('\n2. Ve a la pestaña Console y ejecuta este comando:');
  stdout.writeln(
      '   console.log("AdSense Script:", document.querySelector(\'script[src*="adsbygoogle"]\'));');

  stdout.writeln('\n3. Ve a la pestaña Network y filtra por "adsbygoogle":');
  stdout.writeln('   - Deberías ver requests a pagead/js/adsbygoogle.js');
  stdout.writeln('   - Si hay errores, revisa el status code');

  stdout.writeln('\n4. En Console, verifica si AdSense está cargado:');
  stdout.writeln(
      '   console.log("AdSense loaded:", typeof window.adsbygoogle !== "undefined");');

  stdout.writeln('\n5. Busca elementos de anuncios en el DOM:');
  stdout.writeln(
      '   console.log("Ad containers:", document.querySelectorAll(\'.adsbygoogle\'));');

  stdout.writeln('\n6. Para verificar errores de AdSense:');
  stdout.writeln('   window.addEventListener("message", (e) => {');
  stdout.writeln('     if (e.data && e.data.type === "adsense") {');
  stdout.writeln('       console.log("AdSense message:", e.data);');
  stdout.writeln('     }');
  stdout.writeln('   });');

  stdout.writeln('\n📋 Checklist de verificación:');
  stdout.writeln('   □ Script de AdSense se carga sin errores (Network tab)');
  stdout.writeln('   □ Publisher ID está presente en el HTML');
  stdout.writeln('   □ No hay errores de CORS en Console');
  stdout
      .writeln('   □ AdSense está disponible globalmente (window.adsbygoogle)');
  stdout.writeln('   □ Los contenedores de anuncios se crean correctamente');

  stdout.writeln('\n🎯 URLs importantes para verificar:');
  stdout.writeln('   - Aplicación: http://localhost:8080');
  stdout.writeln('   - AdSense Console: https://www.google.com/adsense/');
  stdout.writeln(
      '   - Test de anuncios: https://www.google.com/adsense/new/u/0/pub-4576016092724628/home');

  stdout.writeln('\n💡 Troubleshooting:');
  stdout.writeln('   - Si no ves anuncios inmediatamente, es normal');
  stdout.writeln('   - AdSense puede tardar 24-48h en mostrar anuncios reales');
  stdout.writeln('   - Usa modo de prueba durante el desarrollo');
  stdout
      .writeln('   - Verifica que el dominio esté aprobado en AdSense Console');
}
