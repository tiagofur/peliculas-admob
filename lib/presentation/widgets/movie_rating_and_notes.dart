import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/movie.dart';
import '../../domain/entities/user_movie_rating.dart';
import '../providers/user_movie_ratings_provider.dart';
import '../providers/auth_provider.dart';
import 'star_rating_widgets.dart';

class MovieRatingAndNotes extends ConsumerStatefulWidget {
  const MovieRatingAndNotes({
    super.key,
    required this.movie,
    this.onRatingChanged,
  });

  final Movie movie;
  final VoidCallback? onRatingChanged;

  @override
  ConsumerState<MovieRatingAndNotes> createState() => _MovieRatingAndNotesState();
}

class _MovieRatingAndNotesState extends ConsumerState<MovieRatingAndNotes> {
  final TextEditingController _notesController = TextEditingController();
  int _currentRating = 0;
  bool _isLoading = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadExistingRating();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingRating() async {
    final existingRating = await ref.read(movieRatingProvider(widget.movie.id).future);
    if (existingRating != null && mounted) {
      setState(() {
        _currentRating = existingRating.rating;
        _notesController.text = existingRating.personalNote ?? '';
        _isExpanded = existingRating.personalNote?.isNotEmpty == true;
      });
    }
  }

  Future<void> _saveRating() async {
    if (_currentRating == 0) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final rating = UserMovieRating(
        id: '', // Will be set by the repository
        userId: '', // Will be set by the repository
        movieId: widget.movie.id,
        movieTitle: widget.movie.title,
        moviePosterPath: widget.movie.posterPath,
        rating: _currentRating,
        personalNote: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(userRatingsProvider.notifier).saveRating(rating);
      
      // Invalidar el provider específico para actualizar la UI
      ref.invalidate(movieRatingProvider(widget.movie.id));
      
      widget.onRatingChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Valoración guardada'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRating() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(userRatingsProvider.notifier).deleteRating(widget.movie.id);
      
      // Invalidar el provider específico para actualizar la UI
      ref.invalidate(movieRatingProvider(widget.movie.id));
      
      widget.onRatingChanged?.call();

      if (mounted) {
        setState(() {
          _currentRating = 0;
          _notesController.clear();
          _isExpanded = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Valoración eliminada'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar valoración'),
        content: const Text('¿Estás seguro de que quieres eliminar tu valoración de esta película?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteRating();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = ref.watch(appStateProvider);
    
    // Show login prompt for guest users
    if (!appState.isAuthenticated) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.star_outline,
                size: 48,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Inicia sesión para valorar películas',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Crea una cuenta gratuita para guardar tus valoraciones y notas personales.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // TODO: Navigate to login screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Función de login en desarrollo')),
                  );
                },
                child: const Text('Iniciar Sesión'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tu valoración',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_currentRating > 0 && !_isLoading)
                  IconButton(
                    onPressed: _showDeleteConfirmation,
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    tooltip: 'Eliminar valoración',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Rating stars
            Center(
              child: InteractiveStarRating(
                initialRating: _currentRating,
                onRatingChanged: (rating) {
                  setState(() {
                    _currentRating = rating;
                  });
                },
                enabled: !_isLoading,
                size: 40,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Notes section
            Row(
              children: [
                Text(
                  'Nota personal (opcional)',
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(_isExpanded ? 'Ocultar' : 'Agregar nota'),
                ),
              ],
            ),
            
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _notesController,
                  maxLines: 3,
                  maxLength: 500,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: 'Escribe tus pensamientos sobre esta película...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              crossFadeState: _isExpanded
                  ? CrossFadeState.secondChild
                  : CrossFadeState.firstChild,
            ),
            
            const SizedBox(height: 16),
            
            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _currentRating > 0 && !_isLoading ? _saveRating : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar valoración'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MovieRatingDisplayCard extends ConsumerWidget {
  const MovieRatingDisplayCard({
    super.key,
    required this.movieId,
    this.showNotes = true,
  });

  final int movieId;
  final bool showNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingAsync = ref.watch(movieRatingProvider(movieId));
    final theme = Theme.of(context);

    return ratingAsync.when(
      data: (rating) {
        if (rating == null) return const SizedBox.shrink();
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tu valoración',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    StarRatingDisplay(
                      rating: rating.rating,
                      size: 18,
                      showValue: true,
                    ),
                  ],
                ),
                if (showNotes && rating.personalNote?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rating.personalNote!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Valorado el ${rating.createdAt.day}/${rating.createdAt.month}/${rating.createdAt.year}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}