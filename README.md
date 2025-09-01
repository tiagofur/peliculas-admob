# Películas - Flutter App

[![CI Pipeline](https://github.com/tiagofur/peliculas-admob/actions/workflows/ci.yml/badge.svg)](https://github.com/tiagofur/peliculas-admob/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/tiagofur/peliculas-admob/branch/main/graph/badge.svg)](https://codecov.io/gh/tiagofur/peliculas-admob)

Aplicación Flutter para explorar y gestionar películas con integración de Supabase, gamificación y sincronización offline.

## 🚀 Getting Started

### Prerequisitos
- Flutter SDK (>=3.0.0 <4.0.0)
- Dart SDK
- Android Studio / VS Code
- Git

### Instalación
```bash
# Clonar el repositorio
git clone https://github.com/tiagofur/peliculas-admob.git
cd peliculas-admob

# Instalar dependencias
flutter pub get

# Ejecutar la aplicación
flutter run
```

## 🔧 Pipeline de Calidad

Este proyecto implementa un pipeline de integración continua que garantiza la calidad del código:

### ✅ Validaciones Automáticas

El CI ejecuta las siguientes validaciones en cada push y pull request:

1. **Formato de código**: `dart format --set-exit-if-changed`
2. **Análisis estático**: `flutter analyze --fatal-infos --fatal-warnings`  
3. **Tests automáticos**: `flutter test --coverage`
4. **Build validation**: Validación de build para web y Android

### 🏗️ Comandos de Desarrollo

Antes de hacer commit, ejecuta localmente:

```bash
# Verificar formato
dart format --output=none --set-exit-if-changed .

# Analizar código
flutter analyze

# Ejecutar tests
flutter test

# Generar cobertura
flutter test --coverage

# Build para diferentes plataformas
flutter build web --release
flutter build apk --release
```

### 📋 Reglas de Calidad

- **Formato**: Código debe estar formateado con `dart format`
- **Análisis**: Zero warnings/errors permitidos (configurado como fatal)
- **Tests**: Todos los tests deben pasar
- **Cobertura**: Se trackea cobertura de código (objetivo: >80%)
- **Build**: Build debe ser exitoso para web y Android

### 🚫 Bloqueo de Merge

Los PRs serán **automáticamente bloqueados** si:
- ❌ El formato no es correcto
- ❌ Hay warnings o errors en el análisis
- ❌ Algún test falla  
- ❌ El build falla

### 🔄 Proceso de Desarrollo

1. **Crear rama**: `git checkout -b feature/nueva-funcionalidad`
2. **Desarrollar**: Implementar cambios
3. **Validar localmente**: Ejecutar comandos de calidad
4. **Commit**: `git commit -m "feat: descripción del cambio"`
5. **Push**: `git push origin feature/nueva-funcionalidad`
6. **PR**: Crear Pull Request (use el template)
7. **CI**: Esperar validación automática ✅
8. **Review**: Code review del equipo
9. **Merge**: Solo si CI pasa y tiene aprobación

### 📊 Métricas de Calidad

- **Build Status**: ![CI](https://github.com/tiagofur/peliculas-admob/actions/workflows/ci.yml/badge.svg)
- **Code Coverage**: Reportado por Codecov
- **Dependencies**: Mantenidas automáticamente por Dependabot

## 🧪 Testing

### Tipos de Tests Disponibles

```bash
# Tests unitarios
flutter test test/

# Tests de integración  
flutter test integration_test/

# Tests específicos
flutter test test/error_handling_test.dart
flutter test test/sync_integration_test.dart
flutter test test/offline_functionality_test.dart
```

### Estructura de Tests
- `test/`: Tests unitarios y de widgets
- `integration_test/`: Tests de integración end-to-end
- Cobertura mínima esperada: 80%

## 📱 Arquitectura

- **Domain-driven design**: Separación clara de capas
- **Riverpod**: Gestión de estado
- **Supabase**: Backend y sincronización
- **Hive/Isar**: Storage local
- **Gamificación**: Sistema de logros y desafíos

## 🔧 Configuración

### Variables de Entorno
Crea un archivo `.env` en la raíz:
```env
SUPABASE_URL=tu_supabase_url
SUPABASE_ANON_KEY=tu_supabase_key
```

### Error Reporting y Monitoreo

La aplicación incluye un sistema de **error reporting** integrado con **Firebase Crashlytics** para detectar y analizar fallos en producción:

#### 🚨 Características del Error Reporting

- **Captura automática de crashes**: Detecta errores fatales y no fatales automáticamente
- **Contexto de usuario**: Asocia errores con información del usuario (cuando está autenticado)
- **Información detallada**: Incluye stack traces, datos de contexto y metadata
- **Configuración por entorno**: Habilitado en producción, configurable en desarrollo
- **Integración con logging**: Se conecta con el sistema de logging existente

#### 🔧 Configuración del Error Reporting

**Automática en producción:**
- Se habilita automáticamente en builds de release
- Los errores se envían a Firebase Crashlytics
- Los usuarios pueden optar por no participar en configuración

**Manual en desarrollo:**
```dart
// Habilitar manualmente para testing
await ErrorReportingService.instance.initialize(enabled: true);

// Reportar error personalizado
await ErrorReportingService.instance.reportError(
  error,
  stackTrace,
  reason: 'Custom error context',
  data: {'additional': 'context'},
  fatal: false,
);

// Simular crash para testing (solo en debug)
await ErrorReportingService.instance.testCrash();
```

#### 📱 Uso en Providers y Pantallas

Los providers críticos incluyen automáticamente error reporting:

```dart
// StateNotifier con error reporting
class MoviesNotifier extends StateNotifier<MoviesStateData> 
    with ErrorReportingMixin<MoviesStateData> {
  
  Future<void> loadMovies() async {
    await runWithErrorReporting(
      () async {
        // Lógica que puede fallar
        final movies = await fetchMovies();
        state = state.copyWith(movies: movies);
      },
      operationName: 'loadMovies',
      customData: {'page': currentPage},
    );
  }
}
```

#### 🔍 Dashboard y Alertas

**Firebase Crashlytics Dashboard:**
- Acceso en: [Firebase Console](https://console.firebase.google.com)
- Métricas de crash-free users
- Análisis de tendencias de errores
- Alertas automáticas para nuevos crashes

**Información Reportada:**
- Stack traces completos
- Device y OS información
- User context (si está autenticado)
- Custom keys y datos adicionales
- Breadcrumbs de navegación

#### ⚙️ Configuración de Usuario

Los usuarios pueden controlar el error reporting en:
- Configuraciones de la app
- Primera ejecución (opt-in/opt-out)
- Ajustes de privacidad

```dart
// Configurar preferencias de usuario
await ErrorReportingConfig.instance.setUserOptIn(false); // Deshabilitar
await ErrorReportingConfig.instance.setUserOptIn(true);  // Habilitar
```

### Plataformas Soportadas
- ✅ Android
- ✅ iOS  
- ✅ Web
- ✅ Linux
- ✅ macOS
- ✅ Windows

## 🤝 Contribución

1. Fork el proyecto
2. Crea tu rama (`git checkout -b feature/AmazingFeature`)
3. **Asegurate que el CI pase localmente**
4. Commit tus cambios (`git commit -m 'feat: Add some AmazingFeature'`)
5. Push a la rama (`git push origin feature/AmazingFeature`)
6. Abre un Pull Request usando el template

### Convenciones de Commit
- `feat:` Nueva funcionalidad
- `fix:` Corrección de bug  
- `docs:` Cambios en documentación
- `style:` Cambios de formato
- `refactor:` Refactoring de código
- `test:` Añadir o modificar tests
- `ci:` Cambios en CI/CD

## 📚 Recursos

- [Flutter Documentation](https://flutter.dev/docs)
- [Supabase Documentation](https://supabase.com/docs)
- [Proyecto Arquitectura](.trae/documents/)

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles. 
