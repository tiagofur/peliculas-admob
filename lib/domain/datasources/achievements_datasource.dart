import '../entities/entities.dart';

abstract class AchievementsDatasource {
  Future<List<Achievement>> getAllAchievements();
  
  Future<void> updateAchievement(Achievement achievement);
  
  Future<void> unlockAchievement(String achievementId);
  
  Future<List<Achievement>> getUnlockedAchievements();
  
  Future<void> incrementAchievementProgress(String achievementId, {int increment = 1});
  
  Future<void> initializeDefaultAchievements();
}