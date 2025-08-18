import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/storage/favorite_movies_provider.dart';
import '../../infrastructure/datasources/isar_datasource.dart';

class LocalStorageDebugWidget extends ConsumerWidget {
  const LocalStorageDebugWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🗄️ DEBUG: Almacenamiento Local',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () async {
                try {
                  print('\n=== DEBUG: ALMACENAMIENTO LOCAL ===');

                  // Test directo con HiveDatasource
                  final hiveDatasource = HiveDatasource();

                  // Cargar todas las películas sin límite
                  final allMovies =
                      await hiveDatasource.loadMovies(limit: 10000, offset: 0);
                  print('🎬 Total películas en Hive: ${allMovies.length}');

                  if (allMovies.isNotEmpty) {
                    print('🎬 Primeras 5 películas en Hive:');
                    for (int i = 0; i < allMovies.length.clamp(0, 5); i++) {
                      final movie = allMovies[i];
                      print('   ${i + 1}. ${movie.title} (ID: ${movie.id})');
                    }
                  } else {
                    print('❌ No hay películas guardadas en Hive');
                  }

                  // También probar con el provider de favoritos
                  final favoritesState = ref.read(favoriteMoviesProvider);
                  final moviesList = favoritesState.values.toList();
                  print('📱 Favoritos en provider: ${moviesList.length}');

                  if (moviesList.isNotEmpty) {
                    print('📱 Primeras 3 películas en provider:');
                    for (int i = 0; i < moviesList.length.clamp(0, 3); i++) {
                      final movie = moviesList[i];
                      print('   ${i + 1}. ${movie.title} (ID: ${movie.id})');
                    }
                  }

                  print('=== FIN DEBUG ===\n');

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Debug completado. Hive: ${allMovies.length} películas, Provider: ${moviesList.length} películas'),
                      backgroundColor:
                          allMovies.isEmpty ? Colors.red : Colors.green,
                    ),
                  );
                } catch (e) {
                  print('❌ Error en debug de almacenamiento: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error en debug: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('🔍 Inspeccionar Almacenamiento Local'),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () async {
                try {
                  print('\n=== RECARGANDO FAVORITOS ===');
                  await ref
                      .read(favoriteMoviesProvider.notifier)
                      .loadNextPage();
                  print('✅ Favoritos recargados');

                  final state = ref.read(favoriteMoviesProvider);
                  final stateMovies = state.values.toList();
                  print(
                      '📱 Favoritos después de recargar: ${stateMovies.length}');

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Favoritos recargados: ${stateMovies.length} películas'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                } catch (e) {
                  print('❌ Error recargando favoritos: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error recargando: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('🔄 Recargar Favoritos'),
            ),

            const SizedBox(height: 12),

            // Mostrar estado actual del provider
            Consumer(
              builder: (context, ref, child) {
                final favoritesState = ref.watch(favoriteMoviesProvider);
                final moviesList = favoritesState.values.toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📊 Estado actual del provider:'),
                    Text('   • Total películas: ${moviesList.length}'),
                    Text('   • Map keys: ${favoritesState.keys.length}'),
                    if (moviesList.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('🎬 Últimas películas:'),
                      ...moviesList.take(3).map(
                          (movie) => Text('   • ${movie.title} (${movie.id})')),
                    ]
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
