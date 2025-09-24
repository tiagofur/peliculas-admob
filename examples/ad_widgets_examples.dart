import 'package:flutter/material.dart';

import 'package:peliculas/core/logging/logger_factory.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/presentation/widgets/movies/movie_horizontal_listview_with_ads.dart';
import 'package:peliculas/presentation/widgets/movies/movie_masonry_with_ads.dart';
import 'package:peliculas/presentation/widgets/admob/full_width_ad_widget.dart';
import 'package:peliculas/presentation/widgets/admob/grid_ad_widget.dart';
import 'package:peliculas/presentation/widgets/admob/movie_card_ad_widget.dart';

/// Ejemplos de uso de todos los widgets de anuncios
/// Este archivo demuestra cómo integrar los anuncios en diferentes contextos
class AdWidgetsExamples extends StatelessWidget {
  const AdWidgetsExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejemplos de Anuncios'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('1. Anuncios en Listas Horizontales'),
            const SizedBox(height: 16),
            _buildHorizontalListExample(),
            const SizedBox(height: 32),
            _buildSectionTitle('2. Anuncios Individuales'),
            const SizedBox(height: 16),
            _buildIndividualAdsExample(),
            const SizedBox(height: 32),
            _buildSectionTitle('3. Anuncios de Ancho Completo'),
            const SizedBox(height: 16),
            _buildFullWidthAdsExample(),
            const SizedBox(height: 32),
            _buildSectionTitle('4. Grid con Anuncios'),
            const SizedBox(height: 16),
            _buildGridExample(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildHorizontalListExample() {
    // Ejemplo con películas ficticias
    final movies = _generateSampleMovies(20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lista horizontal con anuncios cada 5 películas:',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        MovieHorizontalListviewWithAds(
          movies: movies,
          sectionId: 'example-popular',
          title: 'Películas Populares',
          subTitle: 'Ver todas',
          adFrequency: 5,
          enableAds: true,
        ),
      ],
    );
  }

  Widget _buildIndividualAdsExample() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Diferentes tipos de anuncios individuales:',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        SizedBox(height: 16),

        // Fila con diferentes tipos de anuncios de tarjeta
        Row(
          children: [
            // Anuncio de tarjeta estándar
            Expanded(
              child: Column(
                children: [
                  MovieCardAdWidget(),
                  SizedBox(height: 8),
                  Text(
                    'MovieCardAdWidget',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            SizedBox(width: 16),

            // Anuncio de tarjeta compacto
            Expanded(
              child: Column(
                children: [
                  CompactMovieCardAdWidget(),
                  SizedBox(height: 8),
                  Text(
                    'CompactMovieCardAdWidget',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            SizedBox(width: 16),

            // Anuncio de grid
            Expanded(
              child: Column(
                children: [
                  GridAdWidget(),
                  SizedBox(height: 8),
                  Text(
                    'GridAdWidget',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFullWidthAdsExample() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Anuncios de ancho completo:',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        SizedBox(height: 16),

        // Anuncio estándar
        FullWidthAdWidget(),

        SizedBox(height: 16),

        // Anuncio compacto
        CompactFullWidthAdWidget(),

        SizedBox(height: 16),

        // Anuncio premium
        PremiumFullWidthAdWidget(),
      ],
    );
  }

  Widget _buildGridExample() {
    final movies = _generateSampleMovies(30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Grid de películas con anuncios integrados:',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 8),

        // Contenedor con altura fija para el ejemplo
        SizedBox(
          height: 600,
          child: MovieMasonryWithAds(
            movies: movies,
            loadNextPage: () {
              // Simular carga de más películas
              LoggerFactory.info('Cargando más películas...');
            },
            gridAdFrequency: 9,
            fullWidthAdFrequency: 15,
            enableGridAds: true,
            enableFullWidthAds: true,
          ),
        ),
      ],
    );
  }

  /// Genera películas de ejemplo para las demostraciones
  List<Movie> _generateSampleMovies(int count) {
    return List.generate(count, (index) {
      return Movie(
        adult: false,
        backdropPath:
            'https://image.tmdb.org/t/p/w500/sample_backdrop_$index.jpg',
        genreIds: ['28', '12', '878'], // Acción, Aventura, Ciencia ficción
        id: index + 1,
        originalLanguage: 'en',
        originalTitle: 'Sample Movie ${index + 1}',
        overview:
            'Esta es una película de ejemplo número ${index + 1} para demostrar la integración de anuncios.',
        popularity: 100.0 - index,
        posterPath: 'https://image.tmdb.org/t/p/w500/sample_poster_$index.jpg',
        releaseDate: DateTime.now().subtract(Duration(days: index * 30)),
        title: 'Película de Ejemplo ${index + 1}',
        video: false,
        voteAverage: 7.5 + (index % 3) * 0.5,
        voteCount: 1000 + index * 50,
      );
    });
  }
}

/// Widget de demostración para mostrar diferentes configuraciones de anuncios
class AdConfigurationDemo extends StatefulWidget {
  const AdConfigurationDemo({super.key});

  @override
  State<AdConfigurationDemo> createState() => _AdConfigurationDemoState();
}

class _AdConfigurationDemoState extends State<AdConfigurationDemo> {
  int _horizontalAdFrequency = 5;
  int _gridAdFrequency = 9;
  int _fullWidthAdFrequency = 15;
  bool _enableHorizontalAds = true;
  bool _enableGridAds = true;
  bool _enableFullWidthAds = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Anuncios'),
      ),
      body: Column(
        children: [
          // Panel de configuración
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuración de Anuncios',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Controles para anuncios horizontales
                Row(
                  children: [
                    Checkbox(
                      value: _enableHorizontalAds,
                      onChanged: (value) {
                        setState(() {
                          _enableHorizontalAds = value ?? false;
                        });
                      },
                    ),
                    const Text('Anuncios horizontales cada '),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(
                          text: _horizontalAdFrequency.toString(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _horizontalAdFrequency = int.tryParse(value) ?? 5;
                          });
                        },
                      ),
                    ),
                    const Text(' películas'),
                  ],
                ),

                // Controles para anuncios de grid
                Row(
                  children: [
                    Checkbox(
                      value: _enableGridAds,
                      onChanged: (value) {
                        setState(() {
                          _enableGridAds = value ?? false;
                        });
                      },
                    ),
                    const Text('Anuncios de grid cada '),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(
                          text: _gridAdFrequency.toString(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _gridAdFrequency = int.tryParse(value) ?? 9;
                          });
                        },
                      ),
                    ),
                    const Text(' películas'),
                  ],
                ),

                // Controles para anuncios de ancho completo
                Row(
                  children: [
                    Checkbox(
                      value: _enableFullWidthAds,
                      onChanged: (value) {
                        setState(() {
                          _enableFullWidthAds = value ?? false;
                        });
                      },
                    ),
                    const Text('Anuncios completos cada '),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(
                          text: _fullWidthAdFrequency.toString(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _fullWidthAdFrequency = int.tryParse(value) ?? 15;
                          });
                        },
                      ),
                    ),
                    const Text(' películas'),
                  ],
                ),
              ],
            ),
          ),

          // Vista previa con la configuración actual
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Lista horizontal con configuración actual
                  MovieHorizontalListviewWithAds(
                    movies: _generateSampleMovies(20),
                    sectionId: 'config-demo',
                    title: 'Vista Previa - Lista Horizontal',
                    adFrequency: _horizontalAdFrequency,
                    enableAds: _enableHorizontalAds,
                  ),

                  const SizedBox(height: 32),

                  // Grid con configuración actual
                  SizedBox(
                    height: 400,
                    child: MovieMasonryWithAds(
                      movies: _generateSampleMovies(30),
                      loadNextPage: () {},
                      gridAdFrequency: _gridAdFrequency,
                      fullWidthAdFrequency: _fullWidthAdFrequency,
                      enableGridAds: _enableGridAds,
                      enableFullWidthAds: _enableFullWidthAds,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Movie> _generateSampleMovies(int count) {
    return List.generate(count, (index) {
      return Movie(
        adult: false,
        backdropPath:
            'https://image.tmdb.org/t/p/w500/sample_backdrop_$index.jpg',
        genreIds: ['28', '12', '878'],
        id: index + 1,
        originalLanguage: 'en',
        originalTitle: 'Sample Movie ${index + 1}',
        overview: 'Película de ejemplo ${index + 1}',
        popularity: 100.0 - index,
        posterPath: 'https://image.tmdb.org/t/p/w500/sample_poster_$index.jpg',
        releaseDate: DateTime.now().subtract(Duration(days: index * 30)),
        title: 'Película ${index + 1}',
        video: false,
        voteAverage: 7.0 + (index % 4) * 0.5,
        voteCount: 1000 + index * 50,
      );
    });
  }
}
