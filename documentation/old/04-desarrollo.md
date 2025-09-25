# 4. Flujo de Desarrollo

Este documento explica el proceso de desarrollo colaborativo y las mejores prácticas para contribuir al proyecto.

## 4.1 Branching y Versionado

- `main`: rama de producción estable.
- `develop`: rama de integración continua.
- Ramas feature: `feature/<nombre-del-feature>`.
- Ramas hotfix: `hotfix/<issue>`.

## 4.2 Ciclo de Pull Request (PR)

1. Crear rama feature desde `develop`.
2. Implementar cambios y asegurarse de:
   - Pasar `dart format`.
   - Pasar `flutter analyze --fatal-infos --fatal-warnings`.
   - Pasar pruebas unitarias e integración.
3. Abrir PR con descripción clara y checklist de validación.
4. Asignar revisores y esperar aprobaciones.
5. Merge a `develop` y luego a `main` vía Release.

## 4.3 Entorno de Pruebas Local

```powershell
# Ejecutar pruebas unitariaslutter test

# Pruebas de integración
flutter test integration_test/

# Golden testslutter test test/golden_tests/ --update-goldens
flutter test test/golden_tests/
```

## 4.4 Calidad de Código

- Formateo: `dart format --set-exit-if-changed .`
- Análisis: `flutter analyze --fatal-infos --fatal-warnings`
- Lint: se respetan reglas en `analysis_options.yaml`.

## 4.5 Herramientas de Desarrollo

- Generators: `build_runner`.
- Migración de APIs obsoletas: `dart fix`.
- Monitor de memoria y performance: DevTools.
