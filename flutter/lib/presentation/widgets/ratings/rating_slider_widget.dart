import 'package:flutter/material.dart';

/// Widget de slider para valoración de películas (1.0 - 10.0)
/// Consistente con la escala de TMDB, sin conversiones
class RatingSlider extends StatelessWidget {
  const RatingSlider({
    super.key,
    required this.rating,
    this.onChanged,
    this.readonly = false,
    this.showLabels = true,
    this.compact = false,
  });

  final double rating;
  final ValueChanged<double>? onChanged;
  final bool readonly;
  final bool showLabels;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main display - Rating number with star
        Container(
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: _getRatingColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getRatingColor().withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star,
                color: _getRatingColor(),
                size: compact ? 24 : 32,
              ),
              const SizedBox(width: 8),
              Text(
                rating.toStringAsFixed(1),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getRatingColor(),
                  fontSize: compact ? 24 : 32,
                ),
              ),
              Text(
                '/10',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: compact ? 16 : 20,
                ),
              ),
            ],
          ),
        ),

        // Rating label (Excelente, Buena, etc.)
        if (showLabels) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getRatingColor().withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getRatingLabel(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: _getRatingColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],

        // Slider (if not readonly)
        if (!readonly && onChanged != null) ...[
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _getRatingColor(),
              inactiveTrackColor: _getRatingColor().withValues(alpha: 0.2),
              thumbColor: _getRatingColor(),
              overlayColor: _getRatingColor().withValues(alpha: 0.2),
              valueIndicatorColor: _getRatingColor(),
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Slider(
              value: rating,
              min: 1.0,
              max: 10.0,
              divisions: 18, // 0.5 increments (1.0, 1.5, 2.0... 10.0)
              label: '${rating.toStringAsFixed(1)}/10',
              onChanged: onChanged,
            ),
          ),

          // Min/Max labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '10.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Progress bar (visual indicator)
        if (!compact) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rating / 10.0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: _getRatingColor(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(rating * 10).toStringAsFixed(0)}% rating',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  /// Get color based on rating value
  Color _getRatingColor() {
    if (rating >= 9.0) return Colors.green.shade700;
    if (rating >= 8.0) return Colors.green;
    if (rating >= 7.0) return Colors.lightGreen;
    if (rating >= 6.0) return Colors.lime.shade700;
    if (rating >= 5.0) return Colors.orange;
    if (rating >= 4.0) return Colors.deepOrange;
    if (rating >= 3.0) return Colors.red.shade600;
    return Colors.red.shade800;
  }

  /// Get descriptive label based on rating
  String _getRatingLabel() {
    if (rating >= 9.5) return 'Obra Maestra';
    if (rating >= 9.0) return 'Sobresaliente';
    if (rating >= 8.0) return 'Excelente';
    if (rating >= 7.0) return 'Muy Buena';
    if (rating >= 6.0) return 'Buena';
    if (rating >= 5.0) return 'Regular';
    if (rating >= 4.0) return 'Mediocre';
    if (rating >= 3.0) return 'Mala';
    if (rating >= 2.0) return 'Muy Mala';
    return 'Terrible';
  }
}

/// Widget compacto para mostrar rating en listas y cards
class CompactRatingDisplay extends StatelessWidget {
  const CompactRatingDisplay({
    super.key,
    required this.rating,
    this.size = 16.0,
    this.showLabel = true,
    this.showBackground = false,
  });

  final double rating;
  final double size;
  final bool showLabel;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star,
          color: Colors.amber.shade700,
          size: size,
        ),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: size * 0.9,
            fontWeight: FontWeight.bold,
            color: showBackground ? Colors.white : null,
          ),
        ),
        if (showLabel) ...[
          Text(
            '/10',
            style: TextStyle(
              fontSize: size * 0.7,
              color: showBackground ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );

    if (showBackground) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getRatingColor(),
          borderRadius: BorderRadius.circular(12),
        ),
        child: content,
      );
    }

    return content;
  }

  Color _getRatingColor() {
    if (rating >= 8.0) return Colors.green;
    if (rating >= 7.0) return Colors.lightGreen;
    if (rating >= 6.0) return Colors.lime.shade700;
    if (rating >= 5.0) return Colors.orange;
    return Colors.deepOrange;
  }
}

/// Widget para mostrar rating con barra de progreso horizontal
class RatingBarDisplay extends StatelessWidget {
  const RatingBarDisplay({
    super.key,
    required this.rating,
    this.width = 100.0,
    this.height = 8.0,
    this.showValue = true,
  });

  final double rating;
  final double width;
  final double height;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star,
          color: Colors.amber.shade700,
          size: 16,
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: LinearProgressIndicator(
              value: rating / 10.0,
              minHeight: height,
              backgroundColor: Colors.grey.shade300,
              color: _getRatingColor(),
            ),
          ),
        ),
        if (showValue) ...[
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Color _getRatingColor() {
    if (rating >= 8.0) return Colors.green;
    if (rating >= 7.0) return Colors.lightGreen;
    if (rating >= 6.0) return Colors.lime.shade700;
    if (rating >= 5.0) return Colors.orange;
    return Colors.deepOrange;
  }
}
