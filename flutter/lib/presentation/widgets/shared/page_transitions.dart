import 'package:flutter/material.dart';

/// Transiciones cinematográficas personalizadas para navegación entre páginas
class CinematicPageTransitions {
  /// Transición de desvanecimiento con escala - ✅ OPTIMIZADA
  static PageRouteBuilder fadeScaleTransition({
    required Widget page,
    Duration duration =
        const Duration(milliseconds: 350), // Más rápida para mejor UX
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        const curve = Curves.easeOutCubic;

        var fadeAnimation = Tween(
          begin: begin,
          end: end,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));

        var scaleAnimation = Tween(
          begin: 0.8,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Transición de deslizamiento desde abajo con rebote - ✅ OPTIMIZADA
  static PageRouteBuilder slideUpTransition({
    required Widget page,
    Duration duration =
        const Duration(milliseconds: 400), // Ligeramente más rápida
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.elasticOut;

        var slideAnimation = Tween(
          begin: begin,
          end: end,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));

        var fadeAnimation = Tween(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Transición de rotación 3D cinematográfica
  static PageRouteBuilder rotationTransition({
    required Widget page,
    Duration duration = const Duration(milliseconds: 800),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final rotateAnim = Tween(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ));

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(rotateAnim.value * 0.5),
              child: Opacity(
                opacity: rotateAnim.value,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }

  /// Transición de cortina cinematográfica
  static PageRouteBuilder curtainTransition({
    required Widget page,
    Duration duration = const Duration(milliseconds: 700),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return ClipRect(
              child: Align(
                alignment: Alignment.center,
                widthFactor: animation.value,
                heightFactor: 1.0,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }

  /// Transición de zoom con blur
  static PageRouteBuilder zoomBlurTransition({
    required Widget page,
    Duration duration = const Duration(milliseconds: 600),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var scaleAnimation = Tween(
          begin: 1.2,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
        ));

        var fadeAnimation = Tween(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ));

        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }
}

/// Widget para animaciones de micro-interacciones
class MicroInteractionWidget extends StatefulWidget {
  const MicroInteractionWidget({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.95,
    this.duration = const Duration(milliseconds: 150),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;

  @override
  State<MicroInteractionWidget> createState() => _MicroInteractionWidgetState();
}

class _MicroInteractionWidgetState extends State<MicroInteractionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// Widget para efectos de parallax en listas
class ParallaxListItem extends StatelessWidget {
  const ParallaxListItem({
    super.key,
    required this.child,
    required this.scrollController,
    required this.itemIndex,
    this.parallaxFactor = 0.3,
  });

  final Widget child;
  final ScrollController scrollController;
  final int itemIndex;
  final double parallaxFactor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, child) {
        double offset = 0.0;
        if (scrollController.hasClients) {
          offset = scrollController.offset * parallaxFactor;
        }

        return Transform.translate(
          offset: Offset(0, offset * (itemIndex * 0.1)),
          child: this.child,
        );
      },
    );
  }
}

/// Widget para animaciones de feedback
class FeedbackAnimationWidget extends StatefulWidget {
  const FeedbackAnimationWidget({
    super.key,
    required this.child,
    this.feedbackType = FeedbackType.success,
    this.duration = const Duration(milliseconds: 300),
  });

  final Widget child;
  final FeedbackType feedbackType;
  final Duration duration;

  @override
  State<FeedbackAnimationWidget> createState() =>
      _FeedbackAnimationWidgetState();
}

class _FeedbackAnimationWidgetState extends State<FeedbackAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: _getFeedbackColor(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  Color _getFeedbackColor() {
    switch (widget.feedbackType) {
      case FeedbackType.success:
        return Colors.green.withValues(alpha: 0.3);
      case FeedbackType.error:
        return Colors.red.withValues(alpha: 0.3);
      case FeedbackType.warning:
        return Colors.orange.withValues(alpha: 0.3);
      case FeedbackType.info:
        return Colors.blue.withValues(alpha: 0.3);
    }
  }

  void playAnimation() {
    _controller.forward().then((_) {
      _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: _colorAnimation.value,
              borderRadius: BorderRadius.circular(8),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

enum FeedbackType {
  success,
  error,
  warning,
  info,
}
