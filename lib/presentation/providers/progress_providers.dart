import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gamification/progress_tracking_service.dart';
import 'gamification_providers.dart';

final progressUpdatesProvider = StreamProvider<ProgressUpdate>((ref) {
  final progressTrackingService = ref.watch(progressTrackingServiceProvider);
  return progressTrackingService.progressUpdates;
});

final milestoneNotificationsProvider = StreamProvider<MilestoneReached>((ref) {
  final progressTrackingService = ref.watch(progressTrackingServiceProvider);
  return progressTrackingService.milestoneNotifications;
});

final progressSummaryProvider = FutureProvider<ProgressSummary>((ref) async {
  final progressTrackingService = ref.watch(progressTrackingServiceProvider);
  return await progressTrackingService.getProgressSummary();
});

final progressTrackingServiceProvider = Provider<ProgressTrackingService>((ref) {
  return ProgressTrackingService(ref.watch(gamificationManagerProvider));
});
