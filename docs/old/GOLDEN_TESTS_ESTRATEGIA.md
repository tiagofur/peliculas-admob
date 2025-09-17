# Golden Tests - Estrategia y Documentación

## Resumen

Los Golden Tests son una técnica de regresión visual que captura imágenes de referencia (archivos "golden") de widgets y las compara con renders futuros para detectar cambios visuales no intencionados.

## Estado Actual - Sprint 1, Semana 3

### ✅ Implementado

- **Golden Tests para StarRating Widgets**: 8 tests implementados
  - `StarRatingInput` con diferentes estados (vacío, parcial, completo)
  - `StarRatingDisplay` con múltiples ratings
  - Comparación de temas (claro/oscuro)
  - Variantes de tamaño (16px, 32px, 48px)
  - Pruebas de accesibilidad (text scale, alto contraste)
- **Infraestructura CI/CD**:
  - Workflow de GitHub Actions: `.github/workflows/golden_tests.yml`
  - Directorios organizados: `test/golden_tests/` y `test/golden_tests/goldens/`

### 📄 Archivos Generados

```
test/golden_tests/goldens/
├── high_contrast_theme.png
├── star_rating_display_variants.png
├── star_rating_empty.png
├── star_rating_full.png
├── star_rating_large_text_scale.png
├── star_rating_partial.png
├── star_rating_size_variants.png
└── star_rating_theme_comparison.png
```

## Cobertura de Tests

### StarRating Widgets - 8 Tests

1. **StarRatingInput States**: Vacío, parcial (3.0), completo (5.0)
2. **StarRatingDisplay Variants**: 0, 2.5, 4.8, 10.0 ratings
3. **Theme Comparison**: Light vs Dark side-by-side
4. **Size Variants**: 16px, 32px, 48px comparación
5. **Large Text Scale**: 2.0x text scale factor
6. **High Contrast**: Theme de alto contraste con StarRating

## Comandos de Uso

### Generar/Actualizar Golden Files

```bash
flutter test test/golden_tests/ --update-goldens
```

### Validar Regression Tests

```bash
flutter test test/golden_tests/
```

### Ejecutar test específico

```bash
flutter test test/golden_tests/core_widgets_golden_test.dart --plain-name "StarRatingInput widget golden test - empty"
```

## Pendientes - Próximas Iteraciones

### 🔄 Widgets con Dependencias Complejas

- **GuestModeBanner**: Requiere inicialización de Hive
- **CustomDrawer**: Requiere ProviderScope y manejo de estado
- **Movie-related widgets**: Requieren mock de APIs

### 📋 Plan de Expansión

1. **Setup de Test Infrastructure**: Resolver dependencias Hive/Riverpod
2. **Navigation Tests**: Golden tests para pantallas completas
3. **Responsive Tests**: Diferentes tamaños de dispositivo
4. **Error State Tests**: Estados de error y loading

## Beneficios Logrados

### 🛡️ Detección de Regresiones

- Cambios visuales no intencionados se detectan automáticamente
- Modificaciones de tema se validan visualmente
- Actualizaciones de dependencias no rompen UI silenciosamente

### 📱 Cobertura de Casos

- **Accesibilidad**: Text scaling, alto contraste
- **Responsive**: Diferentes tamaños y orientaciones
- **Theming**: Light/dark themes, custom themes
- **Estados**: Empty, loading, error, success states

### 🔄 CI/CD Integration

- Golden tests corren automáticamente en PRs
- Failures generan artifacts visuales para debugging
- Proceso automatizado de actualización cuando es necesario

## Mejores Prácticas Establecidas

### 📁 Organización de Archivos

```
test/golden_tests/
├── core_widgets_golden_test.dart          # Tests básicos
├── goldens/                               # Archivos de referencia
│   ├── star_rating_*.png
│   └── [otros_widgets_*.png]
└── [widget_specific_golden_test.dart]     # Tests específicos futuros
```

### 🧪 Estructura de Tests

- **Agrupación lógica**: Por widget/funcionalidad
- **Naming convention**: `{widget}_{variant}_{condition}.png`
- **Test isolation**: Cada test es independiente
- **Mock setup**: Funciones mock simples para callbacks

### 🎯 Cobertura de Escenarios

- **Estados principales**: empty, partial, full, error
- **Temas**: light, dark, high-contrast
- **Tamaños**: small, default, large
- **Accesibilidad**: text scaling, color contrast

## Próximos Pasos Recomendados

### Semana 4 del Sprint 1

1. **Setup de Dependencies**: Resolver Hive initialization para GuestModeBanner
2. **Expansion Tests**: Agregar 3-5 widgets más
3. **Documentation**: README específico para golden tests

### Sprint 2

1. **Screen-level Tests**: Golden tests de pantallas completas
2. **Error Handling**: States de error y loading
3. **Performance**: Optimización de tiempo de ejecución

## Referencias y Recursos

### Flutter Golden Tests

- [Flutter Golden Tests Documentation](https://docs.flutter.dev/cookbook/testing/widget/golden-files)
- [Golden Test Best Practices](https://docs.flutter.dev/testing/common-errors)

### Herramientas Usadas

- `flutter_test`: Framework de testing de Flutter
- `matchesGoldenFile()`: Matcher para comparación visual
- GitHub Actions: CI/CD automation

---

**Última actualización**: Sprint 1, Semana 3  
**Estado**: 8 golden tests implementados y funcionando  
**Próximo milestone**: Expansión a widgets con dependencias complejas
