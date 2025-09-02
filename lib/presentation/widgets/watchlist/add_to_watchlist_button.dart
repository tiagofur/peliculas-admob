import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/watchlist_movie.dart';
import '../../providers/watchlist_provider.dart';

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
  ConsumerState<AddToWatchlistButton> createState() => _AddToWatchlistButtonState();
}

class _AddToWatchlistButtonState extends ConsumerState<AddToWatchlistButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isInWatchlist = ref.watch(isMovieInWatchlistProvider(widget.movie.id));
    final theme = Theme.of(context);

    return isInWatchlist.when(
      data: (inWatchlist) {
        if (widget.isIconButton) {
          return IconButton(
            onPressed: _isLoading ? null : () => _handleWatchlistAction(inWatchlist),
            icon: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    inWatchlist ? Icons.bookmark : Icons.bookmark_border,
                    color: inWatchlist ? theme.primaryColor : null,
                  ),
            tooltip: inWatchlist ? 'Remover de watchlist' : 'Agregar a watchlist',
          );
        }

        return ElevatedButton.icon(
          onPressed: _isLoading ? null : () => _handleWatchlistAction(inWatchlist),
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  inWatchlist ? Icons.bookmark : Icons.bookmark_border,
                  size: 20,
                ),
          label: widget.showLabel 
              ? Text(inWatchlist ? 'En Watchlist' : 'Agregar a Watchlist')
              : const SizedBox.shrink(),
          style: ElevatedButton.styleFrom(
            backgroundColor: inWatchlist ? theme.primaryColor : null,
            foregroundColor: inWatchlist ? Colors.white : null,
          ),
        );
      },
      loading: () => widget.isIconButton
          ? const IconButton(
              onPressed: null,
              icon: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : ElevatedButton.icon(
              onPressed: null,
              icon: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: widget.showLabel 
                  ? const Text('Cargando...')
                  : const SizedBox.shrink(),
            ),
      error: (_, __) => widget.isIconButton
          ? IconButton(
              onPressed: () => _handleWatchlistAction(false),
              icon: const Icon(Icons.bookmark_border),
              tooltip: 'Agregar a watchlist',
            )
          : ElevatedButton.icon(
              onPressed: () => _handleWatchlistAction(false),
              icon: const Icon(Icons.bookmark_border, size: 20),
              label: widget.showLabel 
                  ? const Text('Agregar a Watchlist')
                  : const SizedBox.shrink(),
            ),
    );
  }

  Future<void> _handleWatchlistAction(bool isCurrentlyInWatchlist) async {
    if (isCurrentlyInWatchlist) {
      await _removeFromWatchlist();
    } else {
      await _showAddToWatchlistDialog();
    }
  }

  Future<void> _removeFromWatchlist() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(watchlistProvider.notifier).removeFromWatchlist(widget.movie.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.movie.title} removida de watchlist'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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

  Future<void> _showAddToWatchlistDialog() async {
    final result = await showDialog<WatchlistPriority>(
      context: context,
      builder: (context) => _AddToWatchlistDialog(movie: widget.movie),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        await ref.read(watchlistProvider.notifier).addToWatchlist(widget.movie, result);
        
        // Track analytics event for add to watchlist
        await AnalyticsService().trackEvent(
          AnalyticsEventType.addWatchlist,
          {
            'movie_id': widget.movie.id,
            'movie_title': widget.movie.title,
            'priority': result.name,
            'action': 'add_to_watchlist',
          },
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.movie.title} agregada a watchlist con ${result.displayName.toLowerCase()} prioridad'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
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
        return RadioListTile<WatchlistPriority>(
          value: priority,
          groupValue: _selectedPriority,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedPriority = value;
              });
            }
          },
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
        return Colors.orange;
      case WatchlistPriority.baja:
        return Colors.green;
    }
  }
}