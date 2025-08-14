import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/movie.dart';
import '../../delegates/search_movie_delegate.dart';
import '../../providers/providers.dart';
import '../../providers/theme/theme_provider.dart';

class CustomAppbar extends ConsumerWidget implements PreferredSizeWidget {
  const CustomAppbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 20);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final isDarkMode = ref.watch(themeNotifierProvider).isDarkMode;

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
                IconButton(
                  onPressed: () {
                    ref.read(themeNotifierProvider.notifier).toggleDarkMode();
                  },
                  icon: Icon(isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined),
                ),
                IconButton(
                    onPressed: () {
                      final searchQuery = ref.read(searchQueryProvider);
                      final movieRepository = ref.read(movieRepositoryProvider);

                      showSearch<Movie?>(
                              query: searchQuery,
                              context: context,
                              delegate: SearchMovieDelegate(
                                  initialMovies: const [],
                                  searchMovies: movieRepository.searchMovies))
                          .then((movie) {
                        if (movie == null) return;
                        if (context.mounted) {
                          context.push('/movie/${movie.id}');
                        }
                      });
                    },
                    icon: const Icon(Icons.search))
              ],
            ),
          ),
        ));
  }
}
