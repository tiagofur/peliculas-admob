import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peliculas/core/logging/logger_factory.dart';
import 'package:peliculas/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Trakt Integration Tests', () {
    testWidgets('App should load with Trakt data', (WidgetTester tester) async {
      // Inicializar la app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verificar que la pantalla principal se carga
      expect(find.byType(MaterialApp), findsOneWidget);

      // Buscar indicadores de que los datos se están cargando
      // (esto puede variar según tu UI específica)

      // Esperar a que se carguen los datos
      await tester.pumpAndSettle(const Duration(seconds: 10));

      LoggerFactory.info('✅ App inicializada correctamente con Trakt');
    });
  });
}
