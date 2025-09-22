import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Widget para mostrar anuncios de AdSense en Web
/// En móvil no se muestra nada para mantener AdMob como prioridad
class AdSenseWidget extends StatelessWidget {
  const AdSenseWidget({
    super.key,
    this.height = 100,
    this.width,
    this.slot = 'default',
  });

  final double height;
  final double? width;
  final String slot;

  @override
  Widget build(BuildContext context) {
    // Solo mostrar en Web
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    return Container(
      height: height,
      width: width ?? double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.ads_click,
            size: 32,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'AdSense Ad Space',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            'Slot: $slot',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget responsivo que muestra AdMob en móvil y AdSense en Web
class ResponsiveAdWidget extends StatelessWidget {
  const ResponsiveAdWidget({
    super.key,
    this.height = 100,
    this.adMobWidget,
    this.adSenseSlot = 'default',
  });

  final double height;
  final Widget? adMobWidget;
  final String adSenseSlot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: kIsWeb
          ? AdSenseWidget(
              height: height,
              slot: adSenseSlot,
            )
          : adMobWidget ?? const SizedBox.shrink(),
    );
  }
}