import 'models/achievement.dart';

/// Definiciones y configuraciones para las categorías de logros
class AchievementCategories {
  static const String _iconBasePath = 'assets/icons/achievements';

  /// Logros de Movie Explorer - Exploración y descubrimiento de películas
  static List<Achievement> get movieExplorerAchievements => [
        Achievement(
          id: 'first_movie',
          name: 'Primera Película',
          description: 'Agrega tu primera película a favoritos',
          category: AchievementCategory.general,
          rarity: AchievementRarity.common,
          points: 10,
          maxProgress: 1,
          iconPath: '$_iconBasePath/first_movie.png',
        ),
        Achievement(
          id: 'movie_enthusiast',
          name: 'Entusiasta del Cine',
          description: 'Agrega 10 películas a favoritos',
          category: AchievementCategory.general,
          rarity: AchievementRarity.common,
          points: 50,
          maxProgress: 10,
          iconPath: '$_iconBasePath/movie_enthusiast.png',
        ),
        Achievement(
          id: 'movie_collector',
          name: 'Coleccionista',
          description: 'Agrega 50 películas a favoritos',
          category: AchievementCategory.collection,
          rarity: AchievementRarity.uncommon,
          points: 150,
          maxProgress: 50,
          iconPath: '$_iconBasePath/collector.png',
        ),
        Achievement(
          id: 'movie_curator',
          name: 'Curador de Cine',
          description: 'Agrega 100 películas a favoritos',
          category: AchievementCategory.collection,
          rarity: AchievementRarity.rare,
          points: 300,
          maxProgress: 100,
          iconPath: '$_iconBasePath/curator.png',
        ),
        Achievement(
          id: 'movie_master',
          name: 'Maestro del Cine',
          description: 'Agrega 200 películas a favoritos',
          category: AchievementCategory.collection,
          rarity: AchievementRarity.epic,
          points: 500,
          maxProgress: 200,
          iconPath: '$_iconBasePath/movie_master.png',
        ),
        Achievement(
          id: 'movie_legend',
          name: 'Leyenda Cinematográfica',
          description: 'Agrega 500 películas a favoritos',
          category: AchievementCategory.collection,
          rarity: AchievementRarity.legendary,
          points: 1000,
          maxProgress: 500,
          iconPath: '$_iconBasePath/movie_legend.png',
        ),
      ];

  /// Logros de Genre Master - Especialización en géneros específicos
  static List<Achievement> get genreMasterAchievements => [
        // Acción
        Achievement(
          id: 'action_fan',
          name: 'Fan de Acción',
          description: 'Agrega 15 películas de acción a favoritos',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.common,
          points: 75,
          maxProgress: 15,
          iconPath: '$_iconBasePath/action_fan.png',
        ),
        Achievement(
          id: 'action_expert',
          name: 'Experto en Acción',
          description: 'Agrega 50 películas de acción a favoritos',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.rare,
          points: 200,
          maxProgress: 50,
          iconPath: '$_iconBasePath/action_expert.png',
        ),

        // Terror
        Achievement(
          id: 'horror_enthusiast',
          name: 'Amante del Terror',
          description: 'Agrega 10 películas de terror a favoritos',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.common,
          points: 60,
          maxProgress: 10,
          iconPath: '$_iconBasePath/horror_fan.png',
        ),
        Achievement(
          id: 'horror_master',
          name: 'Maestro del Terror',
          description: 'Agrega 30 películas de terror a favoritos',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.uncommon,
          points: 150,
          maxProgress: 30,
          iconPath: '$_iconBasePath/horror_master.png',
        ),

        // Comedia
        Achievement(
          id: 'comedy_lover',
          name: 'Risas Garantizadas',
          description: 'Agrega 20 comedias a favoritos',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.common,
          points: 80,
          maxProgress: 20,
          iconPath: '$_iconBasePath/comedy_lover.png',
        ),
        Achievement(
          id: 'comedy_connoisseur',
          name: 'Conocedor de Comedias',
          description: 'Agrega 40 comedias a favoritos',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.uncommon,
          points: 160,
          maxProgress: 40,
          iconPath: '$_iconBasePath/comedy_connoisseur.png',
        ),

        // Drama
        Achievement(
          id: 'drama_appreciator',
          name: 'Apreciador de Dramas',
          description: 'Agrega 15 dramas a favoritos',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.common,
          points: 75,
          maxProgress: 15,
          iconPath: '$_iconBasePath/drama_appreciator.png',
        ),
        Achievement(
          id: 'drama_scholar',
          name: 'Erudito del Drama',
          description: 'Agrega 35 dramas a favoritos',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.uncommon,
          points: 175,
          maxProgress: 35,
          iconPath: '$_iconBasePath/drama_scholar.png',
        ),

        // Ciencia Ficción
        Achievement(
          id: 'scifi_explorer',
          name: 'Explorador Sci-Fi',
          description: 'Agrega 12 películas de ciencia ficción a favoritos',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.common,
          points: 70,
          maxProgress: 12,
          iconPath: '$_iconBasePath/scifi_explorer.png',
        ),
        Achievement(
          id: 'scifi_visionary',
          name: 'Visionario Sci-Fi',
          description: 'Agrega 30 películas de ciencia ficción a favoritos',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.rare,
          points: 180,
          maxProgress: 30,
          iconPath: '$_iconBasePath/scifi_visionary.png',
        ),

        // Romance
        Achievement(
          id: 'romance_fan',
          name: 'Romántico Empedernido',
          description: 'Agrega 15 películas románticas a favoritos',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.common,
          points: 75,
          maxProgress: 15,
          iconPath: '$_iconBasePath/romance_fan.png',
        ),

        // Thriller
        Achievement(
          id: 'thriller_seeker',
          name: 'Buscador de Emociones',
          description: 'Agrega 18 thrillers a favoritos',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.uncommon,
          points: 90,
          maxProgress: 18,
          iconPath: '$_iconBasePath/thriller_seeker.png',
        ),

        // Género Diverso
        Achievement(
          id: 'genre_explorer',
          name: 'Explorador de Géneros',
          description: 'Agrega películas de al menos 5 géneros diferentes',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.rare,
          points: 250,
          maxProgress: 5,
          iconPath: '$_iconBasePath/genre_explorer.png',
        ),
        Achievement(
          id: 'genre_master',
          name: 'Maestro de Géneros',
          description: 'Agrega películas de al menos 10 géneros diferentes',
          category: AchievementCategory.movies,
          rarity: AchievementRarity.epic,
          points: 500,
          maxProgress: 10,
          iconPath: '$_iconBasePath/genre_master.png',
        ),
      ];

  /// Logros de Binge Watcher - Actividad intensiva de visualización
  static List<Achievement> get bingeWatcherAchievements => [
        Achievement(
          id: 'daily_duo',
          name: 'Dúo Diario',
          description: 'Agrega 2 películas en un día',
          category: AchievementCategory.general,
          rarity: AchievementRarity.common,
          points: 20,
          maxProgress: 2,
          iconPath: '$_iconBasePath/daily_duo.png',
        ),
        Achievement(
          id: 'weekend_warrior',
          name: 'Guerrero del Fin de Semana',
          description: 'Agrega 5 películas en un día',
          category: AchievementCategory.general,
          rarity: AchievementRarity.common,
          points: 50,
          maxProgress: 5,
          iconPath: '$_iconBasePath/weekend_warrior.png',
        ),
        Achievement(
          id: 'binge_master',
          name: 'Maestro del Maratón',
          description: 'Agrega 10 películas en un día',
          category: AchievementCategory.general,
          rarity: AchievementRarity.uncommon,
          points: 100,
          maxProgress: 10,
          iconPath: '$_iconBasePath/binge_master.png',
        ),
        Achievement(
          id: 'marathon_legend',
          name: 'Leyenda del Maratón',
          description: 'Agrega 15 películas en un día',
          category: AchievementCategory.general,
          rarity: AchievementRarity.rare,
          points: 200,
          maxProgress: 15,
          iconPath: '$_iconBasePath/marathon_legend.png',
        ),
        Achievement(
          id: 'weekly_explorer',
          name: 'Explorador Semanal',
          description: 'Agrega 20 películas en una semana',
          category: AchievementCategory.general,
          rarity: AchievementRarity.uncommon,
          points: 150,
          maxProgress: 20,
          iconPath: '$_iconBasePath/weekly_explorer.png',
        ),
        Achievement(
          id: 'monthly_champion',
          name: 'Campeón Mensual',
          description: 'Agrega 50 películas en un mes',
          category: AchievementCategory.general,
          rarity: AchievementRarity.rare,
          points: 300,
          maxProgress: 50,
          iconPath: '$_iconBasePath/monthly_champion.png',
        ),
        Achievement(
          id: 'consistency_king',
          name: 'Rey de la Consistencia',
          description: 'Agrega al menos 1 película durante 7 días consecutivos',
          category: AchievementCategory.general,
          rarity: AchievementRarity.epic,
          points: 250,
          maxProgress: 7,
          iconPath: '$_iconBasePath/consistency_king.png',
        ),
      ];

  /// Logros de Social Butterfly - Interacción social y compartir
  static List<Achievement> get socialButterflyAchievements => [
        Achievement(
          id: 'first_share',
          name: 'Primera Compartida',
          description: 'Comparte tu primera película',
          category: AchievementCategory.social,
          rarity: AchievementRarity.common,
          points: 15,
          maxProgress: 1,
          iconPath: '$_iconBasePath/first_share.png',
        ),
        Achievement(
          id: 'social_starter',
          name: 'Iniciador Social',
          description: 'Comparte 5 películas',
          category: AchievementCategory.social,
          rarity: AchievementRarity.common,
          points: 50,
          maxProgress: 5,
          iconPath: '$_iconBasePath/social_starter.png',
        ),
        Achievement(
          id: 'sharing_enthusiast',
          name: 'Entusiasta del Compartir',
          description: 'Comparte 15 películas',
          category: AchievementCategory.social,
          rarity: AchievementRarity.uncommon,
          points: 100,
          maxProgress: 15,
          iconPath: '$_iconBasePath/sharing_enthusiast.png',
        ),
        Achievement(
          id: 'social_influencer',
          name: 'Influencer Social',
          description: 'Comparte 30 películas',
          category: AchievementCategory.social,
          rarity: AchievementRarity.rare,
          points: 200,
          maxProgress: 30,
          iconPath: '$_iconBasePath/social_influencer.png',
        ),
        Achievement(
          id: 'social_star',
          name: 'Estrella Social',
          description: 'Comparte 50 películas',
          category: AchievementCategory.social,
          rarity: AchievementRarity.epic,
          points: 350,
          maxProgress: 50,
          iconPath: '$_iconBasePath/social_star.png',
        ),
        Achievement(
          id: 'viral_creator',
          name: 'Creador Viral',
          description: 'Comparte 100 películas',
          category: AchievementCategory.social,
          rarity: AchievementRarity.legendary,
          points: 500,
          maxProgress: 100,
          iconPath: '$_iconBasePath/viral_creator.png',
        ),
        Achievement(
          id: 'recommendation_guru',
          name: 'Gurú de Recomendaciones',
          description: 'Comparte películas de 8 géneros diferentes',
          category: AchievementCategory.social,
          rarity: AchievementRarity.rare,
          points: 300,
          maxProgress: 8,
          iconPath: '$_iconBasePath/recommendation_guru.png',
        ),
      ];

  /// Logros de Critic - Escritura de reseñas y críticas
  static List<Achievement> get criticAchievements => [
        Achievement(
          id: 'first_review',
          name: 'Primera Reseña',
          description: 'Escribe tu primera reseña',
          category: AchievementCategory.engagement,
          rarity: AchievementRarity.common,
          points: 25,
          maxProgress: 1,
          iconPath: '$_iconBasePath/first_review.png',
        ),
        Achievement(
          id: 'budding_critic',
          name: 'Crítico en Ciernes',
          description: 'Escribe 5 reseñas',
          category: AchievementCategory.engagement,
          rarity: AchievementRarity.common,
          points: 75,
          maxProgress: 5,
          iconPath: '$_iconBasePath/budding_critic.png',
        ),
        Achievement(
          id: 'thoughtful_reviewer',
          name: 'Reseñador Reflexivo',
          description: 'Escribe 10 reseñas',
          category: AchievementCategory.engagement,
          rarity: AchievementRarity.uncommon,
          points: 125,
          maxProgress: 10,
          iconPath: '$_iconBasePath/thoughtful_reviewer.png',
        ),
        Achievement(
          id: 'prolific_critic',
          name: 'Crítico Prolífico',
          description: 'Escribe 25 reseñas',
          category: AchievementCategory.engagement,
          rarity: AchievementRarity.uncommon,
          points: 250,
          maxProgress: 25,
          iconPath: '$_iconBasePath/prolific_critic.png',
        ),
        Achievement(
          id: 'expert_reviewer',
          name: 'Reseñador Experto',
          description: 'Escribe 50 reseñas',
          category: AchievementCategory.engagement,
          rarity: AchievementRarity.rare,
          points: 400,
          maxProgress: 50,
          iconPath: '$_iconBasePath/expert_reviewer.png',
        ),
        Achievement(
          id: 'master_critic',
          name: 'Crítico Maestro',
          description: 'Escribe 100 reseñas',
          category: AchievementCategory.engagement,
          rarity: AchievementRarity.epic,
          points: 750,
          maxProgress: 100,
          iconPath: '$_iconBasePath/master_critic.png',
        ),
        Achievement(
          id: 'legendary_critic',
          name: 'Crítico Legendario',
          description: 'Escribe 200 reseñas',
          category: AchievementCategory.engagement,
          rarity: AchievementRarity.legendary,
          points: 1200,
          maxProgress: 200,
          iconPath: '$_iconBasePath/legendary_critic.png',
        ),
        Achievement(
          id: 'detailed_analyst',
          name: 'Analista Detallado',
          description: 'Escribe 10 reseñas con más de 100 palabras',
          category: AchievementCategory.engagement,
          rarity: AchievementRarity.rare,
          points: 300,
          maxProgress: 10,
          iconPath: '$_iconBasePath/detailed_analyst.png',
        ),
        Achievement(
          id: 'balanced_critic',
          name: 'Crítico Equilibrado',
          description:
              'Escribe reseñas con calificaciones variadas (1-5 estrellas)',
          category: AchievementCategory.engagement,
          rarity: AchievementRarity.uncommon,
          points: 200,
          maxProgress: 5,
          iconPath: '$_iconBasePath/balanced_critic.png',
        ),
      ];

  /// Logros de Completionist - Completar listas y colecciones
  static List<Achievement> get completionistAchievements => [
        Achievement(
          id: 'watchlist_starter',
          name: 'Iniciador de Listas',
          description: 'Crea tu primera lista de reproducción',
          category: AchievementCategory.collection,
          rarity: AchievementRarity.common,
          points: 30,
          maxProgress: 1,
          iconPath: '$_iconBasePath/watchlist_starter.png',
        ),
        Achievement(
          id: 'watchlist_complete',
          name: 'Lista Completada',
          description: 'Completa tu primera lista de reproducción',
          category: AchievementCategory.collection,
          rarity: AchievementRarity.uncommon,
          points: 100,
          maxProgress: 1,
          iconPath: '$_iconBasePath/watchlist_complete.png',
        ),
        Achievement(
          id: 'list_master',
          name: 'Maestro de Listas',
          description: 'Completa 5 listas de reproducción',
          category: AchievementCategory.collection,
          rarity: AchievementRarity.rare,
          points: 300,
          maxProgress: 5,
          iconPath: '$_iconBasePath/list_master.png',
        ),
        Achievement(
          id: 'completion_champion',
          name: 'Campeón de Completado',
          description: 'Completa 10 listas de reproducción',
          category: AchievementCategory.collection,
          rarity: AchievementRarity.epic,
          points: 500,
          maxProgress: 10,
          iconPath: '$_iconBasePath/completion_champion.png',
        ),
        Achievement(
          id: 'organized_viewer',
          name: 'Espectador Organizado',
          description: 'Mantén 3 listas activas simultáneamente',
          category: AchievementCategory.collection,
          rarity: AchievementRarity.uncommon,
          points: 150,
          maxProgress: 3,
          iconPath: '$_iconBasePath/organized_viewer.png',
        ),
      ];

  /// Logros de Trendsetter - Descubrir tendencias y novedades
  static List<Achievement> get trendsetterAchievements => [
        Achievement(
          id: 'early_adopter',
          name: 'Adoptador Temprano',
          description: 'Agrega una película recién estrenada (menos de 1 mes)',
          category: AchievementCategory.discovery,
          rarity: AchievementRarity.common,
          points: 40,
          maxProgress: 1,
          iconPath: '$_iconBasePath/early_adopter.png',
        ),
        Achievement(
          id: 'trend_spotter',
          name: 'Cazador de Tendencias',
          description: 'Agrega 5 películas recién estrenadas',
          category: AchievementCategory.discovery,
          rarity: AchievementRarity.uncommon,
          points: 150,
          maxProgress: 5,
          iconPath: '$_iconBasePath/trend_spotter.png',
        ),
        Achievement(
          id: 'trendsetter',
          name: 'Creador de Tendencias',
          description: 'Agrega 10 películas recién estrenadas',
          category: AchievementCategory.discovery,
          rarity: AchievementRarity.rare,
          points: 300,
          maxProgress: 10,
          iconPath: '$_iconBasePath/trendsetter.png',
        ),
        Achievement(
          id: 'classic_explorer',
          name: 'Explorador de Clásicos',
          description: 'Agrega 10 películas anteriores a 1990',
          category: AchievementCategory.discovery,
          rarity: AchievementRarity.rare,
          points: 250,
          maxProgress: 10,
          iconPath: '$_iconBasePath/classic_explorer.png',
        ),
        Achievement(
          id: 'decade_collector',
          name: 'Coleccionista de Décadas',
          description: 'Agrega películas de al menos 5 décadas diferentes',
          category: AchievementCategory.discovery,
          rarity: AchievementRarity.epic,
          points: 400,
          maxProgress: 5,
          iconPath: '$_iconBasePath/decade_collector.png',
        ),
      ];

  /// Obtener todos los logros organizados por categoría
  static Map<AchievementCategory, List<Achievement>>
      get allAchievementsByCategory => {
            AchievementCategory.general: movieExplorerAchievements,
            AchievementCategory.movies: genreMasterAchievements,
            AchievementCategory.social: socialButterflyAchievements,
            AchievementCategory.discovery: trendsetterAchievements,
            AchievementCategory.collection: completionistAchievements,
            AchievementCategory.engagement: criticAchievements,
          };

  /// Obtener todos los logros en una lista plana
  static List<Achievement> get allAchievements {
    final List<Achievement> achievements = [];
    for (var categoryAchievements in allAchievementsByCategory.values) {
      achievements.addAll(categoryAchievements);
    }
    return achievements;
  }

  /// Obtener logros por tipo de insignia
  static List<Achievement> getAchievementsByBadge(AchievementRarity rarity) {
    return allAchievements
        .where((achievement) => achievement.rarity == rarity)
        .toList();
  }

  /// Obtener logros por rango de puntos
  static List<Achievement> getAchievementsByPointRange(
      int minPoints, int maxPoints) {
    return allAchievements
        .where((achievement) =>
            achievement.points >= minPoints && achievement.points <= maxPoints)
        .toList();
  }

  /// Obtener descripción de la categoría
  static String getCategoryDescription(AchievementCategory type) {
    switch (type) {
      case AchievementCategory.general:
        return 'Descubre y explora el mundo del cine agregando películas a tu colección';
      case AchievementCategory.movies:
        return 'Conviértete en un experto de géneros específicos';
      case AchievementCategory.social:
        return 'Comparte tus descubrimientos cinematográficos con otros';
      case AchievementCategory.discovery:
        return 'Mantente al día con las últimas tendencias y clásicos atemporales';
      case AchievementCategory.collection:
        return 'Completa listas y colecciones organizadas';
      case AchievementCategory.engagement:
        return 'Expresa tus opiniones escribiendo reseñas detalladas';
    }
  }

  /// Obtener nombre amigable de la categoría
  static String getCategoryName(AchievementCategory type) {
    switch (type) {
      case AchievementCategory.general:
        return 'Explorador de Películas';
      case AchievementCategory.movies:
        return 'Maestro de Géneros';
      case AchievementCategory.social:
        return 'Mariposa Social';
      case AchievementCategory.discovery:
        return 'Creador de Tendencias';
      case AchievementCategory.collection:
        return 'Completista';
      case AchievementCategory.engagement:
        return 'Crítico';
    }
  }

  /// Obtener color asociado a cada categoría
  static String getCategoryColor(AchievementCategory type) {
    switch (type) {
      case AchievementCategory.general:
        return '#4CAF50'; // Verde
      case AchievementCategory.movies:
        return '#2196F3'; // Azul
      case AchievementCategory.social:
        return '#E91E63'; // Rosa
      case AchievementCategory.discovery:
        return '#FF5722'; // Rojo naranja
      case AchievementCategory.collection:
        return '#607D8B'; // Azul gris
      case AchievementCategory.engagement:
        return '#9C27B0'; // Púrpura
    }
  }
}
