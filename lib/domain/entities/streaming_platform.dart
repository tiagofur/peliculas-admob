import 'package:flutter/material.dart';

/// Represents a streaming platform (Netflix, Prime Video, etc.)
class StreamingPlatform {
  const StreamingPlatform({
    required this.id,
    required this.name,
    required this.displayName,
    required this.logoUrl,
    required this.baseUrl,
    required this.deepLinkScheme,
    required this.supportedCountries,
    required this.requiresSubscription,
    this.subscriptionUrl,
    this.metadata = const {},
  });

  factory StreamingPlatform.fromJson(Map<String, dynamic> json) {
    return StreamingPlatform(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      logoUrl: json['logoUrl'] as String,
      baseUrl: json['baseUrl'] as String,
      deepLinkScheme: json['deepLinkScheme'] as String,
      supportedCountries: List<String>.from(json['supportedCountries'] as List),
      requiresSubscription: json['requiresSubscription'] as bool,
      subscriptionUrl: json['subscriptionUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
  final String id;
  final String name;
  final String displayName;
  final String logoUrl;
  final String baseUrl;
  final String deepLinkScheme;
  final List<String> supportedCountries;
  final bool requiresSubscription;
  final String? subscriptionUrl;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'logoUrl': logoUrl,
      'baseUrl': baseUrl,
      'deepLinkScheme': deepLinkScheme,
      'supportedCountries': supportedCountries,
      'requiresSubscription': requiresSubscription,
      'subscriptionUrl': subscriptionUrl,
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StreamingPlatform && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'StreamingPlatform(id: $id, name: $name, displayName: $displayName)';
  }

  /// Get the primary color for this platform
  Color get primaryColor {
    switch (id) {
      case 'netflix':
        return const Color(0xFFE50914);
      case 'amazon_prime':
        return const Color(0xFF00A8E1);
      case 'disney_plus':
        return const Color(0xFF113CCF);
      case 'hbo_max':
        return const Color(0xFF8B5CF6);
      case 'hulu':
        return const Color(0xFF1CE783);
      case 'apple_tv':
        return const Color(0xFF000000);
      default:
        return const Color(0xFF6B7280);
    }
  }

  /// Get the website URL for this platform
  String get websiteUrl => baseUrl;

  /// URL del icono de la plataforma
  String get iconUrl {
    switch (id) {
      case 'netflix':
        return 'assets/icons/netflix.png';
      case 'disney_plus':
        return 'assets/icons/disney_plus.png';
      case 'hbo_max':
        return 'assets/icons/hbo_max.png';
      case 'prime_video':
        return 'assets/icons/prime_video.png';
      case 'apple_tv':
        return 'assets/icons/apple_tv.png';
      case 'paramount_plus':
        return 'assets/icons/paramount_plus.png';
      case 'peacock':
        return 'assets/icons/peacock.png';
      default:
        return 'assets/icons/default_platform.png';
    }
  }

  StreamingPlatform copyWith({
    String? id,
    String? name,
    String? displayName,
    String? logoUrl,
    String? baseUrl,
    String? deepLinkScheme,
    List<String>? supportedCountries,
    bool? requiresSubscription,
    String? subscriptionUrl,
    Map<String, dynamic>? metadata,
  }) {
    return StreamingPlatform(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      logoUrl: logoUrl ?? this.logoUrl,
      baseUrl: baseUrl ?? this.baseUrl,
      deepLinkScheme: deepLinkScheme ?? this.deepLinkScheme,
      supportedCountries: supportedCountries ?? this.supportedCountries,
      requiresSubscription: requiresSubscription ?? this.requiresSubscription,
      subscriptionUrl: subscriptionUrl ?? this.subscriptionUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  // Predefined popular streaming platforms
  static const StreamingPlatform netflix = StreamingPlatform(
    id: 'netflix',
    name: 'Netflix',
    displayName: 'Netflix',
    logoUrl:
        'https://assets.nflxext.com/us/ffe/siteui/common/icons/nficon2016.png',
    baseUrl: 'https://www.netflix.com',
    deepLinkScheme: 'nflx',
    supportedCountries: [
      'US',
      'CA',
      'GB',
      'DE',
      'FR',
      'ES',
      'IT',
      'BR',
      'MX',
      'AR'
    ],
    requiresSubscription: true,
    subscriptionUrl: 'https://www.netflix.com/signup',
  );

  static const StreamingPlatform amazonPrime = StreamingPlatform(
    id: 'amazon_prime',
    name: 'Amazon Prime Video',
    displayName: 'Prime Video',
    logoUrl:
        'https://m.media-amazon.com/images/G/01/digital/video/web/Logo-min.png',
    baseUrl: 'https://www.primevideo.com',
    deepLinkScheme: 'aiv',
    supportedCountries: [
      'US',
      'CA',
      'GB',
      'DE',
      'FR',
      'ES',
      'IT',
      'BR',
      'MX',
      'AR'
    ],
    requiresSubscription: true,
    subscriptionUrl: 'https://www.amazon.com/prime',
  );

  static const StreamingPlatform disneyPlus = StreamingPlatform(
    id: 'disney_plus',
    name: 'Disney+',
    displayName: 'Disney+',
    logoUrl:
        'https://cnbl-cdn.bamgrid.com/assets/7ecc8bcb60ad77193058d63e321bd21cbac2fc67.png',
    baseUrl: 'https://www.disneyplus.com',
    deepLinkScheme: 'disneyplus',
    supportedCountries: [
      'US',
      'CA',
      'GB',
      'DE',
      'FR',
      'ES',
      'IT',
      'BR',
      'MX',
      'AR'
    ],
    requiresSubscription: true,
    subscriptionUrl: 'https://www.disneyplus.com/sign-up',
  );

  static const StreamingPlatform hboMax = StreamingPlatform(
    id: 'hbo_max',
    name: 'HBO Max',
    displayName: 'HBO Max',
    logoUrl:
        'https://play-lh.googleusercontent.com/1iyX7VdQ7MlM7iotI9XDtTwgiVmqFGzqwz3zqHQJIZxOTNS2-2wLkzNX8w_2wCHn-w',
    baseUrl: 'https://www.hbomax.com',
    deepLinkScheme: 'hbomax',
    supportedCountries: [
      'US',
      'CA',
      'GB',
      'DE',
      'FR',
      'ES',
      'IT',
      'BR',
      'MX',
      'AR'
    ],
    requiresSubscription: true,
    subscriptionUrl: 'https://www.hbomax.com/subscribe',
  );

  static const StreamingPlatform hulu = StreamingPlatform(
    id: 'hulu',
    name: 'Hulu',
    displayName: 'Hulu',
    logoUrl:
        'https://www.hulu.com/static/hitch/s3/attachments/ckh0k8dxr0001z8m8qjvz8v8x-hulu-logo-green.full.png',
    baseUrl: 'https://www.hulu.com',
    deepLinkScheme: 'hulu',
    supportedCountries: ['US'],
    requiresSubscription: true,
    subscriptionUrl: 'https://www.hulu.com/start',
  );

  static const StreamingPlatform appleTV = StreamingPlatform(
    id: 'apple_tv',
    name: 'Apple TV+',
    displayName: 'Apple TV+',
    logoUrl:
        'https://www.apple.com/v/apple-tv-plus/b/images/overview/apple_tv_plus_logo__c9e0qze1jyuu_large.png',
    baseUrl: 'https://tv.apple.com',
    deepLinkScheme: 'com.apple.tv',
    supportedCountries: [
      'US',
      'CA',
      'GB',
      'DE',
      'FR',
      'ES',
      'IT',
      'BR',
      'MX',
      'AR'
    ],
    requiresSubscription: true,
    subscriptionUrl: 'https://tv.apple.com',
  );

  // Getter aliases for backward compatibility
  static StreamingPlatform get primeVideo => amazonPrime;
  static StreamingPlatform get appleTv => appleTV;

  // Additional platforms (placeholders for future implementation)
  static const StreamingPlatform paramountPlus = StreamingPlatform(
    id: 'paramount_plus',
    name: 'Paramount+',
    displayName: 'Paramount+',
    logoUrl: 'https://www.paramountplus.com/favicon.ico',
    baseUrl: 'https://www.paramountplus.com',
    deepLinkScheme: 'paramountplus',
    supportedCountries: ['US', 'CA'],
    requiresSubscription: true,
    subscriptionUrl: 'https://www.paramountplus.com/account/signup',
  );

  static const StreamingPlatform peacock = StreamingPlatform(
    id: 'peacock',
    name: 'Peacock',
    displayName: 'Peacock',
    logoUrl: 'https://www.peacocktv.com/favicon.ico',
    baseUrl: 'https://www.peacocktv.com',
    deepLinkScheme: 'peacocktv',
    supportedCountries: ['US'],
    requiresSubscription: true,
    subscriptionUrl: 'https://www.peacocktv.com/premium',
  );

  static List<StreamingPlatform> get allPlatforms => [
        netflix,
        amazonPrime,
        disneyPlus,
        hboMax,
        hulu,
        appleTV,
        paramountPlus,
        peacock,
      ];
}
