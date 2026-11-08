import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/datasources/achievements_datasource.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/achievements_repository.dart';

class AchievementsRepositoryImpl extends AchievementsRepository {
  AchievementsRepositoryImpl(this.datasource);

  final AchievementsDatasource datasource;

  static const String _exploredGenresKey = 'explored_genres';
  static const String _exploredDecadesKey = 'explored_decades';

  @override
  Future<List<Achievement>> getAllAchievements() {
    return datasource.getAllAchievements();
  }

  @override
  Future<void> updateAchievement(Achievement achievement) {
    return datasource.updateAchievement(achievement);
  }

  @override
  Future<void> unlockAchievement(String achievementId) {
    return datasource.unlockAchievement(achievementId);
  }

  @override
  Future<List<Achievement>> getUnlockedAchievements() {
    return datasource.getUnlockedAchievements();
  }

  @override
  Future<void> incrementAchievementProgress(String achievementId,
      {int increment = 1}) {
    return datasource.incrementAchievementProgress(achievementId,
        increment: increment);
  }

  @override
  Future<void> initializeDefaultAchievements() {
    return datasource.initializeDefaultAchievements();
  }

  @override
  Future<void> trackMovieWatched() async {
    await incrementAchievementProgress('first_movie');
    await incrementAchievementProgress('movie_explorer');
    await incrementAchievementProgress('movie_enthusiast');
    await incrementAchievementProgress('movie_master');
  }

  @override
  Future<void> trackMovieFavorited() async {
    await incrementAchievementProgress('first_favorite');
    await incrementAchievementProgress('favorite_collector');
  }

  @override
  Future<void> trackGenreExplored(String genre) async {
    final prefs = await SharedPreferences.getInstance();
    final exploredGenres = prefs.getStringList(_exploredGenresKey) ?? [];

    if (!exploredGenres.contains(genre)) {
      exploredGenres.add(genre);
      await prefs.setStringList(_exploredGenresKey, exploredGenres);

      // Actualizar logro de explorador de géneros
      final achievements = await getAllAchievements();
      final genreAchievement = achievements.firstWhere(
        (a) => a.id == 'genre_explorer',
        orElse: () => throw Exception('Genre explorer achievement not found'),
      );

      final updatedAchievement = genreAchievement.copyWith(
        currentValue: exploredGenres.length,
        isUnlocked: exploredGenres.length >= genreAchievement.targetValue,
        unlockedDate: exploredGenres.length >= genreAchievement.targetValue
            ? DateTime.now()
            : genreAchievement.unlockedDate,
      );

      await updateAchievement(updatedAchievement);
    }
  }

  @override
  Future<void> trackDecadeExplored(int year) async {
    final decade =
        (year ~/ 10) * 10; // Convertir año a década (ej: 1995 -> 1990)
    final prefs = await SharedPreferences.getInstance();
    final exploredDecades = prefs.getStringList(_exploredDecadesKey) ?? [];
    final decadeString = decade.toString();

    if (!exploredDecades.contains(decadeString)) {
      exploredDecades.add(decadeString);
      await prefs.setStringList(_exploredDecadesKey, exploredDecades);

      // Actualizar logro de viajero del tiempo
      final achievements = await getAllAchievements();
      final decadeAchievement = achievements.firstWhere(
        (a) => a.id == 'decade_traveler',
        orElse: () => throw Exception('Decade traveler achievement not found'),
      );

      final updatedAchievement = decadeAchievement.copyWith(
        currentValue: exploredDecades.length,
        isUnlocked: exploredDecades.length >= decadeAchievement.targetValue,
        unlockedDate: exploredDecades.length >= decadeAchievement.targetValue
            ? DateTime.now()
            : decadeAchievement.unlockedDate,
      );

      await updateAchievement(updatedAchievement);
    }
  }
}
