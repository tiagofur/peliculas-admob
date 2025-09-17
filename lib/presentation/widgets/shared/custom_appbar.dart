import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/movie.dart';
import '../../delegates/search_movie_delegate.dart';

class CustomAppbar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 20);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    // TODO: Fix legacy compatibility - theme provider commented out
    // final isDarkMode = ref.watch(themeNotifierProvider).isDarkMode;

    return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Icon(Icons.movie_outlined, color: colors.primary),
                const SizedBox(width: 5),
                Text('Peliculas', style: titleStyle),
                const Spacer(),
                // TODO: Theme toggle disabled until provider is fixed
                // IconButton(
                //   onPressed: null,
                //   icon: Icon(isDarkMode
                //       ? Icons.light_mode_outlined
                //       : Icons.dark_mode_outlined),
                //   tooltip: isDarkMode
                //       ? 'Cambiar a modo claro'
                //       : 'Cambiar a modo oscuro',
                // ),
                IconButton(
                  onPressed: () {
                    // TODO: Fix legacy compatibility - providers commented out
                    // final searchQuery = ref.read(searchQueryProvider);
                    // final movieRepository = ref.read(movieRepositoryProvider);
                    const searchQuery = '';

                    showSearch<Movie?>(
                            query: searchQuery,
                            context: context,
                            delegate: SearchMovieDelegate(
                                initialMovies: const [],
                                searchMovies: (query) async => <Movie>[]))
                        .then((movie) {
                      if (movie == null) return;
                      if (context.mounted) {
                        context.push('/movie/${movie.id}');
                      }
                    });
                  },
                  icon: const Icon(Icons.search),
                  tooltip: 'Buscar películas',
                )
              ],
            ),
          ),
        ));
  }
}
