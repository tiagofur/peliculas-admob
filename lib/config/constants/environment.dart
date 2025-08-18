import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../api_keys.dart';

class Environment {
  static String theMovieDbKey = 'No hay api key';

  static Future<void> load() async {
    if (kIsWeb) {
      // En web, usar la constante importada
      theMovieDbKey = theMovieDbApiKey;
      return;
    }
    // Para plataformas móviles y desktop, intentar cargar desde .env
    try {
      await dotenv.load(fileName: '.env');
      theMovieDbKey = dotenv.env['THE_MOVIEDB_KEY'] ?? theMovieDbKey;
    } catch (e) {
      // Fallback: deja el valor por defecto
    }
  }

// Helper para importar la constante solo en web
// ignore: avoid_web_libraries_in_flutter
  Future<Map<String, String>> importApiKeys() async {
    // Importa el archivo de claves
    // En web, puedes usar un import directo
    // Aquí se simula el import, pero en tu código real puedes hacer:
    // import 'package:peliculas-admob/config/api_keys.dart' as api_keys;
    // return {'theMovieDbApiKey': api_keys.theMovieDbApiKey};
    // Para este ejemplo, simplemente retorna la constante
    return {'theMovieDbApiKey': 'c0ebc54da33cf71326f548860eb6b5fb'};
  }
}
