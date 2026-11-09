#!/usr/bin/env dart

import 'dart:io';

import 'package:peliculas/core/services/logger_factory.dart';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  // Load environment variables
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    LoggerFactory.info('❌ No se encontró el archivo .env');
    exit(1);
  }

  final envContent = await envFile.readAsString();
  final envLines = envContent.split('\n');
  String? supabaseUrl;
  String? supabaseKey;

  for (final line in envLines) {
    if (line.startsWith('SUPABASE_URL=')) {
      supabaseUrl = line.substring('SUPABASE_URL='.length).trim();
    } else if (line.startsWith('SUPABASE_ANON_KEY=')) {
      supabaseKey = line.substring('SUPABASE_ANON_KEY='.length).trim();
    }
  }

  if (supabaseUrl == null || supabaseKey == null) {
    LoggerFactory.info(
        '❌ No se encontraron las credenciales de Supabase en .env');
    exit(1);
  }

  final supabase = SupabaseClient(supabaseUrl, supabaseKey);

  LoggerFactory.info('🔍 Verificando estructura de user_profiles...');

  try {
    // First check if we can query the table structure
    final testQuery = await supabase.from('user_profiles').select('*').limit(5);

    LoggerFactory.info('✅ Tabla user_profiles accesible');

    if (testQuery.isNotEmpty) {
      LoggerFactory.info(
          'Usuarios existentes encontrados: ${testQuery.length}');
      LoggerFactory.info(
          'Columnas disponibles: ${testQuery.first.keys.toList()}');

      // Show a sample profile
      final sampleProfile = testQuery.first;
      LoggerFactory.info('\nEjemplo de perfil:');
      sampleProfile.forEach((key, value) {
        if (value is String && value.length > 50) {
          LoggerFactory.info('  $key: ${value.substring(0, 47)}...');
        } else {
          LoggerFactory.info('  $key: $value');
        }
      });
    } else {
      LoggerFactory.info('No hay usuarios en la tabla user_profiles');
    }
  } catch (e) {
    LoggerFactory.info('❌ Error accediendo a user_profiles: $e');
  }

  // Test creating a simple profile manually
  LoggerFactory.info('\n🧪 Probando inserción manual de perfil...');

  try {
    final testUserId = 'test-user-${DateTime.now().millisecondsSinceEpoch}';
    final testProfile = {
      'user_id': testUserId,
      'full_name': 'Usuario de Prueba',
      'display_name': 'Usuario de Prueba',
      'bio': 'Perfil de prueba',
      'avatar_url': null,
      'username': 'test_user_${DateTime.now().millisecondsSinceEpoch}',
      'avatar_hash': null,
      'stats': <String, dynamic>{
        'movies_watched': 0,
        'favorites_count': 0,
        'lists_count': 0,
      },
      'preferences': <String, dynamic>{
        'email_notifications': true,
        'push_notifications': true,
        'profile_public': true,
      },
    };

    final insertResult = await supabase
        .from('user_profiles')
        .insert(testProfile)
        .select()
        .single();

    LoggerFactory.info('✅ Perfil de prueba creado exitosamente:');
    insertResult.forEach((key, value) {
      LoggerFactory.info('  $key: $value');
    });

    // Clean up - delete the test profile
    await supabase.from('user_profiles').delete().eq('user_id', testUserId);
    LoggerFactory.info('✅ Perfil de prueba eliminado');
  } catch (e) {
    LoggerFactory.info('❌ Error creando perfil de prueba: $e');
  }

  // Test username uniqueness
  LoggerFactory.info('\n🔍 Probando verificación de username...');

  try {
    const testUsername = 'test_unique_username';
    final existingUsername = await supabase
        .from('user_profiles')
        .select('user_id')
        .eq('username', testUsername)
        .maybeSingle();

    if (existingUsername == null) {
      LoggerFactory.info('✅ Username "$testUsername" está disponible');
    } else {
      LoggerFactory.info(
          '⚠️ Username "$testUsername" ya está en uso por: ${existingUsername['user_id']}');
    }
  } catch (e) {
    LoggerFactory.info('❌ Error verificando username: $e');
  }

  LoggerFactory.info('\n✅ Verificación de base de datos completada');
}
