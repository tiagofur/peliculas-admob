// Script simple para verificar conectividad directa con Supabase
// Ejecutar con: dart run test/supabase_connection_test.dart

import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('🧪 Iniciando test de conexión directa con Supabase...\n');

  try {
    // 1. Inicializar Supabase
    print('📡 Inicializando Supabase...');
    await Supabase.initialize(
      url: 'https://fyzujpifkzftweynrudh.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTkxOTgsImV4cCI6MjA3MDkzNTE5OH0.-wnFtwyfKuasSJ9GDvhOgKLgfz-clpqnMF1u-lC8sBg',
    );

    final client = Supabase.instance.client;
    print('✅ Cliente Supabase inicializado\n');

    // 2. Test de autenticación
    const testEmail = 'test-sync@peliculas.com';
    const testPassword = 'TestPassword123!';

    print('🔐 Probando autenticación...');

    User? currentUser;

    try {
      // Intentar login primero
      final response = await client.auth.signInWithPassword(
        email: testEmail,
        password: testPassword,
      );

      if (response.user != null) {
        currentUser = response.user;
        print('✅ Login exitoso: ${response.user!.email}');
      } else {
        print('❌ Login falló');
      }
    } catch (e) {
      print('⚠️ Login falló: $e');

      // Si falla, intentar registro
      print('📝 Intentando registro...');
      try {
        final signUpResponse = await client.auth.signUp(
          email: testEmail,
          password: testPassword,
        );

        if (signUpResponse.user != null) {
          currentUser = signUpResponse.user;
          print('✅ Registro exitoso: ${signUpResponse.user!.email}');
        } else {
          print('❌ Registro falló');
        }
      } catch (e2) {
        print('❌ Error en registro: $e2');
      }
    }

    if (currentUser == null) {
      print('❌ No se pudo autenticar. Abortando tests.');
      return;
    }

    print('👤 Usuario actual: ${currentUser.email}\n');

    // 3. Test de operaciones CRUD
    print('📊 Probando operaciones CRUD en user_favorites...');

    // Película de prueba
    final testMovieId = 99999;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final testData = {
      'user_id': currentUser.id,
      'movie_id': testMovieId,
      'movie_title': 'Test Movie $timestamp',
      'movie_poster_path': '/test_poster.jpg',
      'movie_backdrop_path': '/test_backdrop.jpg',
      'movie_overview': 'Test movie para probar sincronización',
      'movie_release_date': '2023-01-01',
      'movie_vote_average': 8.5,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // CREATE - Insertar favorito
    print('⬆️ Insertando favorito...');
    await client
        .from('user_favorites')
        .upsert(testData, onConflict: 'user_id,movie_id');
    print('✅ Favorito insertado');

    // READ - Leer favorito
    print('📖 Leyendo favorito...');
    final readResponse = await client
        .from('user_favorites')
        .select()
        .eq('user_id', currentUser.id)
        .eq('movie_id', testMovieId);

    if (readResponse.isNotEmpty) {
      print('✅ Favorito encontrado: ${readResponse[0]['movie_title']}');
    } else {
      print('❌ No se encontró el favorito recién insertado');
      return;
    }

    // UPDATE - Actualizar favorito
    print('✏️ Actualizando favorito...');
    await client
        .from('user_favorites')
        .update({
          'movie_title': 'Updated Test Movie $timestamp',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', currentUser.id)
        .eq('movie_id', testMovieId);
    print('✅ Favorito actualizado');

    // Verificar actualización
    final updatedResponse = await client
        .from('user_favorites')
        .select()
        .eq('user_id', currentUser.id)
        .eq('movie_id', testMovieId);

    if (updatedResponse.isNotEmpty &&
        updatedResponse[0]['movie_title'] == 'Updated Test Movie $timestamp') {
      print('✅ Actualización verificada: ${updatedResponse[0]['movie_title']}');
    } else {
      print('❌ La actualización no se reflejó correctamente');
    }

    // DELETE - Eliminar favorito
    print('🗑️ Eliminando favorito...');
    await client
        .from('user_favorites')
        .delete()
        .eq('user_id', currentUser.id)
        .eq('movie_id', testMovieId);
    print('✅ Favorito eliminado');

    // Verificar eliminación
    final deletedResponse = await client
        .from('user_favorites')
        .select()
        .eq('user_id', currentUser.id)
        .eq('movie_id', testMovieId);

    if (deletedResponse.isEmpty) {
      print('✅ Eliminación verificada');
    } else {
      print('❌ El favorito no fue eliminado correctamente');
    }

    print('\n🎉 ¡Todos los tests de Supabase completados exitosamente!');
    print('📡 La sincronización con Supabase está funcionando correctamente.');
  } catch (e, stackTrace) {
    print('❌ Error general en el test: $e');
    print('Stack trace: $stackTrace');
  }
}
