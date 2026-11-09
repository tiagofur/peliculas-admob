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

  LoggerFactory.info('🔐 Realizando login de prueba...');

  // Create a test user or login with existing one
  const testEmail = 'testuser@peliculas.app';
  const testPassword = 'TestPassword123!';

  try {
    // Try to sign in first
    final response = await supabase.auth.signInWithPassword(
      email: testEmail,
      password: testPassword,
    );

    if (response.user != null) {
      LoggerFactory.info(
          '✅ Login exitoso con usuario existente: ${response.user!.id}');
    } else {
      LoggerFactory.info('⚠️ Login falló, intentando crear usuario...');
      final signUpResponse = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'Usuario de Prueba',
          'display_name': 'Test User',
        },
      );

      if (signUpResponse.user != null) {
        LoggerFactory.info(
            '✅ Usuario creado exitosamente: ${signUpResponse.user!.id}');
      } else {
        LoggerFactory.info('❌ Error creando usuario');
        return;
      }
    }
  } catch (e) {
    LoggerFactory.info('❌ Error en autenticación: $e');

    // Try to create user if sign in failed
    try {
      LoggerFactory.info('⚠️ Intentando crear usuario nuevo...');
      final signUpResponse = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'Usuario de Prueba',
          'display_name': 'Test User',
        },
      );

      if (signUpResponse.user != null) {
        LoggerFactory.info(
            '✅ Usuario creado exitosamente: ${signUpResponse.user!.id}');
      } else {
        LoggerFactory.info('❌ Error creando usuario');
        return;
      }
    } catch (signUpError) {
      LoggerFactory.info('❌ Error creando usuario: $signUpError');
      return;
    }
  }

  // Wait a bit for the user to be fully processed
  await Future.delayed(const Duration(seconds: 2));

  final user = supabase.auth.currentUser;
  if (user != null) {
    LoggerFactory.info('✅ Usuario autenticado: ${user.id}');
    LoggerFactory.info('Email: ${user.email}');
    LoggerFactory.info('Created at: ${user.createdAt}');
    LoggerFactory.info('Metadata: ${user.userMetadata}');

    // Try to get or create user profile
    LoggerFactory.info('\n👤 Verificando perfil de usuario...');
    try {
      var profile = await supabase
          .from('user_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (profile == null) {
        LoggerFactory.info('⚠️ Perfil no existe, creando uno...');

        final newProfile = {
          'user_id': user.id,
          'full_name': user.userMetadata?['full_name'] ?? 'Usuario de Prueba',
          'display_name': user.userMetadata?['display_name'] ??
              user.userMetadata?['full_name'] ??
              'Test User',
          'bio': 'Perfil de prueba creado automáticamente',
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

        try {
          profile = await supabase
              .from('user_profiles')
              .insert(newProfile)
              .select()
              .single();

          LoggerFactory.info('✅ Perfil creado exitosamente');
        } catch (insertError) {
          LoggerFactory.info('❌ Error insertando perfil: $insertError');
          // Try to get profile again in case it was created by triggers
          profile = await supabase
              .from('user_profiles')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();

          if (profile != null) {
            LoggerFactory.info(
                '✅ Perfil encontrado después del error (creado por trigger)');
          }
        }
      } else {
        LoggerFactory.info('✅ Perfil encontrado');
      }

      if (profile != null) {
        LoggerFactory.info('Datos del perfil:');
        profile.forEach((key, value) {
          LoggerFactory.info('  $key: $value');
        });
      }
    } catch (e) {
      LoggerFactory.info('❌ Error manejando perfil: $e');
    }

    // Test some provider operations that might be failing
    LoggerFactory.info('\n🧪 Probando operaciones típicas...');

    // Update profile
    try {
      final now = DateTime.now().toIso8601String();
      await supabase.from('user_profiles').update({
        'updated_at': now,
        'last_synced_at': now,
      }).eq('user_id', user.id);
      LoggerFactory.info('✅ Actualización de perfil exitosa');
    } catch (e) {
      LoggerFactory.info('❌ Error actualizando perfil: $e');
    }

    // Test username availability
    try {
      const testUsername = 'test_user_available';
      final existingUsername = await supabase
          .from('user_profiles')
          .select('user_id')
          .eq('username', testUsername)
          .maybeSingle();

      if (existingUsername == null) {
        LoggerFactory.info('✅ Username "$testUsername" está disponible');
      } else {
        LoggerFactory.info('⚠️ Username "$testUsername" ya está en uso');
      }
    } catch (e) {
      LoggerFactory.info('❌ Error verificando username: $e');
    }

    LoggerFactory.info(
        '\n🎉 Todo funcionando correctamente. Ahora puedes usar este usuario para probar:');
    LoggerFactory.info('Email: $testEmail');
    LoggerFactory.info('Password: $testPassword');
  } else {
    LoggerFactory.info('❌ No se pudo autenticar usuario');
  }
}
