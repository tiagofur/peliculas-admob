// ignore: unnecessary_library_name
library pro_ad_widgets_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/presentation/widgets/admob/ad_integration_helper.dart';
import 'package:peliculas/presentation/widgets/admob/banner_ad_widget.dart';
import 'package:peliculas/presentation/widgets/admob/controlled_ad_widget.dart';
import 'package:peliculas/presentation/widgets/admob/native_ad_widget.dart';
import 'package:peliculas/services/monetization/user_monetization_preferences_service.dart';
import 'package:peliculas/widgets/ads/ad_placeholder_widget.dart';

Movie _movie(int id) => Movie(
      id: id,
      title: 'M$id',
      adult: false,
      backdropPath: '/b.jpg',
      genreIds: const [1],
      originalLanguage: 'es',
      originalTitle: 'M$id',
      overview: 'overview',
      popularity: 1.0,
      posterPath: '/p.jpg',
      releaseDate: DateTime(2024, 1, 1),
      video: false,
      voteAverage: 7.0,
      voteCount: 10,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    UserMonetizationPreferencesService.isProCached = false;
    await UserMonetizationPreferencesService.instance.initialize();
    await UserMonetizationPreferencesService.instance.clearUserData();
  });

  tearDown(() {
    UserMonetizationPreferencesService.isProCached = false;
  });

  group('AdIntegrationHelper con Pro', () {
    test('lista horizontal Pro no inserta anuncios', () {
      final movies = List.generate(12, _movie);

      final items =
          AdIntegrationHelper.createHorizontalAdList(movies, isPro: true);

      expect(items.length, movies.length);
      expect(items.every((e) => e.type == AdItemType.movie), isTrue);
    });

    test('lista horizontal sin Pro inserta anuncios como antes', () {
      final movies = List.generate(12, _movie);

      final items = AdIntegrationHelper.createHorizontalAdList(movies);

      expect(items.length, greaterThan(movies.length));
      expect(items.any((e) => e.type == AdItemType.horizontalAd), isTrue);
    });

    test('grid Pro no inserta anuncios', () {
      final movies = List.generate(30, _movie);

      final items = AdIntegrationHelper.createGridAdList(movies, isPro: true);

      expect(items.length, movies.length);
      expect(items.every((e) => e.type == AdItemType.movie), isTrue);
    });

    test('grid sin Pro inserta anuncios como antes', () {
      final movies = List.generate(30, _movie);

      final items = AdIntegrationHelper.createGridAdList(movies);

      expect(items.length, greaterThan(movies.length));
    });
  });

  group('Leaf widgets con Pro', () {
    testWidgets('BannerAdWidget Pro renderiza vacío', (tester) async {
      UserMonetizationPreferencesService.isProCached = true;

      await tester.pumpWidget(const MaterialApp(home: BannerAdWidget()));

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byType(AdPlaceholderWidget), findsNothing);
    });

    testWidgets('BannerAdWidget sin Pro mantiene placeholder debug',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BannerAdWidget()));

      expect(find.byType(AdPlaceholderWidget), findsOneWidget);
    });

    testWidgets('NativeAdWidget Pro renderiza vacío', (tester) async {
      UserMonetizationPreferencesService.isProCached = true;

      await tester.pumpWidget(const MaterialApp(home: NativeAdWidget()));

      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('ControlledAdWidget Pro no monta el widget de anuncio',
        (tester) async {
      await UserMonetizationPreferencesService.instance.setProActive(true);

      await tester.pumpWidget(const MaterialApp(
        home: ControlledAdWidget(adType: ControlledAdType.banner),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(BannerAdWidget), findsNothing);
    });
  });
}
