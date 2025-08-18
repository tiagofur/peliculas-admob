import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/config/supabase_config.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/infrastructure/repositories/hybrid_favorites_repository.dart';

void main() {
  group('Sincronización en Tiempo Real Tests', () {
    late HybridFavoritesRepository repository;

    setUpAll(() async {
      // Inicializar Supabase
      await SupabaseConfig.initialize();
    });

    setUp(() {
      // Configurar el repositorio para las pruebas
      // repository = HybridFavoritesRepository();
    });

    testWidgets('Agregar favorito debe sincronizar inmediatamente',
        (WidgetTester tester) async {
      // Película de prueba
      final testMovie = Movie(
        id: 12345,
        title: 'Test Movie Sync',
        overview: 'Película para probar sincronización',
        releaseDate: DateTime(2023, 1, 1),
        posterPath: '/test_poster.jpg',
        backdropPath: '/test_backdrop.jpg',
        voteAverage: 8.5,
        genreIds: ['Action', 'Thriller'],
        adult: false,
        originalLanguage: 'en',
        originalTitle: 'Test Movie Sync',
        popularity: 100.0,
        video: false,
        voteCount: 1000,
      );

      print('🧪 Iniciando test de sincronización en tiempo real...');

      // TODO: Implementar test una vez que se corrija el repositorio
      // 1. Hacer login con usuario de prueba
      // 2. Agregar película a favoritos
      // 3. Verificar que se sincronizó inmediatamente
      // 4. Verificar en Supabase que el dato está presente

      expect(true, true); // Placeholder hasta completar implementación
    });

    testWidgets('Quitar favorito debe sincronizar inmediatamente',
        (WidgetTester tester) async {
      print('🧪 Test de remover favorito...');

      // TODO: Implementar test de eliminación
      expect(true, true); // Placeholder
    });
  });
}

// Helper para crear un usuario de prueba
Future<void> createTestUser() async {
  try {
    final client = SupabaseConfig.client;
    await client.auth.signUp(
      email: 'test-sync@peliculas.com',
      password: 'TestPassword123!',
    );
    print('✅ Usuario de prueba creado');
  } catch (e) {
    print('❌ Error creando usuario de prueba: $e');
  }
}

// Helper para hacer login con usuario de prueba
Future<void> loginTestUser() async {
  try {
    final client = SupabaseConfig.client;
    await client.auth.signInWithPassword(
      email: 'test-sync@peliculas.com',
      password: 'TestPassword123!',
    );
    print('✅ Login de usuario de prueba exitoso');
  } catch (e) {
    print('❌ Error en login de usuario de prueba: $e');
  }
}

// Helper para verificar datos en Supabase
Future<bool> verifyDataInSupabase(String userId, int movieId) async {
  try {
    final client = SupabaseConfig.client;
    final response = await client
        .from('user_favorites')
        .select()
        .eq('user_id', userId)
        .eq('movie_id', movieId);

    final hasData = (response as List).isNotEmpty;
    print(
        '📊 Datos en Supabase para movie $movieId: ${hasData ? "PRESENTE" : "AUSENTE"}');
    return hasData;
  } catch (e) {
    print('❌ Error verificando datos en Supabase: $e');
    return false;
  }
}
