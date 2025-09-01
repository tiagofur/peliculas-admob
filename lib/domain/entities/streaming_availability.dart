import 'streaming_platform.dart';

/// Represents the availability of a movie on streaming platforms
class StreamingAvailability {
  const StreamingAvailability({
    required this.movieId,
    required this.movieTitle,
    required this.platforms,
    required this.lastUpdated,
    required this.region,
  });

  factory StreamingAvailability.fromJson(Map<String, dynamic> json) {
    return StreamingAvailability(
      movieId: json['movieId'] as int,
      movieTitle: json['movieTitle'] as String,
      platforms: (json['platforms'] as List)
          .map((p) => PlatformAvailability.fromJson(p as Map<String, dynamic>))
          .toList(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      region: json['region'] as String,
    );
  }
  final int movieId;
  final String movieTitle;
  final List<PlatformAvailability> platforms;
  final DateTime lastUpdated;
  final String region;

  Map<String, dynamic> toJson() {
    return {
      'movieId': movieId,
      'movieTitle': movieTitle,
      'platforms': platforms.map((p) => p.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'region': region,
    };
  }

  /// Get platforms where the movie is available for free
  List<PlatformAvailability> get freePlatforms {
    return platforms.where((p) => p.isFree).toList();
  }

  /// Get platforms where the movie requires subscription
  List<PlatformAvailability> get subscriptionPlatforms {
    return platforms.where((p) => p.requiresSubscription && !p.isFree).toList();
  }

  /// Get platforms where the movie can be rented
  List<PlatformAvailability> get rentalPlatforms {
    return platforms.where((p) => p.canRent).toList();
  }

  /// Get platforms where the movie can be purchased
  List<PlatformAvailability> get purchasePlatforms {
    return platforms.where((p) => p.canPurchase).toList();
  }

  /// Check if movie is available on any platform
  bool get isAvailable => platforms.isNotEmpty;

  /// Get the cheapest rental option
  PlatformAvailability? get cheapestRental {
    final rentals = rentalPlatforms;
    if (rentals.isEmpty) return null;

    return rentals.reduce((a, b) =>
        (a.rentalPrice ?? double.infinity) < (b.rentalPrice ?? double.infinity)
            ? a
            : b);
  }

  /// Get the cheapest purchase option
  PlatformAvailability? get cheapestPurchase {
    final purchases = purchasePlatforms;
    if (purchases.isEmpty) return null;

    return purchases.reduce((a, b) => (a.purchasePrice ?? double.infinity) <
            (b.purchasePrice ?? double.infinity)
        ? a
        : b);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StreamingAvailability &&
        other.movieId == movieId &&
        other.region == region;
  }

  @override
  int get hashCode => Object.hash(movieId, region);

  StreamingAvailability copyWith({
    int? movieId,
    String? movieTitle,
    List<PlatformAvailability>? platforms,
    DateTime? lastUpdated,
    String? region,
  }) {
    return StreamingAvailability(
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      platforms: platforms ?? this.platforms,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      region: region ?? this.region,
    );
  }
}

/// Represents availability details for a specific platform
class PlatformAvailability {
  const PlatformAvailability({
    required this.platform,
    required this.isAvailable,
    this.isFree = false,
    this.requiresSubscription = false,
    this.canRent = false,
    this.canPurchase = false,
    this.rentalPrice,
    this.purchasePrice,
    this.currency,
    this.deepLink,
    this.quality,
    this.audioLanguages = const [],
    this.subtitleLanguages = const [],
    this.availableUntil,
    this.metadata = const {},
  });

  factory PlatformAvailability.fromJson(Map<String, dynamic> json) {
    return PlatformAvailability(
      platform:
          StreamingPlatform.fromJson(json['platform'] as Map<String, dynamic>),
      isAvailable: json['isAvailable'] as bool,
      isFree: json['isFree'] as bool? ?? false,
      requiresSubscription: json['requiresSubscription'] as bool? ?? false,
      canRent: json['canRent'] as bool? ?? false,
      canPurchase: json['canPurchase'] as bool? ?? false,
      rentalPrice: (json['rentalPrice'] as num?)?.toDouble(),
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      deepLink: json['deepLink'] as String?,
      quality: json['quality'] as String?,
      audioLanguages: List<String>.from(json['audioLanguages'] as List? ?? []),
      subtitleLanguages:
          List<String>.from(json['subtitleLanguages'] as List? ?? []),
      availableUntil: json['availableUntil'] != null
          ? DateTime.parse(json['availableUntil'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
  final StreamingPlatform platform;
  final bool isAvailable;
  final bool isFree;
  final bool requiresSubscription;
  final bool canRent;
  final bool canPurchase;
  final double? rentalPrice;
  final double? purchasePrice;
  final String? currency;
  final String? deepLink;
  final String? quality; // HD, 4K, etc.
  final List<String> audioLanguages;
  final List<String> subtitleLanguages;
  final DateTime? availableUntil;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      'platform': platform.toJson(),
      'isAvailable': isAvailable,
      'isFree': isFree,
      'requiresSubscription': requiresSubscription,
      'canRent': canRent,
      'canPurchase': canPurchase,
      'rentalPrice': rentalPrice,
      'purchasePrice': purchasePrice,
      'currency': currency,
      'deepLink': deepLink,
      'quality': quality,
      'audioLanguages': audioLanguages,
      'subtitleLanguages': subtitleLanguages,
      'availableUntil': availableUntil?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Get formatted price string for rental
  String? get formattedRentalPrice {
    if (rentalPrice == null || currency == null) return null;
    return '${currency!}${rentalPrice!.toStringAsFixed(2)}';
  }

  /// Get formatted price string for purchase
  String? get formattedPurchasePrice {
    if (purchasePrice == null || currency == null) return null;
    return '${currency!}${purchasePrice!.toStringAsFixed(2)}';
  }

  /// Check if the content is expiring soon (within 7 days)
  bool get isExpiringSoon {
    if (availableUntil == null) return false;
    final now = DateTime.now();
    final difference = availableUntil!.difference(now);
    return difference.inDays <= 7 && difference.inDays >= 0;
  }

  /// Get availability type as string
  String get availabilityType {
    if (isFree) return 'Free';
    if (requiresSubscription) return 'Subscription';
    if (canRent && canPurchase) return 'Rent/Buy';
    if (canRent) return 'Rent';
    if (canPurchase) return 'Buy';
    return 'Available';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlatformAvailability && other.platform == platform;
  }

  @override
  int get hashCode => platform.hashCode;

  PlatformAvailability copyWith({
    StreamingPlatform? platform,
    bool? isAvailable,
    bool? isFree,
    bool? requiresSubscription,
    bool? canRent,
    bool? canPurchase,
    double? rentalPrice,
    double? purchasePrice,
    String? currency,
    String? deepLink,
    String? quality,
    List<String>? audioLanguages,
    List<String>? subtitleLanguages,
    DateTime? availableUntil,
    Map<String, dynamic>? metadata,
  }) {
    return PlatformAvailability(
      platform: platform ?? this.platform,
      isAvailable: isAvailable ?? this.isAvailable,
      isFree: isFree ?? this.isFree,
      requiresSubscription: requiresSubscription ?? this.requiresSubscription,
      canRent: canRent ?? this.canRent,
      canPurchase: canPurchase ?? this.canPurchase,
      rentalPrice: rentalPrice ?? this.rentalPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      currency: currency ?? this.currency,
      deepLink: deepLink ?? this.deepLink,
      quality: quality ?? this.quality,
      audioLanguages: audioLanguages ?? this.audioLanguages,
      subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
      availableUntil: availableUntil ?? this.availableUntil,
      metadata: metadata ?? this.metadata,
    );
  }
}
