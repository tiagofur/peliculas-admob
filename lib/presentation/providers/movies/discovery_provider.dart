import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entities.dart';

// Provider para las categorías de descubrimiento
final discoveryCategories = Provider<List<DiscoveryCategory>>((ref) {
  return [
    // Categorías románticas
    const DiscoveryCategory(
      id: 'romantic_night',
      name: 'Noche Romántica',
      description: 'Películas perfectas para una cita especial',
      emoji: '💕',
      color: Colors.pink,
      associatedGenres: ['10749', '18'], // Romance, Drama
      filters: {
        'with_genres': '10749',
        'vote_average.gte': 6.5,
        'sort_by': 'vote_average.desc',
      },
      mood: 'romantic',
      icon: Icons.favorite,
    ),
    const DiscoveryCategory(
      id: 'date_movies',
      name: 'Para Ver en Pareja',
      description: 'Comedias románticas y dramas ligeros',
      emoji: '👫',
      color: Colors.pinkAccent,
      associatedGenres: ['10749', '35'], // Romance, Comedia
      filters: {
        'with_genres': '10749,35',
        'vote_average.gte': 6.0,
        'with_runtime.lte': 140,
      },
      icon: Icons.people,
    ),

    // Clásicos y joyas ocultas
    const DiscoveryCategory(
      id: 'forgotten_classics',
      name: 'Clásicos Olvidados',
      description: 'Obras maestras que merecen ser redescubiertas',
      emoji: '🎭',
      color: Colors.amber,
      associatedGenres: ['18', '36'], // Drama, Historia
      filters: {
        'primary_release_date.lte': '1999-12-31',
        'vote_average.gte': 7.5,
        'vote_count.gte': 1000,
        'sort_by': 'vote_average.desc',
      },
      icon: Icons.history,
    ),
    const DiscoveryCategory(
      id: 'hidden_gems',
      name: 'Joyas Ocultas',
      description: 'Películas increíbles que pocos conocen',
      emoji: '💎',
      color: Colors.teal,
      associatedGenres: ['18', '53', '9648'], // Drama, Thriller, Misterio
      filters: {
        'vote_average.gte': 7.0,
        'vote_count.gte': 500,
        'vote_count.lte': 5000,
        'sort_by': 'vote_average.desc',
      },
      icon: Icons.diamond,
    ),

    // Diversión familiar
    const DiscoveryCategory(
      id: 'family_fun',
      name: 'Diversión Familiar',
      description: 'Para disfrutar con toda la familia',
      emoji: '👨‍👩‍👧‍👦',
      color: Colors.green,
      associatedGenres: ['10751', '16', '35'], // Familiar, Animación, Comedia
      filters: {
        'with_genres': '10751',
        'vote_average.gte': 6.0,
        'certification_country': 'US',
        'certification.lte': 'PG-13',
      },
      icon: Icons.family_restroom,
    ),
    const DiscoveryCategory(
      id: 'weekend_fun',
      name: 'Para el Fin de Semana',
      description: 'Entretenimiento ligero y divertido',
      emoji: '🍿',
      color: Colors.orange,
      associatedGenres: ['35', '28', '12'], // Comedia, Acción, Aventura
      filters: {
        'with_genres': '35,28,12',
        'vote_average.gte': 6.0,
        'with_runtime.gte': 90,
        'with_runtime.lte': 150,
      },
      icon: Icons.weekend,
    ),

    // Emociones fuertes
    const DiscoveryCategory(
      id: 'adrenaline_rush',
      name: 'Adrenalina Pura',
      description: 'Acción y aventura sin parar',
      emoji: '💥',
      color: Colors.red,
      associatedGenres: ['28', '53', '12'], // Acción, Thriller, Aventura
      filters: {
        'with_genres': '28',
        'vote_average.gte': 6.5,
        'sort_by': 'popularity.desc',
      },
      icon: Icons.flash_on,
    ),
    const DiscoveryCategory(
      id: 'mind_bending',
      name: 'Que Te Harán Pensar',
      description: 'Películas complejas y fascinantes',
      emoji: '🧠',
      color: Colors.purple,
      associatedGenres: [
        '878',
        '9648',
        '53'
      ], // Ciencia Ficción, Misterio, Thriller
      filters: {
        'with_genres': '878,9648,53',
        'vote_average.gte': 7.0,
        'with_runtime.gte': 100,
      },
      icon: Icons.psychology,
    ),

    // Especiales por temporada
    const DiscoveryCategory(
      id: 'rainy_day',
      name: 'Para Días Lluviosos',
      description: 'Perfectas para quedarse en casa',
      emoji: '🌧️',
      color: Colors.blueGrey,
      associatedGenres: ['18', '10749', '35'], // Drama, Romance, Comedia
      filters: {
        'with_genres': '18,10749,35',
        'vote_average.gte': 6.5,
        'with_runtime.gte': 90,
        'with_runtime.lte': 140,
      },
      icon: Icons.home,
    ),
    const DiscoveryCategory(
      id: 'feel_good',
      name: 'Para Sentirse Bien',
      description: 'Películas que alegran el día',
      emoji: '😊',
      color: Colors.yellow,
      associatedGenres: ['35', '10751', '10402'], // Comedia, Familiar, Música
      filters: {
        'with_genres': '35,10751,10402',
        'vote_average.gte': 6.5,
        'sort_by': 'vote_average.desc',
      },
      mood: 'happy',
      icon: Icons.sentiment_very_satisfied,
    ),

    // Internacionales
    const DiscoveryCategory(
      id: 'world_cinema',
      name: 'Cine Mundial',
      description: 'Obras maestras de todo el mundo',
      emoji: '🌍',
      color: Colors.indigo,
      associatedGenres: ['18', '36'], // Drama, Historia
      filters: {
        'with_original_language': 'fr,it,de,ja,ko,es',
        'vote_average.gte': 7.0,
        'vote_count.gte': 1000,
      },
      icon: Icons.public,
    ),
    const DiscoveryCategory(
      id: 'award_winners',
      name: 'Ganadoras de Premios',
      description: 'Películas reconocidas por la crítica',
      emoji: '🏆',
      color: Colors.deepOrange,
      associatedGenres: ['18'], // Drama
      filters: {
        'vote_average.gte': 7.5,
        'vote_count.gte': 2000,
        'sort_by': 'vote_average.desc',
      },
      icon: Icons.emoji_events,
    ),
  ];
});

// Provider para las secciones de descubrimiento
final discoverySections = Provider<List<DiscoverySection>>((ref) {
  final categories = ref.watch(discoveryCategories);

  return [
    DiscoverySection(
      id: 'romantic',
      title: 'Romance & Parejas',
      subtitle: 'Para momentos especiales',
      categories: categories
          .where((c) => c.id == 'romantic_night' || c.id == 'date_movies')
          .toList(),
      icon: Icons.favorite,
      color: Colors.pink,
    ),
    DiscoverySection(
      id: 'classics',
      title: 'Clásicos & Joyas',
      subtitle: 'Tesoros cinematográficos',
      categories: categories
          .where((c) => c.id == 'forgotten_classics' || c.id == 'hidden_gems')
          .toList(),
      icon: Icons.star,
      color: Colors.amber,
    ),
    DiscoverySection(
      id: 'family',
      title: 'Familia & Diversión',
      subtitle: 'Para todos los gustos',
      categories: categories
          .where((c) => c.id == 'family_fun' || c.id == 'weekend_fun')
          .toList(),
      icon: Icons.family_restroom,
      color: Colors.green,
    ),
    DiscoverySection(
      id: 'thrills',
      title: 'Emociones Fuertes',
      subtitle: 'Adrenalina y suspense',
      categories: categories
          .where((c) => c.id == 'adrenaline_rush' || c.id == 'mind_bending')
          .toList(),
      icon: Icons.flash_on,
      color: Colors.red,
    ),
    DiscoverySection(
      id: 'mood',
      title: 'Por Estado de Ánimo',
      subtitle: 'Según como te sientes',
      categories: categories
          .where((c) => c.id == 'rainy_day' || c.id == 'feel_good')
          .toList(),
      icon: Icons.mood,
      color: Colors.blue,
    ),
    DiscoverySection(
      id: 'international',
      title: 'Cine Internacional',
      subtitle: 'Lo mejor del mundo',
      categories: categories
          .where((c) => c.id == 'world_cinema' || c.id == 'award_winners')
          .toList(),
      icon: Icons.public,
      color: Colors.indigo,
    ),
  ];
});

// Provider para categorías favoritas del usuario
final userFavoriteCategoriesProvider = StateProvider<List<String>>((ref) {
  return [];
});

// Provider para obtener películas de una categoría específica
final categoryMoviesProvider =
    FutureProvider.family<List<Movie>, String>((ref, categoryId) async {
  // Aquí implementarías la lógica para obtener películas basadas en la categoría
  // Por ahora retornamos una lista vacía
  return [];
});

// Provider para gestionar el estado de descubrimiento
class DiscoveryNotifier
    extends StateNotifier<AsyncValue<List<DiscoveryCategory>>> {
  DiscoveryNotifier() : super(const AsyncValue.loading()) {
    _loadCategories();
  }

  void _loadCategories() {
    // Simular carga de categorías
    Future.delayed(const Duration(milliseconds: 500), () {
      // Aquí cargarías las categorías desde una fuente de datos
      state = const AsyncValue.data([]);
    });
  }

  void toggleFavoriteCategory(String categoryId) {
    // Implementar lógica para marcar/desmarcar categoría como favorita
  }

  void refreshCategories() {
    state = const AsyncValue.loading();
    _loadCategories();
  }
}

final discoveryNotifierProvider = StateNotifierProvider<DiscoveryNotifier,
    AsyncValue<List<DiscoveryCategory>>>((ref) {
  return DiscoveryNotifier();
});
