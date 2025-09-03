import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ml/recommendation_engine.dart';
import '../../core/ml/user_behavior_analyzer.dart';
import '../providers/recommendations/recommendations_provider.dart';

class UserInsightsWidget extends ConsumerWidget {
  const UserInsightsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final behaviorAnalysisAsync = ref.watch(userBehaviorAnalysisProvider);
    final personalizedInsightsAsync = ref.watch(personalizedInsightsProvider);
    final engagementScoreAsync = ref.watch(engagementScoreProvider);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Insights Personalizados',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[800],
                                ),
                      ),
                      Text(
                        'Análisis inteligente de tus preferencias',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Engagement Score
            engagementScoreAsync.when(
              data: (score) => _buildEngagementScore(context, score),
              loading: () => _buildLoadingCard('Calculando engagement...'),
              error: (error, stack) =>
                  _buildErrorCard('Error al calcular engagement'),
            ),

            const SizedBox(height: 16),

            // Behavior Analysis
            behaviorAnalysisAsync.when(
              data: (analysis) => _buildBehaviorAnalysis(context, analysis),
              loading: () => _buildLoadingCard('Analizando comportamiento...'),
              error: (error, stack) =>
                  _buildErrorCard('Error en análisis de comportamiento'),
            ),

            const SizedBox(height: 16),

            // Personalized Insights
            personalizedInsightsAsync.when(
              data: (insights) =>
                  _buildPersonalizedInsightsList(context, insights),
              loading: () => _buildLoadingCard('Generando insights...'),
              error: (error, stack) =>
                  _buildErrorCard('Error al generar insights'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementScore(BuildContext context, double score) {
    final percentage = (score * 100).round();
    final color = _getEngagementColor(score);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$percentage%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nivel de Engagement',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getEngagementDescription(score),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorAnalysis(
      BuildContext context, UserBehaviorAnalysis analysis) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Análisis de Comportamiento',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Patrones temporales
          _buildAnalysisItem(
            'Patrón de Visualización',
            _getTemporalPatternDescription(
              analysis.temporalPatterns.map((key, value) =>
                  MapEntry(key, (value as num?)?.toDouble() ?? 0.0)),
            ),
            Icons.schedule,
            Colors.blue,
          ),

          const SizedBox(height: 8),

          // Diversidad de géneros
          _buildAnalysisItem(
            'Diversidad de Géneros',
            '${(analysis.diversityScore * 100).round()}% de variedad',
            Icons.category,
            Colors.green,
          ),

          const SizedBox(height: 8),

          // Preferencia de calidad
          _buildAnalysisItem(
            'Preferencia de Calidad',
            _getQualityPreferenceDescription(analysis.trendFollowing *
                10), // Escalar para que esté en rango 0-10
            Icons.star,
            Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizedInsightsList(
      BuildContext context, List<UserInsight> insights) {
    if (insights.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.lightbulb_outlined,
              color: Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'No hay insights disponibles aún',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outlined,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Insights Personalizados',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildUserInsightItem(insight),
              )),
        ],
      ),
    );
  }

  Widget _buildUserInsightItem(UserInsight insight) {
    IconData icon;
    Color color;

    switch (insight.type) {
      case InsightType.genrePreference:
        icon = Icons.favorite;
        color = Colors.red;
        break;
      case InsightType.temporalPattern:
        icon = Icons.access_time;
        color = Colors.blue;
        break;
      case InsightType.diversity:
        icon = Icons.category;
        color = Colors.purple;
        break;
      case InsightType.qualityPreference:
        icon = Icons.star;
        color = Colors.amber;
        break;
      case InsightType.trendFollowing:
        icon = Icons.trending_up;
        color = Colors.orange;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                insight.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            insight.description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ),
        if (insight.actionable && insight.recommendation.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              insight.recommendation,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalysisItem(
      String title, String description, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getEngagementColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    if (score >= 0.4) return Colors.amber;
    return Colors.red;
  }

  String _getEngagementDescription(double score) {
    if (score >= 0.8) return 'Excelente engagement con la plataforma';
    if (score >= 0.6) return 'Buen nivel de actividad y diversidad';
    if (score >= 0.4) return 'Engagement moderado, hay potencial de mejora';
    return 'Engagement bajo, considera explorar más contenido';
  }

  String _getTemporalPatternDescription(Map<String, double> patterns) {
    if (patterns.isEmpty) return 'Sin patrones detectados';

    final maxEntry = patterns.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    switch (maxEntry.key) {
      case 'morning':
        return 'Prefieres ver películas por la mañana';
      case 'afternoon':
        return 'Eres más activo por las tardes';
      case 'evening':
        return 'Las noches son tu momento favorito';
      case 'weekend':
        return 'Los fines de semana son tu momento preferido';
      default:
        return 'Patrón de visualización variado';
    }
  }

  String _getQualityPreferenceDescription(double preference) {
    if (preference >= 8.0) return 'Prefieres películas de alta calidad';
    if (preference >= 7.0) return 'Te gustan las películas bien valoradas';
    if (preference >= 6.0) return 'Aceptas variedad en la calidad';
    return 'Eres abierto a todo tipo de contenido';
  }
}
