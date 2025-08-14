import '../entities/entities.dart';

abstract class AchievementsRepository {
  Future<List<Achievement>> getAllAchievements();
  
  Future<void> updateAchievement(Achievement achievement);
  
  Future<void> unlockAchievement(String achievementId);
  
  Future<List<Achievement>> getUnlockedAchievements();
  
  Future<void> incrementAchievementProgress(String achievementId, {int increment = 1});
  
  Future<void> initializeDefaultAchievements();
  
  // Métodos específicos para tracking de actividades
  Future<void> trackMovieWatched();
  
  Future<void> trackMovieFavorited();
  
  Future<void> trackGenreExplored(String genre);
  
  Future<void> trackDecadeExplored(int year);
}