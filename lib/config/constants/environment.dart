import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/logging/logger_factory.dart';
import '../api_keys.dart';

class Environment {
  static String theMovieDbKey = 'No hay api key';
  static String traktClientId = 'No hay client id';
  static String traktClientSecret = 'No hay client secret';

  static Future<void> load() async {
    if (kIsWeb) {
      // En web, usar las constantes importadas
      theMovieDbKey = theMovieDbApiKey;
      traktClientId = traktClientIdConst;
      traktClientSecret = traktClientSecretConst;
      return;
    }
    // Para plataformas móviles y desktop, intentar cargar desde .env
    try {
      await dotenv.load(fileName: '.env');
      theMovieDbKey = dotenv.env['THE_MOVIEDB_KEY'] ?? theMovieDbKey;
      traktClientId = dotenv.env['TRAKT_CLIENT_ID'] ?? traktClientId;
      traktClientSecret =
          dotenv.env['TRAKT_CLIENT_SECRET'] ?? traktClientSecret;
    } catch (e) {
      // Fallback: deja el valor por defecto
      if (kDebugMode) {
        LoggerFactory.error('Error loading .env file: $e');
      }
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
    return {
      'theMovieDbApiKey': 'c0ebc54da33cf71326f548860eb6b5fb',
      'traktClientId':
          '55a6473c0980bc594588b6c6c2fa28f2a084047f52a7530b0c6a7d3b56d7d131',
      'traktClientSecret':
          'b0aeb9f2273bea0d58ae75d71f63804f254dcb5f03e66e767d50ce8a3fcd680a',
    };
  }
}
