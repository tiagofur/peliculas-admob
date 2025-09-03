import 'package:flutter/material.dart';
import '../../services/accessibility_service.dart';

class StarRatingInput extends StatefulWidget {
  const StarRatingInput({
    super.key,
    required this.onRatingChanged,
    this.initialRating = 0,
    this.maxRating = 5,
    this.size = 32.0,
    this.color = Colors.amber,
    this.borderColor,
    this.spacing = 4.0,
    this.allowHalfRating = false,
  });

  final Function(int rating) onRatingChanged;
  final int initialRating;
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
  late int _currentRating;

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

  void _updateRating(int rating) {
    if (rating != _currentRating) {
      setState(() {
        _currentRating = rating;
      });
      widget.onRatingChanged(rating);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessibleSize = AccessibilityService.getAccessibleButtonSize(context);
    final semanticLabel = AccessibilityService.getStarRatingSemantics(_currentRating, widget.maxRating);
    
    return Semantics(
      label: 'Calificación interactiva. $semanticLabel. Toque las estrellas para calificar.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.maxRating, (index) {
          final starNumber = index + 1;
          return Semantics(
            button: true,
            label: 'Calificar con $starNumber de ${widget.maxRating} estrellas',
            onTap: () => _updateRating(starNumber),
            child: GestureDetector(
              onTap: () => _updateRating(starNumber),
              child: Container(
                padding: EdgeInsets.all(widget.spacing),
                constraints: BoxConstraints(
                  minWidth: accessibleSize,
                  minHeight: accessibleSize,
                ),
                child: Center(
                  child: Icon(
                    starNumber <= _currentRating
                        ? Icons.star
                        : Icons.star_border,
                    size: widget.size,
                    color: starNumber <= _currentRating
                        ? widget.color
                        : (widget.borderColor ?? widget.color.withValues(alpha: 0.3 * 255)),
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
    this.maxRating = 5,
    this.size = 20.0,
    this.color = Colors.amber,
    this.spacing = 2.0,
    this.showValue = false,
    this.valueStyle,
  });

  final int rating;
  final int maxRating;
  final double size;
  final Color color;
  final double spacing;
  final bool showValue;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = AccessibilityService.getStarRatingSemantics(rating, maxRating);
    
    return Semantics(
      label: semanticLabel,
      readOnly: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(maxRating, (index) {
            final starNumber = index + 1;
            return Padding(
              padding: EdgeInsets.only(
                right: index < maxRating - 1 ? spacing : 0,
              ),
              child: Icon(
                starNumber <= rating
                    ? Icons.star
                    : Icons.star_border,
                size: size,
                color: starNumber <= rating
                    ? color
                    : color.withValues(alpha: 0.3 * 255),
                semanticLabel: starNumber <= rating ? 'Estrella llena' : 'Estrella vacía',
              ),
            );
          }),
          if (showValue) ...[
            SizedBox(width: spacing * 2),
            Semantics(
              label: 'Valor numérico: $rating de $maxRating',
              child: Text(
                '$rating/$maxRating',
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
    this.maxRating = 5,
    this.size = 32.0,
    this.color = Colors.amber,
    this.spacing = 4.0,
    this.showLabels = true,
    this.enabled = true,
  });

  final Function(int rating) onRatingChanged;
  final int initialRating;
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
  late int _currentRating;
  int _hoverRating = 0;

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

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Muy mala';
      case 2:
        return 'Mala';
      case 3:
        return 'Regular';
      case 4:
        return 'Buena';
      case 5:
        return 'Excelente';
      default:
        return 'Sin calificar';
    }
  }

  void _updateRating(int rating) {
    if (!widget.enabled) return;
    
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
    final accessibleSize = AccessibilityService.getAccessibleButtonSize(context);
    final semanticLabel = AccessibilityService.getStarRatingSemantics(_currentRating, widget.maxRating);
    
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
              final starNumber = index + 1;
              return Semantics(
                button: widget.enabled,
                enabled: widget.enabled,
                label: widget.enabled 
                    ? 'Calificar con $starNumber de ${widget.maxRating} estrellas - ${_getRatingLabel(starNumber)}'
                    : 'Estrella $starNumber de ${widget.maxRating}',
                onTap: widget.enabled ? () => _updateRating(starNumber) : null,
                child: MouseRegion(
                  onEnter: widget.enabled ? (_) => setState(() => _hoverRating = starNumber) : null,
                  onExit: widget.enabled ? (_) => setState(() => _hoverRating = 0) : null,
                  child: GestureDetector(
                    onTap: widget.enabled ? () => _updateRating(starNumber) : null,
                    child: Container(
                      padding: EdgeInsets.all(widget.spacing),
                      constraints: BoxConstraints(
                        minWidth: accessibleSize,
                        minHeight: accessibleSize,
                      ),
                      child: Center(
                        child: Icon(
                          starNumber <= displayRating
                              ? Icons.star
                              : Icons.star_border,
                          size: widget.size,
                          color: widget.enabled
                              ? (starNumber <= displayRating
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
              label: 'Etiqueta de calificación: ${_getRatingLabel(displayRating)}',
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