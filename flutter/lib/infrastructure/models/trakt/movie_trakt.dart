import 'trakt_ids.dart';

class MovieTrakt {
  MovieTrakt({
    required this.title,
    required this.year,
    required this.ids,
    this.overview,
    this.released,
    this.runtime,
    this.trailer,
    this.homepage,
    this.rating,
    this.votes,
    this.plays,
    this.watched,
    this.collected,
    this.watchers,
    this.genres,
    this.certification,
    this.language,
    this.availableTranslations,
    this.comment,
    this.updatedAt,
  });

  factory MovieTrakt.fromJson(Map<String, dynamic> json) => MovieTrakt(
        title: json['title'] ?? '',
        year: json['year'] ?? 0,
        ids: TraktIds.fromJson(json['ids'] ?? {}),
        overview: json['overview'],
        released: json['released'] != null
            ? DateTime.tryParse(json['released'])
            : null,
        runtime: json['runtime'],
        trailer: json['trailer'],
        homepage: json['homepage'],
        rating: json['rating']?.toDouble(),
        votes: json['votes'],
        plays: json['plays'],
        watched: json['watched'],
        collected: json['collected'],
        watchers: json['watchers'],
        genres:
            json['genres'] != null ? List<String>.from(json['genres']) : null,
        certification: json['certification'],
        language: json['language'],
        availableTranslations: json['available_translations'] != null
            ? List<String>.from(json['available_translations'])
            : null,
        comment: json['comment'],
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'])
            : null,
      );

  final String title;
  final int year;
  final TraktIds ids;
  final String? overview;
  final DateTime? released;
  final int? runtime;
  final String? trailer;
  final String? homepage;
  final double? rating;
  final int? votes;
  final int? plays;
  final bool? watched;
  final bool? collected;
  final int? watchers;
  final List<String>? genres;
  final String? certification;
  final String? language;
  final List<String>? availableTranslations;
  final String? comment;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'title': title,
        'year': year,
        'ids': ids.toJson(),
        'overview': overview,
        'released': released?.toIso8601String().split('T')[0],
        'runtime': runtime,
        'trailer': trailer,
        'homepage': homepage,
        'rating': rating,
        'votes': votes,
        'plays': plays,
        'watched': watched,
        'collected': collected,
        'watchers': watchers,
        'genres': genres,
        'certification': certification,
        'language': language,
        'available_translations': availableTranslations,
        'comment': comment,
        'updated_at': updatedAt?.toIso8601String(),
      };
}
