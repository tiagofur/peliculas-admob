// Example integration in main.dart or app initialization

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_initialization_service.dart';
import 'core/notifications/notification_services_initializer.dart';
import 'core/notifications/notification_manager.dart';

/// Example of how to integrate the new push notification system
class NotificationSystemExample {
  
  /// Initialize the complete notification system with Riverpod
  static Future<void> initializeNotificationSystem(Ref ref) async {
    try {
      // 1. Initialize basic notification system (Firebase, local notifications)
      await NotificationInitializationService.instance.initializeWithRiverpod(ref);
      
      print('✅ Push notification system initialized successfully');
      
      // 2. Optional: Get initial system health status
      final initializer = NotificationServicesInitializer.instance;
      final status = initializer.getServicesStatus();
      print('📊 System status: ${status['initialized']}');
      print('💚 System healthy: ${initializer.isHealthy}');
      
    } catch (e) {
      print('❌ Error initializing notification system: $e');
    }
  }
  
  /// Example of manual testing - can be called from debug menu
  static Future<void> testNotificationFeatures() async {
    try {
      final initializer = NotificationServicesInitializer.instance;
      
      // Send a test weekly reminder
      print('📧 Sending test weekly reminder...');
      await initializer.sendTestWatchlistReminder();
      
      // Check metrics
      final metrics = initializer.getLast24HoursMetrics();
      if (metrics != null) {
        print('📈 Last 24h delivery rate: ${metrics['deliveryRate']}');
        print('⚡ Average latency: ${metrics['averageDeliveryLatencyMs']}ms');
      }
      
      print('✅ Test completed successfully');
      
    } catch (e) {
      print('❌ Error during testing: $e');
    }
  }
  
  /// Example of health monitoring - can be called periodically
  static void checkSystemHealth() {
    final initializer = NotificationServicesInitializer.instance;
    final metricsService = NotificationManager.instance.metricsService;
    
    if (metricsService != null) {
      final isHealthy = initializer.isHealthy;
      final healthReport = metricsService.getHealthReport();
      
      print('🏥 System Health Check:');
      print('   Overall healthy: $isHealthy');
      print('   Delivery rate healthy: ${metricsService.isDeliveryRateHealthy}');
      print('   Latency healthy: ${metricsService.isLatencyHealthy}');
      
      if (!isHealthy) {
        print('⚠️  System health issues detected!');
        // Here you could send an alert or log to monitoring service
      }
    }
  }
  
  /// Example usage in a Flutter app
  static Widget buildExampleApp() {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, child) {
          return MaterialApp(
            title: 'Movies with Push Notifications',
            home: Scaffold(
              appBar: AppBar(
                title: Text('Movie App'),
                actions: [
                  IconButton(
                    icon: Icon(Icons.notifications),
                    onPressed: () => testNotificationFeatures(),
                  ),
                  IconButton(
                    icon: Icon(Icons.health_and_safety),
                    onPressed: () => checkSystemHealth(),
                  ),
                ],
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Movie App with Push Notifications'),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => initializeNotificationSystem(ref),
                      child: Text('Initialize Notifications'),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: testNotificationFeatures,
                      child: Text('Test Notifications'),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: checkSystemHealth,
                      child: Text('Check Health'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Integration in main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (if using Firebase)
  // await Firebase.initializeApp();
  
  runApp(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, child) {
          // Initialize notification system on app start
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationSystemExample.initializeNotificationSystem(ref);
          });
          
          return NotificationSystemExample.buildExampleApp();
        },
      ),
    ),
  );
}

/// Settings screen example showing notification preferences
class NotificationSettingsExample extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Notification Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('Weekly Watchlist Reminders'),
            subtitle: Text('Get reminded about movies in your watchlist every Sunday'),
            value: true, // This would come from user preferences
            onChanged: (value) {
              // Update user preferences for weekly reminders
              // NotificationPreferencesService.instance.updateTypeEnabled(
              //   NotificationType.weeklyWatchlistReminder, value);
            },
          ),
          SwitchListTile(
            title: Text('Movie Release Notifications'),
            subtitle: Text('Get notified when movies in your watchlist are released'),
            value: true, // This would come from user preferences
            onChanged: (value) {
              // Update user preferences for release notifications
              // NotificationPreferencesService.instance.updateTypeEnabled(
              //   NotificationType.movieReleaseNotification, value);
            },
          ),
          ListTile(
            title: Text('Notification Health'),
            subtitle: Text('System status and delivery metrics'),
            trailing: Icon(Icons.health_and_safety),
            onTap: () => NotificationSystemExample.checkSystemHealth(),
          ),
          ListTile(
            title: Text('Test Notifications'),
            subtitle: Text('Send test notifications to verify setup'),
            trailing: Icon(Icons.send),
            onTap: () => NotificationSystemExample.testNotificationFeatures(),
          ),
        ],
      ),
    );
  }
}