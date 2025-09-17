# 👥 FASE 2: FEED SOCIAL CINEMATOGRÁFICO

## 📋 **INFORMACIÓN GENERAL**

| Campo                 | Valor             |
| --------------------- | ----------------- |
| **Duración estimada** | 2 semanas         |
| **Fecha inicio**      | Sept 24, 2025     |
| **Fecha fin**         | Oct 7, 2025       |
| **Recursos**          | 2 desarrolladores |
| **Prioridad**         | Alta              |
| **Estado**            | Planificado       |

## 🎯 **OBJETIVOS**

### **Objetivo Principal**

Crear un ecosistema social dentro de la aplicación que permita a los usuarios compartir sus actividades cinematográficas, seguir amigos, interactuar con contenido y descubrir nuevas películas a través de su red social.

### **Objetivos Específicos**

1. **Sistema de Actividad Social**: Feed que muestre actividades de usuarios seguidos
2. **Red de Usuarios**: Sistema de seguir/ser seguido con gestión de relaciones
3. **Interacciones Sociales**: Likes, comentarios y shares en actividades
4. **Descubrimiento Social**: Encontrar usuarios con gustos similares
5. **Engagement**: Aumentar tiempo en app y retención através de conexiones sociales

## 📁 **ARCHIVOS A CREAR/MODIFICAR**

### **1. Modelos de Datos Sociales**

```
📄 lib/domain/entities/social/activity_post.dart
📄 lib/domain/entities/social/user_relationship.dart
📄 lib/domain/entities/social/social_interaction.dart
📄 lib/domain/entities/social/user_profile.dart
```

**Responsabilidades:**

- Estructuras de datos para actividades sociales
- Modelado de relaciones entre usuarios
- Tipos de interacciones (likes, comentarios, shares)
- Perfiles públicos de usuarios

**Componentes principales:**

```dart
class ActivityPost {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final ActivityType type;
  final Movie? movie;
  final CustomList? list;
  final String? content;
  final DateTime timestamp;
  final List<String> likes;
  final List<Comment> comments;
  final Map<String, dynamic> metadata;
}

enum ActivityType {
  movieWatched,
  movieRated,
  movieFavorited,
  listCreated,
  listShared,
  achievementUnlocked,
  reviewPosted,
}
```

### **2. Repositorio Social**

```
📄 lib/infrastructure/repositories/social_repository_impl.dart
📄 lib/domain/repositories/i_social_repository.dart
📄 lib/infrastructure/datasources/supabase_social_datasource.dart
```

**Responsabilidades:**

- CRUD operations para actividades sociales
- Gestión de relaciones entre usuarios
- Sistema de notificaciones sociales
- Cache y sincronización offline

**Componentes principales:**

```dart
abstract class ISocialRepository {
  Future<List<ActivityPost>> getFeedActivities({
    required List<String> followingUserIds,
    int limit = 20,
    String? lastActivityId,
  });

  Future<void> followUser(String userId);
  Future<void> unfollowUser(String userId);
  Future<List<UserProfile>> getFollowing(String userId);
  Future<List<UserProfile>> getFollowers(String userId);

  Future<void> likeActivity(String activityId);
  Future<void> commentOnActivity(String activityId, String comment);
  Future<void> shareActivity(String activityId);

  Future<List<UserProfile>> discoverUsers({
    required List<String> commonGenres,
    int limit = 10,
  });
}
```

### **3. Providers Sociales**

```
📄 lib/presentation/providers/social/social_feed_provider.dart
📄 lib/presentation/providers/social/user_relationships_provider.dart
📄 lib/presentation/providers/social/social_interactions_provider.dart
📄 lib/presentation/providers/social/user_discovery_provider.dart
```

**Responsabilidades:**

- Estado del feed social con paginación
- Gestión de relaciones de seguimiento
- Manejo de interacciones en tiempo real
- Descubrimiento de usuarios relevantes

### **4. UI del Sistema Social**

```
📄 lib/presentation/views/social/social_feed_view.dart
📄 lib/presentation/views/social/user_profile_view.dart
📄 lib/presentation/views/social/followers_following_view.dart
📄 lib/presentation/views/social/discover_users_view.dart

📄 lib/presentation/widgets/social/activity_card.dart
📄 lib/presentation/widgets/social/user_avatar.dart
📄 lib/presentation/widgets/social/follow_button.dart
📄 lib/presentation/widgets/social/interaction_buttons.dart
📄 lib/presentation/widgets/social/comment_widget.dart
```

### **5. Servicios de Apoyo**

```
📄 lib/services/activity_tracking_service.dart
📄 lib/services/social_notification_service.dart
📄 lib/core/social/privacy_manager.dart
```

## 🔧 **IMPLEMENTACIÓN DETALLADA**

### **Database Schema (Supabase)**

#### **Tabla: social_activities**

```sql
CREATE TABLE social_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  activity_type VARCHAR(50) NOT NULL,
  movie_id INTEGER,
  list_id UUID,
  content TEXT,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_social_activities_user_id ON social_activities(user_id);
CREATE INDEX idx_social_activities_created_at ON social_activities(created_at DESC);
```

#### **Tabla: user_relationships**

```sql
CREATE TABLE user_relationships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID REFERENCES auth.users(id),
  following_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(follower_id, following_id)
);

CREATE INDEX idx_user_relationships_follower ON user_relationships(follower_id);
CREATE INDEX idx_user_relationships_following ON user_relationships(following_id);
```

#### **Tabla: social_interactions**

```sql
CREATE TABLE social_interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  activity_id UUID REFERENCES social_activities(id),
  interaction_type VARCHAR(20) NOT NULL, -- 'like', 'comment', 'share'
  content TEXT, -- For comments
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### **Feed Algorithm**

#### **Provider del Feed Social**

```dart
class SocialFeedNotifier extends StateNotifier<SocialFeedState> {
  SocialFeedNotifier(this._repository, this._ref)
      : super(const SocialFeedState.loading());

  final ISocialRepository _repository;
  final Ref _ref;

  Future<void> loadFeed({bool refresh = false}) async {
    if (refresh) {
      state = const SocialFeedState.loading();
    }

    try {
      // Obtener usuarios seguidos
      final currentUser = _ref.read(currentUserProvider);
      final following = await _repository.getFollowing(currentUser.id);
      final followingIds = following.map((u) => u.id).toList();

      // Cargar actividades del feed
      final activities = await _repository.getFeedActivities(
        followingUserIds: followingIds,
        limit: 20,
        lastActivityId: refresh ? null : state.lastActivityId,
      );

      // Mezclar con actividades propias recientes
      final ownActivities = await _repository.getUserActivities(
        userId: currentUser.id,
        limit: 5,
      );

      final allActivities = _mergeFeedActivities(activities, ownActivities);

      state = SocialFeedState.loaded(
        activities: refresh ? allActivities : [...state.activities, ...allActivities],
        hasMore: activities.length == 20,
        lastActivityId: allActivities.isNotEmpty ? allActivities.last.id : null,
      );

    } catch (error) {
      state = SocialFeedState.error(error.toString());
    }
  }

  List<ActivityPost> _mergeFeedActivities(
    List<ActivityPost> feedActivities,
    List<ActivityPost> ownActivities,
  ) {
    final merged = [...feedActivities, ...ownActivities];
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return merged.take(20).toList();
  }

  Future<void> likeActivity(String activityId) async {
    // Actualización optimista
    final updatedActivities = state.activities.map((activity) {
      if (activity.id == activityId) {
        final currentUser = _ref.read(currentUserProvider);
        final isLiked = activity.likes.contains(currentUser.id);

        return activity.copyWith(
          likes: isLiked
              ? activity.likes.where((id) => id != currentUser.id).toList()
              : [...activity.likes, currentUser.id],
        );
      }
      return activity;
    }).toList();

    state = state.copyWith(activities: updatedActivities);

    try {
      await _repository.likeActivity(activityId);
    } catch (error) {
      // Revertir en caso de error
      await loadFeed(refresh: true);
    }
  }
}
```

### **Activity Tracking Service**

```dart
class ActivityTrackingService {
  ActivityTrackingService(this._repository);

  final ISocialRepository _repository;

  Future<void> trackMovieWatched(Movie movie) async {
    await _repository.createActivity(ActivityPost(
      id: '',
      userId: '', // Will be set by repository
      userName: '',
      userAvatar: '',
      type: ActivityType.movieWatched,
      movie: movie,
      timestamp: DateTime.now(),
      likes: [],
      comments: [],
      metadata: {
        'genre_ids': movie.genreIds,
        'rating': movie.voteAverage,
        'release_year': movie.releaseDate.year,
      },
    ));
  }

  Future<void> trackListCreated(CustomList list) async {
    await _repository.createActivity(ActivityPost(
      id: '',
      userId: '',
      userName: '',
      userAvatar: '',
      type: ActivityType.listCreated,
      list: list,
      timestamp: DateTime.now(),
      likes: [],
      comments: [],
      metadata: {
        'movie_count': list.movieIds.length,
        'list_category': list.isDefault ? 'default' : 'custom',
      },
    ));
  }
}
```

### **UI Components**

#### **Activity Card**

```dart
class ActivityCard extends ConsumerWidget {
  const ActivityCard({Key? key, required this.activity}) : super(key: key);

  final ActivityPost activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info
            Row(
              children: [
                UserAvatar(
                  avatarUrl: activity.userAvatar,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.userName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getActivityDescription(activity),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTimestamp(activity.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Content based on activity type
            _buildActivityContent(context, activity),

            const SizedBox(height: 12),

            // Interaction buttons
            InteractionButtons(
              activity: activity,
              onLike: () => ref.read(socialFeedProvider.notifier).likeActivity(activity.id),
              onComment: () => _showCommentDialog(context, activity),
              onShare: () => _shareActivity(context, activity),
            ),

            // Comments preview
            if (activity.comments.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildCommentsPreview(context, activity.comments),
            ],
          ],
        ),
      ),
    );
  }

  String _getActivityDescription(ActivityPost activity) {
    switch (activity.type) {
      case ActivityType.movieWatched:
        return 'vio ${activity.movie?.title}';
      case ActivityType.movieRated:
        return 'calificó ${activity.movie?.title}';
      case ActivityType.listCreated:
        return 'creó la lista "${activity.list?.name}"';
      case ActivityType.movieFavorited:
        return 'agregó ${activity.movie?.title} a favoritos';
      default:
        return 'realizó una actividad';
    }
  }

  Widget _buildActivityContent(BuildContext context, ActivityPost activity) {
    switch (activity.type) {
      case ActivityType.movieWatched:
      case ActivityType.movieRated:
      case ActivityType.movieFavorited:
        return MovieActivityContent(movie: activity.movie!);
      case ActivityType.listCreated:
        return ListActivityContent(list: activity.list!);
      default:
        return const SizedBox.shrink();
    }
  }
}
```

## 📊 **MÉTRICAS DE ÉXITO**

### **KPIs Principales**

| Métrica                    | Objetivo                      | Método de Medición    |
| -------------------------- | ----------------------------- | --------------------- |
| **Daily Active Users**     | +40% DAU                      | Firebase Analytics    |
| **Retención 7 días**       | +30% usuarios activos         | Cohort Analysis       |
| **Interacciones Sociales** | >50% usuarios interactúan     | Event Tracking        |
| **Tiempo en Feed**         | >5 min promedio por sesión    | Screen Time Analytics |
| **User Generated Content** | >20% usuarios crean contenido | Activity Tracking     |

### **Métricas de Engagement**

| Métrica                  | Objetivo               | Herramienta          |
| ------------------------ | ---------------------- | -------------------- |
| **Posts por Usuario**    | >2 actividades/semana  | Database Analytics   |
| **Likes por Post**       | >3 likes promedio      | Interaction Tracking |
| **Comentarios por Post** | >1 comentario/10 posts | Content Analytics    |
| **Shares por Día**       | >100 shares diarios    | Viral Coefficient    |

## ✅ **ENTREGABLES**

### **Semana 1**

#### **Días 1-3: Backend y Modelos**

- [x] **Modelos de Datos Sociales**

  - `ActivityPost`, `UserRelationship`, `SocialInteraction`
  - Schemas de base de datos en Supabase
  - Tests unitarios de modelos

- [x] **Repositorio Social**
  - `ISocialRepository` interface
  - `SocialRepositoryImpl` con Supabase
  - CRUD operations básicas

#### **Días 4-7: Providers y Lógica de Negocio**

- [x] **Providers Sociales**

  - `socialFeedProvider` con paginación
  - `userRelationshipsProvider` para follow/unfollow
  - `socialInteractionsProvider` para likes/comments

- [x] **Activity Tracking**
  - Service para registrar actividades automáticamente
  - Integración con providers existentes

### **Semana 2**

#### **Días 1-4: UI Principal**

- [x] **Feed Social**

  - `SocialFeedView` con pull-to-refresh
  - `ActivityCard` con todos los tipos de actividad
  - Infinite scroll y lazy loading

- [x] **Perfil de Usuario**
  - `UserProfileView` público
  - Lista de seguidores/seguidos
  - Grid de actividades del usuario

#### **Días 5-7: Funcionalidades Avanzadas**

- [x] **Interacciones**

  - Sistema de likes con animaciones
  - Comentarios con thread básico
  - Share functionality

- [x] **Descubrimiento**
  - `DiscoverUsersView` con recomendaciones
  - Búsqueda de usuarios
  - Sugerencias basadas en gustos similares

## 🧪 **PLAN DE TESTING**

### **Tests Unitarios**

```dart
// test/infrastructure/repositories/social_repository_impl_test.dart
group('SocialRepositoryImpl', () {
  test('should fetch feed activities correctly', () async {
    // Test implementation
  });

  test('should handle follow/unfollow operations', () async {
    // Test implementation
  });

  test('should create activities with proper metadata', () async {
    // Test implementation
  });
});
```

### **Tests de Integración**

```dart
// integration_test/social_feed_flow_test.dart
testWidgets('Social feed flow works end-to-end', (tester) async {
  // Test: Login -> View feed -> Like post -> Comment -> Follow user
});

// integration_test/user_discovery_flow_test.dart
testWidgets('User discovery and follow flow', (tester) async {
  // Test: Discover users -> View profile -> Follow -> See in feed
});
```

### **Tests de Performance**

```dart
// test/performance/social_feed_performance_test.dart
test('Feed loading should complete within 2 seconds', () async {
  final stopwatch = Stopwatch()..start();
  await repository.getFeedActivities(followingUserIds: testIds);
  stopwatch.stop();

  expect(stopwatch.elapsedMilliseconds, lessThan(2000));
});
```

## 🔐 **CONSIDERACIONES DE PRIVACIDAD**

### **Configuraciones de Privacidad**

```dart
class PrivacySettings {
  final bool isProfilePublic;
  final bool allowFollowRequests;
  final bool showActivityInFeed;
  final bool allowTagging;
  final List<ActivityType> hiddenActivityTypes;

  // Configuraciones granulares por tipo de actividad
}
```

### **Data Protection**

- Soft delete de actividades (no eliminación física)
- Anonimización de datos de usuarios que eliminan cuenta
- GDPR compliance para export/delete de datos
- Rate limiting para prevenir spam

## 🚀 **PLAN DE DEPLOYMENT**

### **Feature Flags**

```dart
final isSocialFeedEnabled = Provider<bool>((ref) {
  return ref.watch(featureFlagsProvider).isEnabled('social_feed');
});

final isSocialInteractionsEnabled = Provider<bool>((ref) {
  return ref.watch(featureFlagsProvider).isEnabled('social_interactions');
});
```

### **Rollout Strategy**

- **Beta Testing** (Días 12-14): 100 usuarios beta seleccionados
- **Soft Launch** (Día 15): 10% usuarios con análisis A/B
- **Gradual Rollout** (Días 16-20): 25% → 50% → 75% → 100%

### **Monitoring**

- Real-time alerts para performance del feed
- Dashboard de métricas sociales
- Error tracking para interacciones fallidas
- User feedback collection

## 📝 **NOTAS ADICIONALES**

### **Moderación de Contenido**

- Sistema de reportes para contenido inapropiado
- Auto-moderación básica con filtros de palabras
- Review queue para administradores
- Shadow banning para usuarios problemáticos

### **Notificaciones Push**

- Likes y comentarios en mis actividades
- Nuevos seguidores
- Actividades de usuarios VIP que sigo
- Resumen semanal de interacciones

### **Internacionalización**

- Strings localizables para todas las actividades
- Formateo de fechas por región
- Soporte para diferentes culturas cinematográficas

---

**Documento creado**: Sept 16, 2025  
**Última actualización**: Sept 16, 2025  
**Responsable**: Equipo de Desarrollo Social  
**Revisor**: Product Manager
