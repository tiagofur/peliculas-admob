import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:peliculas/presentation/providers/sync_status_provider.dart';
import 'package:peliculas/presentation/providers/auth_provider.dart';
import 'package:peliculas/presentation/widgets/sync/sync_status_indicator.dart';

/// Test para verificar que la funcionalidad de sincronización e indicadores funciona correctamente
void main() {
  group('Sync Status Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('SyncStatus provider inicializa correctamente', () {
      final syncState = container.read(syncStatusProvider);
      
      expect(syncState.status, equals(SyncStatus.idle));
      expect(syncState.message, equals(''));
      expect(syncState.progress, equals(0.0));
      expect(syncState.lastSyncTime, isNull);
    });

    test('SyncStatus cambia cuando usuario se autentica', () async {
      final syncNotifier = container.read(syncStatusProvider.notifier);
      
      // Simular autenticación
      syncNotifier.startManualSync();
      
      final syncState = container.read(syncStatusProvider);
      expect(syncState.status, equals(SyncStatus.syncing));
      expect(syncState.message, equals('Iniciando sincronización...'));
      expect(syncState.progress, greaterThan(0.0));
    });

    test('SyncStatus maneja errores correctamente', () {
      final syncNotifier = container.read(syncStatusProvider.notifier);
      
      syncNotifier.setError('Error de prueba');
      
      final syncState = container.read(syncStatusProvider);
      expect(syncState.status, equals(SyncStatus.error));
      expect(syncState.hasError, isTrue);
      expect(syncState.errorMessage, equals('Error de prueba'));
    });

    test('SyncStatus maneja modo offline', () {
      final syncNotifier = container.read(syncStatusProvider.notifier);
      
      syncNotifier.setOffline();
      
      final syncState = container.read(syncStatusProvider);
      expect(syncState.status, equals(SyncStatus.offline));
      expect(syncState.isOffline, isTrue);
    });

    test('Provider de verificación de sync activo funciona', () {
      final syncNotifier = container.read(syncStatusProvider.notifier);
      
      // Estado inicial
      expect(container.read(isSyncingProvider), isFalse);
      
      // Iniciar sync
      syncNotifier.startManualSync();
      expect(container.read(isSyncingProvider), isTrue);
      
      // Completar sync
      syncNotifier.setSyncSuccess();
      expect(container.read(isSyncingProvider), isFalse);
    });

    test('Provider de errores de sync funciona', () {
      final syncNotifier = container.read(syncStatusProvider.notifier);
      
      // Sin errores inicialmente
      expect(container.read(hasSyncErrorProvider), isFalse);
      
      // Establecer error
      syncNotifier.setError('Error de test');
      expect(container.read(hasSyncErrorProvider), isTrue);
      
      // Limpiar error
      syncNotifier.setSyncSuccess();
      expect(container.read(hasSyncErrorProvider), isFalse);
    });

    testWidgets('SyncStatusIndicator se renderiza correctamente', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(
                size: 24,
                showText: true,
              ),
            ),
          ),
        ),
      );

      // Verificar que el widget se renderiza sin errores
      expect(find.byType(SyncStatusIndicator), findsOneWidget);
    });

    testWidgets('SyncStatusCard se renderiza correctamente', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SyncStatusCard(),
            ),
          ),
        ),
      );

      // Inicialmente debería estar oculto (idle state)
      expect(find.byType(SyncStatusCard), findsOneWidget);
    });

    testWidgets('SyncStatusIndicator muestra progreso durante sincronización', (WidgetTester tester) async {
      final container = ProviderContainer();
      
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(
                size: 24,
                showText: true,
              ),
            ),
          ),
        ),
      );

      // Iniciar sincronización
      container.read(syncStatusProvider.notifier).startManualSync();
      await tester.pump();

      // Debería mostrar el indicador de progreso
      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
      
      container.dispose();
    });

    testWidgets('SyncStatusIndicator muestra estado de éxito', (WidgetTester tester) async {
      final container = ProviderContainer();
      
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(
                size: 24,
                showText: true,
              ),
            ),
          ),
        ),
      );

      // Establecer estado de éxito
      container.read(syncStatusProvider.notifier).setSyncSuccess();
      await tester.pump();

      // Debería mostrar icono de éxito
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      
      container.dispose();
    });

    testWidgets('SyncStatusIndicator muestra estado de error', (WidgetTester tester) async {
      final container = ProviderContainer();
      
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(
                size: 24,
                showText: true,
              ),
            ),
          ),
        ),
      );

      // Establecer estado de error
      container.read(syncStatusProvider.notifier).setError('Error de test');
      await tester.pump();

      // Debería mostrar icono de error
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      
      container.dispose();
    });
  });
}