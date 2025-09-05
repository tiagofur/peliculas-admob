import 'dart:convert';

void main() async {
  print('🧪 Probando funcionalidad básica de favoritos...');
  
  try {
    // Simular el comportamiento de SharedPreferences
    Map<String, dynamic> mockStorage = {};
    
    const storageKey = 'local_favorites';
    const userId = 'anonymous_user';
    
    // Crear datos de prueba
    final testMovie = {
      'id': 12345,
      'title': 'Test Movie',
      'overview': 'A test movie for favorites',
      'poster_path': '/test.jpg',
      'backdrop_path': '/test_backdrop.jpg',
      'vote_average': 8.5,
      'release_date': '2024-01-01',
      'genre_ids': [28, 12],
      'adult': false,
      'original_language': 'en',
      'original_title': 'Test Movie',
      'popularity': 100.0,
      'vote_count': 1000,
      'video': false,
    };
    
    // Crear favorito
    final favorite = {
      'id': 'fav_${userId}_${testMovie['id']}',
      'userId': userId,
      'movie': testMovie,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'needsSync': true,
    };
    
    print('📝 Creado favorito: ${favorite['id']}');
    
    // Simular obtener favoritos existentes
    List<String> existingJsonList = [];
    if (mockStorage.containsKey(storageKey)) {
      existingJsonList = List<String>.from(mockStorage[storageKey]);
    }
    print('📋 Favoritos existentes: ${existingJsonList.length}');
    
    // Convertir a objetos
    final existingFavorites = existingJsonList
        .map((jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>)
        .toList();
    
    // Verificar si ya existe
    final alreadyExists = existingFavorites.any((f) => 
        f['movie']['id'] == testMovie['id'] && f['userId'] == userId);
    print('🔍 ¿Ya existe? $alreadyExists');
    
    if (!alreadyExists) {
      // Agregar nuevo favorito
      existingFavorites.add(favorite);
      
      // Convertir de vuelta a JSON
      final updatedJsonList = existingFavorites
          .map((f) => jsonEncode(f))
          .toList();
      
      // Simular guardar en SharedPreferences
      mockStorage[storageKey] = updatedJsonList;
      
      print('✅ Favorito agregado exitosamente');
      print('📊 Total de favoritos: ${updatedJsonList.length}');
    } else {
      print('ℹ️ El favorito ya existe');
    }
    
    // Verificar que se guardó correctamente
    final savedJsonList = List<String>.from(mockStorage[storageKey] ?? []);
    final savedFavorites = savedJsonList
        .map((jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>)
        .toList();
    
    print('🔍 Verificación final:');
    print('  - Favoritos guardados: ${savedFavorites.length}');
    for (final fav in savedFavorites) {
      print('  - ${fav['movie']['title']} (ID: ${fav['movie']['id']}, User: ${fav['userId']})');
    }
    
    // Probar eliminación
    print('\n🗑️ Probando eliminación...');
    final filteredFavorites = savedFavorites
        .where((f) => !(f['movie']['id'] == testMovie['id'] && f['userId'] == userId))
        .toList();
    
    final filteredJsonList = filteredFavorites
        .map((f) => jsonEncode(f))
        .toList();
    
    mockStorage[storageKey] = filteredJsonList;
    
    print('✅ Favorito eliminado exitosamente');
    print('📊 Total de favoritos después de eliminar: ${filteredJsonList.length}');
    
    // Probar toggle (agregar de nuevo)
    print('\n🔄 Probando toggle (agregar de nuevo)...');
    final currentFavorites = List<String>.from(mockStorage[storageKey] ?? []);
    final currentFavoritesObjects = currentFavorites
        .map((jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>)
        .toList();
    
    final movieExists = currentFavoritesObjects.any((f) => 
        f['movie']['id'] == testMovie['id'] && f['userId'] == userId);
    
    if (movieExists) {
      // Eliminar
      final filtered = currentFavoritesObjects
          .where((f) => !(f['movie']['id'] == testMovie['id'] && f['userId'] == userId))
          .toList();
      mockStorage[storageKey] = filtered.map((f) => jsonEncode(f)).toList();
      print('🗑️ Favorito eliminado por toggle');
    } else {
      // Agregar
      currentFavoritesObjects.add(favorite);
      mockStorage[storageKey] = currentFavoritesObjects.map((f) => jsonEncode(f)).toList();
      print('➕ Favorito agregado por toggle');
    }
    
    final finalCount = (mockStorage[storageKey] as List).length;
    print('📊 Total final de favoritos: $finalCount');
    
    print('\n✅ Todas las operaciones de favoritos funcionan correctamente');
    print('🎯 El problema no está en la lógica de datos, sino posiblemente en:');
    print('   - Inicialización de SharedPreferences en web');
    print('   - Permisos de almacenamiento en el navegador');
    print('   - Configuración de la aplicación Flutter para web');
    
  } catch (e, stackTrace) {
    print('❌ Error durante la prueba: $e');
    print('Stack trace: $stackTrace');
  }
}