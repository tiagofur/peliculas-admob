import 'trakt_ids.dart';

class ShowTrakt {
  ShowTrakt({
    required this.title,
    required this.year,
    required this.ids,
    this.overview,
    this.firstAired,
    this.airs,
    this.runtime,
    this.certification,
    this.network,
    this.country,
    this.trailer,
    this.homepage,
    this.status,
    this.rating,
    this.votes,
    this.plays,
    this.watched,
    this.collected,
    this.watchers,
    this.genres,
    this.language,
    this.availableTranslations,
    this.airedEpisodes,
    this.comment,
    this.updatedAt,
  });

  factory ShowTrakt.fromJson(Map<String, dynamic> json) => ShowTrakt(
        title: json['title'] ?? '',
        year: json['year'] ?? 0,
        ids: TraktIds.fromJson(json['ids'] ?? {}),
        overview: json['overview'],
        firstAired: json['first_aired'] != null
            ? DateTime.tryParse(json['first_aired'])
            : null,
        airs: json['airs'] != null ? TraktAirs.fromJson(json['airs']) : null,
        runtime: json['runtime'],
        certification: json['certification'],
        network: json['network'],
        country: json['country'],
        trailer: json['trailer'],
        homepage: json['homepage'],
        status: json['status'],
        rating: json['rating']?.toDouble(),
        votes: json['votes'],
        plays: json['plays'],
        watched: json['watched'],
        collected: json['collected'],
        watchers: json['watchers'],
        genres:
            json['genres'] != null ? List<String>.from(json['genres']) : null,
        language: json['language'],
        availableTranslations: json['available_translations'] != null
            ? List<String>.from(json['available_translations'])
            : null,
        airedEpisodes: json['aired_episodes'],
        comment: json['comment'],
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'])
            : null,
      );

  final String title;
  final int year;
  final TraktIds ids;
  final String? overview;
  final DateTime? firstAired;
  final TraktAirs? airs;
  final int? runtime;
  final String? certification;
  final String? network;
  final String? country;
  final String? trailer;
  final String? homepage;
  final String? status;
  final double? rating;
  final int? votes;
  final int? plays;
  final bool? watched;
  final bool? collected;
  final int? watchers;
  final List<String>? genres;
  final String? language;
  final List<String>? availableTranslations;
  final int? airedEpisodes;
  final String? comment;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'title': title,
        'year': year,
        'ids': ids.toJson(),
        'overview': overview,
        'first_aired': firstAired?.toIso8601String().split('T')[0],
        'airs': airs?.toJson(),
        'runtime': runtime,
        'certification': certification,
        'network': network,
        'country': country,
        'trailer': trailer,
        'homepage': homepage,
        'status': status,
        'rating': rating,
        'votes': votes,
        'plays': plays,
        'watched': watched,
        'collected': collected,
        'watchers': watchers,
        'genres': genres,
        'language': language,
        'available_translations': availableTranslations,
        'aired_episodes': airedEpisodes,
        'comment': comment,
        'updated_at': updatedAt?.toIso8601String(),
      };
}

class TraktAirs {
  TraktAirs({
    this.day,
    this.time,
    this.timezone,
  });

  factory TraktAirs.fromJson(Map<String, dynamic> json) => TraktAirs(
        day: json['day'],
        time: json['time'],
        timezone: json['timezone'],
      );

  final String? day;
  final String? time;
  final String? timezone;

  Map<String, dynamic> toJson() => {
        'day': day,
        'time': time,
        'timezone': timezone,
      };
}
