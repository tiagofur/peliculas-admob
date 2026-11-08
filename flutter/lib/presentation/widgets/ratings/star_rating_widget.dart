import 'package:flutter/material.dart';

/// Widget para mostrar y seleccionar calificaciones con estrellas
class StarRatingWidget extends StatefulWidget {
  const StarRatingWidget({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.size = 24.0,
    this.readonly = false,
    this.color = Colors.amber,
    this.borderColor,
    this.allowHalfRating = true,
  });

  final double rating;
  final ValueChanged<double>? onRatingChanged;
  final double size;
  final bool readonly;
  final Color color;
  final Color? borderColor;
  final bool allowHalfRating;

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  late double _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.rating;
  }

  @override
  void didUpdateWidget(StarRatingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rating != oldWidget.rating) {
      _currentRating = widget.rating;
    }
  }

  void _handleTap(double rating) {
    if (widget.readonly) return;

    setState(() {
      _currentRating = rating;
    });

    widget.onRatingChanged?.call(rating);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ MOBILE OPTIMIZATION: Responsive star spacing

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starRating = (index + 1).toDouble();
        return GestureDetector(
          onTap: widget.readonly ? null : () => _handleTap(starRating),
          onTapDown: widget.readonly
              ? null
              : (details) {
                  if (!widget.allowHalfRating) return;

                  // ✅ WEB FIX: Safe casting for Flutter Web compatibility
                  final renderObject = context.findRenderObject();
                  if (renderObject is! RenderBox) return;

                  final box = renderObject;
                  final localPosition =
                      box.globalToLocal(details.globalPosition);
                  final starWidth = widget.size;
                  final starIndex = (localPosition.dx / starWidth).floor();
                  final isLeftHalf =
                      (localPosition.dx % starWidth) < (starWidth / 2);

                  // ✅ SIMPLIFIED: Direct 5-star rating (0.5, 1.0, 1.5... 5.0)
                  final starRating = starIndex + (isLeftHalf ? 0.5 : 1.0);
                  if (starRating >= 0.5 && starRating <= 5.0) {
                    _handleTap(
                        starRating); // Direct 5-star rating, no conversion
                  }
                },
          child: _buildStar(index),
        );
      }),
    );
  }

  Widget _buildStar(int index) {
    final starValue = index + 1;
    final difference = _currentRating - starValue;

    // ✅ MOBILE OPTIMIZATION: Check screen size for compact layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    Widget star;

    if (difference >= 0) {
      // Estrella completa
      star = Icon(
        Icons.star,
        size: widget.size,
        color: widget.color,
      );
    } else if (difference > -1 && difference < 0) {
      // Estrella parcial
      if (widget.allowHalfRating && difference > -0.5) {
        star = Icon(
          Icons.star_half,
          size: widget.size,
          color: widget.color,
        );
      } else {
        star = Icon(
          Icons.star_border,
          size: widget.size,
          color: widget.borderColor ?? widget.color.withValues(alpha: 0.3),
        );
      }
    } else {
      // Estrella vacía
      star = Icon(
        Icons.star_border,
        size: widget.size,
        color: widget.borderColor ?? widget.color.withValues(alpha: 0.3),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 0.5 : 1),
      child: star,
    );
  }
}

/// Widget simplificado para mostrar solo calificaciones (readonly)
class SimpleStarRating extends StatelessWidget {
  const SimpleStarRating({
    super.key,
    required this.rating,
    this.size = 16.0,
    this.color = Colors.amber,
    this.showRating = true,
  });

  final double rating;
  final double size;
  final Color color;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StarRatingWidget(
          rating: rating,
          size: size,
          color: color,
          readonly: true,
        ),
        if (showRating) ...[
          const SizedBox(width: 4),
          Text(
            '${rating.toStringAsFixed(1)}/5',
            style: TextStyle(
              fontSize: size * 0.8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}

/// Widget interactivo para seleccionar calificación con slider
class RatingSliderWidget extends StatefulWidget {
  const RatingSliderWidget({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.min = 0.5,
    this.max = 5.0,
  });

  final double rating;
  final ValueChanged<double>? onRatingChanged;
  final double min;
  final double max;

  @override
  State<RatingSliderWidget> createState() => _RatingSliderWidgetState();
}

class _RatingSliderWidgetState extends State<RatingSliderWidget> {
  late double _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.rating.clamp(widget.min, widget.max);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Rating: ${_currentRating.toStringAsFixed(1)}'),
            SimpleStarRating(
              rating: _currentRating, // Direct 5-star rating display
              showRating: false,
            ),
          ],
        ),
        Slider(
          value: _currentRating,
          min: widget.min,
          max: widget.max,
          divisions: ((widget.max - widget.min) * 2)
              .round(), // Allow 0.5 increments (0.5 to 5.0 = 9 divisions)
          label: _currentRating.toStringAsFixed(1),
          onChanged: (value) {
            setState(() {
              _currentRating = value;
            });
            widget.onRatingChanged?.call(value);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.min.toString()}/5',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${widget.max.toString()}/5',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

/// Widget para mostrar distribución de calificaciones
class RatingDistributionWidget extends StatelessWidget {
  const RatingDistributionWidget({
    super.key,
    required this.distribution,
    this.totalRatings = 0,
  });

  final Map<String, int> distribution;
  final int totalRatings;

  @override
  Widget build(BuildContext context) {
    if (totalRatings == 0) {
      return const Text('No ratings yet');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rating Distribution',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...distribution.entries.map((entry) {
          final count = entry.value;
          final percentage =
              totalRatings > 0 ? (count / totalRatings) * 100 : 0.0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '${entry.key}★',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text(
                    '$count (${percentage.toStringAsFixed(1)}%)',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
