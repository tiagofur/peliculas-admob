# 🔔 Push Notification System Implementation

This document describes the implementation of the push notification system for weekly watchlist reminders and movie release notifications.

## Overview

The push notification system provides two main features:
1. **Weekly Watchlist Reminders** - Automated weekly reminders for movies in the user's watchlist
2. **Movie Release Notifications** - Notifications when movies in the watchlist are released

## Architecture

### Core Components

- **NotificationManager** - Central manager for all notifications with metrics tracking
- **WeeklyWatchlistReminderService** - Handles weekly reminder scheduling and delivery
- **MovieReleaseNotificationService** - Monitors and notifies about movie releases
- **NotificationMetricsService** - Tracks delivery rates, latency, and system health
- **NotificationServicesInitializer** - Dependency injection and service coordination

### Integration Points

- **WatchlistHiveDatasource** - Data source for watchlist movies
- **NotificationPreferences** - User preference management
- **Firebase Messaging** - Push notification delivery
- **Local Notifications** - Fallback notification system

## Usage

### Basic Initialization

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/notifications/notification_services_initializer.dart';

// In your main app initialization
Future<void> initializeApp(Ref ref) async {
  // Initialize with Riverpod for full repository integration
  await NotificationServicesInitializer.instance.initializeWithRepositories(ref: ref);
}

// Or for standalone usage (testing, etc.)
Future<void> initializeStandalone() async {
  await NotificationServicesInitializer.instance.initializeStandalone();
}
```

### Manual Testing

```dart
// Send a test weekly reminder
await NotificationServicesInitializer.instance.sendTestWatchlistReminder();

// Check service health
final isHealthy = NotificationServicesInitializer.instance.isHealthy;
print('System healthy: $isHealthy');

// Get metrics
final metrics = NotificationServicesInitializer.instance.getLast24HoursMetrics();
print('Delivery rate: ${metrics?['deliveryRate']}');
```

### Service Status Monitoring

```dart
final status = NotificationServicesInitializer.instance.getServicesStatus();
print('Services initialized: ${status['initialized']}');
print('Health report: ${status['healthReport']}');
```

## Configuration

### Notification Types

The system adds two new notification types:

```dart
enum NotificationType {
  // ... existing types
  weeklyWatchlistReminder,     // Weekly reminders
  movieReleaseNotification,    // Release notifications
}
```

### Default Preferences

```dart
// Weekly reminders: enabled, weekly frequency, normal priority
NotificationType.weeklyWatchlistReminder: {
  enabled: true,
  frequency: NotificationFrequency.weekly,
  priority: NotificationPriority.normal,
}

// Release notifications: enabled, immediate frequency, high priority  
NotificationType.movieReleaseNotification: {
  enabled: true,
  frequency: NotificationFrequency.immediate,
  priority: NotificationPriority.high,
}
```

### Scheduling

- **Weekly Reminders**: Every Sunday at 10:00 AM
- **Release Checks**: Daily at 9:00 AM
- **Upcoming Release Alerts**: 7 days in advance

## Features

### Weekly Watchlist Reminders

- ✅ Automatic scheduling for Sunday mornings
- ✅ Priority-based message content (high priority movies mentioned first)
- ✅ Smart messaging based on watchlist size and priorities
- ✅ Configurable frequency and timing

Example messages:
- "No olvides ver 'Dune: Part Two' que tienes en alta prioridad."
- "Tienes 5 películas de alta prioridad pendientes en tu lista."

### Movie Release Notifications

- ✅ Daily monitoring of release dates
- ✅ Immediate notifications for today's releases
- ✅ Advance notifications for upcoming releases (7 days)
- ✅ Duplicate prevention with intelligent tracking

Example messages:
- "🎬 ¡Ya disponible! 'Oppenheimer' se estrenó hoy. ¡Ve a verla!"
- "🗓️ Próximo estreno: 'Avatar: The Way of Water' se estrena en 3 días."

### Metrics and Monitoring

- ✅ **Delivery Rate Tracking**: Targets >95% delivery success
- ✅ **Latency Monitoring**: Targets <5 seconds delivery time
- ✅ **Health Reporting**: Automatic health status assessment
- ✅ **Historical Data**: 30-day retention with automatic cleanup

Health indicators:
```dart
final metricsService = NotificationManager.instance.metricsService;
final isHealthy = metricsService.isDeliveryRateHealthy && metricsService.isLatencyHealthy;
```

## Data Flow

### Weekly Reminder Flow

1. **Timer Trigger** - Sunday 10:00 AM timer fires
2. **Data Fetch** - Get all watchlist movies from Hive datasource
3. **Priority Analysis** - Group movies by priority (alta, normal, baja)
4. **Message Generation** - Create personalized message based on content
5. **Delivery** - Send through NotificationManager with metrics tracking
6. **Scheduling** - Schedule next Sunday's reminder

### Release Notification Flow

1. **Daily Check** - 9:00 AM timer fires
2. **Data Fetch** - Get watchlist movies with release dates
3. **Date Filtering** - Find movies releasing today or within 7 days
4. **Duplicate Check** - Ensure no duplicate notifications sent
5. **Notification Types** - Send different messages for today vs upcoming
6. **Delivery** - Send through NotificationManager with metrics tracking

### Metrics Flow

1. **Sent Recording** - Record when notification is sent with scheduled time
2. **Delivery Recording** - Record when notification is delivered to device
3. **Interaction Recording** - Record clicks, dismissals, failures
4. **Aggregation** - Calculate delivery rates, latency, and health metrics
5. **Cleanup** - Remove old metrics after 30 days or 1000 records

## Error Handling

- **Graceful Degradation**: Services continue working even if watchlist is empty
- **Retry Logic**: Failed notifications are logged but don't stop the service
- **Health Monitoring**: Automatic detection of delivery rate or latency issues
- **Logging**: Comprehensive logging for debugging and monitoring

## Testing

### Unit Tests

```bash
flutter test test/notification_system_test.dart
```

### Manual Testing

```dart
// Test weekly reminder
await WeeklyWatchlistReminderService.instance.sendManualReminder();

// Test release notification (requires movies with release dates in watchlist)
await MovieReleaseNotificationService.instance.notifyReleaseManually(movie);

// Test metrics recording
await NotificationMetricsService.instance.recordNotificationSent(
  notificationId: 'test-123',
  type: NotificationType.weeklyWatchlistReminder,
  scheduledFor: DateTime.now(),
);
```

### Health Checks

```dart
// Check overall system health
final initializer = NotificationServicesInitializer.instance;
print('System healthy: ${initializer.isHealthy}');

// Check detailed metrics
final metricsService = NotificationManager.instance.metricsService;
final report = metricsService?.getHealthReport();
print('Delivery rate: ${report?['last24Hours']['deliveryRate']}');
print('Average latency: ${report?['last24Hours']['averageDeliveryLatencyMs']}ms');
```

## Performance Considerations

- **Memory Usage**: Metrics are limited to 1000 records and 30 days retention
- **Background Processing**: All services run efficiently with minimal battery impact
- **Network Usage**: Minimal - only syncs notification delivery status
- **Storage**: Uses Hive for efficient local storage of metrics and preferences

## Security

- **No Sensitive Data**: Notifications only contain movie titles and basic info
- **Local Storage**: All user data stored locally in Hive
- **Permission Handling**: Respects user notification permissions
- **Privacy Compliant**: No personal data sent to external services

## Future Enhancements

Potential improvements for future versions:

- **Genre-based Notifications**: Notify about new releases in favorite genres
- **Actor-based Notifications**: Enhanced actor following with release notifications
- **Streaming Platform Integration**: Notify when watchlist movies become available on user's platforms
- **Smart Scheduling**: AI-based optimal notification timing based on user behavior
- **Rich Notifications**: Enhanced notification content with trailers and images

## Troubleshooting

### Common Issues

1. **Notifications not appearing**
   - Check notification permissions
   - Verify service initialization
   - Check user preferences

2. **Empty watchlist reminders**
   - Verify watchlist has movies with release dates
   - Check datasource connection

3. **Poor delivery rates**
   - Check device connectivity
   - Verify Firebase configuration
   - Review metrics health report

### Debug Commands

```dart
// Check service status
final status = NotificationServicesInitializer.instance.getServicesStatus();

// Get detailed metrics
final metrics = NotificationManager.instance.metricsService?.getHealthReport();

// Restart services
await NotificationServicesInitializer.instance.restartServices();
```