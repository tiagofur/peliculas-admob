import 'package:flutter/material.dart';

import '../../domain/entities/enhanced_user_profile.dart';

/// Widget simplificado para mostrar preferencias del usuario
class PreferencesSettingsWidget extends StatelessWidget {
  const PreferencesSettingsWidget({
    super.key,
    required this.preferences,
  });
  final UserPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContentPreferences(),
          const SizedBox(height: 24),
          _buildPersonalPreferences(),
          const SizedBox(height: 24),
          _buildNotificationSettings(),
          const SizedBox(height: 24),
          _buildPrivacySettings(),
        ],
      ),
    );
  }

  Widget _buildContentPreferences() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preferencias de contenido',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPreferenceItem(
              'Rating máximo',
              _getContentRatingDisplayName(preferences.maxContentRating),
              Icons.security,
            ),
            _buildPreferenceItem(
              'Rango de años',
              '${preferences.minReleaseYear} - ${preferences.maxReleaseYear}',
              Icons.calendar_today,
            ),
            _buildPreferenceItem(
              'Duración',
              '${preferences.minRuntime} - ${preferences.maxRuntime} min',
              Icons.access_time,
            ),
            _buildSwitchPreference(
              'Incluir contenido para adultos',
              preferences.includeAdultContent,
              Icons.warning,
            ),
            _buildSwitchPreference(
              'Preferir subtítulos',
              preferences.preferSubtitles,
              Icons.subtitles,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalPreferences() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preferencias personales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildListPreference(
              'Idiomas preferidos',
              preferences.preferredLanguages,
              Icons.language,
            ),
            _buildListPreference(
              'Actores favoritos',
              preferences.favoriteActors,
              Icons.person,
            ),
            _buildListPreference(
              'Directores favoritos',
              preferences.favoriteDirectors,
              Icons.movie_creation,
            ),
            _buildListPreference(
              'Estudios favoritos',
              preferences.favoriteStudios,
              Icons.business,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuración de notificaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchPreference(
              'Notificaciones push habilitadas',
              preferences.notifications.enablePushNotifications,
              Icons.notifications,
            ),
            _buildSwitchPreference(
              'Notificar nuevas recomendaciones',
              preferences.notifications.notifyNewRecommendations,
              Icons.recommend,
            ),
            _buildSwitchPreference(
              'Notificar actividad de amigos',
              preferences.notifications.notifyFriendsActivity,
              Icons.people,
            ),
            _buildSwitchPreference(
              'Notificar nuevos estrenos',
              preferences.notifications.notifyNewReleases,
              Icons.new_releases,
            ),
            _buildSwitchPreference(
              'Notificar actualizaciones de watchlist',
              preferences.notifications.notifyWatchlistUpdates,
              Icons.list,
            ),
            _buildSwitchPreference(
              'Notificar logros desbloqueados',
              preferences.notifications.notifyAchievements,
              Icons.emoji_events,
            ),
            _buildPreferenceItem(
              'Frecuencia de resumen por email',
              _getDigestFrequencyDisplayName(
                  preferences.notifications.digestFrequency),
              Icons.email,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuración de privacidad',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPreferenceItem(
              'Visibilidad del perfil',
              _getProfileVisibilityDisplayName(
                  preferences.privacy.profileVisibility),
              Icons.visibility,
            ),
            _buildSwitchPreference(
              'Mostrar calificaciones públicamente',
              preferences.privacy.showRatingsPublic,
              Icons.star,
            ),
            _buildSwitchPreference(
              'Mostrar watchlist públicamente',
              preferences.privacy.showWatchlistPublic,
              Icons.list,
            ),
            _buildSwitchPreference(
              'Mostrar favoritos públicamente',
              preferences.privacy.showFavoritesPublic,
              Icons.favorite,
            ),
            _buildSwitchPreference(
              'Mostrar estadísticas públicamente',
              preferences.privacy.showStatsPublic,
              Icons.analytics,
            ),
            _buildSwitchPreference(
              'Permitir solicitudes de amistad',
              preferences.privacy.allowFriendRequests,
              Icons.person_add,
            ),
            _buildSwitchPreference(
              'Compartir actividad en redes sociales',
              preferences.privacy.shareActivityOnSocial,
              Icons.share,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceItem(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchPreference(String title, bool value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: null, // Solo vista, no editable
          ),
        ],
      ),
    );
  }

  Widget _buildListPreference(String title, List<String> items, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                'Ninguno configurado',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: items.take(5).map((item) {
                  return Chip(
                    label: Text(
                      item,
                      style: const TextStyle(fontSize: 12),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _getContentRatingDisplayName(MovieContentRating rating) {
    switch (rating) {
      case MovieContentRating.g:
        return 'General (G)';
      case MovieContentRating.pg:
        return 'Guía parental (PG)';
      case MovieContentRating.pg13:
        return 'Mayores de 13 (PG-13)';
      case MovieContentRating.r:
        return 'Restringido (R)';
      case MovieContentRating.nc17:
        return 'Mayores de 17 (NC-17)';
    }
  }

  String _getDigestFrequencyDisplayName(DigestFrequency frequency) {
    switch (frequency) {
      case DigestFrequency.daily:
        return 'Diario';
      case DigestFrequency.weekly:
        return 'Semanal';
      case DigestFrequency.monthly:
        return 'Mensual';
      case DigestFrequency.never:
        return 'Nunca';
    }
  }

  String _getProfileVisibilityDisplayName(ProfileVisibility visibility) {
    switch (visibility) {
      case ProfileVisibility.private:
        return 'Privado';
      case ProfileVisibility.friends:
        return 'Solo amigos';
      case ProfileVisibility.public:
        return 'Público';
    }
  }
}
