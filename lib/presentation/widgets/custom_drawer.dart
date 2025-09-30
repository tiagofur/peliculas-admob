import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/user.dart';
import '../providers/auth_provider.dart';
import '../providers/user_session_provider.dart';
import '../views/debug/lists_debug_view.dart';
import 'profile_avatar.dart';

class CustomDrawer extends ConsumerWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sessionState = ref.watch(userSessionProvider);

    LoggerFactory.info(
        'CustomDrawer.build: isAuthenticated=${sessionState.isAuthenticated}, userId=${sessionState.userId ?? 'null'}');

    return Drawer(
      child: Column(
        children: [
          // Header dinámico
          if (sessionState.isAuthenticated)
            _buildAuthenticatedHeader(context, ref, colorScheme, sessionState)
          else
            _buildGuestHeader(context, colorScheme),

          // Divider
          const Divider(height: 1),

          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (sessionState.isAuthenticated)
                  ..._buildAuthenticatedMenuItems(context, ref)
                else
                  ..._buildGuestMenuItems(context),

                const Divider(),

                // Menu items comunes
                ..._buildCommonMenuItems(context),

                if (sessionState.isAuthenticated)
                  ..._buildAuthenticatedActions(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedHeader(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    UserSessionState sessionState,
  ) {
    final profile = sessionState.profile;
    final user = sessionState.user!;

    LoggerFactory.info(
        '✅ CustomDrawer: Construyendo header autenticado para user: ${user.id}, hasProfile: ${profile != null}');

    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: sessionState.isLoading
          ? _buildLoadingHeader(context, colorScheme, user)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ProfileAvatar(
                      avatarUrl: profile?.avatarUrl,
                      avatarHash: profile?.avatarHash,
                      size: 64,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go('/profile');
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.fullName ?? user.fullName ?? 'Usuario',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (profile?.hasUsername ?? false) ...[
                            const SizedBox(height: 4),
                            Text(
                              '@${profile!.username}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer
                                        .withValues(alpha: 0.7),
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer
                                          .withValues(alpha: 0.8),
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (profile?.bio != null && profile?.bio?.isNotEmpty == true)
                  Text(
                    profile?.bio ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.9),
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
    );
  }

  Widget _buildLoadingHeader(
    BuildContext context,
    ColorScheme colorScheme,
    User user,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const ProfileAvatar(
              avatarUrl: null,
              size: 64,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName ?? 'Usuario',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.8),
                        ),
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(
                    height: 12,
                    width: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGuestHeader(BuildContext context, ColorScheme colorScheme) {
    final theme = Theme.of(context);

    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHighest,
            colorScheme.surfaceContainer,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: colorScheme.primary,
                child: Icon(
                  Icons.person,
                  size: 32,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Inicia sesión para acceder a todas las funciones',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/login');
              },
              child: const Text('Iniciar Sesión'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAuthenticatedMenuItems(
      BuildContext context, WidgetRef ref) {
    return [
      ListTile(
        leading: const Icon(Icons.person),
        title: const Text('Mi Perfil'),
        onTap: () {
          Navigator.of(context).pop();
          context.go('/profile');
        },
      ),
      ListTile(
        leading: const Icon(Icons.favorite),
        title: const Text('Mis Favoritos'),
        onTap: () {
          Navigator.of(context).pop();
          context.go('/my-library/favorites');
        },
      ),
      ListTile(
        leading: const Icon(Icons.list),
        title: const Text('Mis Listas'),
        onTap: () {
          Navigator.of(context).pop();
          context.go('/my-library/lists');
        },
      ),
    ];
  }

  List<Widget> _buildGuestMenuItems(BuildContext context) {
    return [
      ListTile(
        leading: const Icon(Icons.login),
        title: const Text('Iniciar Sesión'),
        onTap: () {
          Navigator.of(context).pop();
          context.go('/login');
        },
      ),
      ListTile(
        leading: const Icon(Icons.person_add),
        title: const Text('Crear Cuenta'),
        onTap: () {
          Navigator.of(context).pop();
          context.go('/register');
        },
      ),
    ];
  }

  List<Widget> _buildCommonMenuItems(BuildContext context) {
    return [
      ListTile(
        leading: const Icon(Icons.settings),
        title: const Text('Configuración'),
        onTap: () {
          Navigator.of(context).pop();
          context.go('/settings');
        },
      ),

      ListTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('Ayuda'),
        onTap: () {
          Navigator.of(context).pop();
          context.go('/help');
        },
      ),
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Acerca de'),
        onTap: () {
          Navigator.of(context).pop();
          context.go('/about');
        },
      ),

      // Debug menu - only show in development
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.bug_report, color: Colors.orange),
        title: const Text('Debug: Reparar Listas'),
        subtitle: const Text('Herramientas de diagnóstico y reparación'),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ListsDebugView(),
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _buildAuthenticatedActions(BuildContext context, WidgetRef ref) {
    return [
      const Divider(),
      ListTile(
        leading: Icon(
          Icons.logout,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          'Cerrar Sesión',
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        onTap: () async {
          Navigator.of(context).pop();
          await _showSignOutDialog(context, ref);
        },
      ),
    ];
  }

  Future<void> _showSignOutDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}
