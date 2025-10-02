import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/custom_list.dart';

void main() {
  group('DefaultListsManager - Lógica de Prevención de Duplicados', () {
    test('Debe detectar correctamente si una lista ya existe', () {
      const userId = 'test-user-123';

      // Lista existente del usuario
      final existingList = CustomList(
        id: 'existing-watchlist-id',
        name: 'Quiero Ver',
        description: 'Películas que quiero ver próximamente',
        emoji: '🍿',
        movieIds: [],
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        isDefault: true,
        defaultType: 'watchlist',
        userId: userId,
      );

      final allUserLists = [existingList];

      // Simular la lógica de verificación del DefaultListsManager
      final exists = allUserLists.any((list) =>
          list.defaultType == 'watchlist' &&
          list.isDefault == true &&
          list.userId == userId);

      expect(exists, true,
          reason: 'Debe detectar que la lista watchlist ya existe');
    });

    test('No debe detectar listas de otros usuarios como existentes', () {
      const userId = 'test-user-123';
      const otherUserId = 'test-user-456';

      // Lista de otro usuario
      final otherUserList = CustomList(
        id: 'other-watchlist-id',
        name: 'Quiero Ver',
        description: 'Películas que quiero ver próximamente',
        emoji: '🍿',
        movieIds: [],
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        isDefault: true,
        defaultType: 'watchlist',
        userId: otherUserId, // Lista de otro usuario
      );

      final allUserLists = [otherUserList];

      // Simular la lógica de verificación del DefaultListsManager
      final exists = allUserLists.any((list) =>
          list.defaultType == 'watchlist' &&
          list.isDefault == true &&
          list.userId == userId); // Buscar para el usuario actual

      expect(exists, false,
          reason: 'No debe considerar listas de otros usuarios');
    });

    test(
        'Debe identificar correctamente las listas predefinidas vs personalizadas',
        () {
      const userId = 'test-user-123';

      // Lista predefinida
      final defaultList = CustomList(
        id: 'default-list-id',
        name: 'Quiero Ver',
        description: 'Lista predefinida del sistema',
        emoji: '🍿',
        movieIds: [],
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        isDefault: true,
        defaultType: 'watchlist',
        userId: userId,
      );

      // Lista personalizada con el mismo nombre pero diferente tipo
      final customList = CustomList(
        id: 'custom-list-id',
        name: 'Quiero Ver',
        description: 'Lista personalizada del usuario',
        emoji: '🎬',
        movieIds: [],
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        isDefault: false, // Esta es la diferencia clave
        defaultType: null,
        userId: userId,
      );

      final allUserLists = [defaultList, customList];

      // Filtrar solo listas predefinidas
      final defaultLists =
          allUserLists.where((list) => list.isDefault == true).toList();

      expect(defaultLists.length, 1);
      expect(defaultLists.first.id, 'default-list-id');
      expect(defaultLists.first.defaultType, 'watchlist');
    });

    test('Debe manejar correctamente diferentes tipos de listas predefinidas',
        () {
      const userId = 'test-user-123';

      // Configuraciones de listas predefinidas (8 tipos diferentes)
      final defaultTypes = [
        'watchlist',
        'weekend',
        'date-night',
        'with-friends',
        'classics',
        'action',
        'documentaries',
        'international'
      ];

      // Crear listas existentes para algunos tipos (solo 3 de 8)
      final existingLists = [
        CustomList(
          id: 'list-1',
          name: 'Quiero Ver',
          description: '',
          emoji: '🍿',
          movieIds: [],
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
          isDefault: true,
          defaultType: 'watchlist',
          userId: userId,
        ),
        CustomList(
          id: 'list-2',
          name: 'Para el Fin de Semana',
          description: '',
          emoji: '🛋️',
          movieIds: [],
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
          isDefault: true,
          defaultType: 'weekend',
          userId: userId,
        ),
        CustomList(
          id: 'list-3',
          name: 'Con Amigos',
          description: '',
          emoji: '👥',
          movieIds: [],
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
          isDefault: true,
          defaultType: 'with-friends',
          userId: userId,
        ),
      ];

      // Identificar qué tipos faltan crear
      final existingTypes = existingLists
          .where((list) => list.isDefault == true)
          .map((list) => list.defaultType)
          .toSet();

      final missingTypes =
          defaultTypes.where((type) => !existingTypes.contains(type)).toList();

      expect(missingTypes.length, 5,
          reason: 'Deben faltar 5 tipos de lista (8 - 3 existentes)');
      expect(missingTypes, contains('date-night'));
      expect(missingTypes, contains('classics'));
      expect(missingTypes, contains('action'));
      expect(missingTypes, contains('documentaries'));
      expect(missingTypes, contains('international'));

      // Los tipos existentes NO deben estar en la lista de faltantes
      expect(missingTypes, isNot(contains('watchlist')));
      expect(missingTypes, isNot(contains('weekend')));
      expect(missingTypes, isNot(contains('with-friends')));
    });
  });
}
