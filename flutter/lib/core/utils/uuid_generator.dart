import 'package:uuid/uuid.dart';

class UuidGenerator {
  const UuidGenerator();

  String v4() => const Uuid().v4();
}
