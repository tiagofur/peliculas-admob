// import 'package:isar/isar.dart';

// part 'person.g.dart';

// @collection
class Person {
  Person();

  Person.fromJson(Map<String, dynamic> json) {
    tmdbId = json['id'] ?? 0;
    name = json['name'] ?? '';
    biography = json['biography'];
    birthday = json['birthday'];
    deathday = json['deathday'];
    placeOfBirth = json['place_of_birth'];
    profilePath = json['profile_path'];
    popularity = json['popularity']?.toDouble();
    knownForDepartment = json['known_for_department'];
    adult = json['adult'] ?? false;
    alsoKnownAs = List<String>.from(json['also_known_as'] ?? []);
    homepage = json['homepage'];
    imdbId = json['imdb_id'];
    gender = json['gender'];
    updatedAt = DateTime.now();
  }
  // Id? id;
  int? id;

  // @Index()
  int tmdbId = 0;

  String name = '';

  String? biography;

  String? birthday;

  String? deathday;

  String? placeOfBirth;

  String? profilePath;

  double? popularity;

  String? knownForDepartment;

  bool adult = false;

  List<String> alsoKnownAs = [];

  String? homepage;

  String? imdbId;

  int? gender; // 0: Not specified, 1: Female, 2: Male, 3: Non-binary

  DateTime createdAt = DateTime.now();

  DateTime updatedAt = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': tmdbId,
      'name': name,
      'biography': biography,
      'birthday': birthday,
      'deathday': deathday,
      'place_of_birth': placeOfBirth,
      'profile_path': profilePath,
      'popularity': popularity,
      'known_for_department': knownForDepartment,
      'adult': adult,
      'also_known_as': alsoKnownAs,
      'homepage': homepage,
      'imdb_id': imdbId,
      'gender': gender,
    };
  }

  String get fullProfileUrl {
    if (profilePath == null || (profilePath?.isEmpty ?? true)) return '';
    return 'https://image.tmdb.org/t/p/w500$profilePath';
  }

  String get genderString {
    switch (gender) {
      case 1:
        return 'Female';
      case 2:
        return 'Male';
      case 3:
        return 'Non-binary';
      default:
        return 'Not specified';
    }
  }

  bool get isAlive => deathday == null || (deathday?.isEmpty ?? true);

  int? get age {
    if (birthday == null || (birthday?.isEmpty ?? true)) return null;

    final birthDate = DateTime.tryParse(birthday!);
    if (birthDate == null) return null;

    final endDate = isAlive ? DateTime.now() : DateTime.tryParse(deathday!);
    if (endDate == null) return null;

    return endDate.year - birthDate.year;
  }
}
