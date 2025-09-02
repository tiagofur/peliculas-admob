# 🤝 Guía de Contribución - Aplicación Películas

¡Gracias por tu interés en contribuir! Esta guía te ayudará a entender cómo trabajamos y cómo puedes participar efectivamente en el desarrollo.

## 🚀 Inicio Rápido para Desarrolladores

### Prerequisitos

- **Flutter SDK**: >=3.0.0 <4.0.0
- **Dart SDK**: Incluido con Flutter
- **Git**: Para control de versiones
- **IDE**: Android Studio, VS Code, o IntelliJ
- **Device/Emulator**: Para testing

### Configuración del Entorno

1. **Clonar el repositorio**
   ```bash
   git clone https://github.com/tiagofur/peliculas-admob.git
   cd peliculas-admob
   ```

2. **Configurar variables de entorno**
   ```bash
   cp .env.example .env
   # Editar .env con tus claves de API
   ```

3. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

4. **Verificar configuración**
   ```bash
   flutter doctor
   flutter analyze
   flutter test
   ```

5. **Ejecutar la aplicación**
   ```bash
   flutter run
   ```

### Configuración de APIs

#### TMDB API
1. Registrarse en [TMDB](https://www.themoviedb.org/documentation/api)
2. Obtener API key
3. Agregar a `.env`: `TMDB_API_KEY=tu_api_key`

#### Supabase (Opcional para desarrollo)
1. Crear proyecto en [Supabase](https://supabase.com)
2. Obtener URL y anon key
3. Agregar a `.env`:
   ```
   SUPABASE_URL=https://tu-proyecto.supabase.co
   SUPABASE_ANON_KEY=tu_anon_key
   ```

## 📁 Estructura del Proyecto

```
lib/
├── config/                 # Configuración global
│   ├── router/             # Rutas de navegación
│   ├── theme/              # Temas y estilos
│   └── constants/          # Constantes de la app
├── core/                   # Funcionalidades transversales
│   ├── error_handling/     # Manejo de errores
│   ├── gamification/       # Sistema de logros
│   ├── network/            # Configuración de red
│   └── utils/              # Utilidades generales
├── domain/                 # Lógica de negocio
│   ├── entities/           # Entidades del dominio
│   ├── repositories/       # Interfaces de repositorios
│   └── usecases/           # Casos de uso
├── infrastructure/         # Implementaciones externas
│   ├── datasources/        # Fuentes de datos
│   ├── models/             # Modelos de datos (DTOs)
│   └── repositories/       # Implementaciones de repositorios
├── presentation/           # Interfaz de usuario
│   ├── pages/              # Pantallas de la aplicación
│   ├── widgets/            # Widgets reutilizables
│   └── providers/          # Gestión de estado (Riverpod)
└── services/               # Servicios especializados
    ├── analytics/          # Servicios de analytics
    ├── auth/               # Autenticación
    ├── cache/              # Cache local
    ├── notification/       # Notificaciones
    └── sync/               # Sincronización
```

## 🏗️ Arquitectura y Patrones

### Clean Architecture
Seguimos los principios de Clean Architecture con DDD:

- **Presentation Layer**: UI y gestión de estado
- **Domain Layer**: Entidades y lógica de negocio
- **Infrastructure Layer**: Implementaciones y servicios externos

### Gestión de Estado
Utilizamos **Riverpod** para gestión de estado:

```dart
// Provider example
final moviesProvider = StateNotifierProvider<MoviesNotifier, MoviesState>((ref) {
  return MoviesNotifier(ref.read(movieRepositoryProvider));
});

// StateNotifier example
class MoviesNotifier extends StateNotifier<MoviesState> 
    with ErrorReportingMixin<MoviesState> {
  
  MoviesNotifier(this._repository) : super(const MoviesState.initial());
  
  final MovieRepository _repository;
  
  Future<void> loadPopularMovies() async {
    await runWithErrorReporting(
      () async {
        state = state.copyWith(isLoading: true);
        final movies = await _repository.getPopularMovies();
        state = state.copyWith(isLoading: false, movies: movies);
      },
      operationName: 'loadPopularMovies',
    );
  }
}
```

### Repository Pattern
Cada dominio tiene su repositorio:

```dart
// Domain interface
abstract class MovieRepository {
  Future<Either<Failure, List<Movie>>> getPopularMovies();
  Future<Either<Failure, Movie>> getMovieDetails(int id);
}

// Infrastructure implementation  
class MovieRepositoryImpl implements MovieRepository {
  final MovieRemoteDataSource _remoteDataSource;
  final MovieLocalDataSource _localDataSource;
  
  @override
  Future<Either<Failure, List<Movie>>> getPopularMovies() async {
    try {
      final movies = await _remoteDataSource.getPopularMovies();
      await _localDataSource.cacheMovies(movies);
      return Right(movies.map((m) => m.toEntity()).toList());
    } catch (e) {
      final cachedMovies = await _localDataSource.getCachedMovies();
      return Right(cachedMovies.map((m) => m.toEntity()).toList());
    }
  }
}
```

## 🔄 Workflow de Desarrollo

### 1. Creación de Issues

Antes de empezar a codificar:

1. **Revisar issues existentes** para evitar duplicados
2. **Crear issue detallado** si no existe
3. **Asignar labels** apropiados (bug, feature, enhancement)
4. **Estimar esfuerzo** (1-5 story points)

### 2. Branching Strategy

```bash
# Feature branch
git checkout -b feature/movie-recommendations

# Bug fix branch  
git checkout -b fix/search-pagination-bug

# Hotfix branch
git checkout -b hotfix/critical-crash-fix
```

### 3. Development Workflow

1. **Crear tests primero** (TDD preferido)
2. **Implementar funcionalidad**
3. **Refactorizar si necesario**
4. **Documentar cambios**
5. **Validar quality gates**

### 4. Quality Gates

Antes de cada commit:

```bash
# Formatear código
dart format .

# Análisis estático
flutter analyze

# Ejecutar tests
flutter test

# Verificar coverage (objetivo >80%)
flutter test --coverage
```

### 5. Commit Guidelines

Usamos [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Feature
git commit -m "feat(movies): add recommendation system

- Implement ML-based movie recommendations
- Add user preference learning
- Create recommendation UI components
- Add unit tests for recommendation logic

Closes #123"

# Bug fix
git commit -m "fix(search): resolve pagination infinite scroll

- Fix memory leak in pagination controller
- Add proper disposal of stream subscriptions
- Improve error handling for network failures

Fixes #456"

# Documentation
git commit -m "docs(api): update authentication guide

- Add Supabase integration examples
- Document RLS policies setup
- Include troubleshooting section"
```

### 6. Pull Request Process

1. **Crear PR** con template completo
2. **Asignar reviewers** (mínimo 1, preferido 2)
3. **Verificar CI** pasa todas las validaciones
4. **Responder feedback** de manera constructiva
5. **Squash and merge** una vez aprobado

## 🧪 Testing Guidelines

### Estructura de Testing

```
test/
├── unit/                   # Tests unitarios
│   ├── domain/             # Tests de entidades y use cases
│   ├── infrastructure/     # Tests de repositorios
│   └── services/           # Tests de servicios
├── widget/                 # Tests de widgets
├── integration/            # Tests de integración
└── helpers/                # Utilidades para testing
```

### Testing Patterns

#### Unit Tests
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('GetPopularMoviesUseCase', () {
    late GetPopularMoviesUseCase usecase;
    late MockMovieRepository mockRepository;

    setUp(() {
      mockRepository = MockMovieRepository();
      usecase = GetPopularMoviesUseCase(mockRepository);
    });

    test('should get popular movies from repository', () async {
      // Arrange
      when(mockRepository.getPopularMovies())
          .thenAnswer((_) async => Right(tMovieList));

      // Act
      final result = await usecase(NoParams());

      // Assert
      expect(result, Right(tMovieList));
      verify(mockRepository.getPopularMovies());
      verifyNoMoreInteractions(mockRepository);
    });
  });
}
```

#### Widget Tests
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('MovieCard Widget', () {
    testWidgets('should display movie information correctly', (tester) async {
      // Arrange
      const movie = Movie(
        id: 1,
        title: 'Test Movie',
        overview: 'Test overview',
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MovieCard(movie: movie),
          ),
        ),
      );

      // Assert
      expect(find.text('Test Movie'), findsOneWidget);
      expect(find.text('Test overview'), findsOneWidget);
    });
  });
}
```

#### Integration Tests
```dart
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Movie Search Flow', () {
    testWidgets('complete search flow works correctly', (tester) async {
      await tester.pumpWidget(MyApp());

      // Navigate to search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Inception');
      await tester.pumpAndSettle();

      // Verify results
      expect(find.text('Inception'), findsAtLeastNWidgets(1));
    });
  });
}
```

### Test Coverage

Objetivos de cobertura:
- **Domain Layer**: >95%
- **Infrastructure Layer**: >90%  
- **Presentation Layer**: >80%
- **Overall**: >85%

## 📝 Código y Estilo

### Dart Style Guide

Seguimos [Effective Dart](https://dart.dev/guides/language/effective-dart):

```dart
// ✅ Correcto
class MovieRepository {
  Future<List<Movie>> getPopularMovies() async {
    // Implementation
  }
}

// ❌ Incorrecto
class movieRepository {
  getPopularMovies() {
    // Implementation
  }
}
```

### Naming Conventions

- **Classes**: PascalCase (`MovieRepository`)
- **Variables/Functions**: camelCase (`getPopularMovies`)
- **Constants**: lowerCamelCase (`defaultPageSize`)
- **Files**: snake_case (`movie_repository.dart`)

### Documentation

Documentar clases y métodos públicos:

```dart
/// Repository for managing movie data.
/// 
/// Provides access to movie information from both remote and local sources,
/// with automatic caching and offline support.
abstract class MovieRepository {
  /// Retrieves a list of popular movies.
  /// 
  /// Returns cached data when offline. May throw [NetworkException]
  /// if no cached data is available and network is unreachable.
  Future<Either<Failure, List<Movie>>> getPopularMovies();
}
```

### Error Handling

Usar `Either` de dartz para manejo de errores:

```dart
// Repository layer
Future<Either<Failure, List<Movie>>> getMovies() async {
  try {
    final movies = await _dataSource.getMovies();
    return Right(movies);
  } on SocketException {
    return Left(NetworkFailure());
  } catch (e) {
    return Left(ServerFailure());
  }
}

// Presentation layer
void _loadMovies() {
  _moviesUseCase().then((result) {
    result.fold(
      (failure) => _handleError(failure),
      (movies) => _updateMovies(movies),
    );
  });
}
```

## 🚀 Deployment y Release

### Environments

- **Development**: Local development
- **Staging**: Pre-production testing
- **Production**: Live app

### Release Process

1. **Version bump** en `pubspec.yaml`
2. **Update CHANGELOG.md**
3. **Create release PR**
4. **Tag release** después del merge
5. **Deploy automático** via CI/CD

### Build Commands

```bash
# Development build
flutter run --debug

# Release builds
flutter build apk --release
flutter build ios --release  
flutter build web --release

# Bundle analysis
flutter build apk --analyze-size
```

## 🎯 Contribución por Área

### Frontend/UI
- Seguir Material Design 3
- Usar tema consistente
- Implementar accessibility
- Optimizar performance

### Backend/API Integration
- Implementar retry logic
- Manejar rate limiting
- Cache apropiadamente
- Error handling robusto

### Testing
- Aumentar coverage
- Agregar integration tests
- Performance testing
- Accessibility testing

### Documentation
- Actualizar README
- Documentar APIs
- Crear tutorials
- Ejemplos de código

## 🔍 Code Review Guidelines

### Para Autores

- **Self-review** antes de crear PR
- **Descripción clara** del cambio
- **Screenshots** para cambios UI
- **Tests incluidos**
- **Documentation actualizada**

### Para Reviewers

- **Feedback constructivo**
- **Revisar funcionalidad** y diseño
- **Verificar tests**
- **Performance considerations**
- **Security implications**

### Checklist de Review

- [ ] El código sigue las convenciones del proyecto
- [ ] Los tests pasan y tienen buena cobertura
- [ ] La documentación está actualizada
- [ ] No hay hardcoded values
- [ ] Error handling apropiado
- [ ] Performance acceptable
- [ ] Security concerns addressed
- [ ] UI/UX consistency

## 🐛 Reportar Issues

### Bug Reports

Usar el template de bug report:

```markdown
**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Device Info:**
 - Device: [e.g. iPhone 12]
 - OS: [e.g. iOS 14.5]
 - App Version: [e.g. 1.2.0]

**Additional context**
Add any other context about the problem here.
```

### Feature Requests

Usar el template de feature request:

```markdown
**Is your feature request related to a problem?**
A clear description of what the problem is.

**Describe the solution you'd like**
A clear description of what you want to happen.

**Describe alternatives you've considered**
Alternative solutions or features you've considered.

**Additional context**
Add any other context or screenshots about the feature request.
```

## 📚 Recursos Útiles

### Documentation
- [Flutter Documentation](https://flutter.dev/docs)
- [Riverpod Documentation](https://riverpod.dev)
- [Supabase Documentation](https://supabase.com/docs)

### Tools
- [Flutter Inspector](https://flutter.dev/docs/development/tools/flutter-inspector)
- [Dart DevTools](https://dart.dev/tools/dart-devtools)
- [Very Good CLI](https://cli.vgv.dev)

### Community
- [Flutter Discord](https://discord.gg/flutter)
- [Reddit r/FlutterDev](https://reddit.com/r/FlutterDev)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)

## 🏆 Recognition

Contribuidores destacados serán reconocidos en:
- README del proyecto
- Release notes
- Contributor showcase
- Team meetings

## 📞 Contacto

Para preguntas sobre contribución:
- **Issues**: Para preguntas técnicas
- **Discussions**: Para ideas y feedback general
- **Email**: Para asuntos privados

---

¡Gracias por contribuir al proyecto! 🎬✨