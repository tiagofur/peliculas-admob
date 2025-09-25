import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/logging/logger_factory.dart';

/// Widget placeholder para anuncios en modo debug/desarrollo
/// Simula la apariencia de los anuncios reales para testing UI
class AdPlaceholderWidget extends StatelessWidget {
  const AdPlaceholderWidget({
    super.key,
    required this.type,
    this.width,
    this.height,
    this.customText,
  });
  final AdPlaceholderType type;
  final double? width;
  final double? height;
  final String? customText;

  @override
  Widget build(BuildContext context) {
    // Solo mostrar placeholder en modo debug
    if (!kDebugMode) {
      LoggerFactory.warning('AdPlaceholderWidget used in release mode');
      return const SizedBox.shrink();
    }

    final placeholderData = _getPlaceholderData();

    return Container(
      width: width ?? placeholderData.defaultWidth,
      height: height ?? placeholderData.defaultHeight,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(
          color: Colors.grey[400]!,
          width: 1,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Usar Flexible para permitir que el contenido se ajuste
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  placeholderData.icon,
                  color: Colors.grey[600],
                  size: _getIconSize(placeholderData.defaultHeight),
                ),
                const SizedBox(height: 4),
                Text(
                  customText ?? placeholderData.text,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: _getFontSize(placeholderData.defaultHeight),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'DEBUG MODE',
                  style: TextStyle(
                    color: Colors.orange[600],
                    fontSize: _getDebugFontSize(placeholderData.defaultHeight),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _PlaceholderData _getPlaceholderData() {
    switch (type) {
      case AdPlaceholderType.banner:
        return _PlaceholderData(
          text: 'Banner Ad\n728x90',
          icon: Icons.image_outlined,
          defaultWidth: 728,
          defaultHeight: 90,
        );
      case AdPlaceholderType.native:
        return _PlaceholderData(
          text: 'Native Ad\n280x200',
          icon: Icons.article_outlined,
          defaultWidth: 280,
          defaultHeight: 200,
        );
      case AdPlaceholderType.fullWidth:
        return _PlaceholderData(
          text: 'Full Width Ad\nResponsive',
          icon: Icons.crop_landscape,
          defaultWidth: double.infinity,
          defaultHeight: 150,
        );
      case AdPlaceholderType.grid:
        return _PlaceholderData(
          text: 'Grid Ad\n300x250',
          icon: Icons.grid_view,
          defaultWidth: 300,
          defaultHeight: 250,
        );
    }
  }

  // Helper methods para tamaños adaptativos basados en la altura del contenedor
  double _getIconSize(double containerHeight) {
    if (containerHeight <= 90) return 20; // Banner pequeño
    if (containerHeight <= 150) return 24; // Altura media
    return 32; // Altura grande
  }

  double _getFontSize(double containerHeight) {
    if (containerHeight <= 90) return 10; // Banner pequeño
    if (containerHeight <= 150) return 11; // Altura media
    return 12; // Altura grande
  }

  double _getDebugFontSize(double containerHeight) {
    if (containerHeight <= 90) return 8; // Banner pequeño
    if (containerHeight <= 150) return 9; // Altura media
    return 10; // Altura grande
  }
}

enum AdPlaceholderType {
  banner,
  native,
  fullWidth,
  grid,
}

class _PlaceholderData {
  _PlaceholderData({
    required this.text,
    required this.icon,
    required this.defaultWidth,
    required this.defaultHeight,
  });
  final String text;
  final IconData icon;
  final double defaultWidth;
  final double defaultHeight;
}
