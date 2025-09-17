# 🏆 FASE 3: DESAFÍOS Y EVENTOS TEMPORALES

## 📋 **INFORMACIÓN GENERAL**

| Campo                 | Valor           |
| --------------------- | --------------- |
| **Duración estimada** | 1 semana        |
| **Fecha inicio**      | Oct 8, 2025     |
| **Fecha fin**         | Oct 14, 2025    |
| **Recursos**          | 1 desarrollador |
| **Prioridad**         | Media           |
| **Estado**            | Planificado     |

## 🎯 **OBJETIVOS**

### **Objetivo Principal**

Implementar un sistema dinámico de desafíos y eventos temporales que mantenga a los usuarios comprometidos através de metas gamificadas, competencias entre amigos y eventos especiales relacionados con fechas del calendario cinematográfico.

### **Objetivos Específicos**

1. **Desafíos Semanales**: Sistema automático de generación de desafíos renovables
2. **Eventos Estacionales**: Celebraciones temáticas (Halloween, Navidad, Oscars, etc.)
3. **Competencias Sociales**: Leaderboards y comparaciones con amigos
4. **Recompensas Especiales**: Badges únicos, títulos y recompensas limitadas en tiempo
5. **Engagement Continuo**: Mantener interés através de contenido fresco y desafiante

## 📁 **ARCHIVOS A CREAR/MODIFICAR**

### **1. Modelos de Desafíos y Eventos**

```
📄 lib/domain/entities/gamification/challenge.dart
📄 lib/domain/entities/gamification/seasonal_event.dart
📄 lib/domain/entities/gamification/leaderboard.dart
📄 lib/domain/entities/gamification/challenge_progress.dart
📄 lib/domain/entities/gamification/event_reward.dart
```

**Responsabilidades:**

- Definir tipos de desafíos y sus criterios de éxito
- Modelar eventos estacionales con fechas y temáticas
- Estructura de leaderboards y rankings
- Tracking de progreso en tiempo real

**Componentes principales:**

```dart
class Challenge {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final int targetValue;
  final int currentProgress;
  final DateTime startDate;
  final DateTime endDate;
  final List<Reward> rewards;
  final ChallengeDifficulty difficulty;
  final String? iconUrl;
  final Map<String, dynamic> metadata;

  bool get isCompleted => currentProgress >= targetValue;
  double get progressPercentage => (currentProgress / targetValue).clamp(0, 1);
  int get daysRemaining => endDate.difference(DateTime.now()).inDays;
}

enum ChallengeType {
  watchMovies,        // Ver X películas
  watchGenre,         // Ver X películas de un género específico
  rateMovies,         // Calificar X películas
  createLists,        // Crear X listas personalizadas
  shareContent,       // Compartir X películas/listas
  marathonChallenge,  // Ver X películas en un día
  diversityChallenge, // Ver películas de X géneros diferentes
  vintageChallenge,   // Ver X películas clásicas (antes de 1990)
  socialChallenge,    // Interacciones sociales
  streakChallenge,    // Mantener racha de X días
}
```

### **2. Sistema de Generación de Desafíos**

```
📄 lib/core/gamification/challenge_system.dart
📄 lib/core/gamification/seasonal_event_manager.dart
📄 lib/core/gamification/challenge_generator.dart
📄 lib/core/gamification/difficulty_calculator.dart
```

**Responsabilidades:**

- Algoritmos de generación automática de desafíos
- Gestión de eventos estacionales y fechas especiales
- Cálculo dinámico de dificultad basado en usuario
- Rotación de contenido y variedad

### **3. Servicios de Tracking y Progreso**

```
📄 lib/services/challenge_progress_service.dart
📄 lib/services/event_participation_service.dart
📄 lib/services/leaderboard_service.dart
📄 lib/services/reward_distribution_service.dart
```

### **4. Providers de Desafíos**

```
📄 lib/presentation/providers/gamification/challenges_provider.dart
📄 lib/presentation/providers/gamification/seasonal_events_provider.dart
📄 lib/presentation/providers/gamification/leaderboard_provider.dart
📄 lib/presentation/providers/gamification/challenge_progress_provider.dart
```

### **5. UI de Desafíos y Eventos**

```
📄 lib/presentation/views/gamification/challenges_view.dart
📄 lib/presentation/views/gamification/seasonal_event_view.dart
📄 lib/presentation/views/gamification/leaderboard_view.dart
📄 lib/presentation/views/gamification/challenge_detail_view.dart

📄 lib/presentation/widgets/gamification/challenge_card.dart
📄 lib/presentation/widgets/gamification/progress_indicator.dart
📄 lib/presentation/widgets/gamification/countdown_timer.dart
📄 lib/presentation/widgets/gamification/reward_showcase.dart
📄 lib/presentation/widgets/gamification/leaderboard_tile.dart
```

## 🔧 **IMPLEMENTACIÓN DETALLADA**

### **Sistema de Generación de Desafíos**

#### **Challenge Generator**

```dart
class ChallengeGenerator {

  Future<List<Challenge>> generateWeeklyChallenges(String userId) async {
    final userProfile = await _getUserProfile(userId);
    final userHistory = await _getUserHistory(userId);

    final challenges = <Challenge>[];

    // Desafío básico de visualización
    challenges.add(_generateWatchChallenge(userProfile));

    // Desafío de diversidad de géneros
    challenges.add(_generateGenreDiversityChallenge(userHistory));

    // Desafío social
    challenges.add(_generateSocialChallenge(userProfile));

    // Desafío especial basado en temporada
    final seasonalChallenge = await _generateSeasonalChallenge();
    if (seasonalChallenge != null) {
      challenges.add(seasonalChallenge);
    }

    return challenges;
  }

  Challenge _generateWatchChallenge(UserProfile profile) {
    final baseTarget = _calculateBaseWatchTarget(profile.activityLevel);
    final difficulty = _calculateDifficulty(profile.challengeHistory);

    return Challenge(
      id: 'weekly_watch_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Explorador Semanal',
      description: 'Ve $baseTarget películas esta semana',
      type: ChallengeType.watchMovies,
      targetValue: baseTarget,
      currentProgress: 0,
      startDate: DateTime.now().startOfWeek(),
      endDate: DateTime.now().endOfWeek(),
      rewards: [
        Reward(
          type: RewardType.points,
          value: baseTarget * 25,
          name: '${baseTarget * 25} Puntos',
        ),
        if (difficulty == ChallengeDifficulty.hard)
          Reward(
            type: RewardType.badge,
            value: 'marathon_master',
            name: 'Badge Maestro del Maratón',
          ),
      ],
      difficulty: difficulty,
      iconUrl: 'assets/icons/challenges/watch_movies.png',
    );
  }

  Challenge _generateGenreDiversityChallenge(UserHistory history) {
    final unexploredGenres = _getUnexploredGenres(history);
    final targetGenres = min(unexploredGenres.length, 3);

    return Challenge(
      id: 'weekly_diversity_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Explorador de Géneros',
      description: 'Ve películas de $targetGenres géneros diferentes',
      type: ChallengeType.diversityChallenge,
      targetValue: targetGenres,
      currentProgress: 0,
      startDate: DateTime.now().startOfWeek(),
      endDate: DateTime.now().endOfWeek(),
      rewards: [
        Reward(
          type: RewardType.points,
          value: targetGenres * 50,
          name: '${targetGenres * 50} Puntos',
        ),
        Reward(
          type: RewardType.badge,
          value: 'genre_explorer',
          name: 'Badge Explorador de Géneros',
        ),
      ],
      difficulty: ChallengeDifficulty.medium,
      metadata: {
        'target_genres': unexploredGenres.take(targetGenres).toList(),
        'progress_genres': <String>[],
      },
    );
  }
}
```

### **Eventos Estacionales**

#### **Seasonal Event Manager**

```dart
class SeasonalEventManager {

  Future<SeasonalEvent?> getCurrentEvent() async {
    final now = DateTime.now();

    // Halloween Event (Octubre)
    if (now.month == 10) {
      return _createHalloweenEvent(now.year);
    }

    // Navidad Event (Diciembre)
    if (now.month == 12) {
      return _createChristmasEvent(now.year);
    }

    // Oscars Season (Febrero-Marzo)
    if (now.month == 2 || (now.month == 3 && now.day <= 15)) {
      return _createOscarsEvent(now.year);
    }

    // Verano de Blockbusters (Junio-Agosto)
    if (now.month >= 6 && now.month <= 8) {
      return _createSummerBlockbustersEvent(now.year);
    }

    return null;
  }

  SeasonalEvent _createHalloweenEvent(int year) {
    return SeasonalEvent(
      id: 'halloween_$year',
      title: '🎃 Terror de Octubre',
      description: 'Sumérgete en las mejores películas de terror y misterio',
      startDate: DateTime(year, 10, 1),
      endDate: DateTime(year, 10, 31),
      themeColor: Colors.deepOrange,
      backgroundImage: 'assets/images/events/halloween_bg.jpg',

      challenges: [
        Challenge(
          id: 'halloween_horror_master',
          title: 'Maestro del Terror',
          description: 'Ve 10 películas de terror durante octubre',
          type: ChallengeType.watchGenre,
          targetValue: 10,
          rewards: [
            Reward(type: RewardType.badge, value: 'horror_master', name: 'Badge Maestro del Terror'),
            Reward(type: RewardType.title, value: 'El Cazador de Sustos', name: 'Título Especial'),
            Reward(type: RewardType.points, value: 500, name: '500 Puntos de Terror'),
          ],
          metadata: {'required_genres': ['Horror', 'Thriller', 'Mystery']},
        ),

        Challenge(
          id: 'halloween_classic_crawler',
          title: 'Rastreador de Clásicos',
          description: 'Ve 5 películas de terror clásicas (antes de 1990)',
          type: ChallengeType.vintageChallenge,
          targetValue: 5,
          rewards: [
            Reward(type: RewardType.badge, value: 'classic_horror_fan', name: 'Fan del Terror Clásico'),
            Reward(type: RewardType.points, value: 300, name: '300 Puntos Clásicos'),
          ],
          metadata: {
            'max_year': 1990,
            'required_genres': ['Horror'],
          },
        ),

        Challenge(
          id: 'halloween_social_scare',
          title: 'Susto Social',
          description: 'Comparte 5 películas de terror con tus amigos',
          type: ChallengeType.socialChallenge,
          targetValue: 5,
          rewards: [
            Reward(type: RewardType.points, value: 200, name: '200 Puntos Sociales'),
          ],
          metadata: {'required_action': 'share', 'required_genres': ['Horror']},
        ),
      ],

      specialRewards: [
        EventReward(
          id: 'halloween_ultimate_2025',
          name: '👻 Leyenda del Terror 2025',
          description: 'Completa todos los desafíos de Halloween',
          type: RewardType.legendaryTitle,
          requirements: ['halloween_horror_master', 'halloween_classic_crawler', 'halloween_social_scare'],
          rarity: RewardRarity.legendary,
        ),
      ],

      leaderboard: EventLeaderboard(
        id: 'halloween_2025_leaderboard',
        title: 'Top Cazadores de Sustos',
        metric: LeaderboardMetric.horrorMoviesWatched,
        rewards: [
          LeaderboardReward(position: 1, reward: Reward(type: RewardType.points, value: 1000)),
          LeaderboardReward(position: 2, reward: Reward(type: RewardType.points, value: 750)),
          LeaderboardReward(position: 3, reward: Reward(type: RewardType.points, value: 500)),
        ],
      ),
    );
  }
}
```

### **Sistema de Progreso en Tiempo Real**

#### **Challenge Progress Service**

```dart
class ChallengeProgressService {

  Stream<ChallengeProgress> watchChallengeProgress(String challengeId) {
    return _progressController.stream
        .where((progress) => progress.challengeId == challengeId);
  }

  Future<void> updateChallengeProgress({
    required String challengeId,
    required String userId,
    required Map<String, dynamic> activityData,
  }) async {
    final challenge = await _getChallengeById(challengeId);
    final currentProgress = await _getChallengeProgress(challengeId, userId);

    final newProgress = _calculateNewProgress(challenge, currentProgress, activityData);

    await _saveChallengeProgress(ChallengeProgress(
      challengeId: challengeId,
      userId: userId,
      currentValue: newProgress,
      lastUpdated: DateTime.now(),
      isCompleted: newProgress >= challenge.targetValue,
      completedAt: newProgress >= challenge.targetValue ? DateTime.now() : null,
    ));

    // Verificar si se completó el desafío
    if (newProgress >= challenge.targetValue && currentProgress.currentValue < challenge.targetValue) {
      await _handleChallengeCompletion(challenge, userId);
    }

    // Emitir actualización en tiempo real
    _progressController.add(ChallengeProgress(
      challengeId: challengeId,
      userId: userId,
      currentValue: newProgress,
      progressPercentage: (newProgress / challenge.targetValue).clamp(0, 1),
      isCompleted: newProgress >= challenge.targetValue,
    ));
  }

  int _calculateNewProgress(Challenge challenge, ChallengeProgress current, Map<String, dynamic> activityData) {
    switch (challenge.type) {
      case ChallengeType.watchMovies:
        return current.currentValue + 1;

      case ChallengeType.watchGenre:
        final requiredGenres = challenge.metadata['required_genres'] as List<String>? ?? [];
        final movieGenres = activityData['genres'] as List<String>? ?? [];
        if (movieGenres.any((genre) => requiredGenres.contains(genre))) {
          return current.currentValue + 1;
        }
        return current.currentValue;

      case ChallengeType.diversityChallenge:
        final progressGenres = Set<String>.from(current.metadata['progress_genres'] ?? []);
        final movieGenres = activityData['genres'] as List<String>? ?? [];
        progressGenres.addAll(movieGenres);
        current.metadata['progress_genres'] = progressGenres.toList();
        return progressGenres.length;

      case ChallengeType.socialChallenge:
        final requiredAction = challenge.metadata['required_action'] as String?;
        final action = activityData['action'] as String?;
        if (requiredAction == action) {
          return current.currentValue + 1;
        }
        return current.currentValue;

      default:
        return current.currentValue;
    }
  }

  Future<void> _handleChallengeCompletion(Challenge challenge, String userId) async {
    // Distribuir recompensas
    for (final reward in challenge.rewards) {
      await _rewardDistributionService.distributeReward(userId, reward);
    }

    // Notificar al usuario
    await _notificationService.sendChallengeCompletionNotification(
      userId: userId,
      challengeTitle: challenge.title,
      rewards: challenge.rewards,
    );

    // Actualizar estadísticas de gamificación
    await _gamificationManager.updateUserStats(
      challengeCompleted: true,
      pointsEarned: challenge.rewards
          .where((r) => r.type == RewardType.points)
          .fold(0, (sum, r) => sum + (r.value as int)),
    );

    // Log para analytics
    await _analyticsService.trackEvent(
      'challenge_completed',
      {
        'challenge_id': challenge.id,
        'challenge_type': challenge.type.toString(),
        'completion_time': DateTime.now().difference(challenge.startDate).inDays,
        'user_id': userId,
      },
    );
  }
}
```

### **UI Components**

#### **Challenge Card**

```dart
class ChallengeCard extends ConsumerWidget {
  const ChallengeCard({Key? key, required this.challenge}) : super(key: key);

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(challengeProgressProvider(challenge.id));

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: _getGradientForDifficulty(challenge.difficulty),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con icono y dificultad
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconForChallengeType(challenge.type),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getDifficultyText(challenge.difficulty),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CountdownTimer(endDate: challenge.endDate),
                ],
              ),

              const SizedBox(height: 12),

              // Descripción
              Text(
                challenge.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),

              const SizedBox(height: 16),

              // Progress bar
              progressAsync.when(
                data: (progress) => Column(
                  children: [
                    LinearProgressIndicator(
                      value: progress.progressPercentage,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${progress.currentValue}/${challenge.targetValue}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${(progress.progressPercentage * 100).toInt()}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => Text('Error: $error'),
              ),

              const SizedBox(height: 16),

              // Rewards showcase
              RewardShowcase(rewards: challenge.rewards),

              // Action button
              if (!challenge.isCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _navigateToChallengeDetail(context, challenge),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _getPrimaryColorForDifficulty(challenge.difficulty),
                      ),
                      child: const Text('Ver Detalles'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient _getGradientForDifficulty(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ChallengeDifficulty.medium:
        return const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFFC107)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ChallengeDifficulty.hard:
        return const LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ChallengeDifficulty.legendary:
        return const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA000), Color(0xFFFF6F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}
```

## 📊 **MÉTRICAS DE ÉXITO**

### **KPIs Principales**

| Métrica                       | Objetivo              | Método de Medición             |
| ----------------------------- | --------------------- | ------------------------------ |
| **Participación en Desafíos** | >60% usuarios activos | Challenge Completion Analytics |
| **Retención Semanal**         | +20% retención        | Cohort Analysis                |
| **Tiempo en App**             | +35% tiempo promedio  | Session Duration Tracking      |
| **Engagement Daily**          | >80% usuarios diarios | Daily Active User Analytics    |
| **Challenge Completion Rate** | >40% completion rate  | Challenge Analytics            |

### **Métricas de Eventos Especiales**

| Métrica                      | Objetivo               | Herramienta                  |
| ---------------------------- | ---------------------- | ---------------------------- |
| **Participación en Eventos** | >70% durante eventos   | Event Participation Tracking |
| **Social Sharing**           | +50% durante eventos   | Viral Coefficient            |
| **User Generated Content**   | +60% durante eventos   | Content Creation Analytics   |
| **Retention Post-Event**     | >85% retention después | Post-Event Analysis          |

## ✅ **ENTREGABLES**

### **Días 1-2: Fundamentos**

- [x] **Modelos de Datos**

  - `Challenge`, `SeasonalEvent`, `ChallengeProgress`
  - Schemas de base de datos
  - Tests unitarios de modelos

- [x] **Sistema de Generación**
  - `ChallengeGenerator` con algoritmos automáticos
  - `SeasonalEventManager` con eventos predefinidos

### **Días 3-4: Lógica de Negocio**

- [x] **Servicios de Progreso**

  - `ChallengeProgressService` con tracking en tiempo real
  - `RewardDistributionService` automático
  - Integración con gamification existente

- [x] **Providers**
  - `challengesProvider` con auto-refresh
  - `seasonalEventsProvider` context-aware
  - `challengeProgressProvider` con streams

### **Días 5-7: UI y Pulimiento**

- [x] **Interfaces de Usuario**

  - `ChallengesView` con tabs y filtering
  - `ChallengeCard` con animaciones y progress
  - `SeasonalEventView` temática

- [x] **Integración Completa**
  - Notificaciones push para challenge completion
  - Analytics tracking completo
  - Tests de integración end-to-end

## 🧪 **PLAN DE TESTING**

### **Tests Unitarios**

```dart
// test/core/gamification/challenge_generator_test.dart
group('ChallengeGenerator', () {
  test('should generate appropriate weekly challenges', () {
    // Test challenge generation based on user profile
  });

  test('should adjust difficulty based on user history', () {
    // Test difficulty calculation
  });

  test('should create seasonal challenges correctly', () {
    // Test seasonal event integration
  });
});

// test/services/challenge_progress_service_test.dart
group('ChallengeProgressService', () {
  test('should update progress correctly for different challenge types', () {
    // Test progress calculation
  });

  test('should handle challenge completion properly', () {
    // Test completion flow and rewards
  });
});
```

### **Tests de Integración**

```dart
// integration_test/challenges_flow_test.dart
testWidgets('Complete challenge flow works end-to-end', (tester) async {
  // Test: View challenges -> Start challenge -> Progress tracking -> Completion
});

// integration_test/seasonal_event_test.dart
testWidgets('Seasonal event participation flow', (tester) async {
  // Test: Event discovery -> Participation -> Progress -> Rewards
});
```

## 🎨 **DISEÑO DE EVENTOS ESTACIONALES**

### **Halloween (Octubre)**

- **Colores**: Naranja, negro, morado
- **Géneros**: Terror, thriller, misterio
- **Desafíos especiales**: Clásicos de terror, maratón nocturno
- **Recompensas**: Badges temáticos, títulos de terror

### **Navidad (Diciembre)**

- **Colores**: Rojo, verde, dorado
- **Géneros**: Familiares, comedias navideñas, romance
- **Desafíos especiales**: Películas familiares, clásicos navideños
- **Recompensas**: Avatar navideño, títulos festivos

### **Oscars Season (Febrero-Marzo)**

- **Colores**: Dorado, negro, elegante
- **Géneros**: Drama, biografías, películas premiadas
- **Desafíos especiales**: Nominadas a Oscar, películas ganadoras
- **Recompensas**: Badge de crítico, título de "Experto en Cine"

### **Verano de Blockbusters (Junio-Agosto)**

- **Colores**: Azul vibrante, amarillo, energético
- **Géneros**: Acción, aventura, ciencia ficción
- **Desafíos especiales**: Franquicias, efectos especiales
- **Recompensas**: Badge de aventurero, título de "Cazador de Blockbusters"

## 📱 **NOTIFICACIONES INTELIGENTES**

### **Timing Estratégico**

```dart
class ChallengeNotificationScheduler {

  Future<void> scheduleProgressReminders(Challenge challenge) async {
    // Recordatorio a mitad de tiempo si no hay progreso
    final midPoint = challenge.startDate.add(
      Duration(milliseconds: challenge.endDate.difference(challenge.startDate).inMilliseconds ~/ 2)
    );

    await _scheduleNotification(
      scheduledDate: midPoint,
      title: '⏰ ¡${challenge.title} esperándote!',
      body: 'Aún tienes tiempo para completar este desafío',
      payload: {'type': 'challenge_reminder', 'challenge_id': challenge.id},
    );

    // Recordatorio final 24h antes de expirar
    final finalReminder = challenge.endDate.subtract(Duration(hours: 24));
    await _scheduleNotification(
      scheduledDate: finalReminder,
      title: '🚨 ¡Última oportunidad!',
      body: '${challenge.title} expira en 24 horas',
      payload: {'type': 'challenge_final_warning', 'challenge_id': challenge.id},
    );
  }
}
```

## 🏆 **SISTEMA DE LEADERBOARDS**

### **Tipos de Rankings**

1. **Global**: Todos los usuarios de la app
2. **Amigos**: Solo usuarios que sigues
3. **Local**: Usuarios en tu región/país
4. **Temporal**: Rankings por evento/temporada

### **Métricas de Ranking**

- Puntos totales obtenidos
- Desafíos completados
- Racha de días activos
- Películas vistas en eventos
- Interacciones sociales

---

**Documento creado**: Sept 16, 2025  
**Última actualización**: Sept 16, 2025  
**Responsable**: Equipo de Gamificación  
**Revisor**: Product Manager
