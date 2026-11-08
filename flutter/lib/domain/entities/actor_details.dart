class ActorDetails {
  const ActorDetails({
    required this.id,
    required this.name,
    required this.biography,
    required this.profilePath,
    required this.knownForDepartment,
    required this.popularity,
    this.birthday,
    this.deathday,
    this.placeOfBirth,
  });

  final int id;
  final String name;
  final String biography;
  final String? profilePath;
  final String knownForDepartment;
  final double popularity;
  final String? birthday;
  final String? deathday;
  final String? placeOfBirth;
}

class ActorMovieCredit {
  const ActorMovieCredit({
    required this.id,
    required this.title,
    required this.voteAverage,
    this.posterPath,
    this.character,
    this.releaseDate,
  });

  final int id;
  final String title;
  final String? posterPath;
  final String? character;
  final String? releaseDate;
  final double voteAverage;
}
