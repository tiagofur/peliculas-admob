import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configuración para tests que evita network calls complejos
void setupImageTestEnvironment() {
  setUpAll(() {
    // Usar TestDefaultBinaryMessengerBinding para evitar problemas de network
    TestWidgetsFlutterBinding.ensureInitialized();
  });
}

/// Widget de prueba simple que no hace network calls
class TestImageWidget extends StatelessWidget {
  const TestImageWidget({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  final double? width;
  final double? height; 
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: placeholder ?? 
        Icon(
          Icons.image,
          size: (width != null && height != null) 
            ? (width! * height!).clamp(16, 48) 
            : 24,
          color: Colors.grey[600],
        ),
    );
  }
}