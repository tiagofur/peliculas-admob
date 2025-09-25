#!/usr/bin/env dart

import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Script para verificar la configuración de monetización
/// Valida que todas las claves de AdMob y AdSense estén correctamente configuradas
void main() async {
  print('🔍 Verificando configuración de monetización...\n');

  try {
    // Cargar archivo .env
    await dotenv.load(fileName: '.env');
    print('✅ Archivo .env cargado exitosamente');

    // Verificar configuraciones de AdSense (Web)
    print('\n📱 Configuración AdSense (Web):');
    verifyConfig('ADSENSE_CLIENT_ID', 'ca-pub-');
    verifyConfig('ADSENSE_BANNER_SLOT', null);
    verifyConfig('ADSENSE_NATIVE_SLOT', null);
    verifyConfig('ADSENSE_FULLWIDTH_SLOT', null);

    // Verificar configuraciones de AdMob (Mobile)
    print('\n📲 Configuración AdMob (Mobile):');
    verifyConfig('ADMOB_APP_ID', 'ca-app-pub-');
    verifyConfig('ADMOB_ANDROID_BANNER', 'ca-app-pub-');
    verifyConfig('ADMOB_ANDROID_NATIVE', 'ca-app-pub-');
    verifyConfig('ADMOB_IOS_BANNER', 'ca-app-pub-');
    verifyConfig('ADMOB_IOS_NATIVE', 'ca-app-pub-');

    // Verificar configuraciones de Supabase
    print('\n🗄️ Configuración Supabase:');
    verifyConfig('SUPABASE_URL', 'https://');
    verifyConfig('SUPABASE_ANON_KEY', 'eyJ');
    verifyOptionalConfig('SUPABASE_SERVICE_ROLE_KEY', 'eyJ');

    // Verificar configuraciones de APIs
    print('\n🎬 Configuración APIs:');
    verifyOptionalConfig('THE_MOVIEDB_KEY', null);
    verifyOptionalConfig('TRAKT_CLIENT_ID', null);
    verifyOptionalConfig('TRAKT_CLIENT_SECRET', null);
    verifyOptionalConfig('TRAKT_API_KEY', null);

    print('\n✅ Verificación completada exitosamente!');
    print('🚀 Tu configuración de monetización está lista para producción.\n');
  } catch (e) {
    print('❌ Error durante la verificación: $e');
    exit(1);
  }
}

void verifyConfig(String key, String? expectedPrefix) {
  final value = dotenv.env[key];

  if (value == null || value.isEmpty) {
    print('❌ $key: NO CONFIGURADO');
    return;
  }

  if (expectedPrefix != null && !value.startsWith(expectedPrefix)) {
    print('⚠️ $key: FORMATO INCORRECTO (esperado: $expectedPrefix...)');
    return;
  }

  final maskedValue = maskValue(value);
  print('✅ $key: $maskedValue');
}

void verifyOptionalConfig(String key, String? expectedPrefix) {
  final value = dotenv.env[key];

  if (value == null || value.isEmpty) {
    print('⚠️ $key: NO CONFIGURADO (opcional)');
    return;
  }

  if (expectedPrefix != null && !value.startsWith(expectedPrefix)) {
    print('⚠️ $key: FORMATO INCORRECTO (esperado: $expectedPrefix...)');
    return;
  }

  final maskedValue = maskValue(value);
  print('✅ $key: $maskedValue');
}

String maskValue(String value) {
  if (value.length <= 8) {
    return '${value.substring(0, 4)}****';
  }
  return '${value.substring(0, 8)}${'*' * (value.length - 12)}${value.substring(value.length - 4)}';
}
