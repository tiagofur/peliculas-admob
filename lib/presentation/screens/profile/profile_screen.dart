import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../domain/entities/user_stats.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_movie_ratings_provider.dart' as ratings;
import '../../widgets/profile_avatar.dart';

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

  @override
  void initState() {
    super.initState();
    // Rastrear visualización del perfil
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyticsService.trackEvent(AnalyticsEventType.userEngagement, {
        'timestamp': DateTime.now().toIso8601String(),
      });
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
    final userProfile = ref.watch(currentUserProfileProvider);
    final userStats = ref.watch(currentUserStatsProvider);
    final authNotifier = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => startEditing(userProfile.value),
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
                  onPressed: authNotifier.isLoading ? null : saveProfile,
                  child: authNotifier.isLoading
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
      body: userProfile.when(
        data: (profile) =>
            _buildProfileContent(theme, profile, userStats.value),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => ref.refresh(currentUserProfileProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(
      ThemeData theme, UserProfile? profile, UserStats? stats) {
    if (profile == null) {
      return const Center(child: Text('No se pudo cargar el perfil'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar y información básica
          _buildProfileHeader(theme, profile),
          const SizedBox(height: 32),

          // Estadísticas
          if (stats != null) ...[
            _buildStatsSection(theme, stats),
            const SizedBox(height: 32),
          ],

          // Valoraciones recientes
          _buildRatingsSection(theme),
          const SizedBox(height: 32),

          // Formulario de edición o información
          if (_isEditing)
            _buildEditForm(theme, profile)
          else
            _buildProfileInfo(theme, profile),

          const SizedBox(height: 32),

          // Botones de acción
          _buildActionButtons(theme),
        ],
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

  Widget _buildStatsSection(ThemeData theme, UserStats stats) {
    return Card(
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
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    theme,
                    'Películas Vistas',
                    stats.moviesWatched.toString(),
                    Icons.movie,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    theme,
                    'Favoritas',
                    stats.favoritesCount.toString(),
                    Icons.favorite,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    theme,
                    'Listas',
                    stats.listsCount.toString(),
                    Icons.list,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      ThemeData theme, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
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

  Widget _buildInfoTile(
      ThemeData theme, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingsSection(ThemeData theme) {
    return Consumer(
      builder: (context, ref, child) {
        final appState = ref.watch(appStateProvider);

        // Don't show ratings section for guest users
        if (!appState.isAuthenticated) {
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
                Consumer(
                  builder: (context, ref, child) {
                    final recentRatingsAsync =
                        ref.watch(ratings.recentRatingsProvider(5));
                    final ratingStatsAsync =
                        ref.watch(ratings.userRatingStatsProvider);

                    return Column(
                      children: [
                        // Estadísticas de valoraciones
                        ratingStatsAsync.when(
                          data: (stats) => _buildRatingStats(theme, stats),
                          loading: () => const CircularProgressIndicator(),
                          error: (error, stack) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 16),

                        // Valoraciones recientes
                        recentRatingsAsync.when(
                          data: (ratings) {
                            if (ratings.isEmpty) {
                              return Column(
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
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                Text(
                                  'Valoraciones Recientes',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...ratings.take(3).map((rating) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _buildRatingItem(theme, rating),
                                    )),
                                if (ratings.length > 3)
                                  TextButton(
                                    onPressed: () => showAllRatings(context),
                                    child: const Text(
                                        'Ver todas mis valoraciones'),
                                  ),
                              ],
                            );
                          },
                          loading: () => const CircularProgressIndicator(),
                          error: (error, stack) => Text(
                            'Error al cargar valoraciones',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRatingStats(ThemeData theme, Map<String, dynamic> stats) {
    final totalRatings = stats['total_ratings'] ?? 0;
    final averageRating = (stats['average_rating'] ?? 0.0) as double;

    if (totalRatings == 0) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Text(
                totalRatings.toString(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                'Películas\nvaloradas',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 20,
                  ),
                ],
              ),
              Text(
                'Promedio',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingItem(ThemeData theme, dynamic rating) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Poster pequeño (si está disponible)
          Container(
            width: 40,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: theme.colorScheme.surface,
            ),
            child: rating.moviePosterPath?.isNotEmpty == true
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      'https://image.tmdb.org/t/p/w92${rating.moviePosterPath}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Icon(Icons.movie,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                    ),
                  )
                : Icon(Icons.movie,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rating.movieTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ...List.generate(
                        5,
                        (index) => Icon(
                              index < rating.rating
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16,
                              color: Colors.amber,
                            )),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  void startEditing(UserProfile? profile) {
    if (profile != null) {
      final currentUser = ref.read(authStateProvider).value;
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
      });
    }
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
        final currentUser = ref.read(authStateProvider).value;
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
                userId: currentUser.id,
                fullName: _fullNameController.text.trim(),
                bio: _bioController.text.trim().isEmpty
                    ? null
                    : _bioController.text.trim(),
                avatarUrl: avatarUrl,
              );

          // Actualizar email si ha cambiado
          if (_emailController.text.trim() != currentUser.email) {
            await ref.read(authNotifierProvider.notifier).updateUser(
                  email: _emailController.text.trim(),
                );
          }
        }

        if (mounted) {
          setState(() {
            _isEditing = false;
            _selectedImage = null;
          });

          // Rastrear guardado exitoso del perfil
          _analyticsService.trackEvent(AnalyticsEventType.userEngagement, {
            'timestamp': DateTime.now().toIso8601String(),
            'has_bio': _bioController.text.trim().isNotEmpty,
            'has_avatar_change': _selectedImage != null,
            'has_email_change':
                _emailController.text.trim() != currentUser?.email,
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

  void showAllRatings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Todas mis valoraciones',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final userRatingsState =
                          ref.watch(ratings.userRatingsProvider);
                      final allRatings = userRatingsState.ratings;

                      if (userRatingsState.isLoading && allRatings.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (userRatingsState.error != null) {
                        return Center(
                          child: Text(
                            'Error al cargar valoraciones: ${userRatingsState.error}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        );
                      }

                      if (allRatings.isEmpty) {
                        return const Center(
                          child: Text('No tienes valoraciones aún'),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: allRatings.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildRatingItem(
                                Theme.of(context), allRatings[index]),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
