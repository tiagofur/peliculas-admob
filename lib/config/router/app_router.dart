import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/app_info/about_screen.dart';
import '../../presentation/screens/app_info/help_screen.dart';
import '../../presentation/screens/app_info/privacy_policy_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/screens.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/screens/watchlist_screen.dart';
import '../../presentation/views/list_share_web_view.dart';
import '../../presentation/views/movie_share_web_view.dart';
import '../../presentation/views/recommendation_share_web_view.dart';
import '../../presentation/views/views.dart';
import '../../presentation/widgets/shared/page_transitions.dart';

// Global navigator key para navegación desde notificaciones
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

// Provider para el router con acceso al estado de autenticación
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authState;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register');

      // Solo redirigir si está autenticado y está en una ruta de auth
      if (isAuthenticated && isAuthRoute) {
        return '/';
      }

      // Permitir acceso a todas las rutas sin autenticación (modo guest)
      return null; // No redirigir
    },
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
                        routes: [
                          GoRoute(
                            path: ':listId',
                            name: 'ListDetail',
                            pageBuilder: (context, state) {
                              final listId =
                                  state.pathParameters['listId'] ?? '0';

                              return CustomTransitionPage(
                                key: state.pageKey,
                                child: Scaffold(
                                  body: ListDetailView(listId: listId),
                                ),
                                transitionsBuilder: (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  return CinematicPageTransitions
                                      .slideUpTransition(
                                    page: child,
                                    duration: const Duration(
                                      milliseconds: 500,
                                    ),
                                  ).transitionsBuilder(
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/my-library/watchlist',
                        name: 'watchlist',
                        builder: (context, state) => const WatchlistScreen(),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/my-library',
                redirect: (_, __) => '/my-library/lists',
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

          // Rama para la pantalla de "Streaming"
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/streaming',
                name: 'streaming-dashboard',
                builder: (context, state) => const StreamingDashboardScreen(),
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

      // Ruta principal de recomendaciones
      GoRoute(
        path: '/recommendations',
        name: 'recommendations',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const RecommendationsView(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return CinematicPageTransitions.slideUpTransition(
                page: child,
                duration: const Duration(milliseconds: 500),
              ).transitionsBuilder(
                context,
                animation,
                secondaryAnimation,
                child,
              );
            },
          );
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return CinematicPageTransitions.slideUpTransition(
                page: child,
                duration: const Duration(milliseconds: 500),
              ).transitionsBuilder(
                context,
                animation,
                secondaryAnimation,
                child,
              );
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return CinematicPageTransitions.slideUpTransition(
                page: child,
                duration: const Duration(milliseconds: 500),
              ).transitionsBuilder(
                context,
                animation,
                secondaryAnimation,
                child,
              );
            },
          );
        },
      ),

      // Ruta para detalles de lista (se mantiene igual)

      // Sharing routes (se mantienen igual, pero ajustamos la de película)
      GoRoute(
        path: '/movie/:id/share',
        name: MovieShareWebView.name,
        pageBuilder: (context, state) {
          final movieId = state.pathParameters['id'] ?? '0';

          return CustomTransitionPage(
            key: state.pageKey,
            child: MovieShareWebView(movieId: movieId),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return CinematicPageTransitions.fadeScaleTransition(
                page: child,
                duration: const Duration(milliseconds: 400),
              ).transitionsBuilder(
                context,
                animation,
                secondaryAnimation,
                child,
              );
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return CinematicPageTransitions.fadeScaleTransition(
                page: child,
                duration: const Duration(milliseconds: 400),
              ).transitionsBuilder(
                context,
                animation,
                secondaryAnimation,
                child,
              );
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return CinematicPageTransitions.fadeScaleTransition(
                page: child,
                duration: const Duration(milliseconds: 400),
              ).transitionsBuilder(
                context,
                animation,
                secondaryAnimation,
                child,
              );
            },
          );
        },
      ),

      // Rutas de autenticación
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Ruta de perfil
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const ProfileScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return CinematicPageTransitions.slideUpTransition(
                page: child,
                duration: const Duration(milliseconds: 500),
              ).transitionsBuilder(
                context,
                animation,
                secondaryAnimation,
                child,
              );
            },
          );
        },
      ),

      // Rutas de Ayuda y Acerca de
      GoRoute(
        path: '/help',
        name: 'help',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const HelpScreen(),
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
        path: '/about',
        name: 'about',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const AboutScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return CinematicPageTransitions.slideUpTransition(
                page: child,
                duration: const Duration(milliseconds: 500),
              ).transitionsBuilder(context, animation, secondaryAnimation, child);
            },
          );
        },
      ),
    ],
  );
});

// Router legacy para compatibilidad (se puede eliminar después)
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
                      routes: [
                        GoRoute(
                          path: ':listId',
                          name: 'ListDetail',
                          pageBuilder: (context, state) {
                            final listId =
                                state.pathParameters['listId'] ?? '0';

                            return CustomTransitionPage(
                              key: state.pageKey,
                              child: Scaffold(
                                body: ListDetailView(listId: listId),
                              ),
                              transitionsBuilder: (
                                context,
                                animation,
                                secondaryAnimation,
                                child,
                              ) {
                                return CinematicPageTransitions
                                    .slideUpTransition(
                                  page: child,
                                  duration: const Duration(
                                    milliseconds: 500,
                                  ),
                                ).transitionsBuilder(
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/my-library',
              redirect: (_, __) => '/my-library/lists',
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

    // Sharing routes (se mantienen igual, pero ajustamos la de película)
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

    // Rutas de autenticación
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // Ruta de perfil
    GoRoute(
      path: '/profile',
      name: 'profile',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return CinematicPageTransitions.slideUpTransition(
              page: child,
              duration: const Duration(milliseconds: 500),
            ).transitionsBuilder(context, animation, secondaryAnimation, child);
          },
        );
      },
    ),

    // Ruta de configuración
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return CinematicPageTransitions.slideUpTransition(
              page: child,
              duration: const Duration(milliseconds: 500),
            ).transitionsBuilder(context, animation, secondaryAnimation, child);
          },
        );
      },
    ),

    // Ruta de política de privacidad
    GoRoute(
      path: '/privacy-policy',
      name: 'privacy-policy',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const PrivacyPolicyScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return CinematicPageTransitions.slideUpTransition(
              page: child,
              duration: const Duration(milliseconds: 500),
            ).transitionsBuilder(context, animation, secondaryAnimation, child);
          },
        );
      },
    ),
  ],
);
