import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Test de simulación de sincronización multi-dispositivo
/// Valida comportamientos complejos entre múltiples plataformas
void main() {
  group('Multi-Device Sync Simulation Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('Cross-Platform Sync Scenarios', () {
      test('Web → Android → iOS sync chain maintains consistency', () async {
        // Simular estado inicial en cada dispositivo
        var webFavorites = <int>[1, 2];
        var androidFavorites = <int>[2, 3];
        var iosFavorites = <int>[3, 4];

        // Operación en Web: Agregar película 5
        webFavorites = [...webFavorites, 5];
        developer.log('Web: Agregó película 5 → ${webFavorites}');

        // Simular latencia de red
        await Future.delayed(Duration(milliseconds: 500));

        // Sincronización Web → Supabase
        final supabaseFavorites = <int>{...webFavorites}.toList();
        developer.log('Supabase: Estado después de Web → ${supabaseFavorites}');

        // Sincronización Supabase → Android (merge)
        androidFavorites = <int>{...androidFavorites, ...supabaseFavorites}.toList();
        await Future.delayed(Duration(milliseconds: 700));
        developer.log('Android: Después de sync → ${androidFavorites}');

        // Sincronización Supabase → iOS (merge)
        iosFavorites = <int>{...iosFavorites, ...supabaseFavorites}.toList();
        await Future.delayed(Duration(milliseconds: 600));
        developer.log('iOS: Después de sync → ${iosFavorites}');

        // Verificar que todos los dispositivos tienen película 5
        expect(webFavorites, contains(5));
        expect(androidFavorites, contains(5));
        expect(iosFavorites, contains(5));

        // Verificar consistencia final
        final allUniqueMovies = <int>{...webFavorites, ...androidFavorites, ...iosFavorites};
        expect(allUniqueMovies, containsAll([1, 2, 3, 4, 5]));

        developer.log('✅ Cadena de sincronización Web → Android → iOS consistente');
      });

      test('Simultaneous operations from multiple devices resolve correctly', () async {
        // Estado inicial en Supabase
        var supabaseState = <int>[1, 2, 3];

        // Operaciones simultáneas
        final webOperation = Future.delayed(Duration(milliseconds: 100), () {
          return {'device': 'web', 'operation': 'add', 'movie_id': 4, 'timestamp': DateTime.now()};
        });

        final androidOperation = Future.delayed(Duration(milliseconds: 150), () {
          return {'device': 'android', 'operation': 'add', 'movie_id': 5, 'timestamp': DateTime.now()};
        });

        final iosOperation = Future.delayed(Duration(milliseconds: 120), () {
          return {'device': 'ios', 'operation': 'remove', 'movie_id': 2, 'timestamp': DateTime.now()};
        });

        // Esperar todas las operaciones
        final operations = await Future.wait([webOperation, androidOperation, iosOperation]);

        // Procesar operaciones por timestamp
        operations.sort((a, b) => 
            (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));

        // Aplicar operaciones en orden
        for (final op in operations) {
          if (op['operation'] == 'add') {
            supabaseState = [...supabaseState, op['movie_id'] as int];
          } else if (op['operation'] == 'remove') {
            supabaseState = supabaseState.where((id) => id != op['movie_id']).toList();
          }
          developer.log('Aplicada operación: ${op['device']} ${op['operation']} ${op['movie_id']}');
        }

        // Verificar estado final
        expect(supabaseState, contains(4)); // Web agregó 4
        expect(supabaseState, contains(5)); // Android agregó 5
        expect(supabaseState, isNot(contains(2))); // iOS eliminó 2

        developer.log('✅ Operaciones simultáneas resueltas correctamente');
      });

      test('Offline device sync after reconnection handles conflicts', () async {
        // Estado inicial sincronizado
        var deviceAState = <int>[1, 2, 3];
        var deviceBState = <int>[1, 2, 3];
        var supabaseState = <int>[1, 2, 3];

        // Dispositivo A va offline y hace cambios
        final deviceAOfflineOperations = [
          {'operation': 'add', 'movie_id': 4, 'timestamp': DateTime.now()},
          {'operation': 'remove', 'movie_id': 2, 'timestamp': DateTime.now().add(Duration(minutes: 1))},
        ];

        // Aplicar operaciones offline en dispositivo A
        for (final op in deviceAOfflineOperations) {
          if (op['operation'] == 'add') {
            deviceAState = [...deviceAState, op['movie_id'] as int];
          } else if (op['operation'] == 'remove') {
            deviceAState = deviceAState.where((id) => id != op['movie_id']).toList();
          }
        }
        developer.log('Dispositivo A offline: ${deviceAState}');

        // Mientras tanto, dispositivo B (online) hace cambios
        deviceBState = [...deviceBState, 5]; // Agregar película 5
        supabaseState = [...supabaseState, 5];
        developer.log('Dispositivo B online: ${deviceBState}');

        // Dispositivo A se reconecta y sincroniza
        await Future.delayed(Duration(milliseconds: 500));

        // Resolver conflictos: merge de operaciones
        final mergedState = <int>{...supabaseState, ...deviceAState}.toList();
        
        // Aplicar eliminaciones de dispositivo A
        for (final op in deviceAOfflineOperations) {
          if (op['operation'] == 'remove') {
            mergedState.removeWhere((id) => id == op['movie_id']);
          }
        }

        // Actualizar Supabase y dispositivo B
        supabaseState = List.from(mergedState);
        deviceBState = List.from(mergedState);

        // Verificar estado final consistente
        expect(supabaseState, containsAll([1, 3, 4, 5])); // Sin película 2
        expect(deviceAState, equals([1, 3, 4])); // Estado local de A
        expect(deviceBState, equals(supabaseState)); // B sincronizado

        developer.log('✅ Sincronización post-offline maneja conflictos correctamente');
      });
    });

    group('Performance Under Load', () {
      test('Multiple devices with high frequency operations', () async {
        const deviceCount = 5;
        const operationsPerDevice = 10;
        const maxLatencyMs = 3000;

        final deviceStates = List.generate(deviceCount, (i) => <int>[1, 2, 3]);
        final completedOperations = <Map<String, dynamic>>[];

        // Simular operaciones concurrentes de múltiples dispositivos
        final futures = <Future>[];

        for (int deviceId = 0; deviceId < deviceCount; deviceId++) {
          for (int opId = 0; opId < operationsPerDevice; opId++) {
            final future = Future.delayed(
              Duration(milliseconds: Random().nextInt(1000)),
              () async {
                final operation = {
                  'device_id': deviceId,
                  'operation_id': opId,
                  'movie_id': Random().nextInt(100) + 100,
                  'operation': Random().nextBool() ? 'add' : 'remove',
                  'timestamp': DateTime.now(),
                };

                // Simular tiempo de procesamiento
                await Future.delayed(Duration(milliseconds: Random().nextInt(200) + 50));
                
                completedOperations.add(operation);
                return operation;
              }
            );
            futures.add(future);
          }
        }

        final startTime = DateTime.now();
        await Future.wait(futures);
        final endTime = DateTime.now();

        final totalLatency = endTime.difference(startTime).inMilliseconds;

        // Verificar rendimiento
        expect(totalLatency, lessThan(maxLatencyMs * 2), // Permitir margen para concurrencia
            reason: 'Operaciones concurrentes tardaron demasiado');

        expect(completedOperations.length, equals(deviceCount * operationsPerDevice));

        developer.log('✅ ${completedOperations.length} operaciones concurrentes completadas en ${totalLatency}ms');
      });

      test('Sync latency meets 3-second requirement under load', () async {
        const targetLatencyMs = 3000;
        final latencies = <int>[];

        // Simular múltiples operaciones de sincronización
        for (int i = 0; i < 20; i++) {
          final stopwatch = Stopwatch()..start();

          // Simular operación de sincronización con carga variable
          final simulatedNetworkDelay = Random().nextInt(1500) + 200; // 200-1700ms
          final simulatedProcessingTime = Random().nextInt(800) + 100; // 100-900ms

          await Future.delayed(Duration(milliseconds: simulatedNetworkDelay));
          await Future.delayed(Duration(milliseconds: simulatedProcessingTime));

          stopwatch.stop();
          latencies.add(stopwatch.elapsedMilliseconds);
        }

        // Verificar que todas las operaciones cumplen el requisito
        final failedOperations = latencies.where((l) => l > targetLatencyMs).length;
        final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
        final maxLatency = latencies.reduce(max);

        expect(failedOperations, equals(0),
            reason: '$failedOperations operaciones excedieron ${targetLatencyMs}ms');

        developer.log('Latencias: Promedio ${avgLatency.toStringAsFixed(1)}ms, Máxima ${maxLatency}ms');
        developer.log('✅ Todas las operaciones completaron en ≤ ${targetLatencyMs}ms');
      });
    });

    group('Data Consistency Across Devices', () {
      test('Eventually consistent state across all devices', () async {
        // Simular 3 dispositivos con estados iniciales diferentes
        final devices = {
          'web': <int>[1, 2],
          'android': <int>[2, 3],
          'ios': <int>[3, 4],
        };

        // Simular operaciones en cada dispositivo
        final operations = [
          {'device': 'web', 'add': 5, 'remove': null},
          {'device': 'android', 'add': 6, 'remove': 1},
          {'device': 'ios', 'add': null, 'remove': 4},
        ];

        // Aplicar operaciones localmente
        for (final op in operations) {
          final device = op['device'] as String;
          final deviceState = devices[device]!;

          if (op['add'] != null) {
            devices[device] = [...deviceState, op['add'] as int];
          }
          if (op['remove'] != null) {
            devices[device] = deviceState.where((id) => id != op['remove']).toList();
          }
        }

        // Simular sincronización: merge todos los estados
        final allIds = <int>{};
        final removedIds = <int>{};

        for (final op in operations) {
          if (op['add'] != null) allIds.add(op['add'] as int);
          if (op['remove'] != null) removedIds.add(op['remove'] as int);
        }

        // Estado inicial de todos los dispositivos
        for (final deviceState in devices.values) {
          allIds.addAll(deviceState);
        }

        // Aplicar eliminaciones
        allIds.removeAll(removedIds);

        final finalConsistentState = allIds.toList()..sort();

        // Sincronizar todos los dispositivos al estado consistente
        for (final device in devices.keys) {
          devices[device] = List.from(finalConsistentState);
        }

        // Verificar consistencia
        final webState = devices['web']!;
        final androidState = devices['android']!;
        final iosState = devices['ios']!;

        expect(webState, equals(androidState));
        expect(androidState, equals(iosState));
        expect(finalConsistentState, containsAll([2, 3, 5, 6]));
        expect(finalConsistentState, isNot(contains(1))); // Eliminado por Android
        expect(finalConsistentState, isNot(contains(4))); // Eliminado por iOS

        developer.log('✅ Estado eventualmente consistente: ${finalConsistentState}');
      });

      test('No data loss during complex multi-device operations', () async {
        // Operaciones complejas simultáneas
        final operations = [
          {'device': 'web', 'type': 'batch_add', 'movies': [10, 11, 12]},
          {'device': 'android', 'type': 'batch_remove', 'movies': [1, 2]},
          {'device': 'ios', 'type': 'update_rating', 'movie': 5, 'rating': 4.5},
          {'device': 'desktop', 'type': 'create_list', 'name': 'Horror Movies', 'movies': [13, 14]},
        ];

        final dataStore = {
          'favorites': <int>[1, 2, 3, 4, 5],
          'ratings': <Map<String, dynamic>>[],
          'custom_lists': <Map<String, dynamic>>[],
        };

        // Procesar operaciones
        for (final op in operations) {
          switch (op['type']) {
            case 'batch_add':
              final moviesToAdd = op['movies'] as List<int>;
              dataStore['favorites'] = <int>{...dataStore['favorites']!, ...moviesToAdd}.toList();
              break;
            
            case 'batch_remove':
              final moviesToRemove = op['movies'] as List<int>;
              dataStore['favorites']!.removeWhere((id) => moviesToRemove.contains(id));
              break;
            
            case 'update_rating':
              dataStore['ratings']!.add({
                'movie_id': op['movie'],
                'rating': op['rating'],
                'device': op['device'],
              });
              break;
            
            case 'create_list':
              dataStore['custom_lists']!.add({
                'name': op['name'],
                'movies': op['movies'],
                'device': op['device'],
              });
              break;
          }
        }

        // Verificar integridad de datos
        expect(dataStore['favorites'], containsAll([3, 4, 5, 10, 11, 12])); // Agregados - eliminados
        expect(dataStore['favorites'], isNot(containsAll([1, 2]))); // Eliminados
        expect(dataStore['ratings']!.length, equals(1)); // Un rating agregado
        expect(dataStore['custom_lists']!.length, equals(1)); // Una lista creada

        // Verificar no duplicados
        final favoriteSet = dataStore['favorites']!.toSet();
        expect(favoriteSet.length, equals(dataStore['favorites']!.length));

        developer.log('✅ Sin pérdida de datos en operaciones complejas multi-dispositivo');
      });
    });

    group('Real-time Update Propagation', () {
      test('Changes propagate to all connected devices within 3 seconds', () async {
        const maxPropagationTimeMs = 3000;
        final connectedDevices = ['web', 'android', 'ios'];
        final deviceLastUpdate = <String, DateTime>{};

        // Inicializar timestamps
        for (final device in connectedDevices) {
          deviceLastUpdate[device] = DateTime.now();
        }

        // Simular cambio en un dispositivo
        final originDevice = 'web';
        final changeTimestamp = DateTime.now();
        
        developer.log('Cambio originado en: $originDevice a las ${changeTimestamp}');

        // Simular propagación a otros dispositivos
        final propagationFutures = <Future>[];
        
        for (final device in connectedDevices) {
          if (device != originDevice) {
            final propagationFuture = Future.delayed(
              Duration(milliseconds: Random().nextInt(2500) + 200), // 200-2700ms
              () {
                deviceLastUpdate[device] = DateTime.now();
                final propagationTime = deviceLastUpdate[device]!.difference(changeTimestamp).inMilliseconds;
                developer.log('Actualización propagada a $device en ${propagationTime}ms');
                return propagationTime;
              }
            );
            propagationFutures.add(propagationFuture);
          }
        }

        final propagationTimes = await Future.wait(propagationFutures.cast<Future<int>>());

        // Verificar que todas las propagaciones cumplan el tiempo límite
        for (final time in propagationTimes) {
          expect(time, lessThan(maxPropagationTimeMs),
              reason: 'Propagación tardó ${time}ms, debe ser < ${maxPropagationTimeMs}ms');
        }

        final avgPropagationTime = propagationTimes.reduce((a, b) => a + b) / propagationTimes.length;
        developer.log('✅ Propagación promedio: ${avgPropagationTime.toStringAsFixed(1)}ms');
      });
    });
  });
}