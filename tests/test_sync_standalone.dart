import 'dart:io';

import 'package:peliculas/core/config/supabase_config.dart';
import 'package:peliculas/core/logging/logger_factory.dart';
import 'package:peliculas/domain/entities/movie.dart';

// Script independiente para probar sincronización con Supabase
void main() async {
  LoggerFactory.info('🧪 Iniciando test de sincronización independiente...');

  try {
    // 1. Inicializar Supabase
    LoggerFactory.info('📡 Inicializando Supabase...');
    await SupabaseConfig.initialize();
    final client = SupabaseConfig.client;
    LoggerFactory.info('✅ Supabase inicializado');

    // 2. Crear/Login usuario de prueba
    const testEmail = 'sync-test@peliculas.com';
    const testPassword = 'TestPassword123!';

    LoggerFactory.info('🔐 Intentando login...');
    try {
      await client.auth.signInWithPassword(
        email: testEmail,
        password: testPassword,
      );
      LoggerFactory.info('✅ Login exitoso');
    } catch (e) {
      LoggerFactory.warning('❌ Login falló, intentando registro...');
      try {
        await client.auth.signUp(
          email: testEmail,
          password: testPassword,
        );
        LoggerFactory.info('✅ Usuario registrado');

        // Esperar un poco para la confirmación automática
        await Future.delayed(Duration(seconds: 2));

        // Intentar login nuevamente
        await client.auth.signInWithPassword(
          email: testEmail,
          password: testPassword,
        );
        LoggerFactory.info('✅ Login después de registro exitoso');
      } catch (e2) {
        LoggerFactory.error('❌ Error en registro: $e2');
        return;
      }
    }

    final user = client.auth.currentUser;
    if (user == null) {
      LoggerFactory.error('❌ No hay usuario autenticado');
      return;
    }

    LoggerFactory.info('👤 Usuario autenticado: ${user.email} (${user.id})');

    // 3. Película de prueba
    final testMovie = Movie(
      id: 99999,
      title: 'Test Sync Movie ${DateTime.now().millisecondsSinceEpoch}',
      overview: 'Película para probar sincronización en tiempo real',
      releaseDate: DateTime(2023, 1, 1),
      posterPath: '/test_poster.jpg',
      backdropPath: '/test_backdrop.jpg',
      voteAverage: 8.5,
      genreIds: ['Action', 'Test'],
      adult: false,
      originalLanguage: 'en',
      originalTitle: 'Test Sync Movie',
      popularity: 100.0,
      video: false,
      voteCount: 1000,
    );

    // 4. Test: Agregar favorito directamente a Supabase
    LoggerFactory.info('⬆️ Agregando favorito directamente a Supabase...');
    try {
      await client.from('user_favorites').upsert({
        'user_id': user.id,
        'movie_id': testMovie.id,
        'movie_title': testMovie.title,
        'movie_poster_path': testMovie.posterPath,
        'movie_backdrop_path': testMovie.backdropPath,
        'movie_overview': testMovie.overview,
        'movie_release_date':
            testMovie.releaseDate.toIso8601String().split('T')[0],
        'movie_vote_average': testMovie.voteAverage,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,movie_id');

      LoggerFactory.info('✅ Favorito agregado exitosamente');
    } catch (e) {
      LoggerFactory.error('❌ Error agregando favorito: $e');
      return;
    }

    // 5. Verificar que el dato está en Supabase
    LoggerFactory.info('📊 Verificando datos en Supabase...');
    try {
      final response = await client
          .from('user_favorites')
          .select()
          .eq('user_id', user.id)
          .eq('movie_id', testMovie.id);

      if ((response as List).isNotEmpty) {
        LoggerFactory.info('✅ Dato encontrado en Supabase:');
        LoggerFactory.info('   - Título: ${response[0]['movie_title']}');
        LoggerFactory.info('   - Agregado: ${response[0]['added_at']}');
        LoggerFactory.info('   - Actualizado: ${response[0]['updated_at']}');
      } else {
        LoggerFactory.error('❌ Dato NO encontrado en Supabase');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error verificando datos: $e');
    }

    // 6. Test: Eliminar favorito
    LoggerFactory.info('⬇️ Eliminando favorito de Supabase...');
    try {
      await client
          .from('user_favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('movie_id', testMovie.id);

      LoggerFactory.info('✅ Favorito eliminado exitosamente');
    } catch (e) {
      LoggerFactory.error('❌ Error eliminando favorito: $e');
    }

    // 7. Verificar que el dato fue eliminado
    LoggerFactory.info('📊 Verificando eliminación...');
    try {
      final response = await client
          .from('user_favorites')
          .select()
          .eq('user_id', user.id)
          .eq('movie_id', testMovie.id);

      if ((response as List).isEmpty) {
        LoggerFactory.info('✅ Dato correctamente eliminado de Supabase');
      } else {
        LoggerFactory.error(
            '❌ Dato AÚN presente en Supabase (error en eliminación)');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error verificando eliminación: $e');
    }

    LoggerFactory.info('🎉 Test de sincronización completado');
  } catch (e) {
    LoggerFactory.error('❌ Error general en test: $e');
  }

  exit(0);
}
