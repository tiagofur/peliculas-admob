import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:peliculas/presentation/widgets/admob/banner_ad_widget.dart';
import 'package:peliculas/presentation/widgets/admob/web_safe_ad_widgets.dart';
import 'package:peliculas/widgets/ads/ad_placeholder_widget.dart';

void main() {
  runApp(const AdPlaceholderTestApp());
}

class AdPlaceholderTestApp extends StatelessWidget {
  const AdPlaceholderTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ad Placeholder Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AdPlaceholderTestScreen(),
    );
  }
}

class AdPlaceholderTestScreen extends StatelessWidget {
  const AdPlaceholderTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ad Placeholders Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo Debug: ${kDebugMode ? 'ACTIVADO' : 'DESACTIVADO'}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDebugMode ? Colors.green : Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    kIsWeb
                        ? 'Plataforma: Web (AdSense)'
                        : 'Plataforma: Móvil (AdMob)',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'En debug: Placeholders | En release: Anuncios reales',
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Direct placeholders
            const Text(
              'Placeholders Directos:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            const Text('Banner Placeholder:'),
            const SizedBox(height: 8),
            const AdPlaceholderWidget(
              type: AdPlaceholderType.banner,
            ),

            const SizedBox(height: 20),
            const Text('Native Placeholder:'),
            const SizedBox(height: 8),
            const AdPlaceholderWidget(
              type: AdPlaceholderType.native,
            ),

            const SizedBox(height: 20),
            const Text('Full Width Placeholder:'),
            const SizedBox(height: 8),
            const AdPlaceholderWidget(
              type: AdPlaceholderType.fullWidth,
            ),

            const SizedBox(height: 20),
            const Text('Grid Placeholder:'),
            const SizedBox(height: 8),
            const AdPlaceholderWidget(
              type: AdPlaceholderType.grid,
            ),

            const SizedBox(height: 32),

            // Real widgets (with debug/release logic)
            const Text(
              'Widgets Reales (con lógica debug/release):',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            const Text('Web Safe Banner (AdSense):'),
            const SizedBox(height: 8),
            const WebSafeBannerAdWidget(),

            const SizedBox(height: 20),
            const Text('Web Safe Native (AdSense):'),
            const SizedBox(height: 8),
            const WebSafeNativeAdWidget(),

            const SizedBox(height: 20),
            const Text('Web Safe Full Width (AdSense):'),
            const SizedBox(height: 8),
            const WebSafeFullWidthAdWidget(),

            const SizedBox(height: 20),
            const Text('Banner Ad Widget:'),
            const SizedBox(height: 8),
            const BannerAdWidget(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
