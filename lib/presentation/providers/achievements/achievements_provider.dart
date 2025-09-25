import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/achievements_repository.dart';
import '../../../infrastructure/datasources/achievements_shared_preferences_datasource.dart';
import '../../../infrastructure/repositories/achievements_repository_impl.dart';
import '../../services/achievement_notification_service.dart';

// Provider del repositorio
final achievementsRepositoryProvider = Provider<AchievementsRepository>((ref) {
  final datasource = AchievementsSharedPreferencesDatasource();
  return AchievementsRepositoryImpl(datasource);
});

// Provider para todos los logros
final achievementsProvider =
    StateNotifierProvider<AchievementsNotifier, AchievementsState>((ref) {
  final repository = ref.watch(achievementsRepositoryProvider);
  return AchievementsNotifier(repository);
});

// Provider para logros desbloqueados
final unlockedAchievementsProvider =
    FutureProvider<List<Achievement>>((ref) async {
  final repository = ref.watch(achievementsRepositoryProvider);
  return repository.getUnlockedAchievements();
});

// Estado para los logros
class AchievementsState {
  AchievementsState({
    this.achievements = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Achievement> achievements;
  final bool isLoading;
  final String? error;

  AchievementsState copyWith({
    List<Achievement>? achievements,
    bool? isLoading,
    String? error,
  }) {
    return AchievementsState(
      achievements: achievements ?? this.achievements,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // Getters para filtrar logros por categoría
  List<Achievement> get movieAchievements => achievements
      .where((a) => a.category == AchievementCategory.movies)
      .toList();

  List<Achievement> get favoriteAchievements => achievements
      .where((a) => a.category == AchievementCategory.favorites)
      .toList();

  List<Achievement> get explorationAchievements => achievements
      .where((a) => a.category == AchievementCategory.exploration)
      .toList();

  List<Achievement> get unlockedAchievements =>
      achievements.where((a) => a.isUnlocked).toList();

  List<Achievement> get lockedAchievements =>
      achievements.where((a) => !a.isUnlocked).toList();
}

// Notifier para gestionar los logros
class AchievementsNotifier extends StateNotifier<AchievementsState> {
  AchievementsNotifier(this.repository) : super(AchievementsState()) {
    _initialize();
  }

  final AchievementsRepository repository;

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      await repository.initializeDefaultAchievements();
      await loadAchievements();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadAchievements() async {
    try {
      final achievements = await repository.getAllAchievements();
      state = state.copyWith(
        achievements: achievements,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> trackMovieWatched(Movie movie) async {
    try {
      final previousAchievements = List<Achievement>.from(state.achievements);

      await repository.trackMovieWatched();

      // Track género explorado
      for (final genre in movie.genreIds) {
        await repository.trackGenreExplored(genre);
      }

      // Track década explorada
      final year = movie.releaseDate.year;
      await repository.trackDecadeExplored(year);

      await loadAchievements();

      // Mostrar notificaciones de logros nuevos
      final newlyUnlocked = getNewlyUnlockedAchievements(previousAchievements);
      for (final achievement in newlyUnlocked) {
        AchievementNotificationService.showAchievementUnlocked(achievement);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> trackMovieFavorited() async {
    try {
      final previousAchievements = List<Achievement>.from(state.achievements);

      await repository.trackMovieFavorited();
      await loadAchievements();

      // Mostrar notificaciones de logros nuevos
      final newlyUnlocked = getNewlyUnlockedAchievements(previousAchievements);
      for (final achievement in newlyUnlocked) {
        AchievementNotificationService.showAchievementUnlocked(achievement);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadAchievements();
  }

  // Método para obtener logros recién desbloqueados
  List<Achievement> getNewlyUnlockedAchievements(
      List<Achievement> previousAchievements) {
    final currentUnlocked = state.unlockedAchievements;
    final previousUnlocked =
        previousAchievements.where((Achievement a) => a.isUnlocked).toList();

    return currentUnlocked.where((Achievement current) {
      return !previousUnlocked
          .any((Achievement previous) => previous.id == current.id);
    }).toList();
  }

  @override
  void dispose() {
    // Limpiar recursos si es necesario
    super.dispose();
  }
}
