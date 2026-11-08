class TraktIds {
  const TraktIds({
    required this.trakt,
    this.slug,
    this.imdb,
    this.tmdb,
    this.tvdb,
  });

  factory TraktIds.fromJson(Map<String, dynamic> json) => TraktIds(
        trakt: json['trakt'] ?? 0,
        slug: json['slug'],
        imdb: json['imdb'],
        tmdb: json['tmdb'],
        tvdb: json['tvdb'],
      );

  final int trakt;
  final String? slug;
  final String? imdb;
  final int? tmdb;
  final int? tvdb;

  Map<String, dynamic> toJson() => {
        'trakt': trakt,
        'slug': slug,
        'imdb': imdb,
        'tmdb': tmdb,
        'tvdb': tvdb,
      };
}
