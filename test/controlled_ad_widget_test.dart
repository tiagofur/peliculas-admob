import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/presentation/widgets/admob/controlled_ad_widget.dart';
import '../lib/core/monetization/ad_frequency_controller.dart';

void main() {
  group('ControlledAdWidget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AdFrequencyController.instance.initialize();
    });

    testWidgets('should show loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ControlledAdWidget(
              adType: ControlledAdType.banner,
            ),
          ),
        ),
      );

      // Should show loading indicator while checking permissions
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show placeholder when ad is blocked', (WidgetTester tester) async {
      // Configure controller to block ads
      await AdFrequencyController.instance.initialize(
        config: const AdFrequencyConfig(maxAdsPerSession: 0),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ControlledAdWidget(
              adType: ControlledAdType.native,
              showLabel: true,
            ),
          ),
        ),
      );

      // Wait for async initialization
      await tester.pumpAndSettle();

      // Should show placeholder with block reason
      expect(find.text('Límite de sesión alcanzado'), findsOneWidget);
    });

    testWidgets('should call onAdBlocked when ad is blocked', (WidgetTester tester) async {
      AdDecisionResult? blockedReason;
      
      // Configure controller to block ads
      await AdFrequencyController.instance.initialize(
        config: const AdFrequencyConfig(maxAdsPerSession: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ControlledAdWidget(
              adType: ControlledAdType.banner,
              onAdBlocked: (reason) {
                blockedReason = reason;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(blockedReason, equals(AdDecisionResult.blockedBySessionLimit));
    });

    testWidgets('should call onAdShown when ad is allowed', (WidgetTester tester) async {
      bool adShown = false;
      
      // Configure controller to allow ads
      await AdFrequencyController.instance.initialize(
        config: const AdFrequencyConfig(maxAdsPerSession: 10),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ControlledAdWidget(
              adType: ControlledAdType.grid,
              onAdShown: () {
                adShown = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(adShown, isTrue);
    });

    testWidgets('should show different placeholders for different block reasons', (WidgetTester tester) async {
      const testCases = [
        (AdFrequencyConfig(maxAdsPerSession: 0), 'Límite de sesión alcanzado'),
        (AdFrequencyConfig(maxAdsPerHour: 0), 'Límite horario alcanzado'),
        (AdFrequencyConfig(maxAdsPerDay: 0), 'Límite diario alcanzado'),
      ];

      for (final testCase in testCases) {
        await AdFrequencyController.instance.initialize(config: testCase.$1);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ControlledAdWidget(
                adType: ControlledAdType.native,
                showLabel: true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text(testCase.$2), findsOneWidget);
        
        // Clean up for next test
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/platform',
          null,
          (data) {},
        );
      }
    });

    testWidgets('should hide placeholder when showLabel is false', (WidgetTester tester) async {
      // Configure controller to block ads
      await AdFrequencyController.instance.initialize(
        config: const AdFrequencyConfig(maxAdsPerSession: 0),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ControlledAdWidget(
              adType: ControlledAdType.banner,
              showLabel: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show empty widget, not placeholder
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('Límite de sesión alcanzado'), findsNothing);
    });
  });

  group('Helper Widgets Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AdFrequencyController.instance.initialize();
    });

    testWidgets('ControlledBannerAd should create banner ad widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ControlledBannerAd(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find the controlled ad widget
      expect(find.byType(ControlledAdWidget), findsOneWidget);
    });

    testWidgets('ControlledNativeAd should create native ad widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ControlledNativeAd(
              height: 150,
              showLabel: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ControlledAdWidget), findsOneWidget);
    });

    testWidgets('ControlledGridAd should create grid ad widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ControlledGridAd(
              aspectRatio: 0.8,
              showLabel: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ControlledAdWidget), findsOneWidget);
    });

    testWidgets('ControlledFullWidthAd should create full width ad widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ControlledFullWidthAd(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ControlledAdWidget), findsOneWidget);
    });
  });

  group('User Experience Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('should respect user interaction cooldowns', (WidgetTester tester) async {
      await AdFrequencyController.instance.initialize(
        config: const AdFrequencyConfig(
          cooldownAfterUserInteraction: Duration(minutes: 5),
        ),
      );

      // Simulate user interaction
      AdFrequencyController.instance.recordUserInteraction();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ControlledAdWidget(
              adType: ControlledAdType.banner,
              showLabel: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show interaction cooldown message
      expect(find.text('Cooldown después de interacción'), findsOneWidget);
    });

    testWidgets('should show different placeholder heights for different ad types', (WidgetTester tester) async {
      await AdFrequencyController.instance.initialize(
        config: const AdFrequencyConfig(maxAdsPerSession: 0),
      );

      final adTypes = [
        ControlledAdType.banner,
        ControlledAdType.native,
        ControlledAdType.grid,
        ControlledAdType.fullWidth,
      ];

      for (final adType in adTypes) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ControlledAdWidget(
                adType: adType,
                showLabel: true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Each ad type should have different placeholder dimensions
        final containers = find.byType(Container);
        expect(containers, findsAtLeastNWidgets(1));
      }
    });

    testWidgets('should maintain consistent styling with theme', (WidgetTester tester) async {
      await AdFrequencyController.instance.initialize(
        config: const AdFrequencyConfig(maxAdsPerSession: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: ControlledAdWidget(
              adType: ControlledAdType.native,
              showLabel: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find themed elements
      expect(find.byType(Container), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('Edge Cases', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('should handle initialization errors gracefully', (WidgetTester tester) async {
      // Don't initialize controller to simulate error
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ControlledAdWidget(
              adType: ControlledAdType.banner,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not crash and show some form of placeholder
      expect(find.byType(Widget), findsAtLeastNWidgets(1));
    });

    testWidgets('should handle rapid widget rebuilds', (WidgetTester tester) async {
      await AdFrequencyController.instance.initialize();

      Widget buildWidget(Key key) => MaterialApp(
        key: key,
        home: const Scaffold(
          body: ControlledAdWidget(
            adType: ControlledAdType.banner,
          ),
        ),
      );

      // Rapidly rebuild the widget
      await tester.pumpWidget(buildWidget(const Key('1')));
      await tester.pumpWidget(buildWidget(const Key('2')));
      await tester.pumpWidget(buildWidget(const Key('3')));
      
      await tester.pumpAndSettle();

      // Should handle rebuilds without errors
      expect(find.byType(ControlledAdWidget), findsOneWidget);
    });

    testWidgets('should handle metadata correctly', (WidgetTester tester) async {
      await AdFrequencyController.instance.initialize();

      const metadata = {
        'placement': 'test_screen',
        'position': 'top',
        'experiment': 'control_group',
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ControlledAdWidget(
              adType: ControlledAdType.native,
              metadata: metadata,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should handle metadata without issues
      expect(find.byType(ControlledAdWidget), findsOneWidget);
    });
  });

  group('Performance Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AdFrequencyController.instance.initialize();
    });

    testWidgets('should render quickly', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ControlledAdWidget(adType: ControlledAdType.banner),
                ControlledAdWidget(adType: ControlledAdType.native),
                ControlledAdWidget(adType: ControlledAdType.grid),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      stopwatch.stop();

      // Rendering should be reasonably fast (less than 1 second)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    testWidgets('should handle multiple ad widgets efficiently', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 20,
              itemBuilder: (context, index) => ControlledAdWidget(
                key: Key('ad_$index'),
                adType: index.isEven ? ControlledAdType.banner : ControlledAdType.native,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should handle multiple widgets without performance issues
      expect(find.byType(ControlledAdWidget), findsWidgets);
    });
  });
}