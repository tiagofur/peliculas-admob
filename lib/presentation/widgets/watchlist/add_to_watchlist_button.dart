import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/watchlist_movie.dart';
import '../../providers/storage/direct_watchlist_provider.dart';

class AddToWatchlistButton extends ConsumerStatefulWidget {
  const AddToWatchlistButton({
    super.key,
    required this.movie,
    this.isIconButton = false,
    this.showLabel = true,
  });

  final Movie movie;
  final bool isIconButton;
  final bool showLabel;

  @override
  ConsumerState<AddToWatchlistButton> createState() =>
      _AddToWatchlistButtonState();
}

class _AddToWatchlistButtonState extends ConsumerState<AddToWatchlistButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final directWatchlistMovies = ref.watch(directWatchlistMoviesProvider);
    final isInWatchlist = directWatchlistMovies.containsKey(widget.movie.id);
    final watchlistMovie = directWatchlistMovies[widget.movie.id];

    // Get priority color if movie is in watchlist
    Color? iconColor;
    Color? backgroundColor;
    if (isInWatchlist && watchlistMovie != null) {
      // Usar color específico según la prioridad
      iconColor = _getPriorityColor(watchlistMovie.priority);
      backgroundColor = iconColor;
    } else if (isInWatchlist) {
      // Fallback si está en watchlist pero no hay información de prioridad
      iconColor = Colors.yellow; // Color por defecto para prioridad normal
      backgroundColor = Colors.yellow;
    } else {
      // NO está en watchlist - usar color blanco con contorno
      iconColor = Colors.white;
      backgroundColor = null;
    }

    if (widget.isIconButton) {
      return IconButton(
        onPressed:
            _isLoading ? null : () => _handleWatchlistAction(isInWatchlist),
        icon: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
                color: iconColor,
              ),
        tooltip: isInWatchlist ? 'Remover de watchlist' : 'Agregar a watchlist',
      );
    }

    return ElevatedButton.icon(
      onPressed:
          _isLoading ? null : () => _handleWatchlistAction(isInWatchlist),
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
              size: 20,
            ),
      label: widget.showLabel
          ? Text(isInWatchlist ? 'En Watchlist' : 'Agregar a Watchlist')
          : const SizedBox.shrink(),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: isInWatchlist ? Colors.white : null,
      ),
    );
  }

  Future<void> _handleWatchlistAction(bool isCurrentlyInWatchlist) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (isCurrentlyInWatchlist) {
        // Use direct provider for real-time sync
        await ref
            .read(directWatchlistMoviesProvider.notifier)
            .toggleWatchlist(widget.movie);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.movie.title} removida de watchlist'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Show dialog to get priority, then toggle to add
        final priority = await showDialog<WatchlistPriority>(
          context: context,
          builder: (context) => _AddToWatchlistDialog(movie: widget.movie),
        );

        if (priority != null) {
          // Use direct provider for real-time sync
          await ref
              .read(directWatchlistMoviesProvider.notifier)
              .toggleWatchlist(widget.movie, priority: priority);

          // Track analytics event for add to watchlist
          await AnalyticsService().trackEvent(
            AnalyticsEventType.addWatchlist,
            {
              'movie_id': widget.movie.id,
              'movie_title': widget.movie.title,
              'priority': priority.name,
              'action': 'add_to_watchlist',
            },
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${widget.movie.title} agregada a watchlist con ${priority.displayName.toLowerCase()} prioridad'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class _AddToWatchlistDialog extends StatefulWidget {
  const _AddToWatchlistDialog({required this.movie});

  final Movie movie;

  @override
  State<_AddToWatchlistDialog> createState() => _AddToWatchlistDialogState();
}

class _AddToWatchlistDialogState extends State<_AddToWatchlistDialog> {
  WatchlistPriority _selectedPriority = WatchlistPriority.normal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Agregar a Watchlist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Película: ${widget.movie.title}',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Selecciona la prioridad:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _buildPriorityOptions(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedPriority),
          child: const Text('Agregar'),
        ),
      ],
    );
  }

  Widget _buildPriorityOptions() {
    return Column(
      children: WatchlistPriority.values.map((priority) {
        return ListTile(
          leading: Radio<WatchlistPriority>(
            value: priority,
            groupValue: _selectedPriority,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedPriority = value;
                });
              }
            },
          ),
          title: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getPriorityColor(priority),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(priority.displayName),
            ],
          ),
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }

  Color _getPriorityColor(WatchlistPriority priority) {
    switch (priority) {
      case WatchlistPriority.alta:
        return Colors.red;
      case WatchlistPriority.normal:
        return Colors.yellow;
      case WatchlistPriority.baja:
        return Colors.green;
    }
  }
}

// Helper function for priority colors
Color _getPriorityColor(WatchlistPriority priority) {
  switch (priority) {
    case WatchlistPriority.alta:
      return Colors.red;
    case WatchlistPriority.normal:
      return Colors.yellow;
    case WatchlistPriority.baja:
      return Colors.green;
  }
}
