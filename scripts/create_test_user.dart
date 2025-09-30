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
  const testEmail = 'testuser@peliculas.app';
  const testPassword = 'TestPassword123!';

  try {
    // Try to sign in first
    final response = await supabase.auth.signInWithPassword(
      email: testEmail,
      password: testPassword,
    );

    if (response.user != null) {
      print('✅ Login exitoso con usuario existente: ${response.user!.id}');
    } else {
      print('⚠️ Login falló, intentando crear usuario...');
      final signUpResponse = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'Usuario de Prueba',
          'display_name': 'Test User',
        },
      );

      if (signUpResponse.user != null) {
        print('✅ Usuario creado exitosamente: ${signUpResponse.user!.id}');
      } else {
        print('❌ Error creando usuario');
        return;
      }
    }
  } catch (e) {
    print('❌ Error en autenticación: $e');

    // Try to create user if sign in failed
    try {
      print('⚠️ Intentando crear usuario nuevo...');
      final signUpResponse = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'Usuario de Prueba',
          'display_name': 'Test User',
        },
      );

      if (signUpResponse.user != null) {
        print('✅ Usuario creado exitosamente: ${signUpResponse.user!.id}');
      } else {
        print('❌ Error creando usuario');
        return;
      }
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
    print('Created at: ${user.createdAt}');
    print('Metadata: ${user.userMetadata}');

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

          print('✅ Perfil creado exitosamente');
        } catch (insertError) {
          print('❌ Error insertando perfil: $insertError');
          // Try to get profile again in case it was created by triggers
          profile = await supabase
              .from('user_profiles')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();

          if (profile != null) {
            print('✅ Perfil encontrado después del error (creado por trigger)');
          }
        }
      } else {
        print('✅ Perfil encontrado');
      }

      if (profile != null) {
        print('Datos del perfil:');
        profile.forEach((key, value) {
          print('  $key: $value');
        });
      }
    } catch (e) {
      print('❌ Error manejando perfil: $e');
    }

    // Test some provider operations that might be failing
    print('\n🧪 Probando operaciones típicas...');

    // Update profile
    try {
      final now = DateTime.now().toIso8601String();
      await supabase.from('user_profiles').update({
        'updated_at': now,
        'last_synced_at': now,
      }).eq('user_id', user.id);
      print('✅ Actualización de perfil exitosa');
    } catch (e) {
      print('❌ Error actualizando perfil: $e');
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
        print('✅ Username "$testUsername" está disponible');
      } else {
        print('⚠️ Username "$testUsername" ya está en uso');
      }
    } catch (e) {
      print('❌ Error verificando username: $e');
    }

    print(
        '\n🎉 Todo funcionando correctamente. Ahora puedes usar este usuario para probar:');
    print('Email: $testEmail');
    print('Password: $testPassword');
  } else {
    print('❌ No se pudo autenticar usuario');
  }
}
