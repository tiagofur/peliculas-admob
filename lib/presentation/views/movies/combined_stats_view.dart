import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/activity_patterns.dart';
import '../../../domain/entities/genre_analysis.dart';
import '../../../domain/entities/rating_analysis.dart';
import '../../../domain/entities/temporal_analysis.dart';
import '../../../domain/entities/user_stats.dart';
import '../../providers/user_stats_provider.dart';
import '../../widgets/admob/native_ad_widget.dart';
import '../../widgets/admob/full_width_ad_widget.dart';

class CombinedStatsView extends ConsumerWidget {
  const CombinedStatsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userStats = ref.watch(userStatsProvider);
    final genreAnalysis = ref.watch(genreAnalysisProvider);
    final temporalAnalysis = ref.watch(temporalAnalysisProvider);
    final ratingAnalysis = ref.watch(ratingAnalysisProvider);
    final activityPatterns = ref.watch(activityPatternsProvider);

    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Estadísticas generales
              userStats.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
                data: (stats) => Column(
                  children: [
                    _buildUserTypeCard(stats, colors, textStyles),
                    const SizedBox(height: 16),
                    _buildGeneralStatsSection(stats, colors, textStyles),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Anuncio nativo discreto antes de géneros
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: NativeAdWidget(
                  height: 100,
                  showLabel: false,
                ),
              ),
              const SizedBox(height: 16),

              // Análisis de géneros
              genreAnalysis.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
                data: (analysis) =>
                    _buildGenreAnalysisSection(analysis, colors, textStyles),
              ),
              const SizedBox(height: 16),

              // Análisis temporal
              temporalAnalysis.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
                data: (analysis) =>
                    _buildTemporalAnalysisSection(analysis, colors, textStyles),
              ),
              const SizedBox(height: 24),

              // Anuncio nativo discreto antes de calificaciones
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: NativeAdWidget(
                  height: 100,
                  showLabel: false,
                ),
              ),
              const SizedBox(height: 16),

              // Análisis de calificaciones
              ratingAnalysis.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
                data: (analysis) =>
                    _buildRatingAnalysisSection(analysis, colors, textStyles),
              ),
              const SizedBox(height: 16),

              // Patrones de actividad
              activityPatterns.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
                data: (patterns) =>
                    _buildActivityPatternsSection(patterns, colors, textStyles),
              ),

              // Banner al final de las estadísticas
              const SizedBox(height: 16),
              const FullWidthAdWidget(
                height: 120,
                margin: EdgeInsets.symmetric(horizontal: 0),
                showLabel: false,
                borderRadius: 12.0,
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildUserTypeCard(
      UserStats stats, ColorScheme colors, TextTheme textStyles) {
    Color typeColor;
    IconData typeIcon;
    String typeDescription;

    switch (stats.userType) {
      case 'Casual':
        typeColor = Colors.green;
        typeIcon = Icons.movie;
        typeDescription = 'Disfrutas del cine ocasionalmente';
        break;
      case 'Enthusiast':
        typeColor = Colors.orange;
        typeIcon = Icons.local_movies;
        typeDescription = 'Eres un verdadero amante del cine';
        break;
      case 'Cinephile':
        typeColor = Colors.purple;
        typeIcon = Icons.theaters;
        typeDescription = 'Eres un cinéfilo experimentado';
        break;
      default:
        typeColor = colors.primary;
        typeIcon = Icons.person;
        typeDescription = 'Tu perfil cinematográfico';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            typeColor.withAlpha(25),
            typeColor.withAlpha(12)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: typeColor.withAlpha(76)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: typeColor.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(typeIcon, color: typeColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.userType,
                  style: textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
                Text(
                  typeDescription,
                  style: textStyles.bodySmall?.copyWith(
                    color: colors.onSurface.withAlpha(178),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralStatsSection(
      UserStats stats, ColorScheme colors, TextTheme textStyles) {
    return _buildSection(
      title: 'Resumen General',
      icon: Icons.analytics,
      colors: colors,
      textStyles: textStyles,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Favoritas',
                  value: stats.totalFavorites.toString(),
                  icon: Icons.favorite,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Vistas',
                  value: stats.totalWatched.toString(),
                  icon: Icons.visibility,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Listas',
                  value: stats.totalLists.toString(),
                  icon: Icons.list_alt,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Este Año',
                  value: stats.moviesThisYear.toString(),
                  icon: Icons.calendar_today,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressIndicator(
            label: 'Calificación Promedio',
            value: stats.averageRating,
            maxValue: 10.0,
            color: Colors.amber,
            suffix: '/10',
          ),
          const SizedBox(height: 8),
          _buildProgressIndicator(
            label: 'Tasa de Descubrimiento',
            value: stats.discoveryRate,
            maxValue: 100.0,
            color: Colors.teal,
            suffix: '%',
          ),
        ],
      ),
    );
  }

  Widget _buildGenreAnalysisSection(
      GenreAnalysis analysis, ColorScheme colors, TextTheme textStyles) {
    return _buildSection(
      title: 'Análisis de Géneros',
      icon: Icons.category,
      colors: colors,
      textStyles: textStyles,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Géneros Favoritos',
            style: textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: analysis.topFavoriteGenres.take(5).map((genre) {
              return Chip(
                label: Text(_getGenreName(genre)),
                backgroundColor: colors.primaryContainer,
                labelStyle: TextStyle(color: colors.onPrimaryContainer),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildProgressIndicator(
            label: 'Diversidad de Géneros',
            value: analysis.genreDiversity * 100,
            maxValue: 100.0,
            color: Colors.purple,
            suffix: '%',
          ),
        ],
      ),
    );
  }

  Widget _buildTemporalAnalysisSection(
      TemporalAnalysis analysis, ColorScheme colors, TextTheme textStyles) {
    return _buildSection(
      title: 'Análisis Temporal',
      icon: Icons.timeline,
      colors: colors,
      textStyles: textStyles,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  title: 'Era Preferida',
                  value: analysis.preferredEra,
                  icon: Icons.history,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  title: 'Preferencia Vintage',
                  value: '${analysis.vintagePreference.toStringAsFixed(1)}%',
                  icon: Icons.movie_filter,
                  color: Colors.brown,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingAnalysisSection(
      RatingAnalysis analysis, ColorScheme colors, TextTheme textStyles) {
    return _buildSection(
      title: 'Análisis de Calificaciones',
      icon: Icons.star,
      colors: colors,
      textStyles: textStyles,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  title: 'Promedio Favoritas',
                  value: analysis.averageFavoriteRating.toStringAsFixed(1),
                  icon: Icons.favorite,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  title: 'Preferencia',
                  value: analysis.qualityPreference,
                  icon: Icons.thumb_up,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressIndicator(
            label: 'Alineación Crítica',
            value: analysis.criticalAlignment,
            maxValue: 100.0,
            color: Colors.amber,
            suffix: '%',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPatternsSection(
      ActivityPatterns patterns, ColorScheme colors, TextTheme textStyles) {
    return _buildSection(
      title: 'Patrones de Actividad',
      icon: Icons.trending_up,
      colors: colors,
      textStyles: textStyles,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  title: 'Mes Más Activo',
                  value: patterns.mostActiveMonth,
                  icon: Icons.calendar_month,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  title: 'Día Favorito',
                  value: patterns.mostActiveDay,
                  icon: Icons.today,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressIndicator(
            label: 'Consistencia',
            value: patterns.consistency,
            maxValue: 100.0,
            color: Colors.teal,
            suffix: '%',
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required ColorScheme colors,
    required TextTheme textStyles,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: textStyles.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withAlpha(204),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withAlpha(204),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
    required String suffix,
  }) {
    final percentage = (value / maxValue).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              '${value.toStringAsFixed(1)}$suffix',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: color.withAlpha(51),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  String _getGenreName(String genreId) {
    final genres = {
      '28': 'Acción',
      '12': 'Aventura',
      '16': 'Animación',
      '35': 'Comedia',
      '80': 'Crimen',
      '99': 'Documental',
      '18': 'Drama',
      '10751': 'Familiar',
      '14': 'Fantasía',
      '36': 'Historia',
      '27': 'Terror',
      '10402': 'Música',
      '9648': 'Misterio',
      '10749': 'Romance',
      '878': 'Ciencia ficción',
      '10770': 'Película de TV',
      '53': 'Thriller',
      '10752': 'Guerra',
      '37': 'Western',
    };
    return genres[genreId] ?? genreId;
  }
}
