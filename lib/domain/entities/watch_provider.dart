import 'package:hive/hive.dart';

part 'watch_provider.g.dart';

@HiveType(typeId: 10)
class WatchProvider {
  @HiveField(0)
  final int providerId;
  
  @HiveField(1)
  final String providerName;
  
  @HiveField(2)
  final String logoPath;
  
  @HiveField(3)
  final int displayPriority;
  
  @HiveField(4)
  final String? link;
  
  @HiveField(5)
  final String? presentationType; // 'flatrate', 'rent', 'buy'
  
  WatchProvider({
    required this.providerId,
    required this.providerName,
    required this.logoPath,
    required this.displayPriority,
    this.link,
    this.presentationType,
  });
  
  factory WatchProvider.fromJson(Map<String, dynamic> json) {
    return WatchProvider(
      providerId: json['provider_id'] ?? 0,
      providerName: json['provider_name'] ?? '',
      logoPath: json['logo_path'] ?? '',
      displayPriority: json['display_priority'] ?? 0,
      link: json['link'],
      presentationType: json['presentation_type'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'provider_id': providerId,
      'provider_name': providerName,
      'logo_path': logoPath,
      'display_priority': displayPriority,
      'link': link,
      'presentation_type': presentationType,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WatchProvider &&
        other.providerId == providerId &&
        other.providerName == providerName;
  }
  
  @override
  int get hashCode => providerId.hashCode ^ providerName.hashCode;
  
  @override
  String toString() {
    return 'WatchProvider(providerId: $providerId, providerName: $providerName, logoPath: $logoPath)';
  }
}