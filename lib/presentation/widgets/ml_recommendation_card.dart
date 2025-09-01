import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ml/ml_recommendation_service.dart';
import '../../core/ml/recommendation_feedback_service.dart';
import '../../domain/entities/recommendation.dart';
import '../providers/recommendations/recommendations_provider.dart';

class MLRecommendationCard extends ConsumerStatefulWidget {
  const MLRecommendationCard({
    super.key,
    required this.recommendation,
    this.onTap,
    this.showExplanation = true,
    this.showFeedback = true,
  });
  final Recommendation recommendation;
  final VoidCallback? onTap;
  final bool showExplanation;
  final bool showFeedback;

  @override
  ConsumerState<MLRecommendationCard> createState() =>
      _MLRecommendationCardState();
}

class _MLRecommendationCardState extends ConsumerState<MLRecommendationCard> {
  bool _showExplanation = false;
  bool _feedbackGiven = false;

  @override
  Widget build(BuildContext context) {
    final explanationAsync =
        ref.watch(recommendationExplanationProvider(widget.recommendation));

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con imagen y título
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                image: DecorationImage(
                  image: NetworkImage(
                    'https://image.tmdb.org/t/p/w500${widget.recommendation.posterPath}',
                  ),
                  fit: BoxFit.cover,
                ),
                color: Colors.grey[300],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.recommendation.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(widget.recommendation.score * 10).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getTypeColor(widget.recommendation.type),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getTypeLabel(widget.recommendation.type),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Contenido principal
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Razón de la recomendación
                  if (widget.recommendation.reason.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.recommendation.reason,
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Tags
                  if (widget.recommendation.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.recommendation.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Botones de acción
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Botón de explicación
                      if (widget.showExplanation)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showExplanation = !_showExplanation;
                              });
                            },
                            icon: Icon(
                              _showExplanation
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                            ),
                            label: Text(
                              _showExplanation ? 'Ocultar' : 'Explicación',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),

                      if (widget.showExplanation && widget.showFeedback)
                        const SizedBox(width: 8),

                      // Botones de feedback
                      if (widget.showFeedback && !_feedbackGiven) ...[
                        IconButton(
                          onPressed: () => _giveFeedback(true),
                          icon: const Icon(Icons.thumb_up_outlined),
                          iconSize: 20,
                          color: Colors.green,
                          tooltip: 'Me gusta',
                        ),
                        IconButton(
                          onPressed: () => _giveFeedback(false),
                          icon: const Icon(Icons.thumb_down_outlined),
                          iconSize: 20,
                          color: Colors.red,
                          tooltip: 'No me gusta',
                        ),
                      ] else if (_feedbackGiven) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Feedback enviado',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Explicación expandible
                  if (_showExplanation && widget.showExplanation) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey[300]!,
                        ),
                      ),
                      child: explanationAsync.when(
                        data: (explanation) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.psychology_outlined,
                                  color: Colors.purple,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Explicación ML',
                                  style: TextStyle(
                                    color: Colors.purple[800],
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              explanation,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (error, stack) => Text(
                          'Error al cargar explicación: $error',
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.basedOnFavorites:
        return Colors.red;
      case RecommendationType.trending:
        return Colors.orange;
      case RecommendationType.forYou:
        return Colors.blue;
      case RecommendationType.mood:
        return Colors.purple;
      case RecommendationType.similar:
        return Colors.green;
      case RecommendationType.basedOnWatched:
        return Colors.teal;
      case RecommendationType.basedOnGenre:
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(RecommendationType type) {
    switch (type) {
      case RecommendationType.basedOnFavorites:
        return 'Favoritos';
      case RecommendationType.trending:
        return 'Tendencia';
      case RecommendationType.forYou:
        return 'Para Ti';
      case RecommendationType.mood:
        return 'Estado';
      case RecommendationType.similar:
        return 'Similar';
      case RecommendationType.basedOnWatched:
        return 'Basado en Vistos';
      case RecommendationType.basedOnGenre:
        return 'Por Género';
      default:
        return 'Recomendado';
    }
  }

  Future<void> _giveFeedback(bool isPositive) async {
    try {
      final feedbackService = RecommendationFeedbackService.instance;
      await feedbackService.processFeedback(
        movieId: widget.recommendation.movieId,
        movieTitle: widget.recommendation.title,
        feedbackType: isPositive ? FeedbackType.like : FeedbackType.dislike,
        userId: 1, // En implementación real, obtener del contexto
      );

      setState(() {
        _feedbackGiven = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPositive
                  ? '¡Gracias! Esto nos ayuda a mejorar las recomendaciones'
                  : 'Gracias por el feedback. Mejoraremos las recomendaciones',
            ),
            backgroundColor: isPositive ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
