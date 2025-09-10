import 'dart:io';

void main() async {
  // Lista de archivos que contienen withValues
  final files = [
    'lib/presentation/widgets/subscription/add_subscription_dialog.dart',
    'lib/presentation/widgets/streaming/streaming_error_widget.dart',
    'lib/presentation/widgets/profile_avatar.dart',
    'lib/core/gamification/widgets/achievement_card.dart',
    'lib/presentation/widgets/shared/cinema_mode.dart',
    'lib/presentation/screens/settings_screen.dart',
    'lib/presentation/widgets/streaming/streaming_loading_indicator.dart',
    'lib/presentation/widgets/streaming/streaming_action_button.dart',
    'lib/presentation/widgets/movies/movie_card_with_actions.dart',
    'lib/presentation/widgets/movies/movie_lists_widget.dart',
    'lib/presentation/widgets/guest_mode_banner.dart',
    'lib/presentation/views/movies/list_detail_view.dart',
    'lib/presentation/widgets/movies/movie_horizontal_listview.dart',
    'lib/presentation/widgets/sync/conflict_preview_widget.dart',
    'lib/widgets/challenge_completion_celebration.dart',
    'lib/presentation/widgets/sync/conflict_resolution_dialog.dart',
    'lib/presentation/widgets/streaming/streaming_availability_indicator.dart',
    'lib/presentation/views/movies/discovery_view.dart',
    'lib/presentation/views/movies/filters_view.dart',
    'lib/presentation/widgets/movies/movie_rating_and_notes.dart',
    'lib/presentation/widgets/watch_providers_widget.dart',
    'lib/presentation/screens/streaming/streaming_dashboard_screen.dart',
    'lib/presentation/widgets/dashboard/quick_actions_widget.dart',
    'lib/presentation/widgets/movies/movie_horizontal_listview_with_ads.dart',
    'lib/presentation/views/movies/discovery_popular_view.dart',
    'lib/presentation/screens/auth/login_screen.dart',
    'lib/presentation/widgets/admob/full_width_ad_widget.dart',
    'lib/presentation/widgets/admob/movie_card_ad_widget.dart',
    'lib/presentation/widgets/admob/grid_ad_widget.dart',
    'lib/presentation/widgets/admob/banner_ad_widget.dart',
    'lib/presentation/widgets/streaming/compact_streaming_widget.dart',
    'lib/core/gamification/widgets/level_progress_indicator.dart',
    'lib/presentation/widgets/achievements/achievement_share_dialog.dart',
    'lib/presentation/screens/ratings/user_ratings_screen.dart',
    'lib/presentation/views/movies/custom_lists_view.dart',
    'lib/presentation/widgets/sync/minimal_sync_indicator.dart',
    'lib/presentation/widgets/shared/custom_bottom_navigation.dart',
    'lib/presentation/widgets/movies/movie_list_item.dart',
    'lib/presentation/widgets/sync/merge_preview_widget.dart',
    'lib/presentation/widgets/sync/connectivity_banner.dart',
    'lib/presentation/widgets/shared/page_transitions.dart',
    'lib/presentation/widgets/ratings/movie_rating_widget.dart',
    'lib/presentation/widgets/user_insights_widget.dart',
    'lib/presentation/views/movies/recommendations_view.dart',
    'lib/presentation/widgets/ratings/star_rating_widget.dart',
    'lib/widgets/challenge_widgets.dart',
    'lib/presentation/widgets/dashboard/subscription_stats_widget.dart',
    'lib/presentation/screens/movies/movie_screen.dart',
    'lib/presentation/widgets/gamification_profile_section.dart',
    'lib/presentation/screens/profile/profile_screen.dart',
    'lib/presentation/widgets/achievements/achievement_card.dart',
    'lib/presentation/widgets/streaming/streaming_options_dialog.dart',
    'lib/presentation/widgets/sync/silent_sync_indicator.dart',
    'lib/presentation/widgets/admob/controlled_ad_widget.dart',
    'lib/presentation/widgets/streaming/platform_availability_card.dart',
    'lib/presentation/widgets/movies/filter_fab.dart',
    'lib/presentation/widgets/custom_drawer.dart',
    'lib/presentation/widgets/movies/enhanced_movie_info.dart',
    'lib/presentation/widgets/videos/videos_from_movie.dart',
    'lib/presentation/widgets/admob/native_ad_widget.dart',
    'lib/presentation/screens/auth/register_screen.dart',
    'lib/presentation/widgets/ml_recommendation_card.dart',
    'lib/presentation/widgets/sync/conflict_history_list.dart',
    'lib/presentation/widgets/sync/sync_history_viewer.dart',
    'lib/presentation/widgets/achievements/achievement_image_generator.dart',
  ];

  final regex = RegExp(r'\.withValues\(alpha:\s*([0-9.]+)\)');

  for (final filePath in files) {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('File not found: $filePath');
        continue;
      }

      String content = await file.readAsString();
      final originalContent = content;

      content = content.replaceAllMapped(regex, (match) {
        final alphaValue = match.group(1)!;
        return '.withOpacity($alphaValue)';
      });

      if (content != originalContent) {
        await file.writeAsString(content);
        print('Updated: $filePath');
      }
    } catch (e) {
      print('Error processing $filePath: $e');
    }
  }

  print('Conversion completed!');
}
