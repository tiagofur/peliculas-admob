import 'dart:io';
import '_logging_utils.dart';

void main() async {
  final file = File(
      'lib/presentation/providers/recommendations/recommendations_provider.dart');
  var content = await file.readAsString();

  // Reemplazar el patrón problemático
  content = content.replaceAll(RegExp(r'favoriteMovies\.values\.toList\(\)'),
      'favoriteMovies.values.map((syncable) => syncable.movie).toList()');

  await file.writeAsString(content);
  logSuccess('Reemplazos completados en recommendations_provider.dart');
}
