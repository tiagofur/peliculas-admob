# Debug Guide - Rating Slider Widget

## Problema Reportado

"No me salió como un slider en la web y me sigue marcando error"

## Verificaciones de Debug

### 1. ¿El widget se está importando correctamente?

Verificar en `rating_dialog.dart`:

```dart
import 'rating_slider_widget.dart'; // ✅ Debe estar presente
```

### 2. ¿El widget se está usando en el dialog?

Verificar en `_buildRatingSection()`:

```dart
RatingSlider(
  rating: _rating,
  onChanged: (value) {
    setState(() {
      _rating = value;
    });
  },
  compact: MediaQuery.of(context).size.width < 400,
),
```

### 3. Errores Comunes y Soluciones

#### Error: "RatingSlider not found"

**Solución:**

```bash
flutter clean
flutter pub get
flutter run -d chrome
```

#### Error: "Slider no aparece"

**Causa:** Podría estar en modo `readonly`
**Verificar:**

- `readonly = false` (default)
- `onChanged != null`

#### Error: "Widget no se renderiza"

**Debug:**

1. Abrir DevTools de Chrome (F12)
2. Buscar errores en Console
3. Buscar warnings en Flutter DevTools

### 4. Test Manual Rápido

```dart
// En rating_dialog.dart, agregar debug print:
@override
Widget build(BuildContext context) {
  print('🐛 DEBUG: Building dialog with rating: $_rating');
  // ... resto del código
}

Widget _buildRatingSection() {
  print('🐛 DEBUG: Building RatingSlider widget');
  return Column(
    // ... código del slider
  );
}
```

### 5. Verificar que el Dialog se Abre

En `movie_rating_and_notes.dart`:

```dart
void _showQuickRating(BuildContext context) {
  print('🐛 DEBUG: Opening QuickRatingDialog');
  showDialog(
    context: context,
    builder: (context) => QuickRatingDialog(movie: movie),
  );
}
```

### 6. Errores Posibles en Consola

#### "Failed assertion: line X: 'rating >= 1.0 && rating <= 10.0'"

**Solución:** Rating fuera de rango

```dart
_rating = _rating.clamp(1.0, 10.0);
```

#### "RenderBox was not laid out"

**Solución:** Problema de layout

```dart
// Envolver RatingSlider en Container con constraints
Container(
  constraints: BoxConstraints(maxWidth: 400),
  child: RatingSlider(...)
)
```

#### "setState() called after dispose()"

**Solución:** Verificar lifecycle

```dart
if (mounted) {
  setState(() {
    _rating = value;
  });
}
```

### 7. Test de Renderizado

Crear archivo temporal `test_rating_slider.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:peliculas/presentation/widgets/ratings/rating_slider_widget.dart';

class TestRatingSliderScreen extends StatefulWidget {
  @override
  State<TestRatingSliderScreen> createState() => _TestRatingSliderScreenState();
}

class _TestRatingSliderScreenState extends State<TestRatingSliderScreen> {
  double _rating = 5.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Test Rating Slider')),
      body: Center(
        child: Container(
          padding: EdgeInsets.all(24),
          constraints: BoxConstraints(maxWidth: 500),
          child: RatingSlider(
            rating: _rating,
            onChanged: (value) {
              setState(() {
                _rating = value;
              });
              print('🐛 Rating changed to: $value');
            },
          ),
        ),
      ),
    );
  }
}
```

Agregar ruta en `main.dart` para testing.

### 8. Verificar Dependencias

```bash
flutter doctor -v
flutter pub get
flutter pub outdated
```

### 9. Hot Reload vs Hot Restart

Si cambios no aparecen:

- `r` - Hot reload (rápido)
- `R` - Hot restart (completo)
- `q` + `flutter run -d chrome` (limpio)

### 10. Revisar Build Web

```bash
# Limpiar completamente
flutter clean
rm -rf build/
rm -rf .dart_tool/

# Rebuild
flutter pub get
flutter run -d chrome
```

## Checklist de Debugging

```
[ ] Imports correctos en rating_dialog.dart
[ ] RatingSlider se está usando (no StarRatingWidget)
[ ] rating_slider_widget.dart existe y compila
[ ] No hay errores en flutter analyze
[ ] App corre sin crash
[ ] Dialog se abre
[ ] Slider es visible en el dialog
[ ] Slider responde a interacción
[ ] Valor se actualiza al mover slider
[ ] Console de Chrome sin errores
```

## Información para Reportar

Si el problema persiste, proveer:

1. **Screenshot del error** (si hay mensaje de error)
2. **Console output** (errores en terminal de Flutter)
3. **Browser console** (errores en DevTools de Chrome)
4. **Qué pantalla** (¿en qué parte de la app?)
5. **Qué acción** (¿qué estabas haciendo?)
6. **Comportamiento esperado vs actual**

## Comando para Debug Completo

```bash
flutter clean
flutter pub get
flutter run -d chrome --verbose 2>&1 | tee debug_output.log
```

Esto guardará todo el output en `debug_output.log` para análisis.
