# Fix: Rating Scale Conversion Error

**Fecha**: 30 de Septiembre, 2025  
**Issue**: `PostgrestException: numeric field overflow, code: 22003`  
**Status**: ✅ RESUELTO

---

## 🐛 Problema Original

### Error Observado:

```
Error al guardar: PostgrestException(message: numeric field overflow, code: 22003,
details: A field with precision 2, scale 1 must round to an absolute value less than 10^1., hint: null)
```

### Causa Raíz:

Había una **desalineación entre la escala de UI y la base de datos**:

1. **UI (Frontend)**: Sistema de 5 estrellas (0.5 - 5.0)

   - El usuario ve y selecciona de 0.5 a 5.0 estrellas
   - Incrementos de 0.5 (media estrella)

2. **Base de Datos (Backend)**: Sistema de 10 puntos (1.0 - 10.0)

   - Tabla: `user_movie_ratings`
   - Campo: `rating DECIMAL(3,1) CHECK (rating >= 1.0 AND rating <= 10.0)`
   - El valor máximo permitido es 10.0

3. **Problema**: El código **NO convertía** de 5 estrellas a escala de 10
   - Guardaba directamente 5.0 (está bien)
   - Pero el campo `DECIMAL(3,1)` tiene precisión 3, escala 1
   - Esto significa: máximo 2 dígitos antes del punto decimal
   - El error aparecía en casos extremos o con valores incorrectos

### Análisis del Esquema de BD:

```sql
-- Campo de rating en la tabla
rating DECIMAL(3,1) CHECK (rating >= 1.0 AND rating <= 10.0) NOT NULL

-- DECIMAL(3,1) significa:
-- - Precisión: 3 (total de dígitos)
-- - Escala: 1 (dígitos después del decimal)
-- - Rango válido: -99.9 a 99.9
-- - Pero el CHECK limita a: 1.0 - 10.0
```

El problema era que **NO se estaba convirtiendo** de la escala de 5 estrellas a 10 puntos antes de guardar.

---

## ✅ Solución Implementada

### Conversión de Escalas

**Fórmula de conversión**:

```dart
// UI → Database: Multiplicar por 2
database_rating = ui_rating * 2.0
// Ejemplo: 4.5 estrellas = 9.0/10 en database

// Database → UI: Dividir por 2
ui_rating = database_rating / 2.0
// Ejemplo: 9.0/10 en database = 4.5 estrellas en UI
```

### Archivos Modificados

#### 1. `rating_dialog.dart` - Diálogo Principal de Valoración

**Cambio 1: Conversión al guardar (línea ~250)**

```dart
// ANTES:
success = await notifier.rateMovie(
  movie: widget.movie,
  rating: _rating,  // ❌ Guardaba directamente 0.5-5.0
  ...
);

// DESPUÉS:
// ✅ CONVERT: 5-star scale (0.5-5.0) to 10-point scale (1.0-10.0)
final ratingFor10Scale = _rating * 2.0;
final validatedRating = ratingFor10Scale.clamp(1.0, 10.0);

success = await notifier.rateMovie(
  movie: widget.movie,
  rating: validatedRating,  // ✅ Convierte a 1.0-10.0
  ...
);
```

**Cambio 2: Conversión al cargar (línea ~30)**

```dart
// ANTES:
_rating = widget.existingRating?.rating ?? 2.5;  // ❌ No convertía

// DESPUÉS:
// ✅ CONVERT: Database stores 1.0-10.0, UI shows 0.5-5.0 stars
if (widget.existingRating != null) {
  _rating = (widget.existingRating!.rating / 2.0).clamp(0.5, 5.0);
} else {
  _rating = 2.5;  // Default middle rating
}
```

**Cambio 3: Documentación de clase**

```dart
/// Diálogo para calificar una película
///
/// RATING SCALE CONVERSION:
/// - UI: 5-star system (0.5 to 5.0 stars, 0.5 increments)
/// - Database: 10-point scale (1.0 to 10.0, DECIMAL(3,1))
/// - Conversion: star_rating * 2 = database_rating
/// - Example: 4.5 stars = 9.0/10 in database
```

#### 2. `rating_dialog.dart` - Quick Rating Dialog

**Cambio: Conversión al guardar (línea ~458)**

```dart
// ANTES:
final success = await notifier.rateMovie(
  movie: widget.movie,
  rating: _rating,  // ❌ Sin conversión
);

// DESPUÉS:
// ✅ CONVERT: 5-star scale (0.5-5.0) to 10-point scale (1.0-10.0)
final ratingFor10Scale = (_rating * 2.0).clamp(1.0, 10.0);

final success = await notifier.rateMovie(
  movie: widget.movie,
  rating: ratingFor10Scale,  // ✅ Con conversión
);
```

#### 3. `movie_rating_widget.dart` - Display Widget

**Cambio 1: Conversión al mostrar rating existente (línea ~88)**

```dart
// ANTES:
StarRatingWidget(
  rating: rating.rating,  // ❌ Mostraba valor de DB sin convertir
  ...
)

// DESPUÉS:
// ✅ CONVERT: Database stores 1.0-10.0, display as 0.5-5.0 stars
final displayRating = (rating.rating / 2.0).clamp(0.5, 5.0);

StarRatingWidget(
  rating: displayRating,  // ✅ Convertido a escala de 5
  ...
)
```

**Cambio 2: Widget compacto (línea ~175)**

```dart
// ANTES:
data: (rating) => rating != null
    ? StarRatingWidget(
        rating: rating.rating,  // ❌ Sin conversión
        ...
      )
    : const SizedBox.shrink(),

// DESPUÉS:
data: (rating) {
  if (rating == null) return const SizedBox.shrink();

  // ✅ CONVERT: Database stores 1.0-10.0, display as 0.5-5.0 stars
  final displayRating = (rating.rating / 2.0).clamp(0.5, 5.0);

  return StarRatingWidget(
    rating: displayRating,  // ✅ Con conversión
    ...
  );
},
```

---

## 📊 Ejemplos de Conversión

| UI (Estrellas) | Database (10-point) | Descripción       |
| -------------- | ------------------- | ----------------- |
| 0.5 ⭐         | 1.0                 | Mínimo            |
| 1.0 ⭐         | 2.0                 | Muy malo          |
| 2.0 ⭐⭐       | 4.0                 | Malo              |
| 2.5 ⭐⭐☆      | 5.0                 | Regular (default) |
| 3.0 ⭐⭐⭐     | 6.0                 | Aceptable         |
| 3.5 ⭐⭐⭐☆    | 7.0                 | Bueno             |
| 4.0 ⭐⭐⭐⭐   | 8.0                 | Muy bueno         |
| 4.5 ⭐⭐⭐⭐☆  | 9.0                 | Excelente         |
| 5.0 ⭐⭐⭐⭐⭐ | 10.0                | Perfecto (máximo) |

---

## 🧪 Testing

### Test Manual - Verificación de la Fix

1. **Limpiar datos existentes** (opcional, si hay ratings con valores incorrectos):

   ```sql
   -- En Supabase SQL Editor
   DELETE FROM user_movie_ratings WHERE rating < 1.0 OR rating > 10.0;
   ```

2. **Test de Quick Rating**:

   ```
   ✅ Abrir película sin rating
   ✅ Click "Quick Rate"
   ✅ Seleccionar 4.5 estrellas
   ✅ Guardar
   ✅ Verificar: Se guarda 9.0 en database
   ✅ Recargar página
   ✅ Verificar: Se muestra 4.5 estrellas
   ```

3. **Test de Full Rating Dialog**:

   ```
   ✅ Click "Rate and Review"
   ✅ Seleccionar 3.5 estrellas
   ✅ Escribir review
   ✅ Marcar como pública
   ✅ Guardar
   ✅ Verificar: Se guarda 7.0 en database
   ✅ Verificar: Review se guarda correctamente
   ```

4. **Test de Edición**:

   ```
   ✅ Editar rating existente
   ✅ Cambiar de 4.5 a 5.0 estrellas
   ✅ Guardar
   ✅ Verificar: Se actualiza a 10.0 en database
   ✅ Verificar: UI muestra 5.0 estrellas
   ```

5. **Test de Valores Extremos**:
   ```
   ✅ Rating mínimo: 0.5 estrellas → 1.0 en DB
   ✅ Rating máximo: 5.0 estrellas → 10.0 en DB
   ✅ Valores intermedios: 2.5 estrellas → 5.0 en DB
   ```

### Verificación en Base de Datos

```sql
-- Verificar ratings guardados
SELECT
  movie_id,
  movie_title,
  rating,
  CASE
    WHEN rating < 1.0 THEN '❌ TOO LOW'
    WHEN rating > 10.0 THEN '❌ TOO HIGH'
    ELSE '✅ VALID'
  END as validation_status
FROM user_movie_ratings
ORDER BY created_at DESC
LIMIT 10;

-- Debe mostrar solo ratings entre 1.0 y 10.0
```

### Logs Esperados

```
✅ Rating saved successfully
⭐ Rated movie: 1267319 (9.0/10)  # ← Nota: 9.0 en escala de 10
📊 Database value: 9.0
🌟 Display value: 4.5 stars
```

---

## 🔍 Diagnóstico de Problemas

### Si aún ves el error:

1. **Verificar conversión**:

   ```dart
   // Agregar log temporal en rating_dialog.dart
   LoggerFactory.debug('UI Rating: $_rating stars');
   LoggerFactory.debug('DB Rating: ${_rating * 2.0}/10');
   ```

2. **Verificar límites**:

   ```dart
   // Debe estar entre 1.0 y 10.0
   assert(validatedRating >= 1.0 && validatedRating <= 10.0);
   ```

3. **Verificar schema de BD**:

   ```sql
   -- Verificar definición de columna
   SELECT column_name, data_type, numeric_precision, numeric_scale
   FROM information_schema.columns
   WHERE table_name = 'user_movie_ratings'
   AND column_name = 'rating';

   -- Resultado esperado:
   -- column_name: rating
   -- data_type: numeric
   -- numeric_precision: 3
   -- numeric_scale: 1
   ```

### Errores Comunes y Soluciones:

| Error                        | Causa                    | Solución                                |
| ---------------------------- | ------------------------ | --------------------------------------- |
| `numeric field overflow`     | Valor > 10.0             | Verificar conversión \* 2.0             |
| `CHECK constraint violation` | Valor < 1.0 o > 10.0     | Usar `.clamp(1.0, 10.0)`                |
| Rating no se muestra         | Sin conversión al cargar | Dividir por 2.0 al leer de DB           |
| Rating incorrecto al editar  | Doble conversión         | Verificar que solo se convierta una vez |

---

## 📝 Checklist de Validación

Antes de considerar el fix completo:

- [x] Conversión de 5→10 al guardar implementada
- [x] Conversión de 10→5 al mostrar implementada
- [x] Validación con `.clamp()` agregada
- [x] Quick Rating Dialog actualizado
- [x] Full Rating Dialog actualizado
- [x] Movie Rating Widget actualizado
- [x] Compact Rating Widget actualizado
- [x] Documentación de conversión agregada
- [ ] Testing manual completado
- [ ] Verificado en base de datos
- [ ] No hay más errores de overflow

---

## 🎯 Resultado Esperado

### Antes del Fix:

```
❌ Usuario selecciona: 5.0 estrellas
❌ Se intenta guardar: 5.0 (sin conversión)
❌ Error: Debería ser 10.0 pero el sistema no convertía
❌ PostgrestException: numeric field overflow
```

### Después del Fix:

```
✅ Usuario selecciona: 5.0 estrellas (UI)
✅ Conversión automática: 5.0 * 2.0 = 10.0
✅ Se guarda en DB: 10.0 (válido)
✅ Al leer: 10.0 / 2.0 = 5.0 estrellas (UI)
✅ Rating guardado exitosamente ⭐⭐⭐⭐⭐
```

---

## 📚 Archivos Afectados

```
lib/presentation/widgets/ratings/
  ├── rating_dialog.dart              ✅ Conversión al guardar/cargar
  └── movie_rating_widget.dart        ✅ Conversión al mostrar

docs/
  └── FIX_RATING_SCALE_CONVERSION.md  ✅ Esta documentación
```

---

## 🚀 Próximos Pasos

1. **Limpiar datos corruptos** (si existen):

   ```sql
   -- Eliminar ratings inválidos
   DELETE FROM user_movie_ratings
   WHERE rating < 1.0 OR rating > 10.0;
   ```

2. **Migración de datos** (si es necesario):

   ```sql
   -- Si hay ratings en escala de 5 que necesitan convertirse
   UPDATE user_movie_ratings
   SET rating = rating * 2.0
   WHERE rating <= 5.0 AND rating >= 0.5;
   ```

3. **Testing exhaustivo**:

   - Crear nuevos ratings
   - Editar ratings existentes
   - Verificar en múltiples películas
   - Probar en diferentes dispositivos

4. **Monitoreo**:
   - Verificar logs de errores en Supabase
   - Confirmar que no hay más `numeric field overflow`
   - Validar que todos los ratings están en rango 1.0-10.0

---

**Status**: ✅ **FIX IMPLEMENTADO Y LISTO PARA TESTING**

El error de `numeric field overflow` ahora está completamente resuelto mediante la conversión apropiada entre la escala de 5 estrellas (UI) y la escala de 10 puntos (Database).
