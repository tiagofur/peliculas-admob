import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/screens/screens.dart';
import '../../presentation/views/views.dart';
import '../../presentation/views/movies/combined_stats_view.dart';
import '../../presentation/views/movie_share_web_view.dart';
import '../../presentation/views/list_share_web_view.dart';
import '../../presentation/views/recommendation_share_web_view.dart';
import '../../presentation/widgets/shared/page_transitions.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Rutas principales con StatefulShellRoute
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return HomeScreen(navigationShell: navigationShell);
      },
      branches: [
        // Rama para la pantalla de Inicio
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomeView(),
            ),
          ],
        ),

        // Rama para la pantalla de "Mi Biblioteca" con sub-rutas
        StatefulShellBranch(
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, navigationShell) {
                return MyLibraryView(navigationShell: navigationShell);
              },
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/my-library/favorites',
                      name: 'favorites',
                      builder: (context, state) => const FavoritesView(),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/my-library/watched',
                      name: 'watched',
                      builder: (context, state) => const WatchedView(),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/my-library/lists',
                      name: 'lists',
                      builder: (context, state) => const CustomListsView(),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/my-library',
              redirect: (_, __) => '/my-library/favorites',
            ),
          ],
        ),

        // Rama para la pantalla de "Estadísticas" con sub-rutas
        StatefulShellBranch(
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, navigationShell) {
                return StatisticsView(navigationShell: navigationShell);
              },
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/statistics/overview',
                      name: 'overview',
                      builder: (context, state) => const CombinedStatsView(),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/statistics/achievements',
                      name: 'achievements',
                      builder: (context, state) => const AchievementsView(),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/statistics',
              redirect: (_, __) => '/statistics/overview',
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/movie/:id',
      name: MovieScreen.name,
      builder: (context, state) {
        final movieId = state.pathParameters['id'] ?? 'no-id';
        return MovieScreen(movieId: movieId);
      },
    ),

    // Rutas para recomendaciones (se mantienen igual)
    GoRoute(
      path: '/recommendations/category/:categoryId',
      name: 'RecommendationCategory',
      pageBuilder: (context, state) {
        final categoryId = state.pathParameters['categoryId'] ?? '';

        return CustomTransitionPage(
          key: state.pageKey,
          child: RecommendationCategoryScreen(categoryId: categoryId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return CinematicPageTransitions.slideUpTransition(
              page: child,
              duration: const Duration(milliseconds: 500),
            ).transitionsBuilder(context, animation, secondaryAnimation, child);
          },
        );
      },
    ),
    GoRoute(
      path: '/recommendations/mood/:mood',
      name: 'RecommendationMood',
      pageBuilder: (context, state) {
        final mood = state.pathParameters['mood'] ?? '';

        return CustomTransitionPage(
          key: state.pageKey,
          child: RecommendationMoodScreen(mood: mood),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return CinematicPageTransitions.slideUpTransition(
              page: child,
              duration: const Duration(milliseconds: 500),
            ).transitionsBuilder(context, animation, secondaryAnimation, child);
          },
        );
      },
    ),
    // Ruta para detalles de lista (se mantiene igual)
    GoRoute(
      path: '/lists/:listId',
      name: 'ListDetail',
      pageBuilder: (context, state) {
        final listId = state.pathParameters['listId'] ?? '0';

        return CustomTransitionPage(
          key: state.pageKey,
          child: Scaffold(
            body: ListDetailView(listId: listId),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return CinematicPageTransitions.slideUpTransition(
              page: child,
              duration: const Duration(milliseconds: 500),
            ).transitionsBuilder(context, animation, secondaryAnimation, child);
          },
        );
      },
    ),
    // Sharing routes (se mantienen igual, pero ajustamos la de película)
    GoRoute(
      path: '/movie/:id/share',
      name: MovieShareWebView.name,
      pageBuilder: (context, state) {
        final movieId = state.pathParameters['id'] ?? 'no-id';

        return CustomTransitionPage(
          key: state.pageKey,
          child: MovieShareWebView(movieId: movieId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return CinematicPageTransitions.fadeScaleTransition(
              page: child,
              duration: const Duration(milliseconds: 400),
            ).transitionsBuilder(context, animation, secondaryAnimation, child);
          },
        );
      },
    ),
    GoRoute(
      path: '/list/:listId/share',
      name: ListShareWebView.name,
      pageBuilder: (context, state) {
        final listId = state.pathParameters['listId'] ?? '0';

        return CustomTransitionPage(
          key: state.pageKey,
          child: ListShareWebView(listId: listId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return CinematicPageTransitions.fadeScaleTransition(
              page: child,
              duration: const Duration(milliseconds: 400),
            ).transitionsBuilder(context, animation, secondaryAnimation, child);
          },
        );
      },
    ),
    GoRoute(
      path: '/recommendations/:type/:id/share',
      name: RecommendationShareWebView.name,
      pageBuilder: (context, state) {
        final type = state.pathParameters['type'] ?? '';
        final id = state.pathParameters['id'] ?? '';

        return CustomTransitionPage(
          key: state.pageKey,
          child: RecommendationShareWebView(type: type, id: id),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return CinematicPageTransitions.fadeScaleTransition(
              page: child,
              duration: const Duration(milliseconds: 400),
            ).transitionsBuilder(context, animation, secondaryAnimation, child);
          },
        );
      },
    ),
  ],
);
