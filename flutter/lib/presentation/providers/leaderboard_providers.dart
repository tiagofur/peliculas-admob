import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gamification/leaderboard_service.dart';

final leaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, LeaderboardQuery>(
        (ref, query) async {
  final leaderboardService = ref.watch(leaderboardServiceProvider);
  return await leaderboardService.getLeaderboard(query);
});

final leaderboardStatsProvider =
    FutureProvider.family<LeaderboardStats, LeaderboardQuery>(
        (ref, query) async {
  final leaderboardService = ref.watch(leaderboardServiceProvider);
  return await leaderboardService.getLeaderboardStats(query);
});

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  return LeaderboardService();
});
