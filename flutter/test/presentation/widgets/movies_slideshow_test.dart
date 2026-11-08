import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/generated/app_localizations.dart';
import 'package:peliculas/presentation/widgets/movies/movies_slideshow.dart';

Movie _movie(int id) => Movie(
      adult: false,
      backdropPath: '/backdrop.jpg',
      genreIds: const [28],
      id: id,
      originalLanguage: 'en',
      originalTitle: 'Title $id',
      overview: 'Overview',
      popularity: 1.0,
      posterPath: '/poster.jpg',
      releaseDate: DateTime(2026, 1, 1),
      title: 'Title $id',
      video: false,
      voteAverage: 7.0,
      voteCount: 10,
    );

void main() {
  testWidgets('slideshow lays out without scroll-extent precision error',
      (tester) async {
    // Ancho fraccionario: reproduce el viewport real (426.7px) donde
    // itemExtent = width * 0.8 no es exacto en binario.
    tester.view.physicalSize = const Size(427, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MoviesSlideshow(
            movies: [_movie(1), _movie(2), _movie(3)],
          ),
        ),
      ),
    );
    await tester.pump();
    // Drena timers one-shot (reintentos de imagen, etc.). El autoplay
    // periódico se cancela solo al hacer dispose del Swiper.
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));

    expect(tester.takeException(), isNull);
  });
}
