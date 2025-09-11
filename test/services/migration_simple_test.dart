import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/services/id_mapping_service.dart';
import '../../lib/domain/entities/custom_list.dart';
import '../../lib/domain/entities/list_item.dart';

void main() {
  group('Migration Basic Tests', () {
    late IdMappingService idMappingService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      idMappingService = IdMappingService(prefs);
    });

    test('Debe crear IdMappingService correctamente', () {
      expect(idMappingService, isNotNull);
    });

    test('Debe mapear ID local a UUID', () async {
      // Arrange
      const localId = 1;
      const uuid = 'test-uuid-123';
      
      // Act
      await idMappingService.mapLocalIdToUuid(localId, uuid);
      final mappedUuid = await idMappingService.getUuidForLocalId(localId);
      
      // Assert
      expect(mappedUuid, equals(uuid));
    });

    test('Debe retornar null para ID no mapeado', () async {
      // Act
      final mappedUuid = await idMappingService.getUuidForLocalId(999);
      
      // Assert
      expect(mappedUuid, isNull);
    });

    test('Debe crear CustomList con datos válidos', () {
      // Arrange & Act
      final customList = CustomList(
        id: 'test-id',
        name: 'Test List',
        description: 'Test Description',
        emoji: '🎬',
        colorHex: '#FF5722',
        movieIds: [1, 2],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDefault: false,
        defaultType: null,
      );
      
      // Assert
      expect(customList.id, equals('test-id'));
      expect(customList.name, equals('Test List'));
      expect(customList.movieIds.length, equals(2));
      expect(customList.isDefault, isFalse);
    });

    test('Debe crear DefaultListConfig con datos válidos', () {
      // Arrange & Act
      const config = DefaultListConfig(
        localId: 'favorites',
        name: 'Favoritas',
        description: 'Mis películas favoritas',
        emoji: '❤️',
        color: '#E91E63',
        defaultType: 'favorites',
      );
      
      // Assert
      expect(config.defaultType, equals('favorites'));
      expect(config.name, equals('Favoritas'));
      expect(config.emoji, equals('❤️'));
    });
  });
}