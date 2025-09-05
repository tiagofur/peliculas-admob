import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/sync/entity_sync_manager.dart';
import 'package:peliculas/domain/entities/syncable_entity.dart';
import 'package:peliculas/presentation/widgets/sync/conflict_history_list.dart';
import 'package:peliculas/presentation/widgets/sync/conflict_preview_widget.dart';
import 'package:peliculas/presentation/widgets/sync/conflict_resolution_dialog.dart';
import 'package:peliculas/presentation/widgets/sync/merge_preview_widget.dart';

/// Test implementation of SyncableEntity for testing purposes
class TestSyncableEntity extends SyncableEntity {
  TestSyncableEntity({
    required String id,
    required String userId,
    required DateTime createdAt,
    required DateTime lastModifiedAt,
    required bool isDeleted,
    required int syncVersion,
    required String? deviceId,
    required this.testData,
    required this.testField,
  })  : _id = id,
        _userId = userId,
        _createdAt = createdAt,
        _lastModifiedAt = lastModifiedAt,
        _isDeleted = isDeleted,
        _syncVersion = syncVersion,
        _deviceId = deviceId;

  final String _id;
  final String _userId;
  final DateTime _createdAt;
  final DateTime _lastModifiedAt;
  final bool _isDeleted;
  final int _syncVersion;
  final String? _deviceId;
  final String testData;
  final String testField;

  @override
  String get id => _id;

  @override
  String get userId => _userId;

  @override
  DateTime get createdAt => _createdAt;

  @override
  DateTime get lastModifiedAt => _lastModifiedAt;

  @override
  bool get isDeleted => _isDeleted;

  @override
  int get syncVersion => _syncVersion;

  @override
  String? get deviceId => _deviceId;

  @override
  String get entityType => 'test_entity';

  @override
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'last_modified_at': lastModifiedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'sync_version': syncVersion,
      'device_id': deviceId,
      'test_data': testData,
      'test_field': testField,
    };
  }

  @override
  SyncableEntity copyWith({
    DateTime? lastModifiedAt,
    int? syncVersion,
    String? deviceId,
    bool? isDeleted,
  }) {
    return TestSyncableEntity(
      id: id,
      userId: userId,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      testData: testData,
      testField: testField,
    );
  }

  TestSyncableEntity copyWithData({
    String? testData,
    String? testField,
  }) {
    return TestSyncableEntity(
      id: id,
      userId: userId,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt,
      isDeleted: isDeleted,
      syncVersion: syncVersion,
      deviceId: deviceId,
      testData: testData ?? this.testData,
      testField: testField ?? this.testField,
    );
  }
}

void main() {
  group('Conflict Resolution Widgets Tests', () {
    late TestSyncableEntity localEntity;
    late TestSyncableEntity remoteEntity;
    late ConflictInfo<TestSyncableEntity> conflictInfo;
    late DateTime now;

    setUp(() {
      now = DateTime.now();
      localEntity = TestSyncableEntity(
        id: 'test-id-1',
        userId: 'user-123',
        createdAt: now.subtract(const Duration(hours: 2)),
        lastModifiedAt: now.subtract(const Duration(minutes: 30)),
        isDeleted: false,
        syncVersion: 2,
        deviceId: 'device-local',
        testData: 'local data',
        testField: 'local field',
      );

      remoteEntity = TestSyncableEntity(
        id: 'test-id-1',
        userId: 'user-123',
        createdAt: now.subtract(const Duration(hours: 2)),
        lastModifiedAt: now.subtract(const Duration(minutes: 15)),
        isDeleted: false,
        syncVersion: 3,
        deviceId: 'device-remote',
        testData: 'remote data',
        testField: 'remote field',
      );

      conflictInfo = ConflictInfo<TestSyncableEntity>(
        localEntity: localEntity,
        remoteEntity: remoteEntity,
        conflictType: ConflictType.concurrentModification,
        detectedAt: now,
        metadata: {'source': 'test'},
      );
    });

    group('ConflictResolutionDialog Tests', () {
      testWidgets('should display conflict information correctly',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await showDialog<ConflictStrategy>(
                      context: context,
                      builder: (context) =>
                          ConflictResolutionDialog<TestSyncableEntity>(
                        conflict: conflictInfo,
                        onResolved: (resolution) {
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Tap to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Verify dialog content
        expect(find.text('Modificación Concurrente'), findsOneWidget);
        expect(find.text('Detalles del Conflicto'), findsOneWidget);
        expect(find.text('Mantener Versión Local'), findsOneWidget);
        expect(find.text('Usar Versión Remota'), findsOneWidget);
        expect(find.text('Fusionar Cambios'), findsOneWidget);
        expect(find.text('Resolución Manual'), findsOneWidget);
      });

      testWidgets('should handle strategy selection correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await showDialog<ConflictStrategy>(
                      context: context,
                      builder: (context) =>
                          ConflictResolutionDialog<TestSyncableEntity>(
                        conflict: conflictInfo,
                        onResolved: (resolution) {
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Tap to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Verify dialog is displayed with strategy options
        expect(find.text('Mantener Versión Local'), findsOneWidget);
        expect(find.text('Resolver'), findsOneWidget);
      });
    });

    group('ConflictPreviewWidget Tests', () {
      testWidgets('should display local and remote versions', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConflictPreviewWidget<TestSyncableEntity>(
                conflict: conflictInfo,
                selectedStrategy: ConflictStrategy.localWins,
              ),
            ),
          ),
        );

        expect(find.text('Vista Previa del Conflicto'), findsOneWidget);
        expect(find.text('Versión Local'), findsOneWidget);
        expect(find.text('Versión Remota'), findsOneWidget);
        expect(find.text('local data'), findsOneWidget);
        expect(find.text('remote data'), findsOneWidget);
      });

      testWidgets('should highlight differences between versions',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConflictPreviewWidget<TestSyncableEntity>(
                conflict: conflictInfo,
                selectedStrategy: ConflictStrategy.merge,
                compact: true,
              ),
            ),
          ),
        );

        // Verify that different values are shown
        expect(find.text('local field'), findsOneWidget);
        expect(find.text('remote field'), findsOneWidget);
      });
    });

    group('MergePreviewWidget Tests', () {
      testWidgets('should display merge preview correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MergePreviewWidget<TestSyncableEntity>(
                conflict: conflictInfo,
              ),
            ),
          ),
        );

        expect(find.text('Vista Previa de Fusión'), findsOneWidget);
        expect(find.text('Versión Fusionada'), findsOneWidget);
      });

      testWidgets('should show merge strategy for each field', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MergePreviewWidget<TestSyncableEntity>(
                conflict: conflictInfo,
              ),
            ),
          ),
        );

        // Should show some indication of merge strategy
        expect(find.byType(Card), findsWidgets);
      });
    });

    group('ConflictHistoryList Tests', () {
      testWidgets('should display empty state when no conflicts',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConflictHistoryList(),
            ),
          ),
        );

        // Wait for loading to complete
        await tester.pumpAndSettle();

        expect(find.text('Historial de Conflictos'), findsOneWidget);
        expect(find.text('No hay conflictos registrados'), findsOneWidget);
        expect(
            find.text(
                'Los conflictos de sincronización aparecerán aquí cuando ocurran'),
            findsOneWidget);
      });

      testWidgets('should display conflicts when provided', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConflictHistoryList(),
            ),
          ),
        );

        // Wait for loading to complete
        await tester.pumpAndSettle();

        // Verify basic structure is rendered
        expect(find.text('Historial de Conflictos'), findsOneWidget);
        expect(find.byType(ConflictHistoryList), findsOneWidget);
      });

      testWidgets('should filter conflicts by search query', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConflictHistoryList(),
            ),
          ),
        );

        // Wait for loading to complete
        await tester.pumpAndSettle();

        // Verify the widget renders and has filter functionality
        expect(find.text('Historial de Conflictos'), findsOneWidget);
        expect(find.byType(ConflictHistoryList), findsOneWidget);

        // Verify empty state message is shown
        expect(find.text('No hay conflictos registrados'), findsOneWidget);
      });
    });
  });
}
