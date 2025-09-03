import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_theme.dart' as app_theme;
import '../providers/auth_provider.dart';
import '../providers/theme/theme_provider.dart';
import 'profile_avatar.dart';

class CustomDrawer extends ConsumerWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Drawer(
      child: Column(
        children: [
          // Header dinámico
          if (isAuthenticated)
            _buildAuthenticatedHeader(context, ref, colorScheme)
          else
            _buildGuestHeader(context, colorScheme),

          // Divider
          const Divider(height: 1),

          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (isAuthenticated)
                  ..._buildAuthenticatedMenuItems(context, ref)
                else
                  ..._buildGuestMenuItems(context),

                const Divider(),

                // Menu items comunes
                ..._buildCommonMenuItems(context),

                if (isAuthenticated)
                  ..._buildAuthenticatedActions(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedHeader(
      BuildContext context, WidgetRef ref, ColorScheme colorScheme) {
    final user = ref.watch(currentUserProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);

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
      child: userProfileAsync.when(
        data: (profile) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  avatarUrl: profile?.avatarUrl,
                  size: 64,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/profile');
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.fullName ?? user?.fullName ?? 'Usuario',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
            if (profile?.bio != null && (profile?.bio?.isNotEmpty ?? false))
              Text(
                profile?.bio ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        loading: () => Column(
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
                        user?.fullName ?? 'Usuario',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        error: (error, stack) => Column(
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
                        user?.fullName ?? 'Usuario',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
                context.push('/login');
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
          context.push('/profile');
        },
      ),
      ListTile(
        leading: const Icon(Icons.favorite),
        title: const Text('Mis Favoritos'),
        onTap: () {
          Navigator.of(context).pop();
          context.push('/my-library/favorites');
        },
      ),
      ListTile(
        leading: const Icon(Icons.list),
        title: const Text('Mis Listas'),
        onTap: () {
          Navigator.of(context).pop();
          context.push('/my-library/lists');
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
          context.push('/login');
        },
      ),
      ListTile(
        leading: const Icon(Icons.person_add),
        title: const Text('Crear Cuenta'),
        onTap: () {
          Navigator.of(context).pop();
          context.push('/register');
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
          context.push('/settings');
        },
      ),

      // Quick theme toggle
      Consumer(
        builder: (context, ref, child) {
          final themeState = ref.watch(themeNotifierProvider);
          final isDark = themeState.themeMode == app_theme.ThemeMode.dark;
          final isSystem = themeState.themeMode == app_theme.ThemeMode.system;

          String subtitle;
          IconData icon;

          if (isSystem) {
            subtitle = 'Siguiendo el sistema';
            icon = Icons.brightness_auto;
          } else if (isDark) {
            subtitle = 'Modo oscuro activo';
            icon = Icons.dark_mode;
          } else {
            subtitle = 'Modo claro activo';
            icon = Icons.light_mode;
          }

          return ListTile(
            leading: Icon(icon),
            title: const Text('Tema'),
            subtitle: Text(subtitle),
            trailing: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                size: 20,
              ),
              onPressed: () {
                final notifier = ref.read(themeNotifierProvider.notifier);
                if (themeState.themeMode == app_theme.ThemeMode.dark) {
                  notifier.setThemeMode(app_theme.ThemeMode.light);
                } else {
                  notifier.setThemeMode(app_theme.ThemeMode.dark);
                }
              },
              tooltip:
                  isDark ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro',
            ),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/settings');
            },
          );
        },
      ),

      ListTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('Ayuda'),
        onTap: () {
          Navigator.of(context).pop();
          context.push('/help');
        },
      ),
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Acerca de'),
        onTap: () {
          Navigator.of(context).pop();
          context.push('/about');
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
