import '../../domain/entities/streaming_platform.dart';
import '../logging/logger_factory.dart';

/// Single source of truth mapping TMDB watch-provider IDs to
/// [StreamingPlatform].
///
/// TMDB is the only availability data source. IDs were verified against
/// `GET /watch/providers/movie` and live `/movie/{id}/watch/providers`
/// responses, so platforms that TMDB reports (Max as 1899, Claro video,
/// ViX, MUBI, storefronts such as Apple TV Store or Claro video) resolve
/// to real platforms instead of being dropped.
///
/// Unknown IDs resolve to null and are logged for a future mapping update.
/// They are never replaced with invented platforms.
class TmdbProviderMapper {
  const TmdbProviderMapper._();

  /// Map a TMDB provider to its [StreamingPlatform].
  ///
  /// Returns null when TMDB reports an ID this app does not model yet.
  static StreamingPlatform? mapProvider(int providerId, String providerName) {
    switch (providerId) {
      case 8: // Netflix
      case 1796: // Netflix Standard with Ads
        return StreamingPlatform.netflix;
      case 9: // Amazon Prime Video (legacy ID)
      case 119: // Amazon Prime Video
      case 2100: // Amazon Prime Video with Ads
      case 10: // Amazon Video storefront
        return StreamingPlatform.amazonPrime;
      case 337: // Disney Plus
        return StreamingPlatform.disneyPlus;
      case 350: // Apple TV+
      case 2: // Apple TV Store storefront
        return StreamingPlatform.appleTV;
      case 3: // Google Play Movies
        return StreamingPlatform.googlePlay;
      case 192: // YouTube storefront
      case 188: // YouTube Premium
        return StreamingPlatform.youtube;
      case 7: // Fandango At Home
        return StreamingPlatform.fandango;
      case 35: // Rakuten TV
        return StreamingPlatform.rakutenTV;
      case 68: // Microsoft Store
        return StreamingPlatform.microsoftStore;
      // Max migrated from legacy IDs 384/425 to 1899; 1825 is its
      // Amazon Channel. All of them are the same Max service.
      case 1899:
      case 1825:
      case 384:
      case 425:
        return StreamingPlatform.hboMax;
      case 531: // Paramount Plus
      case 582: // Paramount+ Amazon Channel
      case 2303: // Paramount Plus Premium
        return StreamingPlatform.paramountPlus;
      case 283: // Crunchyroll
      case 1968: // Crunchyroll Amazon Channel
        return StreamingPlatform.crunchyroll;
      case 167: // Claro video
        return StreamingPlatform.claroVideo;
      case 457: // ViX
      case 1866: // ViX Premium Amazon Channel
        return StreamingPlatform.vix;
      case 11: // MUBI
      case 201: // MUBI Amazon Channel
        return StreamingPlatform.mubi;
      case 73: // Tubi TV
        return StreamingPlatform.tubi;
      case 300: // Pluto TV
        return StreamingPlatform.plutoTV;
      case 538: // Plex
        return StreamingPlatform.plex;
      case 1889: // Universal+ Amazon Channel
        return StreamingPlatform.universalPlus;
      case 15: // Hulu
        return StreamingPlatform.hulu;
      case 387: // Peacock
        return StreamingPlatform.peacock;
      default:
        LoggerFactory.debug(
          'Unmapped TMDB provider: $providerName (ID: $providerId)',
        );
        return null;
    }
  }
}
