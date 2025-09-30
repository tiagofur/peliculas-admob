#!/usr/bin/env dart

import 'dart:io';
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
    print('❌ No se encontraron las credenciales de Supabase en .env');
    exit(1);
  }

  final supabase = SupabaseClient(supabaseUrl, supabaseKey);

  print('🔐 Realizando login de prueba...');

  // Create a test user or login with existing one
  const testEmail = 'test@peliculas.app';
  const testPassword = 'TestPassword123!';

  try {
    // Try to sign in first
    await supabase.auth.signInWithPassword(
      email: testEmail,
      password: testPassword,
    );
    print('✅ Login exitoso con usuario existente');
  } catch (e) {
    print('⚠️ Login falló, intentando crear usuario: $e');
    try {
      await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'Usuario de Prueba',
          'display_name': 'Test User',
        },
      );
      print('✅ Usuario creado exitosamente');
    } catch (signUpError) {
      print('❌ Error creando usuario: $signUpError');
      return;
    }
  }

  // Wait a bit for the user to be fully processed
  await Future.delayed(const Duration(seconds: 2));

  final user = supabase.auth.currentUser;
  if (user != null) {
    print('✅ Usuario autenticado: ${user.id}');
    print('Email: ${user.email}');

    // Try to get or create user profile
    print('\n👤 Verificando perfil de usuario...');
    try {
      var profile = await supabase
          .from('user_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (profile == null) {
        print('⚠️ Perfil no existe, creando uno...');

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

        print('✅ Perfil creado exitosamente');
      } else {
        print('✅ Perfil encontrado');
      }

      print('Datos del perfil:');
      profile.forEach((key, value) {
        print('  $key: $value');
      });
    } catch (e) {
      print('❌ Error manejando perfil: $e');
    }

    // Test some provider operations that might be failing
    print('\n🧪 Probando operaciones típicas...');

    // Update profile
    try {
      await supabase.from('user_profiles').update({
        'updated_at': DateTime.now().toIso8601String(),
        'last_synced_at': DateTime.now().toIso8601String(),
      }).eq('user_id', user.id);
      print('✅ Actualización de perfil exitosa');
    } catch (e) {
      print('❌ Error actualizando perfil: $e');
    }

    // Test username availability
    try {
      final existingUsername = await supabase
          .from('user_profiles')
          .select('user_id')
          .eq('username', 'test_user')
          .maybeSingle();

      if (existingUsername == null) {
        print('✅ Username "test_user" está disponible');
      } else {
        print('⚠️ Username "test_user" ya está en uso');
      }
    } catch (e) {
      print('❌ Error verificando username: $e');
    }
  } else {
    print('❌ No se pudo autenticar usuario');
  }
}
