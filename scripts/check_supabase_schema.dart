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
    } else if (line.startsWith('SUPABASE_SERVICE_ROLE_KEY=')) {
      supabaseKey = line.substring('SUPABASE_SERVICE_ROLE_KEY='.length).trim();
    }
  }

  if (supabaseUrl == null || supabaseKey == null) {
    LoggerFactory.info(
        '❌ No se encontraron las credenciales de Supabase en .env');
    exit(1);
  }

  LoggerFactory.info('🔗 Conectando a Supabase...');
  LoggerFactory.info('URL: $supabaseUrl');

  try {
    final supabase = SupabaseClient(supabaseUrl, supabaseKey);

    // Check if user_profiles table exists and its structure
    LoggerFactory.info('\n📋 Verificando estructura de user_profiles...');

    final response = await supabase.rpc('get_table_columns',
        params: {'table_name': 'user_profiles'}).catchError((_) => null);

    if (response == null) {
      // Fallback: try to query the table directly
      LoggerFactory.info('🔍 Intentando consulta directa...');
      try {
        final testQuery =
            await supabase.from('user_profiles').select('*').limit(1);
        LoggerFactory.info('✅ Tabla user_profiles existe y es accesible');
        LoggerFactory.info(
            'Columnas detectadas en la respuesta: ${testQuery.isNotEmpty ? testQuery.first.keys.toList() : 'Tabla vacía'}');
      } catch (e) {
        LoggerFactory.info('❌ Error accediendo a user_profiles: $e');
      }
    } else {
      LoggerFactory.info('✅ Estructura obtenida: $response');
    }

    // Test basic authentication flow
    LoggerFactory.info('\n🔐 Verificando autenticación actual...');
    final user = supabase.auth.currentUser;
    if (user != null) {
      LoggerFactory.info('✅ Usuario autenticado: ${user.id}');
      LoggerFactory.info('Email: ${user.email}');

      // Try to get user profile
      LoggerFactory.info('\n👤 Intentando obtener perfil de usuario...');
      try {
        final profile = await supabase
            .from('user_profiles')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (profile != null) {
          LoggerFactory.info('✅ Perfil encontrado:');
          profile.forEach((key, value) {
            LoggerFactory.info('  $key: $value');
          });
        } else {
          LoggerFactory.info('⚠️ No se encontró perfil para el usuario actual');
        }
      } catch (e) {
        LoggerFactory.info('❌ Error obteniendo perfil: $e');
      }
    } else {
      LoggerFactory.info('ℹ️ No hay usuario autenticado actualmente');
    }

    // Test storage bucket
    LoggerFactory.info('\n📁 Verificando bucket de avatares...');
    try {
      final buckets = await supabase.storage.listBuckets();
      final avatarBucket = buckets.firstWhere(
        (bucket) => bucket.name == 'avatars',
        orElse: () => throw 'No found',
      );
      LoggerFactory.info('✅ Bucket avatars encontrado: ${avatarBucket.name}');
      LoggerFactory.info('Público: ${avatarBucket.public}');
    } catch (e) {
      LoggerFactory.info('❌ Error con bucket avatars: $e');
    }

    LoggerFactory.info('\n✅ Verificación completada');
  } catch (e) {
    LoggerFactory.info('❌ Error conectando a Supabase: $e');
    exit(1);
  }
}
