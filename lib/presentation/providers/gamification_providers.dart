import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gamification/gamification_manager.dart';
import '../../core/gamification/models/user_progress.dart';
import '../../core/gamification/models/achievement.dart';

final gamificationManagerProvider = Provider<GamificationManager>((ref) {
  return GamificationManager();
});

final userProgressProvider = FutureProvider<UserProgress>((ref) async {
  final gamificationManager = ref.watch(gamificationManagerProvider);
  return await gamificationManager.getUserProgress();
});

final recentAchievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final gamificationManager = ref.watch(gamificationManagerProvider);
  return await gamificationManager.getRecentAchievements(limit: 3);
});

final unlockedAchievementsProvider = Provider<List<Achievement>>((ref) {
  final gamificationManager = ref.watch(gamificationManagerProvider);
  return gamificationManager.getUnlockedAchievements();
});
