import 'package:isar/isar.dart';

part 'pending_action.g.dart';

@collection
class PendingAction {
  Id? id = Isar.autoIncrement;

  late String actionType;

  late String payload;

  late DateTime createdAt;

  late int attempts;
}