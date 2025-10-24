# ✅ Checklist de Testing: Sistema de Rating

**Fecha**: 30 de Septiembre, 2025  
**Objetivo**: Validar que el sistema de rating funciona correctamente con slider y sin errores de overflow

---

## 🎯 Cambios Implementados

### ✅ Correcciones Aplicadas

1. **Validación Triple de Rating (1.0-10.0)**:

   - ✅ En `SyncableMovieRating.toSupabaseJson()`
   - ✅ En `HybridMovieRatingsRepository.rateMovie()`
   - ✅ En `HybridMovieRatingsRepository.updateRating()`

2. **Protección contra PostgreSQL Overflow**:

   - ✅ Todos los ratings se validan con `.clamp(1.0, 10.0)`
   - ✅ Se loggean warnings si el valor fue ajustado
   - ✅ Imposible guardar valores fuera del rango

3. **Sistema de Slider Confirmado**:
   - ✅ `RatingDialog` usa `RatingSlider`
   - ✅ Escala directa 1.0-10.0 (sin conversión de estrellas)
   - ✅ Incrementos de 0.5 (18 divisiones)

---

## 🧪 Tests Manuales Requeridos

### Test 1: Calificar Nueva Película ⭐

**Objetivo**: Verificar que se puede calificar una película nueva sin errores

**Pasos**:

1. ✅ Abrir la aplicación
2. ✅ Navegar a detalles de una película sin calificación
3. ✅ Buscar la sección "Tu valoración" o "Your Rating"
4. ✅ Click en "Rate Movie" o "Calificar película"
5. ✅ **VERIFICAR**: ¿Se muestra un SLIDER o ESTRELLAS?
   - ✅ CORRECTO: Slider horizontal con escala 1.0-10.0
   - ❌ INCORRECTO: Estrellas ⭐⭐⭐⭐⭐
6. ✅ Mover el slider a **5.0**
7. ✅ Click en "Rate" o "Guardar valoración"
8. ✅ **VERIFICAR**:
   - ✅ Mensaje de éxito aparece
   - ✅ NO aparece error de PostgreSQL
   - ✅ La calificación se muestra correctamente

**Resultado Esperado**:

```
✅ Slider visible
✅ Rating guardado: 5.0/10
✅ Sin errores en consola
```

---

### Test 2: Actualizar Calificación Existente 📝

**Objetivo**: Verificar que se puede actualizar una calificación sin errores

**Pasos**:

1. ✅ Abrir película con calificación existente
2. ✅ Click en "Edit Rating" o "Editar valoración"
3. ✅ **VERIFICAR**: Slider muestra el valor actual
4. ✅ Cambiar rating a **8.5**
5. ✅ Click en "Update" o "Actualizar"
6. ✅ **VERIFICAR**:
   - ✅ Rating actualizado correctamente
   - ✅ NO aparece error PostgreSQL
   - ✅ Nueva calificación se refleja inmediatamente

**Resultado Esperado**:

```
✅ Rating actualizado: 8.5/10
✅ Sin errores
✅ UI actualizada
```

---

### Test 3: Valores Límite 🔢

**Objetivo**: Verificar que los valores mínimos y máximos funcionan

**Escenarios**:

#### 3.1: Rating Mínimo

- ✅ Mover slider a **1.0**
- ✅ Guardar
- ✅ **VERIFICAR**: Se guarda correctamente

#### 3.2: Rating Máximo

- ✅ Mover slider a **10.0**
- ✅ Guardar
- ✅ **VERIFICAR**: Se guarda correctamente

#### 3.3: Rating Intermedio con Decimales

- ✅ Mover slider a **7.5**
- ✅ Guardar
- ✅ **VERIFICAR**: Se guarda como 7.5 (no como 7 o 8)

**Resultado Esperado**:

```
✅ 1.0 → guardado correctamente
✅ 10.0 → guardado correctamente
✅ 7.5 → guardado correctamente
✅ Sin errores PostgreSQL
```

---

### Test 4: Quick Rating ⚡

**Objetivo**: Verificar el diálogo rápido de calificación

**Pasos**:

1. ✅ Abrir detalles de película sin calificación
2. ✅ Click en "Quick Rate" (si está disponible)
3. ✅ **VERIFICAR**: Diálogo simplificado con slider
4. ✅ Seleccionar rating (ejemplo: 6.5)
5. ✅ Confirmar
6. ✅ **VERIFICAR**: Rating guardado sin errores

**Resultado Esperado**:

```
✅ Diálogo rápido funciona
✅ Slider visible
✅ Rating guardado correctamente
```

---

### Test 5: Rating con Review 📝⭐

**Objetivo**: Verificar calificación con reseña

**Pasos**:

1. ✅ Click en "Rate and Review" o "Calificar y reseñar"
2. ✅ Mover slider a **9.0**
3. ✅ Escribir reseña: "Excelente película, muy emotiva"
4. ✅ Marcar como pública (opcional)
5. ✅ Guardar
6. ✅ **VERIFICAR**:
   - ✅ Rating y reseña guardados
   - ✅ Reseña visible en UI
   - ✅ Sin errores

**Resultado Esperado**:

```
✅ Rating: 9.0/10
✅ Review: "Excelente película..."
✅ Sin errores PostgreSQL
```

---

### Test 6: Eliminar Calificación 🗑️

**Objetivo**: Verificar que se puede eliminar una calificación

**Pasos**:

1. ✅ Abrir película con calificación
2. ✅ Click en "Delete" o botón de eliminar
3. ✅ Confirmar eliminación
4. ✅ **VERIFICAR**:
   - ✅ Calificación eliminada
   - ✅ UI muestra "Rate Movie" nuevamente
   - ✅ Sin errores

**Resultado Esperado**:

```
✅ Rating eliminado
✅ UI actualizada
✅ Sin errores
```

---

## 🔍 Verificaciones en Consola

### Logs Esperados (NO son errores)

```dart
✅ INFO: ⭐ Rated movie: 123 (8.5/10)
✅ INFO: 📝 Updated movie rating: 123 (9.0/10)
```

### Logs de Warning (Indican validación funcionando)

```dart
⚠️ WARNING: Rating clamped from 11.5 to 10.0 for movie 123
```

**Nota**: Este warning es BUENO, significa que la validación está funcionando.

### Errores a EVITAR

```
❌ PostgrestException: numeric field overflow, code: 22003
❌ A field with precision 2, scale 1 must round to an absolute value less than 10^1
```

Si ves estos errores → **La solución NO está funcionando**, reportar inmediatamente.

---

## 🖥️ Testing en Diferentes Plataformas

### Web (Chrome)

```powershell
flutter run -d chrome --web-browser-flag="--disable-cache"
```

### Android

```powershell
flutter run -d android
```

### Desktop (Windows)

```powershell
flutter run -d windows
```

**Verificar en TODAS las plataformas**:

- ✅ Slider visible y funcional
- ✅ Ratings se guardan correctamente
- ✅ Sin errores PostgreSQL

---

## 📊 Criterios de Éxito

### ✅ TODO OK si...

1. **UI Correcta**:

   - ✅ Se muestra SLIDER (no estrellas)
   - ✅ Escala 1.0 - 10.0 visible
   - ✅ Incrementos de 0.5 funcionan

2. **Funcionalidad**:

   - ✅ Crear rating: Funciona
   - ✅ Actualizar rating: Funciona
   - ✅ Eliminar rating: Funciona
   - ✅ Rating con review: Funciona

3. **Estabilidad**:

   - ✅ CERO errores PostgreSQL
   - ✅ CERO errores de overflow
   - ✅ Logs limpios (solo INFO/WARNING válidos)

4. **Valores**:
   - ✅ 1.0 se guarda correctamente
   - ✅ 10.0 se guarda correctamente
   - ✅ 5.5, 7.5, 8.5 se guardan con decimales

### ❌ FALLO si...

- ❌ Aparece error PostgreSQL overflow
- ❌ Se muestran estrellas en lugar de slider
- ❌ Rating no se guarda
- ❌ Rating se guarda con valor incorrecto
- ❌ Decimales no funcionan (7.5 → 7 o 8)

---

## 🐛 Troubleshooting

### Problema: Sigo viendo estrellas

**Solución**:

1. Hacer `flutter clean`
2. Hacer `flutter pub get`
3. Recargar aplicación con caché deshabilitado
4. Verificar que se importa `RatingDialog` correctamente

### Problema: Error PostgreSQL persiste

**Verificar**:

1. ¿Se están usando los archivos modificados?
2. ¿Se ejecutó `flutter pub get` después de cambios?
3. ¿Hay algún widget antiguo llamando a `StarRatingWidget`?

**Comando de búsqueda**:

```powershell
# Buscar usos de widgets antiguos
flutter analyze --fatal-infos
grep -r "StarRatingWidget" lib/
```

### Problema: Rating se guarda con valor incorrecto

**Verificar en logs**:

```
⚠️ Rating clamped from X to Y
```

Si ves este log frecuentemente → Hay un bug en la UI que está generando valores incorrectos.

---

## 📝 Reporte de Testing

### Plantilla de Reporte

```markdown
## Reporte de Testing - Sistema de Rating

**Fecha**: **\_**
**Plataforma**: [ ] Web [ ] Android [ ] iOS [ ] Windows

### Tests Ejecutados

- [ ] Test 1: Calificar nueva película
- [ ] Test 2: Actualizar calificación
- [ ] Test 3: Valores límite (1.0, 10.0, 7.5)
- [ ] Test 4: Quick rating
- [ ] Test 5: Rating con review
- [ ] Test 6: Eliminar calificación

### Resultados

**UI**:

- Slider visible: [ ] Sí [ ] No
- Estrellas visibles: [ ] Sí (❌ MAL) [ ] No (✅ BIEN)

**Funcionalidad**:

- Crear rating: [ ] ✅ [ ] ❌
- Actualizar rating: [ ] ✅ [ ] ❌
- Eliminar rating: [ ] ✅ [ ] ❌

**Errores**:

- Error PostgreSQL: [ ] Sí (❌ MAL) [ ] No (✅ BIEN)
- Otros errores: **\_**

### Capturas de Pantalla

[Adjuntar screenshots del slider y ratings guardados]

### Conclusión

[ ] ✅ TODO FUNCIONA CORRECTAMENTE
[ ] ⚠️ PROBLEMAS MENORES (especificar)
[ ] ❌ FALLO CRÍTICO (reportar inmediatamente)

**Notas adicionales**:

---
```

---

## 🚀 Comandos Útiles

### Build y Run

```powershell
# Limpiar y rebuild
flutter clean
flutter pub get
flutter run -d chrome

# Build para producción
flutter build web --release
```

### Testing

```powershell
# Tests unitarios
flutter test

# Análisis estático
flutter analyze --fatal-infos

# Formatear código
dart format .
```

### Debugging

```powershell
# Ver logs detallados
flutter run -d chrome --verbose

# Desabilitar caché
flutter run -d chrome --web-browser-flag="--disable-cache"
```

---

## 📞 Siguientes Pasos

1. ✅ **Ejecutar todos los tests de este checklist**
2. ✅ **Completar el reporte de testing**
3. ✅ **Tomar capturas de pantalla del slider funcionando**
4. ✅ **Verificar en base de datos que los valores son correctos**:
   ```sql
   SELECT id, movie_id, rating
   FROM user_movie_ratings
   ORDER BY created_at DESC
   LIMIT 10;
   ```
5. ✅ **Confirmar CERO errores PostgreSQL**

---

**Estado Actual**: 🔄 Esperando Testing Manual  
**Documentación**: `docs/FIX_RATING_OVERFLOW_AND_SLIDER.md`  
**Archivos Modificados**:

- `lib/domain/entities/syncable_movie_rating.dart`
- `lib/infrastructure/repositories/hybrid_movie_ratings_repository.dart`
