import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../models/rating_helpfulness.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../services/movie_rating_service.dart';

/// Widget para votar sobre la utilidad de una reseña
class ReviewHelpfulnessVoting extends ConsumerStatefulWidget {
  const ReviewHelpfulnessVoting({
    super.key,
    required this.reviewId,
    this.initialStats,
    this.userVote,
    this.onVoteChanged,
  });
  final String reviewId;
  final RatingHelpfulnessStats? initialStats;
  final RatingHelpfulnessVote? userVote;
  final VoidCallback? onVoteChanged;

  @override
  ConsumerState<ReviewHelpfulnessVoting> createState() =>
      _ReviewHelpfulnessVotingState();
}

class _ReviewHelpfulnessVotingState
    extends ConsumerState<ReviewHelpfulnessVoting> {
  bool _isLoading = false;
  RatingHelpfulnessStats? _stats;
  RatingHelpfulnessVote? _userVote;

  @override
  void initState() {
    super.initState();
    _stats = widget.initialStats;
    _userVote = widget.userVote;
  }

  Future<void> _handleVote(bool isHelpful) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      LoggerFactory.warning('Usuario no autenticado para votar');
      _showLoginSnackBar();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      LoggerFactory.info('Enviando voto de utilidad: isHelpful=$isHelpful');

      // Enviar voto
      final newVote = await MovieRatingService.instance.markReviewHelpfulness(
        ratingId: widget.reviewId,
        isHelpful: isHelpful,
        currentUserId: user.id,
      );

      // Obtener estadísticas actualizadas
      final updatedStats = await MovieRatingService.instance
          .getReviewHelpfulnessStats(ratingId: widget.reviewId);

      setState(() {
        _userVote = newVote;
        _stats = updatedStats;
        _isLoading = false;
      });

      widget.onVoteChanged?.call();

      _showSuccessSnackBar(isHelpful);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      LoggerFactory.error('Error al enviar voto de utilidad: $e');
      _showErrorSnackBar();
    }
  }

  void _showLoginSnackBar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para votar'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showSuccessSnackBar(bool isHelpful) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHelpful ? '¡Marcado como útil!' : 'Marcado como no útil',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showErrorSnackBar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al votar. Inténtalo de nuevo.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botones de votación
        Row(
          children: [
            // Botón "Útil"
            _buildVoteButton(
              icon: Icons.thumb_up_outlined,
              label: 'Útil',
              isSelected: _userVote?.isHelpful == true,
              onPressed: _isLoading ? null : () => _handleVote(true),
              selectedColor: Colors.green,
            ),
            const SizedBox(width: 8),
            // Botón "No útil"
            _buildVoteButton(
              icon: Icons.thumb_down_outlined,
              label: 'No útil',
              isSelected: _userVote?.isHelpful == false,
              onPressed: _isLoading ? null : () => _handleVote(false),
              selectedColor: Colors.red,
            ),
            if (_isLoading) ...[
              const SizedBox(width: 12),
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),

        // Estadísticas de votos
        if (_stats != null && _stats!.totalVotes > 0) ...[
          const SizedBox(height: 8),
          _buildStatsDisplay(),
        ],

        // Mensaje si no hay usuario autenticado
        if (user == null) ...[
          const SizedBox(height: 8),
          Text(
            'Inicia sesión para votar sobre la utilidad de esta reseña',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVoteButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback? onPressed,
    required Color selectedColor,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? selectedColor
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(20),
            color: isSelected ? selectedColor.withValues(alpha: 0.1) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected
                    ? (icon == Icons.thumb_up_outlined
                        ? Icons.thumb_up
                        : Icons.thumb_down)
                    : icon,
                size: 16,
                color: isSelected
                    ? selectedColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? selectedColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsDisplay() {
    final theme = Theme.of(context);
    final stats = _stats!;

    return Row(
      children: [
        // Contador de votos útiles
        if (stats.helpfulVotes > 0) ...[
          Icon(
            Icons.thumb_up,
            size: 14,
            color: Colors.green.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 2),
          Text(
            '${stats.helpfulVotes}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.green.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],

        if (stats.helpfulVotes > 0 && stats.notHelpfulVotes > 0) ...[
          const SizedBox(width: 8),
          Text(
            '•',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Contador de votos no útiles
        if (stats.notHelpfulVotes > 0) ...[
          Icon(
            Icons.thumb_down,
            size: 14,
            color: Colors.red.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 2),
          Text(
            '${stats.notHelpfulVotes}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.red.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],

        // Score de utilidad si hay suficientes votos
        if (stats.hasSignificantVotes) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: stats.isMostlyHelpful
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              stats.helpfulnessDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: stats.isMostlyHelpful
                    ? Colors.green.withValues(alpha: 0.8)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
