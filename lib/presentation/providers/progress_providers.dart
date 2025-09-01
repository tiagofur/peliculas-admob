import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gamification/progress_tracking_service.dart';
import 'gamification_providers.dart';

// TODO: Implement progressUpdateStream getter in ProgressTrackingService
// final progressUpdatesProvider = StreamProvider<ProgressUpdate>((ref) {
//   final progressTrackingService = ref.watch(progressTrackingServiceProvider);
//   return progressTrackingService.progressUpdateStream;
// });

// TODO: Implement milestoneReachedStream getter in ProgressTrackingService
// final milestoneNotificationsProvider = StreamProvider<MilestoneReached>((ref) {
//   final progressTrackingService = ref.watch(progressTrackingServiceProvider);
//   return progressTrackingService.milestoneReachedStream;
// });

final progressSummaryProvider = FutureProvider<ProgressSummary>((ref) async {
  final progressTrackingService = ref.watch(progressTrackingServiceProvider);
  return await progressTrackingService.getProgressSummary();
});

final progressTrackingServiceProvider = Provider<ProgressTrackingService>((ref) {
  return ProgressTrackingService(ref.watch(gamificationManagerProvider));
});
