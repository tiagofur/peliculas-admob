# Guía de Pruebas - Detalles de Película y Valoraciones

## 🎯 Resumen de Cambios

Se han corregido dos problemas principales en la pantalla de detalles de películas:

1. **✅ Detalles Técnicos Incompletos** - Ahora se muestran todos los datos disponibles
2. **✅ Sistema de Valoración** - Mejorado manejo de errores y feedback visual

## 🧪 Cómo Probar los Cambios

### Preparación del Entorno

```powershell
# 1. Asegúrate de estar en el directorio del proyecto
cd c:\Users\tfurt\source\repos\peliculas-admob-clean

# 2. Obtener dependencias
flutter pub get

# 3. Ejecutar en web (desarrollo)
flutter run -d chrome
```

### 📋 Test 1: Detalles Técnicos

#### Películas para Probar:

**Película con todos los datos** (Hollywood Blockbuster):

```
URL: http://localhost:56411/movie/505642
Título: Black Panther: Wakanda Forever
Debe mostrar: Runtime, Budget, Revenue, Vote Average, Vote Count, Popularity, IMDb ID
```

**Película sin Budget/Revenue** (Indie/Internacional):

```
URL: http://localhost:56411/movie/1267319
Título: [Verificar en la app]
Debe mostrar: Runtime, Vote Average, Vote Count, Popularity (sin Budget/Revenue)
```

#### Verificación Visual:

La sección "Detalles Técnicos" debe mostrar un grid con:

```
┌─────────────────────────────────────┐
│ 🎬 Detalles Técnicos                │
├─────────────────────────────────────┤
│  ⏰ Duración        📋 Estado        │
│  120 min            Released         │
├─────────────────────────────────────┤
│  ⭐ Calificación    🗳️ Votos         │
│  7.5/10             12.3K            │
├─────────────────────────────────────┤
│  📈 Popularidad     🎬 IMDb ID       │
│  123.4              tt1234567        │
├─────────────────────────────────────┤
│  💰 Presupuesto     💵 Ingresos      │  (solo si disponible)
│  $50M               $200M            │
└─────────────────────────────────────┘
```

#### Logs Esperados en Consola:

```
🎬 DEBUG - Detalles técnicos de la película: [Título]
  💰 Budget: 50000000
  💵 Revenue: 200000000
  ⏰ Runtime: 120
  🌟 Popularity: 123.456
  🎭 IMDb ID: tt1234567
  📊 Vote Average: 7.5
  🗳️ Vote Count: 1234
```

### 📋 Test 2: Sistema de Valoración

#### Escenario 1: Primera Valoración

1. **Navegar** a cualquier película sin valoración previa
2. **Verificar** que aparece la tarjeta "Your Rating" con:

   - Icono de estrella vacía
   - Mensaje "Rate this Movie"
   - Botones "Quick Rate" y "Rate and Review"

3. **Hacer clic** en "Rate and Review"
4. **Verificar** el diálogo muestra:

   - Título de la película
   - Sistema de 5 estrellas interactivo
   - Slider con valor 0.5-5.0
   - Campo de texto para review (opcional)
   - Checkbox "Make this rating public"
   - Botones "Cancel" y "Save"

5. **Seleccionar** una calificación (ej: 4.5 estrellas)
6. **Escribir** una review (opcional)
7. **Hacer clic** en "Save"
8. **Verificar** mensaje de éxito: "Movie rated successfully!"

#### Escenario 2: Editar Valoración Existente

1. **Recargar** la página de la película
2. **Verificar** que aparece la valoración guardada con:

   - Estrellas llenas mostrando la calificación
   - Fecha "Rated on [date]"
   - Review (si se escribió)
   - Badge "Public" (si se marcó como pública)
   - Botón "Edit Rating"
   - Icono de eliminar (🗑️)

3. **Hacer clic** en "Edit Rating"
4. **Cambiar** la calificación o review
5. **Guardar** cambios
6. **Verificar** mensaje: "Rating updated successfully!"

#### Escenario 3: Eliminar Valoración

1. **En la tarjeta** de valoración existente
2. **Hacer clic** en el icono de eliminar (🗑️)
3. **Verificar** diálogo de confirmación
4. **Confirmar** eliminación
5. **Verificar** mensaje: "Rating deleted successfully!"
6. **Verificar** que vuelve al estado inicial (sin valoración)

#### Escenario 4: Manejo de Errores

**Simular error de red**:

1. Desconectar WiFi o deshabilitar red
2. Intentar cargar página de película
3. **Verificar** mensaje de error con:
   - Icono de error (⚠️)
   - Mensaje descriptivo
   - Botón de retry (🔄)
4. Reconectar red
5. Hacer clic en retry
6. **Verificar** que carga correctamente

#### Logs Esperados en Consola:

```
# Al cargar
📊 Watching rating for movie: 1267319
✅ MovieRatingsProvider initialized

# Al calificar
⭐ Successfully rated movie: 1267319

# Al actualizar
📝 Successfully updated rating: 1267319

# Al eliminar
🗑️ Successfully removed rating: 1267319

# En caso de error
❌ Error loading rating: [descripción del error]
```

### 📋 Test 3: Sincronización y Persistencia

#### Test de Persistencia:

1. **Calificar** una película
2. **Cerrar** la aplicación completamente
3. **Reabrir** la aplicación
4. **Navegar** a la película calificada
5. **Verificar** que la calificación persiste

#### Test de Sincronización (si aplica):

1. **Calificar** una película en dispositivo A
2. **Abrir** la misma película en dispositivo B (misma cuenta)
3. **Verificar** que la calificación se sincroniza
4. **Editar** en dispositivo B
5. **Refrescar** en dispositivo A
6. **Verificar** que muestra la versión actualizada

### 📋 Test 4: Estados de UI

#### Loading State:

```
┌─────────────────────────────────────┐
│ ⭐ Your Rating                      │
├─────────────────────────────────────┤
│                                     │
│        🔄 Loading...                │
│                                     │
└─────────────────────────────────────┘
```

#### Error State:

```
┌─────────────────────────────────────┐
│ ⭐ Your Rating                      │
├─────────────────────────────────────┤
│ ⚠️ Error loading rating.            │
│    Tap to retry.              [🔄]  │
└─────────────────────────────────────┘
```

#### Empty State (sin valoración):

```
┌─────────────────────────────────────┐
│ ⭐ Your Rating                      │
├─────────────────────────────────────┤
│        ☆                            │
│   Rate this Movie                   │
│   Share your opinion                │
│                                     │
│ [⭐ Quick Rate] [✍️ Rate & Review]  │
└─────────────────────────────────────┘
```

#### Success State (con valoración):

```
┌─────────────────────────────────────┐
│ ⭐ Your Rating                      │
├─────────────────────────────────────┤
│ ⭐⭐⭐⭐☆ 4.5/5  Rated on 2 days ago │
│                                     │
│ ✍️ Your Review                      │
│ "Excellent movie! The visual..."    │
│                                     │
│ 🌐 Public                           │
│                                     │
│ [✏️ Edit Rating]            [🗑️]    │
└─────────────────────────────────────┘
```

## 🐛 Troubleshooting

### Problema: Los detalles técnicos no se muestran

**Solución**:

1. Abrir DevTools del navegador (F12)
2. Ver la pestaña Console
3. Buscar los logs de debug: `🎬 DEBUG - Detalles técnicos`
4. Verificar qué campos tienen valores `null` o `0`
5. Si todos son `null`, verificar que el API devuelve los datos:
   ```bash
   # En PowerShell
   curl "https://api.themoviedb.org/3/movie/1267319?api_key=YOUR_KEY"
   ```

### Problema: La valoración no se guarda

**Checklist**:

- [ ] ¿Hay un usuario autenticado? (verificar en esquina superior derecha)
- [ ] ¿La consola muestra errores? (buscar `❌` en logs)
- [ ] ¿Supabase está configurado correctamente? (verificar `.env`)
- [ ] ¿La tabla `user_movie_ratings` existe en Supabase?

**Logs a verificar**:

```
✅ MovieRatingsProvider initialized   ← Debe aparecer
⭐ Successfully rated movie: [id]     ← Debe aparecer al guardar
```

### Problema: "Error loading rating" persistente

**Soluciones**:

1. **Verificar autenticación**:

   ```dart
   // En la consola de debug, buscar:
   User ID: [uuid]
   ```

2. **Limpiar caché del provider**:

   - Hacer clic en el botón de retry (🔄)
   - O recargar la página completa (F5)

3. **Verificar conexión a Supabase**:
   ```powershell
   # En PowerShell, verificar variables de entorno
   Get-Content .env | Select-String "SUPABASE"
   ```

### Problema: Los datos de TMDB están incompletos

**Es normal** que algunas películas no tengan todos los datos:

- Budget/Revenue: ~30% de películas lo tienen
- Runtime: ~95% lo tienen
- IMDb ID: ~90% lo tienen

**Películas para probar con datos completos**:

- Avengers: Endgame (movie/299534)
- The Dark Knight (movie/155)
- Inception (movie/27205)
- Black Panther (movie/284054)

## 📊 Métricas de Éxito

Los cambios son exitosos si:

- [x] **Detalles Técnicos**: Al menos 4-5 campos se muestran para la mayoría de películas
- [x] **Valoración**: El flujo completo (crear/editar/eliminar) funciona sin errores
- [x] **UI/UX**: Los estados loading/error/success son claros y útiles
- [x] **Logs**: Los mensajes de debug ayudan a diagnosticar problemas
- [x] **Persistencia**: Las valoraciones se mantienen después de recargar

## 🔗 Referencias

- **Documentación completa**: `docs/FIX_MOVIE_DETAILS_AND_RATINGS.md`
- **Archivos modificados**:
  - `lib/presentation/widgets/movies/enhanced_movie_info.dart`
  - `lib/presentation/widgets/movies/movie_rating_and_notes.dart`
- **Provider de ratings**: `lib/presentation/providers/movie_ratings_provider.dart`
- **Repository**: `lib/infrastructure/repositories/hybrid_movie_ratings_repository.dart`

## ✅ Checklist Final

Antes de considerar completo:

- [ ] Probado en al menos 3 películas diferentes
- [ ] Flujo completo de valoración funciona
- [ ] Los detalles técnicos se muestran correctamente
- [ ] Los logs de debug son útiles y no invasivos
- [ ] No hay errores en la consola de Flutter
- [ ] La UI es responsiva en diferentes tamaños de pantalla
- [ ] Los mensajes de error son descriptivos
- [ ] El botón de retry funciona cuando hay errores

---

**Última actualización**: 30 de Septiembre, 2025  
**Status**: ✅ Mejoras implementadas y listas para testing
