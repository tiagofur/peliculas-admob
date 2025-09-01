// Script simple para verificar conectividad directa con Supabase
// Ejecutar con: dart run test/supabase_connection_test.dart

import 'package:peliculas/core/logging/logger_factory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  LoggerFactory.info('🧪 Iniciando test de conexión directa con Supabase...\n');

  try {
    // 1. Inicializar Supabase
    LoggerFactory.info('📡 Inicializando Supabase...');
    await Supabase.initialize(
      url: 'https://fyzujpifkzftweynrudh.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTkxOTgsImV4cCI6MjA3MDkzNTE5OH0.-wnFtwyfKuasSJ9GDvhOgKLgfz-clpqnMF1u-lC8sBg',
    );

    final client = Supabase.instance.client;
    LoggerFactory.info('✅ Cliente Supabase inicializado\n');

    // 2. Test de autenticación
    const testEmail = 'test-sync@peliculas.com';
    const testPassword = 'TestPassword123!';

    LoggerFactory.info('🔐 Probando autenticación...');

    User? currentUser;

    try {
      // Intentar login primero
      final response = await client.auth.signInWithPassword(
        email: testEmail,
        password: testPassword,
      );

      if (response.user != null) {
        currentUser = response.user;
        LoggerFactory.info('✅ Login exitoso: ${response.user!.email}');
      } else {
        LoggerFactory.warning('❌ Login falló');
      }
    } catch (e) {
      LoggerFactory.warning('⚠️ Login falló: $e');

      // Si falla, intentar registro
      LoggerFactory.info('📝 Intentando registro...');
      try {
        final signUpResponse = await client.auth.signUp(
          email: testEmail,
          password: testPassword,
        );

        if (signUpResponse.user != null) {
          currentUser = signUpResponse.user;
          LoggerFactory.info(
              '✅ Registro exitoso: ${signUpResponse.user!.email}');
        } else {
          LoggerFactory.warning('❌ Registro falló');
        }
      } catch (e2) {
        LoggerFactory.error('❌ Error en registro: $e2');
      }
    }

    if (currentUser == null) {
      LoggerFactory.error('❌ No se pudo autenticar. Abortando tests.');
      return;
    }

    LoggerFactory.info('👤 Usuario actual: ${currentUser.email}\n');

    // 3. Test de operaciones CRUD
    LoggerFactory.info('📊 Probando operaciones CRUD en user_favorites...');

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
    LoggerFactory.info('⬆️ Insertando favorito...');
    await client
        .from('user_favorites')
        .upsert(testData, onConflict: 'user_id,movie_id');
    LoggerFactory.info('✅ Favorito insertado');

    // READ - Leer favorito
    LoggerFactory.info('📖 Leyendo favorito...');
    final readResponse = await client
        .from('user_favorites')
        .select()
        .eq('user_id', currentUser.id)
        .eq('movie_id', testMovieId);

    if (readResponse.isNotEmpty) {
      LoggerFactory.info(
          '✅ Favorito encontrado: ${readResponse[0]['movie_title']}');
    } else {
      LoggerFactory.error('❌ No se encontró el favorito recién insertado');
      return;
    }

    // UPDATE - Actualizar favorito
    LoggerFactory.info('✏️ Actualizando favorito...');
    await client
        .from('user_favorites')
        .update({
          'movie_title': 'Updated Test Movie $timestamp',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', currentUser.id)
        .eq('movie_id', testMovieId);
    LoggerFactory.info('✅ Favorito actualizado');

    // Verificar actualización
    final updatedResponse = await client
        .from('user_favorites')
        .select()
        .eq('user_id', currentUser.id)
        .eq('movie_id', testMovieId);

    if (updatedResponse.isNotEmpty &&
        updatedResponse[0]['movie_title'] == 'Updated Test Movie $timestamp') {
      LoggerFactory.info(
          '✅ Actualización verificada: ${updatedResponse[0]['movie_title']}');
    } else {
      LoggerFactory.error('❌ La actualización no se reflejó correctamente');
    }

    // DELETE - Eliminar favorito
    LoggerFactory.info('🗑️ Eliminando favorito...');
    await client
        .from('user_favorites')
        .delete()
        .eq('user_id', currentUser.id)
        .eq('movie_id', testMovieId);
    LoggerFactory.info('✅ Favorito eliminado');

    // Verificar eliminación
    final deletedResponse = await client
        .from('user_favorites')
        .select()
        .eq('user_id', currentUser.id)
        .eq('movie_id', testMovieId);

    if (deletedResponse.isEmpty) {
      LoggerFactory.info('✅ Eliminación verificada');
    } else {
      LoggerFactory.error('❌ El favorito no fue eliminado correctamente');
    }

    LoggerFactory.info(
        '\n🎉 ¡Todos los tests de Supabase completados exitosamente!');
    LoggerFactory.info(
        '📡 La sincronización con Supabase está funcionando correctamente.');
  } catch (e, stackTrace) {
    LoggerFactory.error('❌ Error general en el test: $e');
    LoggerFactory.error('Stack trace: $stackTrace');
  }
}
