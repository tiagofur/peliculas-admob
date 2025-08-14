import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/datasources/achievements_datasource.dart';
import '../../domain/entities/entities.dart';

class AchievementsSharedPreferencesDatasource extends AchievementsDatasource {
  static const String _achievementsKey = 'achievements';
  static const String _initializedKey = 'achievements_initialized';

  @override
  Future<List<Achievement>> getAllAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final achievementsJson = prefs.getStringList(_achievementsKey) ?? [];
    
    if (achievementsJson.isEmpty) {
      await initializeDefaultAchievements();
      return getAllAchievements();
    }
    
    return achievementsJson
        .map((json) => _achievementFromJson(jsonDecode(json)))
        .toList();
  }

  @override
  Future<void> updateAchievement(Achievement achievement) async {
    final achievements = await getAllAchievements();
    final index = achievements.indexWhere((a) => a.id == achievement.id);
    
    if (index != -1) {
      achievements[index] = achievement;
      await _saveAchievements(achievements);
    }
  }

  @override
  Future<void> unlockAchievement(String achievementId) async {
    final achievements = await getAllAchievements();
    final index = achievements.indexWhere((a) => a.id == achievementId);
    
    if (index != -1 && !achievements[index].isUnlocked) {
      achievements[index] = achievements[index].copyWith(
        isUnlocked: true,
        unlockedDate: DateTime.now(),
        currentValue: achievements[index].targetValue,
      );
      await _saveAchievements(achievements);
    }
  }

  @override
  Future<List<Achievement>> getUnlockedAchievements() async {
    final achievements = await getAllAchievements();
    return achievements.where((a) => a.isUnlocked).toList();
  }

  @override
  Future<void> incrementAchievementProgress(String achievementId, {int increment = 1}) async {
    final achievements = await getAllAchievements();
    final index = achievements.indexWhere((a) => a.id == achievementId);
    
    if (index != -1 && !achievements[index].isUnlocked) {
      final currentAchievement = achievements[index];
      final newValue = (currentAchievement.currentValue + increment)
          .clamp(0, currentAchievement.targetValue);
      
      achievements[index] = currentAchievement.copyWith(
        currentValue: newValue,
        isUnlocked: newValue >= currentAchievement.targetValue,
        unlockedDate: newValue >= currentAchievement.targetValue ? DateTime.now() : null,
      );
      
      await _saveAchievements(achievements);
    }
  }

  @override
  Future<void> initializeDefaultAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final isInitialized = prefs.getBool(_initializedKey) ?? false;
    
    if (!isInitialized) {
      final defaultAchievements = _getDefaultAchievements();
      await _saveAchievements(defaultAchievements);
      await prefs.setBool(_initializedKey, true);
    }
  }

  Future<void> _saveAchievements(List<Achievement> achievements) async {
    final prefs = await SharedPreferences.getInstance();
    final achievementsJson = achievements
        .map((achievement) => jsonEncode(_achievementToJson(achievement)))
        .toList();
    
    await prefs.setStringList(_achievementsKey, achievementsJson);
  }

  List<Achievement> _getDefaultAchievements() {
    return [
      // Logros de películas vistas
      Achievement(
        id: 'first_movie',
        title: 'Primera Película',
        description: 'Marca tu primera película como vista',
        iconName: 'visibility',
        targetValue: 1,
        category: AchievementCategory.movies,
      ),
      Achievement(
        id: 'movie_explorer',
        title: 'Explorador Cinematográfico',
        description: 'Marca 10 películas como vistas',
        iconName: 'explore',
        targetValue: 10,
        category: AchievementCategory.movies,
      ),
      Achievement(
        id: 'movie_enthusiast',
        title: 'Entusiasta del Cine',
        description: 'Marca 50 películas como vistas',
        iconName: 'movie',
        targetValue: 50,
        category: AchievementCategory.movies,
      ),
      Achievement(
        id: 'movie_master',
        title: 'Maestro Cinematográfico',
        description: 'Marca 100 películas como vistas',
        iconName: 'star',
        targetValue: 100,
        category: AchievementCategory.movies,
      ),
      Achievement(
        id: 'movie_legend',
        title: 'Leyenda del Cine',
        description: 'Marca 250 películas como vistas',
        iconName: 'military_tech',
        targetValue: 250,
        category: AchievementCategory.movies,
      ),
      Achievement(
        id: 'marathon_viewer',
        title: 'Maratonista',
        description: 'Ve 5 películas en un solo día',
        iconName: 'timer',
        targetValue: 5,
        category: AchievementCategory.movies,
      ),
      
      // Logros de favoritos
      Achievement(
        id: 'first_favorite',
        title: 'Primer Favorito',
        description: 'Agrega tu primera película a favoritos',
        iconName: 'favorite',
        targetValue: 1,
        category: AchievementCategory.favorites,
      ),
      Achievement(
        id: 'favorite_collector',
        title: 'Coleccionista de Favoritos',
        description: 'Agrega 25 películas a favoritos',
        iconName: 'favorite_border',
        targetValue: 25,
        category: AchievementCategory.favorites,
      ),
      Achievement(
        id: 'favorite_curator',
        title: 'Curador de Favoritos',
        description: 'Agrega 50 películas a favoritos',
        iconName: 'collections_bookmark',
        targetValue: 50,
        category: AchievementCategory.favorites,
      ),
      Achievement(
        id: 'quality_seeker',
        title: 'Buscador de Calidad',
        description: 'Agrega 10 películas con rating >8.0 a favoritos',
        iconName: 'grade',
        targetValue: 10,
        category: AchievementCategory.favorites,
      ),
      
      // Logros de exploración
      Achievement(
        id: 'genre_explorer',
        title: 'Explorador de Géneros',
        description: 'Ve películas de 5 géneros diferentes',
        iconName: 'category',
        targetValue: 5,
        category: AchievementCategory.exploration,
      ),
      Achievement(
        id: 'genre_master',
        title: 'Maestro de Géneros',
        description: 'Ve películas de 10 géneros diferentes',
        iconName: 'dashboard',
        targetValue: 10,
        category: AchievementCategory.exploration,
      ),
      Achievement(
        id: 'decade_traveler',
        title: 'Viajero del Tiempo',
        description: 'Ve películas de 3 décadas diferentes',
        iconName: 'schedule',
        targetValue: 3,
        category: AchievementCategory.exploration,
      ),
      Achievement(
        id: 'nostalgic_viewer',
        title: 'Nostálgico',
        description: 'Ve 10 películas de los 80s y 90s',
        iconName: 'history',
        targetValue: 10,
        category: AchievementCategory.exploration,
      ),
      Achievement(
        id: 'blockbuster_fan',
        title: 'Fan de Blockbusters',
        description: 'Ve 15 películas muy populares (>1000 votos)',
        iconName: 'local_fire_department',
        targetValue: 15,
        category: AchievementCategory.exploration,
      ),
      Achievement(
        id: 'indie_discoverer',
        title: 'Descubridor Indie',
        description: 'Ve 10 películas poco conocidas (<500 votos)',
        iconName: 'search',
        targetValue: 10,
        category: AchievementCategory.exploration,
      ),
      Achievement(
        id: 'critic_aligned',
        title: 'Crítico Alineado',
        description: 'Ve 20 películas aclamadas por la crítica (>7.5)',
        iconName: 'thumb_up',
        targetValue: 20,
        category: AchievementCategory.exploration,
      ),
      Achievement(
        id: 'list_creator',
        title: 'Creador de Listas',
        description: 'Crea tu primera lista personalizada',
        iconName: 'playlist_add',
        targetValue: 1,
        category: AchievementCategory.exploration,
      ),
      Achievement(
        id: 'list_organizer',
        title: 'Organizador Experto',
        description: 'Crea 5 listas personalizadas',
        iconName: 'folder_special',
        targetValue: 5,
        category: AchievementCategory.exploration,
      ),
    ];
  }

  Map<String, dynamic> _achievementToJson(Achievement achievement) {
    return {
      'id': achievement.id,
      'title': achievement.title,
      'description': achievement.description,
      'iconName': achievement.iconName,
      'targetValue': achievement.targetValue,
      'currentValue': achievement.currentValue,
      'isUnlocked': achievement.isUnlocked,
      'unlockedDate': achievement.unlockedDate?.toIso8601String(),
      'category': achievement.category.index,
    };
  }

  Achievement _achievementFromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      iconName: json['iconName'],
      targetValue: json['targetValue'],
      currentValue: json['currentValue'] ?? 0,
      isUnlocked: json['isUnlocked'] ?? false,
      unlockedDate: json['unlockedDate'] != null 
          ? DateTime.parse(json['unlockedDate']) 
          : null,
      category: AchievementCategory.values[json['category'] ?? 0],
    );
  }
}