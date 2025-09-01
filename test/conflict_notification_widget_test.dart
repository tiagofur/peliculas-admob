import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:peliculas/core/sync/conflict_resolution/multiplatform_conflict_resolver.dart';
import 'package:peliculas/presentation/widgets/sync/conflict_notification_widget.dart';

/// Test básico para el widget de notificaciones de conflicto
void main() {
  group('ConflictNotificationWidget Tests', () {
    testWidgets('should display conflict information correctly', (WidgetTester tester) async {
      // Crear un resultado de conflicto simulado
      final conflictResult = ConflictResolutionResult<String>(
        resolvedItem: 'resolved_item',
        conflictType: ConflictType.simultaneousModification,
        severity: ConflictSeverity.medium,
        resolution: 'Used most recent timestamp',
        description: 'Conflicto resuelto usando last-write-wins para modificaciones simultáneas.',
        requiresManualIntervention: false,
        dataLoss: false,
        resolvedAt: DateTime.now(),
      );

      // Construir el widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictNotificationWidget(
              conflictResolution: conflictResult,
              showDetails: true,
            ),
          ),
        ),
      );

      // Verificar que el widget muestra la información correcta
      expect(find.text('Cambios simultáneos resueltos'), findsOneWidget);
      expect(find.text('Conflicto resuelto usando last-write-wins para modificaciones simultáneas.'), findsOneWidget);
      expect(find.text('Tipo: Modificaciones simultáneas'), findsOneWidget);
      expect(find.text('Estrategia: Used most recent timestamp'), findsOneWidget);
      
      // Verificar que el icono apropiado está presente
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });

    testWidgets('should show manual intervention warning when required', (WidgetTester tester) async {
      final conflictResult = ConflictResolutionResult<String>(
        resolvedItem: 'resolved_item',
        conflictType: ConflictType.simultaneousModification,
        severity: ConflictSeverity.high,
        resolution: 'Manual resolution required',
        description: 'Conflicto que requiere atención manual del usuario.',
        requiresManualIntervention: true,
        dataLoss: true,
        resolvedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictNotificationWidget(
              conflictResolution: conflictResult,
              showDetails: true,
            ),
          ),
        ),
      );

      // Verificar que se muestra la advertencia de intervención manual
      expect(find.text('Este conflicto podría requerir tu atención. Revisa los cambios para confirmar que son correctos.'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
      
      // Verificar que se indica pérdida de datos
      expect(find.text('Nota: Se perdieron algunos datos durante la resolución'), findsOneWidget);
    });

    testWidgets('should have dismissible functionality', (WidgetTester tester) async {
      bool dismissed = false;
      
      final conflictResult = ConflictResolutionResult<String>(
        resolvedItem: 'resolved_item',
        conflictType: ConflictType.simultaneousAddition,
        severity: ConflictSeverity.low,
        resolution: 'Merged successfully',
        description: 'Adiciones simultáneas fusionadas correctamente.',
        requiresManualIntervention: false,
        dataLoss: false,
        resolvedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictNotificationWidget(
              conflictResolution: conflictResult,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      // Buscar y tocar el botón de cerrar
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);
      
      await tester.tap(closeButton);
      await tester.pump();

      // Verificar que se llamó la función de dismiss
      expect(dismissed, isTrue);
    });
  });

  group('ConflictStatsWidget Tests', () {
    testWidgets('should display conflict statistics correctly', (WidgetTester tester) async {
      final stats = {
        'totalConflicts': 5,
        'dataLossIncidents': 2,
        'conflictsByType': {
          'simultaneousModification': 3,
          'simultaneousAddition': 2,
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictStatsWidget(
              conflictStats: stats,
            ),
          ),
        ),
      );

      expect(find.text('Estadísticas de Sincronización'), findsOneWidget);
      expect(find.text('Conflictos resueltos: 5'), findsOneWidget);
      expect(find.text('Incidentes con pérdida de datos: 2'), findsOneWidget);
    });

    testWidgets('should hide when no conflicts exist', (WidgetTester tester) async {
      final stats = {
        'totalConflicts': 0,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictStatsWidget(
              conflictStats: stats,
            ),
          ),
        ),
      );

      // No debería mostrarse nada cuando no hay conflictos
      expect(find.text('Estadísticas de Sincronización'), findsNothing);
    });
  });
}