import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/movie_rating.dart';
import '../../services/movie_rating_service.dart';
import '../providers/auth_provider.dart';
import '../providers/movie_ratings_provider.dart';
import 'ratings/rating_slider_widget.dart';

/// Widget para calificar y reseñar una película
class MovieRatingWidget extends ConsumerStatefulWidget {
  const MovieRatingWidget({
    super.key,
    required this.movie,
    this.existingRating,
    this.onRatingSubmitted,
    this.showFullReviewForm = false,
  });
  final Movie movie;
  final MovieRating? existingRating;
  final VoidCallback? onRatingSubmitted;
  final bool showFullReviewForm;

  @override
  ConsumerState<MovieRatingWidget> createState() => _MovieRatingWidgetState();
}

class _MovieRatingWidgetState extends ConsumerState<MovieRatingWidget> {
  final TextEditingController _reviewController = TextEditingController();
  double _currentRating = 0.0;
  bool _containsSpoilers = false;
  bool _isSubmitting = false;
  bool _showReviewForm = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeFromExistingRating();
  }

  void _initializeFromExistingRating() {
    if (widget.existingRating != null) {
      _currentRating = widget.existingRating!.rating;
      _reviewController.text = widget.existingRating!.review ?? '';
      _containsSpoilers = widget.existingRating!.containsSpoilers;
      _showReviewForm =
          widget.existingRating!.hasReview || widget.showFullReviewForm;
    } else {
      _showReviewForm = widget.showFullReviewForm;
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_currentRating == 0.0) {
      setState(() {
        _errorMessage = 'Por favor selecciona una calificación';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (widget.existingRating != null) {
        // Actualizar calificación existente
        await MovieRatingService.instance.updateRating(
          ratingId: widget.existingRating!.id,
          userId: widget.existingRating!.userId,
          movieId: widget.movie.id,
          newRating: _currentRating,
          newReview: _reviewController.text.trim().isEmpty
              ? null
              : _reviewController.text.trim(),
          containsSpoilers: _containsSpoilers,
          repository: ref.read(movieRatingsRepositoryProvider),
        );
      } else {
        // Crear nueva calificación
        final currentUser = ref.read(currentUserProvider);
        await MovieRatingService.instance.submitRating(
          userId: currentUser?.id ?? 'anonymous',
          movieId: widget.movie.id,
          rating: _currentRating,
          review: _reviewController.text.trim().isEmpty
              ? null
              : _reviewController.text.trim(),
          containsSpoilers: _containsSpoilers,
          repository: ref.read(movieRatingsRepositoryProvider),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingRating != null
                  ? '✅ Calificación actualizada'
                  : '✅ Calificación guardada',
            ),
            backgroundColor: Colors.green,
          ),
        );

        widget.onRatingSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al guardar la calificación: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.existingRating != null
                      ? 'Tu calificación'
                      : 'Califica esta película',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Rating slider
            RatingSlider(
              rating: _currentRating,
              onChanged: (rating) {
                setState(() {
                  _currentRating = rating;
                  _errorMessage = null;
                });
              },
              compact: MediaQuery.of(context).size.width < 400,
            ),

            const SizedBox(height: 8),

            // Rating text
            if (_currentRating > 0) ...[
              Text(
                '${_currentRating.toStringAsFixed(1)}/10',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Review toggle
            if (!_showReviewForm && _currentRating > 0) ...[
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showReviewForm = true;
                  });
                },
                icon: const Icon(Icons.edit),
                label: const Text('Escribir reseña'),
              ),
              const SizedBox(height: 8),
            ],

            // Review form
            if (_showReviewForm) ...[
              Text(
                'Escribe tu reseña',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _reviewController,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: 'Comparte tu opinión sobre esta película...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  counterText: '${_reviewController.text.length}/1000',
                ),
                onChanged: (value) {
                  setState(() {}); // Para actualizar el contador
                },
              ),

              const SizedBox(height: 12),

              // Spoiler checkbox
              CheckboxListTile(
                value: _containsSpoilers,
                onChanged: (value) {
                  setState(() {
                    _containsSpoilers = value ?? false;
                  });
                },
                title: const Text('Contiene spoilers'),
                subtitle: const Text(
                    'Marca si tu reseña revela detalles importantes'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 16),

              // Review form controls
              Row(
                children: [
                  if (_showReviewForm && !widget.showFullReviewForm)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showReviewForm = false;
                          _reviewController.clear();
                          _containsSpoilers = false;
                        });
                      },
                      child: const Text('Cancelar reseña'),
                    ),
                  const Spacer(),
                ],
              ),
            ],

            // Error message
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.existingRating != null
                            ? 'Actualizar calificación'
                            : 'Guardar calificación',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget para mostrar reseñas de otros usuarios
class MovieReviewsWidget extends ConsumerStatefulWidget {
  const MovieReviewsWidget({
    super.key,
    required this.movie,
    this.maxReviews = 5,
  });
  final Movie movie;
  final int maxReviews;

  @override
  ConsumerState<MovieReviewsWidget> createState() => _MovieReviewsWidgetState();
}

class _MovieReviewsWidgetState extends ConsumerState<MovieReviewsWidget> {
  List<MovieRating> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final repository = ref.read(movieRatingsRepositoryProvider);
      final reviews = await MovieRatingService.instance.getFeaturedReviews(
        movieId: widget.movie.id,
        repository: repository,
        limit: widget.maxReviews,
      );

      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar reseñas: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(_errorMessage!),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadReviews,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_reviews.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.rate_review, color: Colors.grey, size: 48),
              SizedBox(height: 16),
              Text(
                'Aún no hay reseñas para esta película',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                '¡Sé el primero en escribir una reseña!',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.reviews, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Reseñas destacadas (${_reviews.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _reviews.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final review = _reviews[index];
            return _ReviewItem(
              rating: review,
              onHelpfulPressed: (isHelpful) {
                _markReviewHelpful(review, isHelpful);
              },
              onReportPressed: (ratingId) {
                _showReportDialog(context, ratingId);
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _markReviewHelpful(MovieRating rating, bool isHelpful) async {
    try {
      final currentUser = ref.read(currentUserProvider);
      await MovieRatingService.instance.markReviewHelpfulness(
        ratingId: rating.id,
        isHelpful: isHelpful,
        currentUserId: currentUser?.id ?? 'anonymous',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHelpful ? '👍 Marcada como útil' : '👎 Marcada como no útil',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Muestra el dialog para reportar una reseña
  void _showReportDialog(BuildContext context, String ratingId) {
    final reportReasons = [
      'Contenido ofensivo o inapropiado',
      'Spam o contenido promocional',
      'Información falsa o engañosa',
      'Violencia o discurso de odio',
      'Contenido sexual explícito',
      'Otro motivo',
    ];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reportar reseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Por qué quieres reportar esta reseña?'),
              const SizedBox(height: 16),
              ...reportReasons.map(
                (reason) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(reason),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _submitReport(ratingId, reason);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  /// Envía el reporte al servicio
  Future<void> _submitReport(String ratingId, String reason) async {
    final user = ref.read(currentUserProvider);
    final userId = user?.id ?? 'anonymous';
    try {
      await MovieRatingService.instance.reportReview(
        ratingId: ratingId,
        reason: reason,
        reporterUserId: userId,
      );
      await LoggerFactory.info(
        'Reporte enviado',
        data: {
          'ratingId': ratingId,
          'reason': reason,
          'reporterUserId': userId,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte enviado. Gracias por tu colaboración.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, st) {
      await LoggerFactory.error(
        'Error al enviar el reporte',
        data: {
          'ratingId': ratingId,
          'reason': reason,
          'reporterUserId': userId,
          'error': e.toString(),
        },
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al enviar el reporte. Inténtalo de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({
    required this.rating,
    required this.onHelpfulPressed,
    required this.onReportPressed,
  });
  final MovieRating rating;
  final Function(bool isHelpful) onHelpfulPressed;
  final Function(String ratingId) onReportPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating and user info
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  rating.userId.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CompactRatingDisplay(
                      rating: rating.rating,
                      size: 16,
                    ),
                    Text(
                      'Usuario ${rating.userId.substring(0, 8)}...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(rating.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Spoiler warning
          if (rating.containsSpoilers) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Contiene spoilers',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Review text
          if (rating.hasReview) ...[
            Text(
              rating.review!,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
          ],

          // Helpful buttons
          Row(
            children: [
              TextButton.icon(
                onPressed: () => onHelpfulPressed(true),
                icon: const Icon(Icons.thumb_up, size: 16),
                label: Text('Útil (${rating.likesCount})'),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),

              TextButton.icon(
                onPressed: () => onHelpfulPressed(false),
                icon: const Icon(Icons.thumb_down, size: 16),
                label: Text('No útil (${rating.dislikesCount})'),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),

              const Spacer(),

              // Report button
              TextButton(
                onPressed: () => onReportPressed(rating.id),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  foregroundColor: Colors.grey,
                ),
                child: const Text('Reportar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Hace ${difference.inMinutes} min';
      }
      return 'Hace ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Hace $weeks semana${weeks > 1 ? 's' : ''}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Hace $months mes${months > 1 ? 'es' : ''}';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Hace $years año${years > 1 ? 's' : ''}';
    }
  }
}
