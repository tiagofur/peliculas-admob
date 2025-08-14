import 'package:hive/hive.dart';
import 'watch_provider.dart';

part 'watch_providers.g.dart';

@HiveType(typeId: 11)
class WatchProviders {
  @HiveField(0)
  final String? link;
  
  @HiveField(1)
  final List<WatchProvider> flatrate; // Streaming platforms
  
  @HiveField(2)
  final List<WatchProvider> rent; // Rental platforms
  
  @HiveField(3)
  final List<WatchProvider> buy; // Purchase platforms
  
  WatchProviders({
    this.link,
    this.flatrate = const [],
    this.rent = const [],
    this.buy = const [],
  });
  
  factory WatchProviders.fromJson(Map<String, dynamic> json) {
    return WatchProviders(
      link: json['link'],
      flatrate: (json['flatrate'] as List<dynamic>?)
          ?.map((provider) => WatchProvider.fromJson(provider))
          .toList() ?? [],
      rent: (json['rent'] as List<dynamic>?)
          ?.map((provider) => WatchProvider.fromJson(provider))
          .toList() ?? [],
      buy: (json['buy'] as List<dynamic>?)
          ?.map((provider) => WatchProvider.fromJson(provider))
          .toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'link': link,
      'flatrate': flatrate.map((provider) => provider.toJson()).toList(),
      'rent': rent.map((provider) => provider.toJson()).toList(),
      'buy': buy.map((provider) => provider.toJson()).toList(),
    };
  }
  
  /// Get all providers combined
  List<WatchProvider> get allProviders {
    return [...flatrate, ...rent, ...buy];
  }
  
  /// Check if any providers are available
  bool get hasProviders {
    return flatrate.isNotEmpty || rent.isNotEmpty || buy.isNotEmpty;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WatchProviders &&
        other.link == link &&
        other.flatrate == flatrate &&
        other.rent == rent &&
        other.buy == buy;
  }
  
  @override
  int get hashCode {
    return link.hashCode ^
        flatrate.hashCode ^
        rent.hashCode ^
        buy.hashCode;
  }
  
  @override
  String toString() {
    return 'WatchProviders(flatrate: ${flatrate.length}, rent: ${rent.length}, buy: ${buy.length})';
  }
}