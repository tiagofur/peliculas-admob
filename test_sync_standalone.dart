import 'dart:io';

import 'package:peliculas/core/config/supabase_config.dart';
import 'package:peliculas/domain/entities/movie.dart';

// Script independiente para probar sincronización con Supabase
void main() async {
  print('🧪 Iniciando test de sincronización independiente...');

  try {
    // 1. Inicializar Supabase
    print('📡 Inicializando Supabase...');
    await SupabaseConfig.initialize();
    final client = SupabaseConfig.client;
    print('✅ Supabase inicializado');

    // 2. Crear/Login usuario de prueba
    const testEmail = 'sync-test@peliculas.com';
    const testPassword = 'TestPassword123!';

    print('🔐 Intentando login...');
    try {
      await client.auth.signInWithPassword(
        email: testEmail,
        password: testPassword,
      );
      print('✅ Login exitoso');
    } catch (e) {
      print('❌ Login falló, intentando registro...');
      try {
        await client.auth.signUp(
          email: testEmail,
          password: testPassword,
        );
        print('✅ Usuario registrado');

        // Esperar un poco para la confirmación automática
        await Future.delayed(Duration(seconds: 2));

        // Intentar login nuevamente
        await client.auth.signInWithPassword(
          email: testEmail,
          password: testPassword,
        );
        print('✅ Login después de registro exitoso');
      } catch (e2) {
        print('❌ Error en registro: $e2');
        return;
      }
    }

    final user = client.auth.currentUser;
    if (user == null) {
      print('❌ No hay usuario autenticado');
      return;
    }

    print('👤 Usuario autenticado: ${user.email} (${user.id})');

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
    print('⬆️ Agregando favorito directamente a Supabase...');
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

      print('✅ Favorito agregado exitosamente');
    } catch (e) {
      print('❌ Error agregando favorito: $e');
      return;
    }

    // 5. Verificar que el dato está en Supabase
    print('📊 Verificando datos en Supabase...');
    try {
      final response = await client
          .from('user_favorites')
          .select()
          .eq('user_id', user.id)
          .eq('movie_id', testMovie.id);

      if ((response as List).isNotEmpty) {
        print('✅ Dato encontrado en Supabase:');
        print('   - Título: ${response[0]['movie_title']}');
        print('   - Agregado: ${response[0]['added_at']}');
        print('   - Actualizado: ${response[0]['updated_at']}');
      } else {
        print('❌ Dato NO encontrado en Supabase');
      }
    } catch (e) {
      print('❌ Error verificando datos: $e');
    }

    // 6. Test: Eliminar favorito
    print('⬇️ Eliminando favorito de Supabase...');
    try {
      await client
          .from('user_favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('movie_id', testMovie.id);

      print('✅ Favorito eliminado exitosamente');
    } catch (e) {
      print('❌ Error eliminando favorito: $e');
    }

    // 7. Verificar que el dato fue eliminado
    print('📊 Verificando eliminación...');
    try {
      final response = await client
          .from('user_favorites')
          .select()
          .eq('user_id', user.id)
          .eq('movie_id', testMovie.id);

      if ((response as List).isEmpty) {
        print('✅ Dato correctamente eliminado de Supabase');
      } else {
        print('❌ Dato AÚN presente en Supabase (error en eliminación)');
      }
    } catch (e) {
      print('❌ Error verificando eliminación: $e');
    }

    print('🎉 Test de sincronización completado');
  } catch (e) {
    print('❌ Error general en test: $e');
  }

  exit(0);
}
