class TraktPerson {
  TraktPerson({
    required this.name,
    required this.ids,
    this.biography,
    this.birthday,
    this.death,
    this.birthplace,
    this.homepage,
    this.tmdbImageUrl,
  });

  factory TraktPerson.fromJson(Map<String, dynamic> json) => TraktPerson(
        name: json['name'] ?? '',
        ids: TraktPersonIds.fromJson(json['ids'] ?? {}),
        biography: json['biography'],
        birthday: json['birthday'] != null
            ? DateTime.tryParse(json['birthday'])
            : null,
        death: json['death'] != null ? DateTime.tryParse(json['death']) : null,
        birthplace: json['birthplace'],
        homepage: json['homepage'],
        tmdbImageUrl: json['tmdb_image_url'],
      );

  final String name;
  final TraktPersonIds ids;
  final String? biography;
  final DateTime? birthday;
  final DateTime? death;
  final String? birthplace;
  final String? homepage;
  final String? tmdbImageUrl;

  Map<String, dynamic> toJson() => {
        'name': name,
        'ids': ids.toJson(),
        'biography': biography,
        'birthday': birthday?.toIso8601String().split('T')[0],
        'death': death?.toIso8601String().split('T')[0],
        'birthplace': birthplace,
        'homepage': homepage,
        'tmdb_image_url': tmdbImageUrl,
      };
}

class TraktPersonIds {
  TraktPersonIds({
    required this.trakt,
    this.slug,
    this.imdb,
    this.tmdb,
  });

  factory TraktPersonIds.fromJson(Map<String, dynamic> json) => TraktPersonIds(
        trakt: json['trakt'] ?? 0,
        slug: json['slug'],
        imdb: json['imdb'],
        tmdb: json['tmdb'],
      );

  final int trakt;
  final String? slug;
  final String? imdb;
  final int? tmdb;

  Map<String, dynamic> toJson() => {
        'trakt': trakt,
        'slug': slug,
        'imdb': imdb,
        'tmdb': tmdb,
      };
}

class TraktCastMember {
  TraktCastMember({
    required this.character,
    required this.person,
  });

  factory TraktCastMember.fromJson(Map<String, dynamic> json) =>
      TraktCastMember(
        character: json['character'] ?? '',
        person: TraktPerson.fromJson(json['person'] ?? {}),
      );

  final String character;
  final TraktPerson person;

  Map<String, dynamic> toJson() => {
        'character': character,
        'person': person.toJson(),
      };
}

class TraktCrewMember {
  TraktCrewMember({
    required this.job,
    required this.person,
  });

  factory TraktCrewMember.fromJson(Map<String, dynamic> json) =>
      TraktCrewMember(
        job: json['job'] ?? '',
        person: TraktPerson.fromJson(json['person'] ?? {}),
      );

  final String job;
  final TraktPerson person;

  Map<String, dynamic> toJson() => {
        'job': job,
        'person': person.toJson(),
      };
}
