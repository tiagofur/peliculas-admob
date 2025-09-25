# 5. Estrategia de Pruebas y Validación

Esta sección describe el enfoque de pruebas y validación para garantizar la calidad de la aplicación.

## 5.1 Tipos de Pruebas

- **Unitarias** (`flutter test`): Validan la lógica de negocio en `lib/domain` y servicios.
- **Widget** (`flutter test`): Pruebas de widgets individuales, validación de UI.
- **Integración** (`flutter test integration_test/`): Flujos end-to-end (login, navegación, watchlist).
- **Golden Tests** (`flutter test test/golden_tests/`): Comparación de snapshots de UI.
- **Pruebas de rendimiento** (benchmarking y carga).

## 5.2 Cobertura de Código

- **Objetivo**: ≥ 85% de cobertura global.
- **Herramientas**: `flutter test --coverage` + `lcov`.
- **Reportes**: `coverage/lcov.info` → GitHub Pages.

## 5.3 Comandos Clave

```powershell
# Ejecución completa de pruebas
flutter test --coverage

# Integración
flutter test integration_test/

# Golden
flutter test test/golden_tests/ --update-goldens
flutter test test/golden_tests/
```

## 5.4 Pipeline CI

- Formateo: `dart format --set-exit-if-changed .`
- Análisis: `flutter analyze --fatal-infos --fatal-warnings`
- Pruebas unitarias, widget e integración.
- Generación y validación de golden tests.
