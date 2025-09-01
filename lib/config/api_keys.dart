import 'package:flutter_dotenv/flutter_dotenv.dart';

// Archivo de configuración de claves API
// Las claves se cargan desde el archivo .env

const String theMovieDbApiKey = 'c0ebc54da33cf71326f548860eb6b5fb';

// Claves de Trakt.tv (constantes para web, desde .env para móvil)
const String traktApiKeyConst =
    '8969e2e8dd5d7ca6b3e9a7b5b476c7b7e4f3b1b0ad1d5d2f9e5e4e3c7e9e5b4a';
const String traktClientIdConst =
    '55a6473c0980bc594588b6c6c2fa28f2a084047f52a7530b0c6a7d3b56d7d131';
const String traktClientSecretConst =
    'b0aeb9f2273bea0d58ae75d71f63804f254dcb5f03e66e767d50ce8a3fcd680a';

// Claves de Trakt.tv desde .env
String get traktApiKey => dotenv.env['TRAKT_API_KEY'] ?? traktApiKeyConst;
String get traktClientId => dotenv.env['TRAKT_CLIENT_ID'] ?? traktClientIdConst;
String get traktClientSecret =>
    dotenv.env['TRAKT_CLIENT_SECRET'] ?? traktClientSecretConst;

// URLs base
class ApiUrls {
  static const String traktBase = 'https://api.trakt.tv';
  static const String tmdbBase = 'https://api.themoviedb.org/3';
  static const String tmdbImageBase = 'https://image.tmdb.org/t/p/w500';
}
