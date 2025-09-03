import 'package:flutter/material.dart';

import '../../../core/logging/base_logger.dart';
import '../../../core/logging/logger_factory.dart';
import '../../../core/monetization/ad_frequency_controller.dart';
import 'banner_ad_widget.dart';
import 'full_width_ad_widget.dart';
import 'grid_ad_widget.dart';
import 'native_ad_widget.dart';

/// Tipos de anuncios controlados
enum ControlledAdType {
  banner,
  native,
  grid,
  fullWidth,
}

/// Widget que controla la frecuencia de anuncios automáticamente
class ControlledAdWidget extends StatefulWidget {
  const ControlledAdWidget({
    super.key,
    required this.adType,
    this.height,
    this.showLabel = false,
    this.margin,
    this.borderRadius = 12,
    this.aspectRatio,
    this.onAdShown,
    this.onAdBlocked,
    this.metadata,
  });

  final ControlledAdType adType;
  final double? height;
  final bool showLabel;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double? aspectRatio;
  final VoidCallback? onAdShown;
  final ValueChanged<AdDecisionResult>? onAdBlocked;
  final Map<String, dynamic>? metadata;

  @override
  State<ControlledAdWidget> createState() => _ControlledAdWidgetState();
}

class _ControlledAdWidgetState extends State<ControlledAdWidget> {
  final BaseLogger _logger = LoggerFactory.logger;
  final AdFrequencyController _controller = AdFrequencyController.instance;

  bool _canShowAd = false;
  bool _isInitialized = false;
  AdDecisionResult? _lastDecision;

  @override
  void initState() {
    super.initState();
    _checkAdPermission();
  }

  Future<void> _checkAdPermission() async {
    try {
      final decision = await _controller.canShowAd(adType: widget.adType.name);

      setState(() {
        _canShowAd = decision == AdDecisionResult.allowed;
        _lastDecision = decision;
        _isInitialized = true;
      });

      if (_canShowAd) {
        // Registrar que el anuncio se va a mostrar
        await _controller.recordAdShown(
          adType: widget.adType.name,
          metadata: {
            'widget_type': widget.adType.name,
            'height': widget.height,
            'showLabel': widget.showLabel,
            ...?widget.metadata,
          },
        );

        widget.onAdShown?.call();
      } else {
        widget.onAdBlocked?.call(decision);
      }
    } catch (e) {
      _logger.error('Error checking ad permission: $e');
      setState(() {
        _canShowAd = false;
        _isInitialized = true;
      });
    }
  }

  Widget _buildAdWidget() {
    switch (widget.adType) {
      case ControlledAdType.banner:
        return const BannerAdWidget();

      case ControlledAdType.native:
        return NativeAdWidget(
          height: widget.height ?? 120,
          showLabel: widget.showLabel,
          margin: widget.margin,
          borderRadius: widget.borderRadius,
        );

      case ControlledAdType.grid:
        return GridAdWidget(
          aspectRatio: widget.aspectRatio ?? 0.7,
          showLabel: widget.showLabel,
        );

      case ControlledAdType.fullWidth:
        return const FullWidthAdWidget();
    }
  }

  Widget _buildPlaceholder() {
    // Mostrar placeholder discreto cuando no se puede mostrar anuncio
    if (!widget.showLabel) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Container(
      height: _getPlaceholderHeight(),
      margin: widget.margin ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Center(
        child: Text(
          _getBlockedReasonText(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  double _getPlaceholderHeight() {
    switch (widget.adType) {
      case ControlledAdType.banner:
        return 50;
      case ControlledAdType.native:
        return widget.height ?? 120;
      case ControlledAdType.grid:
        return 100;
      case ControlledAdType.fullWidth:
        return 80;
    }
  }

  String _getBlockedReasonText() {
    final decision = _lastDecision;
    if (decision == null) return '';

    switch (decision) {
      case AdDecisionResult.blockedBySessionLimit:
        return 'Límite de sesión alcanzado';
      case AdDecisionResult.blockedByHourlyLimit:
        return 'Límite horario alcanzado';
      case AdDecisionResult.blockedByDailyLimit:
        return 'Límite diario alcanzado';
      case AdDecisionResult.blockedByTimeCooldown:
        return 'Esperando cooldown';
      case AdDecisionResult.blockedByUserInteraction:
        return 'Cooldown después de interacción';
      case AdDecisionResult.blockedByUserPreference:
        return 'Bloqueado por preferencias';
      case AdDecisionResult.allowed:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Mostrar indicador de carga discreto
      return SizedBox(
        height: _getPlaceholderHeight(),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_canShowAd) {
      return _buildAdWidget();
    } else {
      return _buildPlaceholder();
    }
  }
}

/// Widget helper para mostrar anuncios con control de frecuencia automático
class ControlledBannerAd extends StatelessWidget {
  const ControlledBannerAd({
    super.key,
    this.onAdShown,
    this.onAdBlocked,
  });

  final VoidCallback? onAdShown;
  final ValueChanged<AdDecisionResult>? onAdBlocked;

  @override
  Widget build(BuildContext context) {
    return ControlledAdWidget(
      adType: ControlledAdType.banner,
      onAdShown: onAdShown,
      onAdBlocked: onAdBlocked,
    );
  }
}

/// Widget helper para mostrar anuncios nativos con control de frecuencia
class ControlledNativeAd extends StatelessWidget {
  const ControlledNativeAd({
    super.key,
    this.height = 120,
    this.showLabel = false,
    this.margin,
    this.borderRadius = 12,
    this.onAdShown,
    this.onAdBlocked,
  });

  final double height;
  final bool showLabel;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onAdShown;
  final ValueChanged<AdDecisionResult>? onAdBlocked;

  @override
  Widget build(BuildContext context) {
    return ControlledAdWidget(
      adType: ControlledAdType.native,
      height: height,
      showLabel: showLabel,
      margin: margin,
      borderRadius: borderRadius,
      onAdShown: onAdShown,
      onAdBlocked: onAdBlocked,
    );
  }
}

/// Widget helper para mostrar anuncios de grid con control de frecuencia
class ControlledGridAd extends StatelessWidget {
  const ControlledGridAd({
    super.key,
    this.aspectRatio = 0.7,
    this.showLabel = true,
    this.onAdShown,
    this.onAdBlocked,
  });

  final double aspectRatio;
  final bool showLabel;
  final VoidCallback? onAdShown;
  final ValueChanged<AdDecisionResult>? onAdBlocked;

  @override
  Widget build(BuildContext context) {
    return ControlledAdWidget(
      adType: ControlledAdType.grid,
      aspectRatio: aspectRatio,
      showLabel: showLabel,
      onAdShown: onAdShown,
      onAdBlocked: onAdBlocked,
    );
  }
}

/// Widget helper para mostrar anuncios de ancho completo con control de frecuencia
class ControlledFullWidthAd extends StatelessWidget {
  const ControlledFullWidthAd({
    super.key,
    this.onAdShown,
    this.onAdBlocked,
  });

  final VoidCallback? onAdShown;
  final ValueChanged<AdDecisionResult>? onAdBlocked;

  @override
  Widget build(BuildContext context) {
    return ControlledAdWidget(
      adType: ControlledAdType.fullWidth,
      onAdShown: onAdShown,
      onAdBlocked: onAdBlocked,
    );
  }
}
