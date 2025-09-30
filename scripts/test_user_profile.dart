#!/usr/bin/env dart

import 'dart:io';

import 'package:peliculas/core/services/logger_factory.dart';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  // Load environment variables
  final envFile = File('.env');
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
  const testEmail = 'test@peliculas.app';
  const testPassword = 'TestPassword123!';

  try {
    // Try to sign in first
    await supabase.auth.signInWithPassword(
      email: testEmail,
      password: testPassword,
    );
    LoggerFactory.info('✅ Login exitoso con usuario existente');
  } catch (e) {
    LoggerFactory.info('⚠️ Login falló, intentando crear usuario: $e');
    try {
      await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'Usuario de Prueba',
          'display_name': 'Test User',
        },
      );
      LoggerFactory.info('✅ Usuario creado exitosamente');
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
          'display_name': user.userMetadata?['display_name'] ?? 'Test User',
          'bio': null,
          'avatar_url': null,
          'username': null,
          'avatar_hash': null,
          'stats': {},
          'preferences': {
            'email_notifications': true,
            'push_notifications': true,
            'profile_public': true,
          },
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        profile = await supabase
            .from('user_profiles')
            .insert(newProfile)
            .select()
            .single();

        LoggerFactory.info('✅ Perfil creado exitosamente');
      } else {
        LoggerFactory.info('✅ Perfil encontrado');
      }

      LoggerFactory.info('Datos del perfil:');
      profile.forEach((key, value) {
        LoggerFactory.info('  $key: $value');
      });
    } catch (e) {
      LoggerFactory.info('❌ Error manejando perfil: $e');
    }

    // Test some provider operations that might be failing
    LoggerFactory.info('\n🧪 Probando operaciones típicas...');

    // Update profile
    try {
      await supabase.from('user_profiles').update({
        'updated_at': DateTime.now().toIso8601String(),
        'last_synced_at': DateTime.now().toIso8601String(),
      }).eq('user_id', user.id);
      LoggerFactory.info('✅ Actualización de perfil exitosa');
    } catch (e) {
      LoggerFactory.info('❌ Error actualizando perfil: $e');
    }

    // Test username availability
    try {
      final existingUsername = await supabase
          .from('user_profiles')
          .select('user_id')
          .eq('username', 'test_user')
          .maybeSingle();

      if (existingUsername == null) {
        LoggerFactory.info('✅ Username "test_user" está disponible');
      } else {
        LoggerFactory.info('⚠️ Username "test_user" ya está en uso');
      }
    } catch (e) {
      LoggerFactory.info('❌ Error verificando username: $e');
    }
  } else {
    LoggerFactory.info('❌ No se pudo autenticar usuario');
  }
}
