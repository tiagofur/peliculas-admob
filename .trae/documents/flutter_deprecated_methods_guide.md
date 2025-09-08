# Guía de Métodos Deprecated en Flutter

## 1. Métodos Deprecated Comunes y sus Reemplazos

### 1.1 Manejo de Transparencia en Colores

#### ❌ Deprecated
```dart
// Estas formas están deprecated
color.withOpacity(0.5)  // Deprecated desde Flutter 3.27
color.withValues(alpha: 0.5 * 255)  // Sintaxis incorrecta
```

#### ✅ Reemplazo Moderno
```dart
// Forma correcta actual
color.withValues(alpha: 0.5)  // Sin multiplicar por 255

// O usando Color.fromARGB para mayor claridad
Color.fromARGB(
  (255 * 0.5).round(),  // alpha
  color.red,
  color.green,
  color.blue,
)
```

### 1.2 Otros Métodos Deprecated Comunes

#### TextTheme
```dart
// ❌ Deprecated
theme.textTheme.headline1
theme.textTheme.headline2
theme.textTheme.bodyText1
theme.textTheme.bodyText2

// ✅ Reemplazo
theme.textTheme.displayLarge
theme.textTheme.displayMedium
theme.textTheme.bodyLarge
theme.textTheme.bodyMedium
```

#### Material Colors
```dart
// ❌ Deprecated
Colors.grey[500]
Theme.of(context).primaryColor

// ✅ Reemplazo
Theme.of(context).colorScheme.outline
Theme.of(context).colorScheme.primary
```

#### Scaffold
```dart
// ❌ Deprecated
Scaffold.of(context).showSnackBar()

// ✅ Reemplazo
ScaffoldMessenger.of(context).showSnackBar()
```

#### MediaQuery
```dart
// ❌ Deprecated
MediaQuery.of(context).size
MediaQuery.of(context).padding

// ✅ Reemplazo (cuando sea posible)
MediaQuery.sizeOf(context)
MediaQuery.paddingOf(context)
```

## 2. Guía de Migración Paso a Paso

### Paso 1: Identificar Métodos Deprecated
```bash
# Ejecutar análisis estático
flutter analyze

# Buscar warnings específicos
flutter analyze | grep -i "deprecated"
```

### Paso 2: Buscar Patrones Comunes
```bash
# Buscar withOpacity
grep -r "withOpacity" lib/

# Buscar withValues con multiplicación
grep -r "withValues.*\*.*255" lib/

# Buscar textTheme deprecated
grep -r "headline[1-6]\|bodyText[1-2]" lib/
```

### Paso 3: Reemplazar Sistemáticamente
1. **Colores**: Cambiar `withOpacity()` por `withValues(alpha:)`
2. **TextTheme**: Actualizar a los nuevos nombres
3. **ColorScheme**: Migrar de colores específicos a esquemas de color
4. **Scaffold**: Usar ScaffoldMessenger

### Paso 4: Verificar Cambios
```bash
# Verificar que no hay errores
flutter analyze

# Ejecutar tests
flutter test

# Compilar para verificar
flutter build apk --debug
```

## 3. Ejemplos de Código Antes y Después

### Ejemplo 1: Transparencia de Colores
```dart
// ❌ ANTES (Deprecated)
Container(
  decoration: BoxDecoration(
    color: Colors.blue.withOpacity(0.3),
    border: Border.all(
      color: Colors.blue.withOpacity(0.5),
    ),
  ),
)

// ✅ DESPUÉS (Moderno)
Container(
  decoration: BoxDecoration(
    color: Colors.blue.withValues(alpha: 0.3),
    border: Border.all(
      color: Colors.blue.withValues(alpha: 0.5),
    ),
  ),
)
```

### Ejemplo 2: TextTheme
```dart
// ❌ ANTES (Deprecated)
Text(
  'Título',
  style: Theme.of(context).textTheme.headline1,
)
Text(
  'Cuerpo',
  style: Theme.of(context).textTheme.bodyText1,
)

// ✅ DESPUÉS (Moderno)
Text(
  'Título',
  style: Theme.of(context).textTheme.displayLarge,
)
Text(
  'Cuerpo',
  style: Theme.of(context).textTheme.bodyLarge,
)
```

### Ejemplo 3: ColorScheme
```dart
// ❌ ANTES (Deprecated)
Container(
  color: Theme.of(context).primaryColor,
  child: Text(
    'Texto',
    style: TextStyle(
      color: Theme.of(context).accentColor,
    ),
  ),
)

// ✅ DESPUÉS (Moderno)
Container(
  color: Theme.of(context).colorScheme.primary,
  child: Text(
    'Texto',
    style: TextStyle(
      color: Theme.of(context).colorScheme.secondary,
    ),
  ),
)
```

## 4. Lista de Verificación para Evitar Deprecated

### ✅ Checklist de Desarrollo
- [ ] Usar `withValues(alpha:)` en lugar de `withOpacity()`
- [ ] Usar nuevos nombres de TextTheme (`displayLarge`, `bodyLarge`, etc.)
- [ ] Usar `ColorScheme` en lugar de colores específicos del tema
- [ ] Usar `ScaffoldMessenger` en lugar de `Scaffold.of(context)`
- [ ] Usar `MediaQuery.sizeOf()` cuando sea posible
- [ ] Verificar warnings de deprecated en el IDE
- [ ] Ejecutar `flutter analyze` regularmente

### ✅ Checklist de Revisión de Código
- [ ] No hay warnings de deprecated en el análisis
- [ ] Los colores usan la API moderna
- [ ] Los estilos de texto usan nombres actualizados
- [ ] Los temas usan ColorScheme
- [ ] Las navegaciones usan APIs actuales

## 5. Herramientas y Comandos para Detectar Deprecated

### Análisis Estático
```bash
# Análisis completo
flutter analyze

# Solo warnings de deprecated
flutter analyze 2>&1 | grep -i "deprecated"

# Análisis con más detalles
flutter analyze --verbose
```

### Búsquedas con Grep
```bash
# Buscar withOpacity
grep -r "withOpacity" lib/ --include="*.dart"

# Buscar TextTheme deprecated
grep -r "headline[1-6]\|bodyText[1-2]\|subtitle[1-2]" lib/ --include="*.dart"

# Buscar colores deprecated
grep -r "primaryColor\|accentColor\|backgroundColor" lib/ --include="*.dart"

# Buscar Scaffold deprecated
grep -r "Scaffold\.of.*showSnackBar" lib/ --include="*.dart"
```

### Configuración del IDE
```yaml
# En analysis_options.yaml
linter:
  rules:
    - deprecated_member_use: error
    - deprecated_member_use_from_same_package: error
```

### Scripts de Automatización
```bash
#!/bin/bash
# check_deprecated.sh
echo "Buscando métodos deprecated..."

echo "\n1. withOpacity:"
grep -r "withOpacity" lib/ --include="*.dart" | wc -l

echo "\n2. TextTheme deprecated:"
grep -r "headline[1-6]\|bodyText[1-2]" lib/ --include="*.dart" | wc -l

echo "\n3. Colores deprecated:"
grep -r "primaryColor\|accentColor" lib/ --include="*.dart" | wc -l

echo "\n4. Ejecutando flutter analyze..."
flutter analyze 2>&1 | grep -i "deprecated" | wc -l
```

## 6. Estado Actual del Proyecto

### Archivos que Requieren Corrección de `withOpacity`

Se encontraron las siguientes instancias de `withOpacity` que necesitan ser actualizadas:

1. **conflict_history_list.dart** - 14 instancias
2. **merge_preview_widget.dart** - 14 instancias  
3. **conflict_resolution_dialog.dart** - 4 instancias
4. **connectivity_banner.dart** - 12 instancias
5. **conflict_preview_widget.dart** - 17 instancias
6. **sync_status_indicator.dart** - 2 instancias
7. **silent_sync_indicator.dart** - 7 instancias
8. **sync_history_viewer.dart** - 4 instancias

**Total: 74 instancias** que necesitan ser corregidas.

### Patrón de Corrección Automática
```bash
# Buscar y reemplazar withOpacity por withValues
find lib/ -name "*.dart" -exec sed -i 's/\.withOpacity(\([^)]*\))/.withValues(alpha: \1)/g' {} \;
```

## 7. Recursos Adicionales

### Documentación Oficial
- [Flutter Breaking Changes](https://docs.flutter.dev/release/breaking-changes)
- [Migration Guide](https://docs.flutter.dev/release/breaking-changes/theme-data-accent-properties)
- [Color API Changes](https://docs.flutter.dev/release/breaking-changes/color-scheme-text-styles)

### Herramientas Útiles
- **Flutter Inspector**: Para verificar widgets en tiempo real
- **Dart DevTools**: Para análisis de rendimiento
- **IDE Extensions**: Para warnings en tiempo real

### Comandos de Migración Automática
```bash
# Actualizar dependencias
flutter pub upgrade

# Migración automática (cuando esté disponible)
dart fix --apply

# Verificar compatibilidad
flutter doctor
```

---

## Notas Importantes

⚠️ **Siempre verifica los cambios después de la migración**
- Ejecuta tests completos
- Verifica la UI en diferentes dispositivos
- Revisa el rendimiento

💡 **Mantente actualizado**
- Suscríbete a las notas de lanzamiento de Flutter
- Revisa regularmente la documentación de breaking changes
- Actualiza este documento cuando encuentres nuevos deprecated

🔧 **Automatización**
- Configura CI/CD para detectar deprecated
- Usa pre-commit hooks para análisis
- Implementa revisiones de código regulares