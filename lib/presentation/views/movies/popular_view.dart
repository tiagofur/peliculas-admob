import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/movies/movies_providers.dart';
import '../../widgets/widgets.dart';

class PopularView extends ConsumerStatefulWidget {
  const PopularView({super.key});

  @override
  PopularViewState createState() => PopularViewState();
}

class PopularViewState extends ConsumerState<PopularView>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final popularState = ref.watch(popularMoviesProvider);
    final popularMovies = popularState.movies;

    if (popularState.state == MoviesState.loading && popularMovies.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (popularState.state == MoviesState.error && popularMovies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              popularState.errorMessage ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(popularMoviesProvider.notifier).refresh(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Barra de filtros rápidos
          QuickFiltersBar(
            onFilterChanged: () {
              // Aquí podrías implementar la lógica para aplicar filtros
              // Por ahora solo refrescamos la lista
              ref.read(popularMoviesProvider.notifier).refresh();
            },
          ),
          if (popularState.state == MoviesState.error)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      popularState.errorMessage ?? 'Error desconocido',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(popularMoviesProvider.notifier).refresh(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: MovieMasonry(
              loadNextPage: () =>
                  ref.read(popularMoviesProvider.notifier).loadNextPage(),
              movies: popularMovies,
            ),
          ),
        ],
      ),
      floatingActionButton: FilterFab(
        onFiltersApplied: () {
          // Aplicar filtros y refrescar la lista
          ref.read(popularMoviesProvider.notifier).refresh();
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
