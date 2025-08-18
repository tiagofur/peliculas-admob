import '../../../domain/entities/watch_provider.dart';
import '../../../domain/entities/watch_providers.dart';

class WatchProvidersResponse {
  WatchProvidersResponse({
    required this.id,
    required this.results,
  });

  factory WatchProvidersResponse.fromJson(Map<String, dynamic> json) {
    final resultsMap = <String, WatchProviders>{};

    if (json['results'] != null) {
      final results = json['results'] as Map<String, dynamic>;

      results.forEach((countryCode, countryData) {
        if (countryData is Map<String, dynamic>) {
          resultsMap[countryCode] = WatchProviders.fromJson(countryData);
        }
      });
    }

    return WatchProvidersResponse(
      id: json['id'] ?? 0,
      results: resultsMap,
    );
  }
  final int id;
  final Map<String, WatchProviders> results;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'results': results.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  /// Get providers for a specific country
  WatchProviders? getProvidersForCountry(String countryCode) {
    return results[countryCode.toUpperCase()];
  }

  /// Get providers for Mexico (MX)
  WatchProviders? get mexicoProviders => getProvidersForCountry('MX');

  /// Get providers for United States (US)
  WatchProviders? get usProviders => getProvidersForCountry('US');

  /// Get the first available providers (prioritizing MX, then US)
  WatchProviders? get primaryProviders {
    return mexicoProviders ?? usProviders ?? results.values.firstOrNull;
  }

  @override
  String toString() {
    return 'WatchProvidersResponse(id: $id, countries: ${results.keys.join(", ")})';
  }
}

class WatchProviderModel {
  WatchProviderModel({
    required this.providerId,
    required this.providerName,
    required this.logoPath,
    required this.displayPriority,
  });

  factory WatchProviderModel.fromJson(Map<String, dynamic> json) {
    return WatchProviderModel(
      providerId: json['provider_id'] ?? 0,
      providerName: json['provider_name'] ?? '',
      logoPath: json['logo_path'] ?? '',
      displayPriority: json['display_priority'] ?? 0,
    );
  }
  final int providerId;
  final String providerName;
  final String logoPath;
  final int displayPriority;

  WatchProvider toEntity() {
    return WatchProvider(
      providerId: providerId,
      providerName: providerName,
      logoPath: logoPath,
      displayPriority: displayPriority,
    );
  }
}
