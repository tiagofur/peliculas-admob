/// Entity representing a user's subscription to a streaming platform
class UserSubscription {
  const UserSubscription({
    required this.id,
    required this.platformId,
    required this.platformName,
    required this.type,
    required this.monthlyCost,
    required this.startDate,
    this.endDate,
    this.nextBillingDate,
    required this.isActive,
    this.autoRenew = true,
    this.billingCycle,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from JSON
  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'] as String,
      platformId: json['platformId'] as String,
      platformName: json['platformName'] as String,
      type: SubscriptionType.fromString(json['type'] as String),
      monthlyCost: (json['monthlyCost'] as num).toDouble(),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      nextBillingDate: json['nextBillingDate'] != null ? DateTime.parse(json['nextBillingDate'] as String) : null,
      isActive: json['isActive'] as bool,
      autoRenew: json['autoRenew'] as bool? ?? true,
      billingCycle: json['billingCycle'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Create a new subscription
  factory UserSubscription.create({
    required String platformId,
    required String platformName,
    required SubscriptionType type,
    required double monthlyCost,
    required DateTime startDate,
    DateTime? endDate,
    bool autoRenew = true,
    String? billingCycle,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    final nextBilling = _calculateNextBilling(startDate, billingCycle);
    
    return UserSubscription(
      id: _generateId(),
      platformId: platformId,
      platformName: platformName,
      type: type,
      monthlyCost: monthlyCost,
      startDate: startDate,
      endDate: endDate,
      nextBillingDate: nextBilling,
      isActive: true,
      autoRenew: autoRenew,
      billingCycle: billingCycle ?? 'monthly',
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );
  }



  final String id;
  final String platformId;
  final String platformName;
  final SubscriptionType type;
  final double monthlyCost;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextBillingDate;
  final bool isActive;
  final bool autoRenew;
  final String? billingCycle;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Check if subscription is currently active and not expired
  bool get isCurrentlyActive {
    if (!isActive) return false;
    if (endDate != null && DateTime.now().isAfter(endDate!)) return false;
    return true;
  }

  /// Check if subscription is expiring soon (within 7 days)
  bool get isExpiringSoon {
    if (nextBillingDate == null) return false;
    final daysUntilExpiry = nextBillingDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 7 && daysUntilExpiry >= 0;
  }

  /// Get days until next billing
  int? get daysUntilNextBilling {
    if (nextBillingDate == null) return null;
    return nextBillingDate!.difference(DateTime.now()).inDays;
  }

  /// Get subscription duration in days
  int get subscriptionDurationDays {
    final end = endDate ?? DateTime.now();
    return end.difference(startDate).inDays;
  }

  /// Get total cost paid so far
  double get totalCostPaid {
    final months = subscriptionDurationDays / 30.44; // Average days per month
    return monthlyCost * months;
  }

  /// Get formatted billing cycle
  String get formattedBillingCycle {
    switch (billingCycle?.toLowerCase()) {
      case 'monthly':
        return 'Monthly';
      case 'yearly':
      case 'annual':
        return 'Yearly';
      case 'quarterly':
        return 'Quarterly';
      default:
        return 'Monthly';
    }
  }

  /// Get formatted monthly cost
  String get formattedMonthlyCost {
    return '\$${monthlyCost.toStringAsFixed(2)}/month';
  }

  /// Create a copy with updated fields
  UserSubscription copyWith({
    String? id,
    String? platformId,
    String? platformName,
    SubscriptionType? type,
    double? monthlyCost,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextBillingDate,
    bool? isActive,
    bool? autoRenew,
    String? billingCycle,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserSubscription(
      id: id ?? this.id,
      platformId: platformId ?? this.platformId,
      platformName: platformName ?? this.platformName,
      type: type ?? this.type,
      monthlyCost: monthlyCost ?? this.monthlyCost,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      isActive: isActive ?? this.isActive,
      autoRenew: autoRenew ?? this.autoRenew,
      billingCycle: billingCycle ?? this.billingCycle,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'platformId': platformId,
      'platformName': platformName,
      'type': type.name,
      'monthlyCost': monthlyCost,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'nextBillingDate': nextBillingDate?.toIso8601String(),
      'isActive': isActive,
      'autoRenew': autoRenew,
      'billingCycle': billingCycle,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }



  /// Generate a unique ID
  static String _generateId() {
    return 'sub_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}';
  }

  /// Calculate next billing date based on billing cycle
  static DateTime _calculateNextBilling(DateTime startDate, String? billingCycle) {
    switch (billingCycle?.toLowerCase()) {
      case 'yearly':
      case 'annual':
        return DateTime(startDate.year + 1, startDate.month, startDate.day);
      case 'quarterly':
        return DateTime(startDate.year, startDate.month + 3, startDate.day);
      case 'monthly':
      default:
        return DateTime(startDate.year, startDate.month + 1, startDate.day);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSubscription && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserSubscription(id: $id, platformName: $platformName, type: $type, monthlyCost: $monthlyCost, isActive: $isActive)';
  }
}

/// Types of streaming subscriptions
enum SubscriptionType {
  free('Free'),
  basic('Basic'),
  standard('Standard'),
  premium('Premium'),
  family('Family'),
  student('Student'),
  trial('Trial');

  const SubscriptionType(this.displayName);
  
  final String displayName;

  /// Get subscription type from string
  static SubscriptionType fromString(String value) {
    return SubscriptionType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SubscriptionType.premium,
    );
  }
}