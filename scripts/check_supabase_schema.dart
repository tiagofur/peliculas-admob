#!/usr/bin/env dart

import 'dart:io';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  // Load environment variables
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('❌ No se encontró el archivo .env');
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
    print('❌ No se encontraron las credenciales de Supabase en .env');
    exit(1);
  }

  print('🔗 Conectando a Supabase...');
  print('URL: $supabaseUrl');

  try {
    final supabase = SupabaseClient(supabaseUrl, supabaseKey);

    // Check if user_profiles table exists and its structure
    print('\n📋 Verificando estructura de user_profiles...');

    final response = await supabase.rpc('get_table_columns',
        params: {'table_name': 'user_profiles'}).catchError((_) => null);

    if (response == null) {
      // Fallback: try to query the table directly
      print('🔍 Intentando consulta directa...');
      try {
        final testQuery =
            await supabase.from('user_profiles').select('*').limit(1);
        print('✅ Tabla user_profiles existe y es accesible');
        print(
            'Columnas detectadas en la respuesta: ${testQuery.isNotEmpty ? testQuery.first.keys.toList() : 'Tabla vacía'}');
      } catch (e) {
        print('❌ Error accediendo a user_profiles: $e');
      }
    } else {
      print('✅ Estructura obtenida: $response');
    }

    // Test basic authentication flow
    print('\n🔐 Verificando autenticación actual...');
    final user = supabase.auth.currentUser;
    if (user != null) {
      print('✅ Usuario autenticado: ${user.id}');
      print('Email: ${user.email}');

      // Try to get user profile
      print('\n👤 Intentando obtener perfil de usuario...');
      try {
        final profile = await supabase
            .from('user_profiles')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (profile != null) {
          print('✅ Perfil encontrado:');
          profile.forEach((key, value) {
            print('  $key: $value');
          });
        } else {
          print('⚠️ No se encontró perfil para el usuario actual');
        }
      } catch (e) {
        print('❌ Error obteniendo perfil: $e');
      }
    } else {
      print('ℹ️ No hay usuario autenticado actualmente');
    }

    // Test storage bucket
    print('\n📁 Verificando bucket de avatares...');
    try {
      final buckets = await supabase.storage.listBuckets();
      final avatarBucket = buckets.firstWhere(
        (bucket) => bucket.name == 'avatars',
        orElse: () => throw 'No found',
      );
      print('✅ Bucket avatars encontrado: ${avatarBucket.name}');
      print('Público: ${avatarBucket.public}');
    } catch (e) {
      print('❌ Error con bucket avatars: $e');
    }

    print('\n✅ Verificación completada');
  } catch (e) {
    print('❌ Error conectando a Supabase: $e');
    exit(1);
  }
}
