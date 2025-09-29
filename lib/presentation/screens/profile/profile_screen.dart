import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/logging/logger_factory.dart';
// import removido: tmdb_image_utils ya no es utilizado en este archivo
import '../../../domain/entities/syncable_movie_rating.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../domain/entities/user_stats.dart';
import '../../providers/auth_provider.dart';
import '../../providers/movie_ratings_provider.dart';
// Eliminado provider legacy de valoraciones por no utilizarse
import '../../widgets/profile_avatar.dart';
import '../../widgets/ratings/star_rating_widget.dart';
import '../../widgets/sync/minimal_sync_indicator.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isEditing = false;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _hasRequestedProfileRecovery = false;

  @override
  void initState() {
    super.initState();
    // Rastrear visualización del perfil
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyticsService.trackEvent(AnalyticsEventType.userEngagement, {
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Forzar carga de datos si hay un usuario autenticado
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        // Refrescar perfil de usuario si no se ha cargado
        final profileState = ref.read(userProfileNotifierProvider);
        if (profileState.value == null && !profileState.isLoading) {
          ref.read(userProfileNotifierProvider.notifier).refreshProfile();
        }

        // Cargar estadísticas si no están disponibles
        ref.invalidate(currentUserStatsProvider);
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProfile = ref.watch(userProfileNotifierProvider);
    final userStats = ref.watch(currentUserStatsProvider);
    final authNotifier = ref.watch(authNotifierProvider);
    // Consider both profile updates and auth updates as a saving state
    final isSaving = userProfile.isLoading || authNotifier.isLoading;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar perfil',
              onPressed: currentUser == null
                  ? null
                  : () => startEditing(
                        userProfile.value ??
                            _createFallbackProfileFromUser(currentUser),
                        isFallback: userProfile.value == null,
                      ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: cancelEditing,
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isSaving ? null : saveProfile,
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
                const SizedBox(width: 8),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          const MinimalSyncIndicator(),
          Expanded(
            child: userProfile.when(
              data: (profile) => _buildProfileContent(
                theme,
                ref,
                currentUser,
                profile,
                userStats.value,
              ),
              loading: () => currentUser != null
                  ? _buildBasicUserInfo(theme, currentUser)
                  : const Center(child: CircularProgressIndicator()),
              error: (error, _) {
                LoggerFactory.error('Error al cargar el perfil: $error');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar el perfil',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => ref
                            .read(userProfileNotifierProvider.notifier)
                            .refreshProfile(),
                        child: const Text('Reintentar'),
                      ),
                      if (currentUser != null) ...[
                        const SizedBox(height: 24),
                        _buildBasicUserInfo(theme, currentUser),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Muestra información básica (nombre y correo) incluso si el perfil está cargando o falló
  Widget _buildBasicUserInfo(ThemeData theme, User user) {
    final fallbackProfile = _createFallbackProfileFromUser(user);

    return RefreshIndicator(
      onRefresh: () async {
        // Forzar recarga de perfil y estadísticas
        await ref.read(userProfileNotifierProvider.notifier).refreshProfile();
        ref.invalidate(currentUserStatsProvider);
        ref.invalidate(recentRatingsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(theme, fallbackProfile),
            const SizedBox(height: 24),
            Text(
              'Información Básica',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoTile(
              theme,
              'Nombre',
              fallbackProfile.fullName,
              Icons.person,
            ),
            const SizedBox(height: 12),
            _buildInfoTile(
              theme,
              'Email',
              user.email,
              Icons.email,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    ThemeData theme,
    WidgetRef ref,
    User? currentUser,
    UserProfile? profile,
    UserStats? stats,
  ) {
    if (currentUser == null) {
      return _buildGuestPlaceholder(theme);
    }

    final usingFallbackProfile = profile == null;
    final effectiveProfile =
        profile ?? _createFallbackProfileFromUser(currentUser);

    if (usingFallbackProfile && !_hasRequestedProfileRecovery) {
      _hasRequestedProfileRecovery = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(userProfileNotifierProvider.notifier).refreshProfile();
      });
    } else if (!usingFallbackProfile && _hasRequestedProfileRecovery) {
      _hasRequestedProfileRecovery = false;
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(userProfileNotifierProvider.notifier).refreshProfile();
        ref.invalidate(currentUserStatsProvider);
        ref.invalidate(recentRatingsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (usingFallbackProfile) _buildFallbackNotice(theme),
            _buildProfileHeader(theme, effectiveProfile),
            const SizedBox(height: 32),
            if (stats != null) ...[
              _buildStatsSection(theme, stats),
              const SizedBox(height: 32),
            ] else ...[
              // Mostrar placeholder de estadísticas mientras cargan
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estadísticas',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ref.watch(currentUserStatsProvider).when(
                            data: (_) => const SizedBox(), // Ya manejado arriba
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (error, _) {
                              LoggerFactory.error(
                                  'Error cargando estadísticas: $error');
                              return Column(
                                children: [
                                  Text(
                                    'Error cargando estadísticas',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      ref.invalidate(currentUserStatsProvider);
                                    },
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
            _buildRatingsSection(theme),
            const SizedBox(height: 32),
            if (_isEditing)
              _buildEditForm(theme, effectiveProfile)
            else
              _buildProfileInfo(theme, effectiveProfile),
            const SizedBox(height: 32),
            _buildActionButtons(theme),
          ],
        ),
      ),
    );
  }

  UserProfile _createFallbackProfileFromUser(User user) {
    final fallbackName = () {
      if (user.fullName != null && user.fullName!.trim().isNotEmpty) {
        return user.fullName!.trim();
      }
      final emailParts = user.email.split('@');
      return emailParts.isNotEmpty && emailParts.first.isNotEmpty
          ? emailParts.first
          : 'Usuario';
    }();

    return UserProfile(
      id: user.id,
      userId: user.id,
      fullName: fallbackName,
      bio: null,
      avatarUrl: user.avatarUrl,
      createdAt: user.createdAt,
      updatedAt: user.lastSignInAt ?? user.createdAt,
    );
  }

  Widget _buildFallbackNotice(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sync,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Estamos sincronizando tu perfil completo. Puedes actualizar tus datos y se guardarán en cuanto termine la sincronización.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestPlaceholder(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 72,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'Inicia sesión para ver tu perfil',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Crea una cuenta o accede con tus credenciales para sincronizar tu información en todos tus dispositivos.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login),
              label: const Text('Iniciar sesión'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/register'),
              child: const Text('Crear cuenta gratuita'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, UserProfile profile) {
    return Column(
      children: [
        Stack(
          children: [
            ProfileAvatar(
              avatarUrl: profile.avatarUrl,
              selectedImage: _selectedImage,
              size: 120,
              onTap: _isEditing ? selectImage : null,
              showEditIcon: _isEditing,
              heroTag: 'profile_avatar',
            ),
            if (_isEditing)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.camera_alt,
                      color: theme.colorScheme.onPrimary,
                      size: 20,
                    ),
                    tooltip: 'Cambiar avatar',
                    onPressed: selectImage,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (!_isEditing) ...[
          Text(
            profile.fullName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Miembro desde ${formatDate(profile.createdAt)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditForm(ThemeData theme, UserProfile profile) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información Personal',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Por favor ingresa tu nombre';
              }
              if (value.trim().length < 2) {
                return 'El nombre debe tener al menos 2 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Por favor ingresa tu email';
              }
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Por favor ingresa un email válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 150,
            decoration: InputDecoration(
              labelText: 'Biografía (opcional)',
              hintText: 'Cuéntanos un poco sobre ti...',
              prefixIcon: const Icon(Icons.edit_note),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(ThemeData theme, UserProfile profile) {
    final currentUser = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Información Personal',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoTile(
          theme,
          'Nombre',
          profile.fullName,
          Icons.person,
        ),
        const SizedBox(height: 12),
        if (currentUser?.email != null)
          _buildInfoTile(
            theme,
            'Email',
            currentUser?.email ?? '',
            Icons.email,
          ),
        if (currentUser?.email != null) const SizedBox(height: 12),
        if (profile.hasBio) ...[
          _buildInfoTile(
            theme,
            'Biografía',
            profile.bio ?? '',
            Icons.edit_note,
          ),
          const SizedBox(height: 12),
        ],
        _buildInfoTile(
          theme,
          'Última actualización',
          formatDate(profile.updatedAt),
          Icons.update,
        ),
      ],
    );
  }

  Widget _buildRatingsSection(ThemeData theme) {
    return Consumer(
      builder: (context, ref, child) {
        final currentUser = ref.watch(currentUserProvider);

        // Don't show ratings section for guest users
        if (currentUser == null) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mis Valoraciones',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Rating statistics and recent ratings section
                Consumer(
                  builder: (context, ref, child) {
                    final recentRatingsAsync = ref.watch(recentRatingsProvider);
                    final ratingStats = ref.watch(userRatingStatsProvider);

                    return Column(
                      children: [
                        // User rating statistics - verificar si hay datos
                        if (ratingStats != null &&
                            ratingStats.isNotEmpty &&
                            (ratingStats['totalRatings'] ?? 0) > 0) ...[
                          _buildRatingStats(theme, ratingStats),
                          const SizedBox(height: 16),
                        ],

                        // Recent ratings - manejar diferentes estados
                        recentRatingsAsync.when(
                          data: (recentRatings) {
                            if (recentRatings.isNotEmpty) {
                              return _buildRecentRatings(theme, recentRatings);
                            } else {
                              // Mostrar mensaje cuando no hay valoraciones
                              return Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.star_border,
                                      size: 48,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Aún no has valorado ninguna película',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          loading: () => Container(
                            padding: const EdgeInsets.all(16),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (error, stack) {
                            LoggerFactory.error(
                                'Error cargando valoraciones: $error');
                            return Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Error al cargar valoraciones',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      ref.invalidate(recentRatingsProvider);
                                    },
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                // (Se eliminó el contenedor temporal deshabilitado para valoraciones)
              ],
            ),
          ),
        );
      },
    );
  }

  // Eliminado _buildRatingItem legacy no utilizado

  // Tile compacto para información de perfil
  Widget _buildInfoTile(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sección de estadísticas del usuario
  Widget _buildStatsSection(ThemeData theme, UserStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Estadísticas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme,
                    'Vistas',
                    stats.moviesWatched.toString(),
                    Icons.remove_red_eye,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    theme,
                    'Favoritos',
                    stats.favoritesCount.toString(),
                    Icons.favorite,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme,
                    'Listas',
                    stats.listsCount.toString(),
                    Icons.list_alt,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    theme,
                    'Actividad',
                    formatDate(stats.lastActivity),
                    Icons.update,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        // Botón de cerrar sesión
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: showLogoutDialog,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar Sesión'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }

  void startEditing(UserProfile profile, {bool isFallback = false}) {
    // Read the current authenticated user directly to avoid nulls from AsyncValue
    final currentUser = ref.read(currentUserProvider);

    if (isFallback) {
      ref.read(userProfileNotifierProvider.notifier).refreshProfile();
    }

    setState(() {
      _isEditing = true;
      _fullNameController.text = profile.fullName;
      _bioController.text = profile.bio ?? '';
      _emailController.text = currentUser?.email ?? '';
      _selectedImage = null;
    });

    // Rastrear inicio de edición del perfil
    _analyticsService.trackEvent(AnalyticsEventType.userEngagement, {
      'timestamp': DateTime.now().toIso8601String(),
      'has_bio': profile.bio != null,
      'has_avatar': profile.avatarUrl != null,
      'is_fallback_profile': isFallback,
    });
  }

  void cancelEditing() {
    setState(() {
      _isEditing = false;
      _selectedImage = null;
      _fullNameController.clear();
      _bioController.clear();
      _emailController.clear();
    });
  }

  Future<void> saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        // Use the derived current user to ensure we have the latest value
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          String? avatarUrl;

          // Si hay una imagen seleccionada, subirla primero
          if (_selectedImage != null) {
            avatarUrl = await ref
                .read(userProfileNotifierProvider.notifier)
                .uploadAvatar(
                  userId: currentUser.id,
                  filePath: _selectedImage?.path ?? '',
                );
          }

          // Actualizar perfil en la tabla user_profiles
          await ref.read(userProfileNotifierProvider.notifier).updateProfile(
                fullName: _fullNameController.text.trim(),
                bio: _bioController.text.trim().isEmpty
                    ? null
                    : _bioController.text.trim(),
                avatarUrl: avatarUrl,
              );

          await ref.read(userProfileNotifierProvider.notifier).refreshProfile();

          // Actualizar email si ha cambiado
          if (_emailController.text.trim() != currentUser.email) {
            await ref.read(authNotifierProvider.notifier).updateUser(
                  email: _emailController.text.trim(),
                );
          }
        }

        if (mounted) {
          // Capture change flags BEFORE clearing state
          final bool avatarChanged = _selectedImage != null;
          final bool emailChanged =
              _emailController.text.trim() != currentUser?.email;

          setState(() {
            _isEditing = false;
            _selectedImage = null;
          });

          // Rastrear guardado exitoso del perfil
          _analyticsService.trackEvent(AnalyticsEventType.userEngagement, {
            'timestamp': DateTime.now().toIso8601String(),
            'has_bio': _bioController.text.trim().isNotEmpty,
            'has_avatar_change': avatarChanged,
            'has_email_change': emailChanged,
            'name_length': _fullNameController.text.trim().length,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil actualizado correctamente'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        LoggerFactory.error('Error al actualizar perfil: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar perfil: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> selectImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512,
        maxHeight: 512,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar Avatar',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Theme.of(context).colorScheme.onPrimary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Recortar Avatar',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _selectedImage = File(croppedFile.path);
        });

        // Rastrear selección de imagen de avatar
        _analyticsService.trackEvent(AnalyticsEventType.userEngagement, {
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'gallery',
        });
      }
    }
  }

  void showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();

              // Rastrear cierre de sesión
              _analyticsService.trackEvent(AnalyticsEventType.sessionEnd, {
                'timestamp': DateTime.now().toIso8601String(),
                'source': 'profile_screen',
              });

              ref.read(authNotifierProvider.notifier).signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  String formatDate(DateTime date) {
    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];

    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  // Se eliminó el bottom sheet legacy para mostrar todas las valoraciones,
  // ahora delegamos a una pantalla dedicada mediante _showAllRatings.

  /// Builds the rating statistics section
  Widget _buildRatingStats(ThemeData theme, Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tus valoraciones',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Total',
                  stats['totalRatings'].toString(),
                  Icons.movie,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Promedio',
                  '${stats['averageRating']}/10',
                  Icons.star_half,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Con reseña',
                  stats['ratingsWithReview'].toString(),
                  Icons.rate_review,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Recientes',
                  stats['recentRatingsCount'].toString(),
                  Icons.schedule,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a small stat card
  Widget _buildStatCard(
      ThemeData theme, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Builds the recent ratings section
  Widget _buildRecentRatings(
      ThemeData theme, List<SyncableMovieRating> ratings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'Valoraciones recientes',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...ratings.take(5).map((rating) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SimpleStarRating(
                      rating: rating.rating / 2, // Convert to 5-star scale
                      size: 14,
                      showRating: false,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rating.movieTitle,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${rating.rating}/10',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showAllRatings(context),
            child: const Text('Ver todas las valoraciones'),
          ),
        ],
      ),
    );
  }

  /// Shows all user ratings in a dedicated screen
  void _showAllRatings(BuildContext context) {
    context.go('/ratings');
  }
}
