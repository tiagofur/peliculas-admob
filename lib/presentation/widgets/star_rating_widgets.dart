import 'package:flutter/material.dart';
import '../../services/accessibility_service.dart';

class StarRatingInput extends StatefulWidget {
  const StarRatingInput({
    super.key,
    required this.onRatingChanged,
    this.initialRating = 0,
    this.maxRating = 5, // 5 stars representing 2-point increments
    this.size = 32.0,
    this.color = Colors.amber,
    this.borderColor,
    this.spacing = 4.0,
    this.allowHalfRating = false,
  });

  final Function(double rating) onRatingChanged;
  final double initialRating;
  final int maxRating;
  final double size;
  final Color color;
  final Color? borderColor;
  final double spacing;
  final bool allowHalfRating;

  @override
  State<StarRatingInput> createState() => _StarRatingInputState();
}

class _StarRatingInputState extends State<StarRatingInput> {
  late double _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  void didUpdateWidget(StarRatingInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRating != widget.initialRating) {
      _currentRating = widget.initialRating;
    }
  }

  void _updateRating(int starIndex) {
    // Convert star index (1-5) to rating value (2, 4, 6, 8, 10)
    final double rating = starIndex * 2.0;
    if (rating != _currentRating) {
      setState(() {
        _currentRating = rating;
      });
      widget.onRatingChanged(rating);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessibleSize =
        AccessibilityService.getAccessibleButtonSize(context);
    final semanticLabel = AccessibilityService.getStarRatingSemantics(
        _currentRating, widget.maxRating);

    return Semantics(
      label:
          'Calificación interactiva. $semanticLabel. Toque las estrellas para calificar.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.maxRating, (index) {
          final starIndex = index + 1;
          final starValue = starIndex * 2.0; // Each star represents 2 points
          final isStarFilled = starValue <= _currentRating;
          
          return Semantics(
            button: true,
            label: 'Calificar con $starIndex de ${widget.maxRating} estrellas (valor ${starValue.toInt()})',
            onTap: () => _updateRating(starIndex),
            child: GestureDetector(
              onTap: () => _updateRating(starIndex),
              child: Container(
                padding: EdgeInsets.all(widget.spacing),
                constraints: BoxConstraints(
                  minWidth: accessibleSize,
                  minHeight: accessibleSize,
                ),
                child: Center(
                  child: Icon(
                    isStarFilled ? Icons.star : Icons.star_border,
                    size: widget.size,
                    color: isStarFilled
                        ? widget.color
                        : (widget.borderColor ??
                            widget.color.withValues(alpha: 0.3 * 255)),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.maxRating = 5, // 5 stars representing 2-point increments
    this.size = 20.0,
    this.color = Colors.amber,
    this.spacing = 2.0,
    this.showValue = false,
    this.valueStyle,
  });

  final double rating;
  final int maxRating;
  final double size;
  final Color color;
  final double spacing;
  final bool showValue;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final semanticLabel =
        AccessibilityService.getStarRatingSemantics(rating, maxRating);

    return Semantics(
      label: semanticLabel,
      readOnly: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(maxRating, (index) {
            final starIndex = index + 1;
            final starValue = starIndex * 2.0; // Each star represents 2 points
            final isStarFilled = starValue <= rating;
            
            return Padding(
              padding: EdgeInsets.only(
                right: index < maxRating - 1 ? spacing : 0,
              ),
              child: Icon(
                isStarFilled ? Icons.star : Icons.star_border,
                size: size,
                color: isStarFilled
                    ? color
                    : color.withValues(alpha: 0.3 * 255),
                semanticLabel:
                    isStarFilled ? 'Estrella llena' : 'Estrella vacía',
              ),
            );
          }),
          if (showValue) ...[
            SizedBox(width: spacing * 2),
            Semantics(
              label: 'Valor numérico: $rating de 10',
              child: Text(
                '$rating/10',
                style: valueStyle ?? Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class InteractiveStarRating extends StatefulWidget {
  const InteractiveStarRating({
    super.key,
    required this.onRatingChanged,
    this.initialRating = 0,
    this.maxRating = 5, // 5 stars representing 2-point increments
    this.size = 32.0,
    this.color = Colors.amber,
    this.spacing = 4.0,
    this.showLabels = true,
    this.enabled = true,
  });

  final Function(double rating) onRatingChanged;
  final double initialRating;
  final int maxRating;
  final double size;
  final Color color;
  final double spacing;
  final bool showLabels;
  final bool enabled;

  @override
  State<InteractiveStarRating> createState() => _InteractiveStarRatingState();
}

class _InteractiveStarRatingState extends State<InteractiveStarRating> {
  late double _currentRating;
  double _hoverRating = 0;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  void didUpdateWidget(InteractiveStarRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRating != widget.initialRating) {
      _currentRating = widget.initialRating;
    }
  }

  String _getRatingLabel(double rating) {
    switch (rating) {
      case 1:
      case 2:
        return 'Muy mala';
      case 3:
      case 4:
        return 'Mala';
      case 5:
      case 6:
        return 'Regular';
      case 7:
      case 8:
        return 'Buena';
      case 9:
      case 10:
        return 'Excelente';
      default:
        return 'Sin calificar';
    }
  }

  void _updateRating(int starIndex) {
    if (!widget.enabled) return;

    // Convert star index (1-5) to rating value (2, 4, 6, 8, 10)
    final double rating = starIndex * 2.0;
    if (rating != _currentRating) {
      setState(() {
        _currentRating = rating;
      });
      widget.onRatingChanged(rating);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayRating = _hoverRating > 0 ? _hoverRating : _currentRating;
    final accessibleSize =
        AccessibilityService.getAccessibleButtonSize(context);
    final semanticLabel = AccessibilityService.getStarRatingSemantics(
        _currentRating, widget.maxRating);

    return Semantics(
      label: widget.enabled
          ? 'Calificación interactiva. $semanticLabel. Seleccione una estrella para calificar.'
          : 'Calificación no editable. $semanticLabel',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.maxRating, (index) {
              final starIndex = index + 1;
              final starValue = starIndex * 2.0; // Each star represents 2 points
              final isStarFilled = starValue <= displayRating;
              
              return Semantics(
                button: widget.enabled,
                enabled: widget.enabled,
                label: widget.enabled
                    ? 'Calificar con $starIndex de ${widget.maxRating} estrellas (valor ${starValue.toInt()}) - ${_getRatingLabel(starValue)}'
                    : 'Estrella $starIndex de ${widget.maxRating} (valor ${starValue.toInt()})',
                onTap: widget.enabled ? () => _updateRating(starIndex) : null,
                child: MouseRegion(
                  onEnter: widget.enabled
                      ? (_) => setState(() => _hoverRating = starValue)
                      : null,
                  onExit: widget.enabled
                      ? (_) => setState(() => _hoverRating = 0)
                      : null,
                  child: GestureDetector(
                    onTap:
                        widget.enabled ? () => _updateRating(starIndex) : null,
                    child: Container(
                      padding: EdgeInsets.all(widget.spacing),
                      constraints: BoxConstraints(
                        minWidth: accessibleSize,
                        minHeight: accessibleSize,
                      ),
                      child: Center(
                        child: Icon(
                          isStarFilled ? Icons.star : Icons.star_border,
                          size: widget.size,
                          color: widget.enabled
                              ? (isStarFilled
                                  ? widget.color
                                  : widget.color.withValues(alpha: 0.3 * 255))
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (widget.showLabels) ...[
            const SizedBox(height: 8),
            Semantics(
              label:
                  'Etiqueta de calificación: ${_getRatingLabel(displayRating)}',
              child: Text(
                _getRatingLabel(displayRating),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: widget.enabled ? null : Colors.grey,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
