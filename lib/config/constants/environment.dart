import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class Environment {

  static String theMovieDbKey = const String.fromEnvironment(
    'THE_MOVIEDB_KEY',
    defaultValue: 'No hay api key',
  );

  static Future<void> load() async {
    // Para plataforma web: usar únicamente String.fromEnvironment
    // Para otras plataformas (Android, iOS, desktop): usar .env como fallback
    if (kIsWeb) {
      // En web, usar solo variables de entorno del sistema/build
      // La variable ya está configurada por String.fromEnvironment
      return;
    }
    
    // Para plataformas móviles y desktop, intentar cargar desde .env
    try {
      await dotenv.load(fileName: '.env');
      theMovieDbKey = dotenv.env['THE_MOVIEDB_KEY'] ?? theMovieDbKey;
    } catch (e) {
      // Fallback to fromEnvironment if .env fails
      // The value will already be set by fromEnvironment
    }
  }


}