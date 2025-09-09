import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/movie.dart';
import '../../../domain/entities/syncable_movie_rating.dart';
import '../../providers/movie_ratings_provider.dart';
import 'star_rating_widget.dart';

/// Diálogo para calificar una película
class RatingDialog extends ConsumerStatefulWidget {
  const RatingDialog({
    super.key,
    required this.movie,
    this.existingRating,
  });

  final Movie movie;
  final SyncableMovieRating? existingRating;

  @override
  ConsumerState<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends ConsumerState<RatingDialog> {
  late double _rating;
  late TextEditingController _reviewController;
  late bool _isPublic;
  late List<String> _tags;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Inicializar con valores existentes o valores por defecto
    _rating = widget.existingRating?.rating ?? 5.0;
    _reviewController = TextEditingController(
      text: widget.existingRating?.review ?? '',
    );
    _isPublic = widget.existingRating?.isPublic ?? false;
    _tags = widget.existingRating?.tags.toList() ?? [];
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildRatingSection(),
            const SizedBox(height: 24),
            _buildReviewSection(),
            const SizedBox(height: 16),
            _buildOptionsSection(),
            const SizedBox(height: 24),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.existingRating != null ? 'Edit Rating' : 'Rate Movie',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.movie.title,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      children: [
        Text(
          'Your Rating',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        StarRatingWidget(
          rating: _rating / 2, // Convert to 5-star scale for display
          size: 40,
          onRatingChanged: (starRating) {
            setState(() {
              _rating = starRating * 2; // Convert back to 10-point scale
            });
          },
        ),
        const SizedBox(height: 8),
        Text(
          '${_rating.toStringAsFixed(1)}/10.0',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _rating,
          min: 1.0,
          max: 10.0,
          divisions: 18, // Allow 0.5 increments
          label: _rating.toStringAsFixed(1),
          onChanged: (value) {
            setState(() {
              _rating = value;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1.0', style: Theme.of(context).textTheme.bodySmall),
            Text('10.0', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review (Optional)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reviewController,
          decoration: const InputDecoration(
            hintText: 'Share your thoughts about this movie...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          maxLength: 500,
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Make this rating public'),
          subtitle: const Text('Other users can see your rating and review'),
          value: _isPublic,
          onChanged: (value) {
            setState(() {
              _isPublic = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        if (widget.existingRating != null)
          TextButton(
            onPressed: _isSubmitting ? null : _handleDelete,
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        const Spacer(),
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.existingRating != null ? 'Update' : 'Rate'),
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final notifier = ref.read(movieRatingsProvider.notifier);
      bool success = false;

      if (widget.existingRating != null) {
        // Actualizar calificación existente
        success = await notifier.updateRating(
          movieId: widget.movie.id,
          rating: _rating,
          review: _reviewController.text.trim().isEmpty
              ? null
              : _reviewController.text.trim(),
          isPublic: _isPublic,
          tags: _tags,
        );
      } else {
        // Crear nueva calificación
        success = await notifier.rateMovie(
          movie: widget.movie,
          rating: _rating,
          review: _reviewController.text.trim().isEmpty
              ? null
              : _reviewController.text.trim(),
          isPublic: _isPublic,
          tags: _tags,
        );
      }

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingRating != null
                  ? 'Rating updated successfully!'
                  : 'Movie rated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    if (_isSubmitting || widget.existingRating == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rating'),
        content: const Text('Are you sure you want to delete this rating?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final notifier = ref.read(movieRatingsProvider.notifier);
      final success = await notifier.removeRating(widget.movie.id);

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

/// Diálogo simplificado para calificación rápida
class QuickRatingDialog extends ConsumerStatefulWidget {
  const QuickRatingDialog({
    super.key,
    required this.movie,
  });

  final Movie movie;

  @override
  ConsumerState<QuickRatingDialog> createState() => _QuickRatingDialogState();
}

class _QuickRatingDialogState extends ConsumerState<QuickRatingDialog> {
  double _rating = 5.0;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rate "${widget.movie.title}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarRatingWidget(
            rating: _rating / 2, // Convert to 5-star scale
            size: 32,
            onRatingChanged: (starRating) {
              setState(() {
                _rating = starRating * 2; // Convert back to 10-point scale
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${_rating.toStringAsFixed(1)}/10.0',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleQuickRate,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Rate'),
        ),
      ],
    );
  }

  Future<void> _handleQuickRate() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final notifier = ref.read(movieRatingsProvider.notifier);
      final success = await notifier.rateMovie(
        movie: widget.movie,
        rating: _rating,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Movie rated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to rate movie: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
