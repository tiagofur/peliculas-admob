import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/core/gamification/gamification_manager.dart';
import 'package:peliculas/core/gamification/widgets/gamification_dashboard.dart';
import 'package:peliculas/core/gamification/widgets/badge_display.dart';
import 'package:peliculas/presentation/providers/gamification_providers.dart';

void main() {
  runApp(const ProviderScope(child: GamificationTestApp()));
}

class GamificationTestApp extends StatelessWidget {
  const GamificationTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gamification Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const GamificationTestScreen(),
    );
  }
}

class GamificationTestScreen extends ConsumerStatefulWidget {
  const GamificationTestScreen({super.key});

  @override
  ConsumerState<GamificationTestScreen> createState() => _GamificationTestScreenState();
}

class _GamificationTestScreenState extends ConsumerState<GamificationTestScreen> {
  @override
  void initState() {
    super.initState();
    _initializeGamification();
  }

  Future<void> _initializeGamification() async {
    final manager = ref.read(gamificationManagerProvider);
    await manager.initialize();
    
    // Simulate some user activities for testing
    await manager.trackMovieAddedToFavorites('movie1', 'Action');
    await manager.trackMovieShared('movie1');
    await manager.trackReviewWritten('movie1', 4.5);
    
    // Trigger rebuild
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userProgressAsync = ref.watch(userProgressProvider);
    final recentAchievementsAsync = ref.watch(recentAchievementsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gamification Test'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Progress Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progreso del Usuario',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    userProgressAsync.when(
                      data: (progress) => Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatColumn('Puntos', progress.totalPoints.toString()),
                              _buildStatColumn('Nivel', progress.currentLevel.toString()),
                              _buildStatColumn('Racha', '${progress.streakDays} días'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatColumn('Películas', progress.moviesFavorited.toString()),
                              _buildStatColumn('Compartidas', progress.moviesShared.toString()),
                              _buildStatColumn('Reseñas', progress.reviewsWritten.toString()),
                            ],
                          ),
                        ],
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (error, stack) => Text('Error: $error'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Recent Achievements Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logros Recientes',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    recentAchievementsAsync.when(
                      data: (achievements) => achievements.isEmpty
                          ? const Text('No hay logros desbloqueados aún')
                          : Column(
                              children: achievements.map((achievement) => 
                                Card(
                                  color: Colors.green[50],
                                  child: ListTile(
                                    leading: const Icon(Icons.star, color: Colors.orange),
                                    title: Text(achievement.name),
                                    subtitle: Text(achievement.description),
                                    trailing: Text('${achievement.points} pts'),
                                  ),
                                ),
                              ).toList(),
                            ),
                      loading: () => const CircularProgressIndicator(),
                      error: (error, stack) => Text('Error: $error'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Badge Display Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insignias',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Consumer(
                      builder: (context, ref, child) {
                        final manager = ref.read(gamificationManagerProvider);
                        final unlockedAchievements = manager.getUnlockedAchievements();
                        
                        return BadgeDisplay(
                          unlockedAchievements: unlockedAchievements,
                          showCount: true,
                          isHorizontal: true,
                          maxVisible: 5,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final manager = ref.read(gamificationManagerProvider);
                    await manager.trackMovieAddedToFavorites('movie${DateTime.now().millisecondsSinceEpoch}', 'Action');
                    setState(() {});
                  },
                  child: const Text('Agregar Película'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final manager = ref.read(gamificationManagerProvider);
                    await manager.trackMovieShared('movie${DateTime.now().millisecondsSinceEpoch}');
                    setState(() {});
                  },
                  child: const Text('Compartir'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final manager = ref.read(gamificationManagerProvider);
                    await manager.trackReviewWritten('movie${DateTime.now().millisecondsSinceEpoch}', 4.0);
                    setState(() {});
                  },
                  child: const Text('Escribir Reseña'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}