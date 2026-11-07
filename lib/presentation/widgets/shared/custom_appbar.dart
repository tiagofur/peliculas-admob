import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/movie.dart';
import '../../../generated/app_localizations.dart';
import '../../delegates/search_movie_delegate.dart';
import '../../providers/movies/movies_repository_provider.dart';
import '../../providers/search/search_movies_provider.dart';
import '../../providers/theme/theme_provider.dart';

class CustomAppbar extends ConsumerWidget implements PreferredSizeWidget {
  const CustomAppbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 20);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    // Apple large-title voice: bold with tight tracking, like the TV app.
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        );
    // LEGACY COMPATIBILITY FIXED - theme provider restored
    final themeState = ref.watch(themeNotifierProvider);
    final isDarkMode = themeState.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.movie_outlined,
                      color: colors.primary, size: 20),
                ),
                const SizedBox(width: 8),
                Text(l10n.appTitle, style: titleStyle),
                const Spacer(),
                // THEME TOGGLE RESTORED - provider fixed
                IconButton(
                  onPressed: () {
                    ref.read(themeControllerProvider).toggleDarkMode();
                  },
                  icon: Icon(isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined),
                  tooltip: isDarkMode
                      ? l10n.appBarToggleToLightMode
                      : l10n.appBarToggleToDarkMode,
                ),
                IconButton(
                  onPressed: () {
                    // SEARCH FUNCTIONALITY RESTORED - providers fixed
                    final searchQuery = ref.read(searchQueryProvider);
                    final movieRepository = ref.read(movieRepositoryProvider);

                    showSearch<Movie?>(
                            query: searchQuery,
                            context: context,
                            delegate: SearchMovieDelegate(
                                initialMovies: const [],
                                searchMovies: (query) =>
                                    movieRepository.searchMovies(query)))
                        .then((movie) {
                      if (movie == null) return;
                      if (context.mounted) {
                        context.push('/movie/${movie.id}');
                      }
                    });
                  },
                  icon: const Icon(Icons.search),
                  tooltip: l10n.searchMoviesTooltip,
                )
              ],
            ),
          ),
        ));
  }
}
