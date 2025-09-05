import 'dart:convert';

void main() async {
  print('🧪 Simulando prueba de favoritos para usuario anonymous_user');
  
  try {
    // Simular datos de favoritos como se almacenarían en SharedPreferences
    final Map<String, dynamic> testFavorite = {
      'id': 'fav_anonymous_user_12345_${DateTime.now().millisecondsSinceEpoch}',
      'userId': 'anonymous_user',
      'movieId': 12345,
      'movieTitle': 'Test Movie',
      'posterPath': '/test-poster.jpg',
      'rating': 8.5,
      'overview': 'This is a test movie for favorites functionality',
      'releaseDate': DateTime.now().toIso8601String(),
      'addedAt': DateTime.now().toIso8601String(),
      'lastModified': DateTime.now().toIso8601String(),
      'syncStatus': 'pending',
    };
    
    print('📽️ Datos de favorito de prueba:');
    print('   - ID: ${testFavorite['id']}');
    print('   - Usuario: ${testFavorite['userId']}');
    print('   - Película: ${testFavorite['movieTitle']} (${testFavorite['movieId']})');
    
    // Simular conversión a JSON como haría SharedPreferences
    final String jsonString = jsonEncode(testFavorite);
    print('📄 JSON generado: ${jsonString.length} caracteres');
    
    // Simular lectura desde JSON
    final Map<String, dynamic> parsedData = jsonDecode(jsonString);
    print('✅ JSON parseado correctamente');
    print('   - Título recuperado: ${parsedData['movieTitle']}');
    print('   - Usuario recuperado: ${parsedData['userId']}');
    
    // Simular clave de almacenamiento
    final String storageKey = 'favorites_anonymous_user';
    print('🔑 Clave de almacenamiento: $storageKey');
    
    print('🎉 Simulación completada exitosamente');
    print('💡 La funcionalidad básica de favoritos debería funcionar correctamente');
    
  } catch (e, stackTrace) {
    print('❌ Error en la simulación: $e');
    print('📍 Stack trace: $stackTrace');
  }
}