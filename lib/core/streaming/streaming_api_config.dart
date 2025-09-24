/// Configuration service for streaming platform APIs
class StreamingApiConfig {
  static const String _netflixApiKey =
      String.fromEnvironment('NETFLIX_API_KEY', defaultValue: '');
  static const String _primeVideoApiKey =
      String.fromEnvironment('PRIME_VIDEO_API_KEY', defaultValue: '');
  static const String _disneyPlusApiKey =
      String.fromEnvironment('DISNEY_PLUS_API_KEY', defaultValue: '');
  static const String _hboMaxApiKey =
      String.fromEnvironment('HBO_MAX_API_KEY', defaultValue: '');
  static const String _watchmodeApiKey =
      String.fromEnvironment('WATCHMODE_API_KEY', defaultValue: '');
  static const String _justWatchApiKey =
      String.fromEnvironment('JUSTWATCH_API_KEY', defaultValue: '');

  // API Endpoints
  static const String netflixBaseUrl = 'https://api.netflix.com/v1';
  static const String primeVideoBaseUrl = 'https://api.primevideo.com/v1';
  static const String disneyPlusBaseUrl = 'https://api.disneyplus.com/v1';
  static const String hboMaxBaseUrl = 'https://api.hbomax.com/v1';

  // Third-party streaming availability APIs
  static const String watchmodeBaseUrl = 'https://api.watchmode.com/v1';
  static const String justWatchBaseUrl = 'https://apis.justwatch.com/content';
  static const String utelllyBaseUrl =
      'https://utelly-tv-shows-and-movies-availability-v1.p.rapidapi.com';

  // API Keys getters
  static String get netflixApiKey => _netflixApiKey;
  static String get primeVideoApiKey => _primeVideoApiKey;
  static String get disneyPlusApiKey => _disneyPlusApiKey;
  static String get hboMaxApiKey => _hboMaxApiKey;
  static String get watchmodeApiKey => _watchmodeApiKey;
  static String get justWatchApiKey => _justWatchApiKey;

  // Base URL getters (removed duplicate definitions)

  // Check if API keys are configured
  static bool get isNetflixConfigured => _netflixApiKey.isNotEmpty;
  static bool get isPrimeVideoConfigured => _primeVideoApiKey.isNotEmpty;
  static bool get isDisneyPlusConfigured => _disneyPlusApiKey.isNotEmpty;
  static bool get isHboMaxConfigured => _hboMaxApiKey.isNotEmpty;
  static bool get isWatchmodeConfigured => _watchmodeApiKey.isNotEmpty;
  static bool get isJustWatchConfigured => _justWatchApiKey.isNotEmpty;

  // Alternative getters for compatibility
  static bool get hasNetflixApiKey => isNetflixConfigured;
  static bool get hasPrimeVideoApiKey => isPrimeVideoConfigured;
  static bool get hasDisneyPlusApiKey => isDisneyPlusConfigured;
  static bool get hasHboMaxApiKey => isHboMaxConfigured;

  // Check if any streaming API is configured
  static bool get hasAnyStreamingApi =>
      isNetflixConfigured ||
      isPrimeVideoConfigured ||
      isDisneyPlusConfigured ||
      isHboMaxConfigured;

  // Check if any availability API is configured
  static bool get hasAnyAvailabilityApi =>
      isWatchmodeConfigured || isJustWatchConfigured;

  // Request headers for different platforms
  static Map<String, String> get netflixHeaders => {
        'Authorization': 'Bearer $netflixApiKey',
        'Content-Type': 'application/json',
        'User-Agent': 'PeliculasApp/1.0',
      };

  static Map<String, String> get primeVideoHeaders => {
        'Authorization': 'Bearer $primeVideoApiKey',
        'Content-Type': 'application/json',
        'User-Agent': 'PeliculasApp/1.0',
      };

  static Map<String, String> get disneyPlusHeaders => {
        'Authorization': 'Bearer $disneyPlusApiKey',
        'Content-Type': 'application/json',
        'User-Agent': 'PeliculasApp/1.0',
      };

  static Map<String, String> get hboMaxHeaders => {
        'Authorization': 'Bearer $hboMaxApiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Get headers for Watchmode API
  static Map<String, String> get watchmodeHeaders => {
        'X-API-Key': watchmodeApiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Get headers for JustWatch API
  static Map<String, String> get justWatchHeaders => {
        'Authorization': 'Bearer $justWatchApiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Rate limiting configuration
  static const Duration rateLimitDelay = Duration(milliseconds: 100);
  static const int maxRetries = 3;
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Cache configuration
  static const Duration cacheExpiration = Duration(hours: 6);
  static const Duration availabilityCacheExpiration = Duration(hours: 1);
  static const int maxCacheSize = 1000;
}
