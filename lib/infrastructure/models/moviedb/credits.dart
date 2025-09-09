class Credits {
  Credits({
    required this.id,
    required this.cast,
    required this.crew,
  });

  factory Credits.fromJson(Map<String, dynamic> json) => Credits(
        id: json['id'] ?? 0,
        cast: List<Cast>.from(json['cast'].map((x) => Cast.fromJson(x))),
        crew: List<Crew>.from(json['crew'].map((x) => Crew.fromJson(x))),
      );

  final int id;
  final List<Cast> cast;
  final List<Crew> crew;

  Map<String, dynamic> toJson() => {
        'id': id,
        'cast': List<dynamic>.from(cast.map((x) => x.toJson())),
        'crew': List<dynamic>.from(crew.map((x) => x.toJson())),
      };
}

class Cast {
  Cast({
    required this.adult,
    required this.gender,
    required this.id,
    required this.knownForDepartment,
    required this.name,
    required this.originalName,
    required this.popularity,
    required this.profilePath,
    required this.castId,
    required this.character,
    required this.creditId,
    required this.order,
  });

  factory Cast.fromJson(Map<String, dynamic> json) => Cast(
        adult: json['adult'] ?? false,
        gender: json['gender'] ?? 0,
        id: json['id'] ?? 0,
        knownForDepartment: json['known_for_department'] ?? '',
        name: json['name'] ?? '',
        originalName: json['original_name'] ?? '',
        popularity: json['popularity']?.toDouble() ?? 0.0,
        profilePath: json['profile_path'],
        castId: json['cast_id'] ?? 0,
        character: json['character'] ?? '',
        creditId: json['credit_id'] ?? '',
        order: json['order'] ?? 0,
      );

  final bool adult;
  final int gender;
  final int id;
  final String knownForDepartment;
  final String name;
  final String originalName;
  final double popularity;
  final String? profilePath;
  final int castId;
  final String character;
  final String creditId;
  final int order;

  Map<String, dynamic> toJson() => {
        'adult': adult,
        'gender': gender,
        'id': id,
        'known_for_department': knownForDepartment,
        'name': name,
        'original_name': originalName,
        'popularity': popularity,
        'profile_path': profilePath,
        'cast_id': castId,
        'character': character,
        'credit_id': creditId,
        'order': order,
      };
}

class Crew {
  Crew({
    required this.adult,
    required this.gender,
    required this.id,
    required this.knownForDepartment,
    required this.name,
    required this.originalName,
    required this.popularity,
    required this.profilePath,
    required this.creditId,
    required this.department,
    required this.job,
  });

  factory Crew.fromJson(Map<String, dynamic> json) => Crew(
        adult: json['adult'] ?? false,
        gender: json['gender'] ?? 0,
        id: json['id'] ?? 0,
        knownForDepartment: json['known_for_department'] ?? '',
        name: json['name'] ?? '',
        originalName: json['original_name'] ?? '',
        popularity: json['popularity']?.toDouble() ?? 0.0,
        profilePath: json['profile_path'],
        creditId: json['credit_id'] ?? '',
        department: json['department'] ?? '',
        job: json['job'] ?? '',
      );

  final bool adult;
  final int gender;
  final int id;
  final String knownForDepartment;
  final String name;
  final String originalName;
  final double popularity;
  final String? profilePath;
  final String creditId;
  final String department;
  final String job;

  Map<String, dynamic> toJson() => {
        'adult': adult,
        'gender': gender,
        'id': id,
        'known_for_department': knownForDepartment,
        'name': name,
        'original_name': originalName,
        'popularity': popularity,
        'profile_path': profilePath,
        'credit_id': creditId,
        'department': department,
        'job': job,
      };
}
