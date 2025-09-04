import 'package:isar/isar.dart';

part 'user_favorite.g.dart';

@collection
class UserFavorite {
  Id? id = Isar.autoIncrement;

  late int movieId;

  late bool isDeleted;

  late DateTime lastModifiedAt;
}