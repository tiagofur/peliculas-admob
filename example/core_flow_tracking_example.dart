import 'package:peliculas/core/logging/logger_factory.dart';

/// Example implementation showing how to integrate core flow tracking
/// This file demonstrates best practices for tracking critical user flows
/// to meet the success criteria of <5% error rate
void main() {
  LoggerFactory.info(
      'Core Flow Tracking Example - See lib/core/error_reporting/error_metrics_service.dart for implementation');
  LoggerFactory.info('Example flows to track:');
  LoggerFactory.info('- authentication');
  LoggerFactory.info('- movie_search');
  LoggerFactory.info('- movie_details');
  LoggerFactory.info('- watchlist_add');
  LoggerFactory.info('- watchlist_remove');
  LoggerFactory.info('- movie_rating');
  LoggerFactory.info('- user_profile');
  LoggerFactory.info('- sync_operation');
}

/// Example usage patterns:
/// 
/// 1. Automatic tracking with trackCoreFlow:
/// ```dart
/// final result = await ErrorMetricsService.instance.trackCoreFlow(
///   'authentication',
///   () async => await performAuthentication(),
/// );
/// ```
/// 
/// 2. Manual tracking:
/// ```dart
/// await ErrorMetricsService.instance.recordCoreFlowAttempt('movie_search');
/// try {
///   final result = await searchMovies();
/// } catch (error) {
///   await ErrorMetricsService.instance.recordCoreFlowError('movie_search');
///   rethrow;
/// }
/// ```
/// 
/// 3. StateNotifier with mixin:
/// ```dart
/// class AuthNotifier extends StateNotifier<AuthState> 
///     with CoreFlowTrackingMixin<AuthState> {
///   
///   Future<void> signIn() async {
///     await trackCoreFlow('authentication', () async {
///       // authentication logic
///     });
///   }
/// }
/// ```