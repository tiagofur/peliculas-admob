class PersonDetailsResponse {
  PersonDetailsResponse({
    required this.id,
    required this.name,
    required this.biography,
    required this.knownForDepartment,
    required this.popularity,
    this.birthday,
    this.deathday,
    this.placeOfBirth,
    this.profilePath,
  });

  factory PersonDetailsResponse.fromJson(Map<String, dynamic> json) =>
      PersonDetailsResponse(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        biography: json['biography'] ?? '',
        birthday: json['birthday'],
        deathday: json['deathday'],
        placeOfBirth: json['place_of_birth'],
        profilePath: json['profile_path'],
        knownForDepartment: json['known_for_department'] ?? '',
        popularity: (json['popularity'] as num?)?.toDouble() ?? 0.0,
      );

  final int id;
  final String name;
  final String biography;
  final String? birthday;
  final String? deathday;
  final String? placeOfBirth;
  final String? profilePath;
  final String knownForDepartment;
  final double popularity;
}

class PersonMovieCreditsResponse {
  PersonMovieCreditsResponse({required this.id, required this.cast});

  factory PersonMovieCreditsResponse.fromJson(Map<String, dynamic> json) =>
      PersonMovieCreditsResponse(
        id: json['id'] ?? 0,
        cast: List<PersonMovieCredit>.from(
          (json['cast'] as List? ?? []).map(
            (x) =>
                PersonMovieCredit.fromJson(Map<String, dynamic>.from(x as Map)),
          ),
        ),
      );

  final int id;
  final List<PersonMovieCredit> cast;
}

class PersonMovieCredit {
  PersonMovieCredit({
    required this.id,
    required this.title,
    required this.voteAverage,
    required this.popularity,
    this.posterPath,
    this.character,
    this.releaseDate,
  });

  factory PersonMovieCredit.fromJson(Map<String, dynamic> json) =>
      PersonMovieCredit(
        id: json['id'] ?? 0,
        title: (json['title'] ?? json['name'] ?? '') as String,
        posterPath: json['poster_path'],
        character: json['character'],
        releaseDate: json['release_date'] ?? json['first_air_date'],
        voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
        popularity: (json['popularity'] as num?)?.toDouble() ?? 0.0,
      );

  final int id;
  final String title;
  final String? posterPath;
  final String? character;
  final String? releaseDate;
  final double voteAverage;
  final double popularity;
}
