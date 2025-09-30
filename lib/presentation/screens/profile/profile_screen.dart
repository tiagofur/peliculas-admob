import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'; // Agregado para kIsWeb y Uint8List
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../providers/auth_provider.dart' hide currentUserProvider;
import '../../providers/movie_ratings_provider.dart';
import '../../providers/user_profile/user_profile_providers.dart';
import '../../providers/user_session_provider.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/ratings/star_rating_widget.dart';
import '../../widgets/sync/minimal_sync_indicator.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});

  /// ID del usuario a mostrar. Si es null, muestra el perfil del usuario autenticado.
  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isEditing = false;
  File? _selectedImage;
  Uint8List? _selectedImageBytes; // Para Web
  final ImagePicker _imagePicker = ImagePicker();
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isCheckingUsername = false;
  String? _usernameError;
  String? _initialUsername;
  Timer? _usernameDebounce;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _profilePublic = true;

  @override
  void initState() {
    super.initState();
    // Rastrear visualización del perfil
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyticsService.trackEvent(AnalyticsEventType.userEngagement, {
        'timestamp': DateTime.now().toIso8601String(),
      });

      _loadProfileData();
    });
  }

  /// Carga los datos del perfil desde el userId de la URL o del usuario autenticado
  void _loadProfileData() {
    try {
      final targetUserId = widget.userId;
      final currentUser = ref.read(currentUserProvider);

      if (targetUserId != null && targetUserId.isNotEmpty) {
        // Caso 1: Se especificó un userId en la URL
        LoggerFactory.info('🔄 Cargando perfil desde URL: $targetUserId');

        // Verificar si el usuario existe
        _loadProfileFromUserId(targetUserId);
      } else if (currentUser != null) {
        // Caso 2: No hay userId en URL, usar el usuario autenticado
        LoggerFactory.info(
            '🔄 Cargando perfil del usuario autenticado: ${currentUser.id}');

        // Refrescar perfil de usuario si no se ha cargado
        final sessionState = ref.read(userSessionProvider);
        if (sessionState.profile == null && !sessionState.isLoading) {
          ref.read(userSessionProvider.notifier).refreshProfile();
        }

        // Cargar estadísticas si no están disponibles
        ref.invalidate(currentUserStatsProvider);
      } else {
        // Caso 3: No hay usuario autenticado ni userId en URL
        // ⚠️ NO redirigir inmediatamente - el provider puede estar inicializándose
        // La UI mostrará el estado de carga apropiado
        LoggerFactory.info('⏳ Esperando inicialización de usuario...');

        // Intentar refrescar la sesión por si el usuario ya está autenticado
        // pero el provider aún no ha completado la inicialización
        ref.read(userSessionProvider.notifier).refreshProfile();
      }
    } catch (e) {
      LoggerFactory.error('❌ Error al cargar datos del perfil: $e');
      _showErrorAndRedirect('Error al cargar el perfil del usuario');
    }
  }

  /// Carga el perfil de un usuario específico por su ID
  Future<void> _loadProfileFromUserId(String userId) async {
    try {
      // Aquí puedes implementar la lógica para cargar el perfil desde Supabase
      // Por ahora, verificamos si el usuario autenticado coincide
      final currentUser = ref.read(currentUserProvider);

      if (currentUser != null && currentUser.id == userId) {
        // Es el mismo usuario, cargar normalmente
        final sessionState = ref.read(userSessionProvider);
        if (sessionState.profile == null && !sessionState.isLoading) {
          ref.read(userSessionProvider.notifier).refreshProfile();
        }
        ref.invalidate(currentUserStatsProvider);
      } else {
        // Es un usuario diferente o no hay usuario autenticado
        // TODO: Implementar carga de perfil público de otros usuarios
        LoggerFactory.warning(
            '⚠️ Visualización de perfiles de otros usuarios no implementada aún');
        _showErrorAndRedirect('No tienes permiso para ver este perfil');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error al cargar perfil del usuario $userId: $e');
      _showErrorAndRedirect('No se encontró el perfil del usuario');
    }
  }

  /// Muestra un error y redirige a la home
  void _showErrorAndRedirect(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      // Redirigir a home después de mostrar el error
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          context.go('/');
        }
      });
    }
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionState = ref.watch(userSessionProvider);
    final userStats = ref.watch(currentUserStatsProvider);
    final authNotifier = ref.watch(authNotifierProvider);
    // Consider both profile updates and auth updates as a saving state
    final isSaving = sessionState.isLoading || authNotifier.isLoading;
    final currentUser = sessionState.user;
    final profile = sessionState.profile;

    LoggerFactory.info(
        'ProfileScreen.build: user=${currentUser?.id ?? 'null'}, profile=${profile?.id ?? 'null'}, isLoading=${sessionState.isLoading}');

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
                  : () {
                      final sessionState = ref.read(userSessionProvider);
                      startEditing(
                        sessionState.profile ??
                            _createFallbackProfileFromUser(currentUser),
                        isFallback: sessionState.profile == null,
                      );
                    },
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
            child: _buildContent(
              theme,
              sessionState,
              userStats.value,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el contenido principal basado en el estado de la sesión
  Widget _buildContent(
    ThemeData theme,
    UserSessionState sessionState,
    UserStats? stats,
  ) {
    // Mostrar loading mientras se inicializa la sesión
    if (sessionState.isLoading && sessionState.user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Cargando perfil...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    // Usuario no autenticado (después de que terminó de cargar)
    if (!sessionState.isAuthenticated || sessionState.user == null) {
      return _buildGuestPlaceholder(theme);
    }

    // Usuario autenticado - mostrar perfil
    return _buildProfileContent(
      theme,
      ref,
      sessionState.user!,
      sessionState.profile,
      stats,
    );
  }

  Widget _buildProfileContent(
    ThemeData theme,
    WidgetRef ref,
    User currentUser,
    UserProfile? profile,
    UserStats? stats,
  ) {
    final effectiveProfile =
        profile ?? _createFallbackProfileFromUser(currentUser);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(userSessionProvider.notifier).refreshProfile();
        ref.invalidate(currentUserStatsProvider);
        ref.invalidate(recentRatingsProvider);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;
          final horizontalPadding = isWide ? 32.0 : 16.0;

          final statsPanel = _buildStatsPanel(theme, stats, ref);
          final detailsPanel = _isEditing
              ? _buildEditFormCard(theme, effectiveProfile)
              : _buildProfileInfoCard(theme, effectiveProfile);
          final ratingsPanel = _buildRatingsSection(theme);
          final actionsPanel = _buildActionButtons(theme);

          final headerSection = <Widget>[
            _buildProfileHeader(theme, effectiveProfile),
            const SizedBox(height: 24),
          ];

          final wideLayout = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...headerSection,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        detailsPanel,
                        const SizedBox(height: 24),
                        actionsPanel,
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        statsPanel,
                        const SizedBox(height: 24),
                        ratingsPanel,
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );

          final narrowLayout = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...headerSection,
              statsPanel,
              const SizedBox(height: 24),
              ratingsPanel,
              const SizedBox(height: 24),
              detailsPanel,
              const SizedBox(height: 24),
              actionsPanel,
            ],
          );

          final layoutKey = ValueKey(
            '${isWide}_${_isEditing}_${profile != null}_${stats != null}',
          );

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 24,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: layoutKey,
                    child: isWide ? wideLayout : narrowLayout,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditFormCard(ThemeData theme, UserProfile profile) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: _buildEditForm(theme, profile),
      ),
    );
  }

  Widget _buildProfileInfoCard(ThemeData theme, UserProfile profile) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: _buildProfileInfo(theme, profile),
      ),
    );
  }

  Widget _buildStatsPanel(
    ThemeData theme,
    UserStats? stats,
    WidgetRef ref,
  ) {
    if (stats != null) {
      return _buildStatsSection(theme, stats);
    }

    final statsState = ref.watch(currentUserStatsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights,
                  color: theme.colorScheme.primary,
                ),
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
            statsState.when(
              data: (_) => Column(
                children: [
                  Icon(
                    Icons.movie_creation_outlined,
                    size: 40,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tus estadísticas aparecerán aquí en cuanto registres actividad reciente.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              loading: () => const SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) {
                LoggerFactory.error('Error cargando estadísticas: $error');
                return Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error al cargar estadísticas',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
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
    final moviesWatched =
        (profile.stats['movies_watched'] as num?)?.toInt() ?? 0;
    final favoritesCount =
        (profile.stats['favorites_count'] as num?)?.toInt() ?? 0;
    final listsCount = (profile.stats['lists_count'] as num?)?.toInt() ?? 0;
    final isPublic = profile.preferences['profile_public'] ?? true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.16),
            theme.colorScheme.secondary.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 138,
                height: 138,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
              ),
              ProfileAvatar(
                avatarUrl: profile.avatarUrl,
                avatarHash: profile.avatarHash,
                selectedImage: _selectedImage,
                selectedImageBytes: _selectedImageBytes,
                size: 128,
                onTap: _isEditing ? selectImage : null,
                showEditIcon: _isEditing,
                heroTag: 'profile_avatar',
              ),
              if (_isEditing)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 3,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.photo_camera_outlined,
                        color: theme.colorScheme.onPrimary,
                        size: 20,
                      ),
                      tooltip: 'Cambiar avatar',
                      onPressed: selectImage,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              profile.fullName,
              key: ValueKey(profile.fullName),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (profile.hasUsername) ...[
            const SizedBox(height: 6),
            Text(
              '@${profile.username}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                letterSpacing: 0.2,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Miembro desde ${formatDate(profile.createdAt)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
          if (!_isEditing && profile.hasBio) ...[
            const SizedBox(height: 14),
            Text(
              profile.bio!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildHeaderChip(
                theme,
                Icons.local_movies_outlined,
                '$moviesWatched vistos',
              ),
              if (favoritesCount > 0)
                _buildHeaderChip(
                  theme,
                  Icons.favorite_outline,
                  '$favoritesCount favoritos',
                ),
              if (listsCount > 0)
                _buildHeaderChip(
                  theme,
                  Icons.list_alt_outlined,
                  '$listsCount listas',
                ),
              _buildHeaderChip(
                theme,
                isPublic ? Icons.public : Icons.lock_outline,
                isPublic ? 'Perfil público' : 'Perfil privado',
              ),
            ],
          ),
          if (_isEditing) ...[
            const SizedBox(height: 16),
            Chip(
              avatar: Icon(
                Icons.edit_outlined,
                size: 18,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              label: const Text('Editando perfil'),
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: theme.colorScheme.secondaryContainer,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
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
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Nombre de usuario',
              hintText: 'usuario_cinefilo',
              prefixText: '@',
              prefixIcon: const Icon(Icons.alternate_email),
              helperText:
                  'Entre 3 y 20 caracteres, solo minúsculas, números y guion bajo',
              suffixIcon: _buildUsernameStatusIcon(),
              errorText: _usernameError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
            ),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
              LengthLimitingTextInputFormatter(20),
            ],
            onChanged: _onUsernameChanged,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return null;
              }
              if (trimmed.length < 3) {
                return 'El usuario debe tener al menos 3 caracteres';
              }
              if (trimmed.length > 20) {
                return 'El usuario debe tener máximo 20 caracteres';
              }
              if (!RegExp(r'^[a-z0-9_]+$').hasMatch(trimmed)) {
                return 'Solo se permiten minúsculas, números y guion bajo';
              }
              return null;
            },
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
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Biografía (opcional)',
              hintText: 'Cuéntanos un poco sobre ti...',
              prefixIcon: const Icon(Icons.edit_note),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_bioController.text.length}/500',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
          _buildPreferencesEditor(theme),
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
        if (profile.hasUsername) ...[
          _buildInfoTile(
            theme,
            'Usuario',
            '@${profile.username}',
            Icons.alternate_email,
          ),
          const SizedBox(height: 12),
        ],
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
        const SizedBox(height: 12),
        _buildPreferencesInfo(theme, profile.preferences),
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

  Widget _buildPreferencesInfo(
    ThemeData theme,
    Map<String, bool> preferences,
  ) {
    final items = [
      (
        icon: Icons.email_outlined,
        label: 'Notificaciones por email',
        enabled: preferences['email_notifications'] ?? true,
      ),
      (
        icon: Icons.notifications_active_outlined,
        label: 'Notificaciones push',
        enabled: preferences['push_notifications'] ?? true,
      ),
      (
        icon: Icons.public,
        label: 'Perfil público',
        enabled: preferences['profile_public'] ?? true,
      ),
    ];

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_suggest_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Preferencias',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Icon(
                    item.enabled ? Icons.check_circle : Icons.highlight_off,
                    color: item.enabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesEditor(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_suggest_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Preferencias',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _emailNotifications,
              onChanged: (value) {
                setState(() {
                  _emailNotifications = value;
                });
              },
              title: const Text('Recibir notificaciones por email'),
              subtitle: const Text(
                  'Noticias, recordatorios y actualizaciones importantes'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _pushNotifications,
              onChanged: (value) {
                setState(() {
                  _pushNotifications = value;
                });
              },
              title: const Text('Notificaciones push'),
              subtitle: const Text(
                  'Alertas instantáneas sobre actividad en tu cuenta'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _profilePublic,
              onChanged: (value) {
                setState(() {
                  _profilePublic = value;
                });
              },
              title: const Text('Hacer mi perfil público'),
              subtitle: const Text(
                  'Permite que otros usuarios vean tus listas y actividad'),
            ),
          ],
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Cuenta y seguridad',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Gestiona tu sesión activa y tus preferencias de privacidad.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: showLogoutDialog,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void startEditing(UserProfile profile, {bool isFallback = false}) {
    // Read the current authenticated user directly to avoid nulls from AsyncValue
    final currentUser = ref.read(currentUserProvider);

    if (isFallback) {
      ref.read(userSessionProvider.notifier).refreshProfile();
    }

    setState(() {
      _isEditing = true;
      _usernameDebounce?.cancel();
      final normalizedUsername = profile.username?.toLowerCase();
      _usernameController.text = normalizedUsername ?? '';
      _initialUsername = normalizedUsername;
      _usernameError = null;
      _isCheckingUsername = false;
      _fullNameController.text = profile.fullName;
      _bioController.text = profile.bio ?? '';
      _emailController.text = currentUser?.email ?? '';
      _selectedImage = null;
      _selectedImageBytes = null;
      final preferences = profile.preferences;
      _emailNotifications = preferences['email_notifications'] ?? true;
      _pushNotifications = preferences['push_notifications'] ?? true;
      _profilePublic = preferences['profile_public'] ?? true;
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
      _usernameDebounce?.cancel();
      _usernameController.clear();
      _usernameError = null;
      _isCheckingUsername = false;
      _initialUsername = null;
      _selectedImage = null;
      _selectedImageBytes = null;
      _fullNameController.clear();
      _bioController.clear();
      _emailController.clear();
      _emailNotifications = true;
      _pushNotifications = true;
      _profilePublic = true;
    });
  }

  Future<void> saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_isCheckingUsername) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Espera a que finalice la verificación del nombre de usuario',
            ),
          ),
        );
        return;
      }

      if (_usernameError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_usernameError!),
          ),
        );
        return;
      }

      try {
        // Use the derived current user to ensure we have the latest value
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          String? avatarUrl;
          final normalizedUsername =
              _usernameController.text.trim().toLowerCase();

          // Si hay una imagen seleccionada, subirla primero
          if (_selectedImage != null || _selectedImageBytes != null) {
            late Uint8List bytes;
            String? extension;

            if (kIsWeb && _selectedImageBytes != null) {
              // En Web, usar los bytes directamente
              bytes = _selectedImageBytes!;
              extension = 'jpg'; // Default extension para Web
            } else if (_selectedImage != null) {
              // En otras plataformas, leer desde File
              bytes = await _selectedImage!.readAsBytes();
              final pathSegments = _selectedImage!.path.split('.');
              extension = pathSegments.length > 1 ? pathSegments.last : null;
            } else {
              throw Exception('No image available');
            }

            avatarUrl = await ref
                .read(userProfileNotifierProvider.notifier)
                .uploadAvatar(
                  bytes,
                  fileExtension: extension,
                );
          }

          // Actualizar perfil usando userSessionProvider
          await ref.read(userSessionProvider.notifier).updateProfile(
            fullName: _fullNameController.text.trim(),
            // Pasar username: null significa "no cambiar"
            // Pasar username: '' significa "limpiar el username"
            // Pasar username: 'valor' significa "actualizar con este valor"
            username: normalizedUsername,
            bio: _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
            avatarUrl: avatarUrl,
            preferences: {
              'email_notifications': _emailNotifications,
              'push_notifications': _pushNotifications,
              'profile_public': _profilePublic,
            },
          );

          // El userSessionProvider ya se actualiza automáticamente con el tiempo real

          // Actualizar email si ha cambiado
          if (_emailController.text.trim() != currentUser.email) {
            await ref.read(authNotifierProvider.notifier).updateUser(
                  email: _emailController.text.trim(),
                );
          }
        }

        if (mounted) {
          // Capture change flags BEFORE clearing state
          final bool avatarChanged =
              _selectedImage != null || _selectedImageBytes != null;
          final bool emailChanged =
              _emailController.text.trim() != currentUser?.email;

          setState(() {
            _isEditing = false;
            _selectedImage = null;
            _selectedImageBytes = null;
          });

          // Rastrear guardado exitoso del perfil
          _analyticsService.trackEvent(AnalyticsEventType.userEngagement, {
            'timestamp': DateTime.now().toIso8601String(),
            'has_bio': _bioController.text.trim().isNotEmpty,
            'has_avatar_change': avatarChanged,
            'has_email_change': emailChanged,
            'has_username': _usernameController.text.trim().isNotEmpty,
            'name_length': _fullNameController.text.trim().length,
            'email_notifications': _emailNotifications,
            'push_notifications': _pushNotifications,
            'profile_public': _profilePublic,
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
    // Capturar theme antes de operaciones async
    final theme = Theme.of(context);

    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image != null && mounted) {
      // WORKAROUND: En Web, skip cropping debido a incompatibilidad con image_cropper_for_web v6.1.0
      // TODO: Actualizar a image_cropper v11.x para habilitar cropping en Web
      if (kIsWeb) {
        LoggerFactory.info('Web platform: skipping image cropper (workaround)');

        // Mostrar mensaje informativo al usuario
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Imagen seleccionada sin recorte. Para recortar imágenes, usa la app móvil.',
                    ),
                  ),
                ],
              ),
              backgroundColor: theme.colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // En Web, leer los bytes de la imagen
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImage = null; // Clear File reference en Web
        });

        // Rastrear selección de imagen de avatar
        _analyticsService.trackEvent(AnalyticsEventType.userEngagement, {
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'gallery',
          'platform': 'web',
          'cropped': false,
        });

        return;
      }

      // En móvil/desktop: usar cropper normalmente
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512,
        maxHeight: 512,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar Avatar',
            toolbarColor: theme.colorScheme.primary,
            toolbarWidgetColor: theme.colorScheme.onPrimary,
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

      if (croppedFile != null && mounted) {
        setState(() {
          _selectedImage = File(croppedFile.path);
        });

        // Rastrear selección de imagen de avatar
        _analyticsService.trackEvent(AnalyticsEventType.userEngagement, {
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'gallery',
          'platform': kIsWeb ? 'web' : 'mobile',
          'cropped': true,
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

  void _onUsernameChanged(String value) {
    final trimmed = value.trim();
    final normalized = trimmed.toLowerCase();
    _usernameDebounce?.cancel();

    setState(() {
      _usernameError = null;
      _isCheckingUsername = false;
    });

    if (normalized.isEmpty) {
      return;
    }

    if (value != normalized) {
      final position = normalized.length;
      _usernameController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: position),
      );
    }

    if (_initialUsername != null && normalized == _initialUsername) {
      return;
    }

    if (normalized.length < 3) {
      return;
    }

    _usernameDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_checkUsernameAvailability(normalized));
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    try {
      final notifier = ref.read(userProfileNotifierProvider.notifier);
      final normalized = username.toLowerCase();
      final isAvailable = await notifier.isUsernameAvailable(normalized);
      if (!mounted) return;
      setState(() {
        _isCheckingUsername = false;
        _usernameError =
            isAvailable ? null : 'Este nombre de usuario ya está en uso';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCheckingUsername = false;
        _usernameError = 'No se pudo verificar el nombre de usuario';
      });
    }
  }

  Widget? _buildUsernameStatusIcon() {
    final trimmed = _usernameController.text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (_isCheckingUsername) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_usernameError != null) {
      return const Icon(Icons.error_outline, color: Colors.redAccent);
    }
    return const Icon(Icons.check_circle, color: Colors.green);
  }

  Widget _buildHeaderChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
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
