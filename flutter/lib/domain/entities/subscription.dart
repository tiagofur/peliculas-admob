import 'streaming_platform.dart';

/// Represents a user's subscription to a streaming platform
class Subscription {
  const Subscription({
    required this.id,
    required this.userId,
    required this.platform,
    required this.status,
    required this.tier,
    required this.startDate,
    this.endDate,
    this.nextBillingDate,
    this.monthlyPrice,
    this.currency,
    required this.autoRenew,
    this.features = const [],
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      userId: json['userId'] as String,
      platform:
          StreamingPlatform.fromJson(json['platform'] as Map<String, dynamic>),
      status: SubscriptionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SubscriptionStatus.inactive,
      ),
      tier: SubscriptionTier.values.firstWhere(
        (t) => t.name == json['tier'],
        orElse: () => SubscriptionTier.basic,
      ),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      nextBillingDate: json['nextBillingDate'] != null
          ? DateTime.parse(json['nextBillingDate'] as String)
          : null,
      monthlyPrice: (json['monthlyPrice'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      autoRenew: json['autoRenew'] as bool,
      features: List<String>.from(json['features'] as List? ?? []),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
  final String id;
  final String userId;
  final StreamingPlatform platform;
  final SubscriptionStatus status;
  final SubscriptionTier tier;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextBillingDate;
  final double? monthlyPrice;
  final String? currency;
  final bool autoRenew;
  final List<String> features;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'platform': platform.toJson(),
      'status': status.name,
      'tier': tier.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'nextBillingDate': nextBillingDate?.toIso8601String(),
      'monthlyPrice': monthlyPrice,
      'currency': currency,
      'autoRenew': autoRenew,
      'features': features,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Check if subscription is currently active
  bool get isActive {
    return status == SubscriptionStatus.active &&
        (endDate == null || endDate?.isAfter(DateTime.now()) == true);
  }

  /// Check if subscription is expiring soon (within 7 days)
  bool get isExpiringSoon {
    final end = endDate;
    if (end == null || !isActive) return false;
    final now = DateTime.now();
    final difference = end.difference(now);
    return difference.inDays <= 7 && difference.inDays >= 0;
  }

  /// Get days until expiration
  int? get daysUntilExpiration {
    final end = endDate;
    if (end == null) return null;
    final now = DateTime.now();
    final difference = end.difference(now);
    return difference.inDays;
  }

  /// Get formatted monthly price
  String? get formattedMonthlyPrice {
    final price = monthlyPrice;
    final curr = currency;
    if (price == null || curr == null) return null;
    return '$curr${price.toStringAsFixed(2)}/month';
  }

  /// Get subscription duration in months
  int get durationInMonths {
    final end = endDate ?? DateTime.now();
    final difference = end.difference(startDate);
    return (difference.inDays / 30).round();
  }

  /// Check if subscription has specific feature
  bool hasFeature(String feature) {
    return features.contains(feature);
  }

  /// Get subscription display name
  String get displayName {
    return '${platform.displayName} ${tier.displayName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Subscription && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Subscription(id: $id, platform: ${platform.name}, status: ${status.name}, tier: ${tier.name})';
  }

  Subscription copyWith({
    String? id,
    String? userId,
    StreamingPlatform? platform,
    SubscriptionStatus? status,
    SubscriptionTier? tier,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextBillingDate,
    double? monthlyPrice,
    String? currency,
    bool? autoRenew,
    List<String>? features,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      platform: platform ?? this.platform,
      status: status ?? this.status,
      tier: tier ?? this.tier,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      currency: currency ?? this.currency,
      autoRenew: autoRenew ?? this.autoRenew,
      features: features ?? this.features,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Subscription status enumeration
enum SubscriptionStatus {
  active('Active'),
  inactive('Inactive'),
  cancelled('Cancelled'),
  expired('Expired'),
  suspended('Suspended'),
  trial('Trial'),
  pastDue('Past Due');

  const SubscriptionStatus(this.displayName);
  final String displayName;

  bool get isActive =>
      this == SubscriptionStatus.active || this == SubscriptionStatus.trial;
  bool get needsAttention =>
      this == SubscriptionStatus.pastDue ||
      this == SubscriptionStatus.suspended;
}

/// Subscription tier enumeration
enum SubscriptionTier {
  basic('Basic'),
  standard('Standard'),
  premium('Premium'),
  family('Family'),
  student('Student'),
  annual('Annual');

  const SubscriptionTier(this.displayName);
  final String displayName;

  /// Get typical features for each tier
  List<String> get typicalFeatures {
    switch (this) {
      case SubscriptionTier.basic:
        return ['SD Quality', 'Limited Downloads', '1 Screen'];
      case SubscriptionTier.standard:
        return ['HD Quality', 'Downloads', '2 Screens'];
      case SubscriptionTier.premium:
        return ['4K Quality', 'Unlimited Downloads', '4 Screens', 'HDR'];
      case SubscriptionTier.family:
        return ['HD Quality', 'Downloads', '6 Screens', 'Parental Controls'];
      case SubscriptionTier.student:
        return [
          'HD Quality',
          'Limited Downloads',
          '1 Screen',
          'Student Discount'
        ];
      case SubscriptionTier.annual:
        return ['HD Quality', 'Downloads', '2 Screens', 'Annual Billing'];
    }
  }
}

/// User's subscription summary across all platforms
class SubscriptionSummary {
  const SubscriptionSummary({
    required this.userId,
    required this.subscriptions,
    required this.totalMonthlySpend,
    required this.currency,
    required this.activeSubscriptions,
    required this.expiringSoon,
    required this.lastUpdated,
  });

  factory SubscriptionSummary.fromSubscriptions({
    required String userId,
    required List<Subscription> subscriptions,
    String currency = 'USD',
  }) {
    final activeCount = subscriptions.where((s) => s.isActive).length;
    final expiringCount = subscriptions.where((s) => s.isExpiringSoon).length;
    final totalSpend = subscriptions
        .where((s) => s.isActive && s.monthlyPrice != null)
        .fold<double>(0.0, (sum, s) => sum + s.monthlyPrice!);

    return SubscriptionSummary(
      userId: userId,
      subscriptions: subscriptions,
      totalMonthlySpend: totalSpend,
      currency: currency,
      activeSubscriptions: activeCount,
      expiringSoon: expiringCount,
      lastUpdated: DateTime.now(),
    );
  }
  final String userId;
  final List<Subscription> subscriptions;
  final double totalMonthlySpend;
  final String currency;
  final int activeSubscriptions;
  final int expiringSoon;
  final DateTime lastUpdated;

  /// Get subscriptions by status
  List<Subscription> getByStatus(SubscriptionStatus status) {
    return subscriptions.where((s) => s.status == status).toList();
  }

  /// Get subscriptions by platform
  List<Subscription> getByPlatform(String platformId) {
    return subscriptions.where((s) => s.platform.id == platformId).toList();
  }

  /// Get formatted total monthly spend
  String get formattedTotalSpend {
    return '$currency${totalMonthlySpend.toStringAsFixed(2)}/month';
  }

  /// Get annual spend estimate
  double get estimatedAnnualSpend {
    return totalMonthlySpend * 12;
  }

  /// Get formatted annual spend
  String get formattedAnnualSpend {
    return '$currency${estimatedAnnualSpend.toStringAsFixed(2)}/year';
  }
}
