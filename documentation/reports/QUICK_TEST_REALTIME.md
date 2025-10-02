# 🚀 Quick Start - Probar Real-Time Sync

## ⚡ Prueba Rápida (5 minutos)

### 1. Abrir 2 Tabs en Chrome

**Terminal 1:**

```powershell
flutter run -d chrome --web-port 8080
```

**Terminal 2:**

```powershell
flutter run -d chrome --web-port 8081
```

### 2. Login con el MISMO Usuario

En ambos tabs (http://localhost:8080 y http://localhost:8081):

- Inicia sesión con las mismas credenciales
- Espera a que cargue completamente

### 3. Test Watched Movies (30 segundos)

**Tab 1 (8080)**:

1. Ve a "Movies" o "Popular"
2. Elige cualquier película
3. Haz clic en "Mark as Watched" o ícono de visto ✓

**Tab 2 (8081)**:

1. Ve a "Watched Movies" o sección de películas vistas
2. **Espera 1-3 segundos** (NO hagas refresh)
3. ✅ La película debe aparecer automáticamente

**Resultado Esperado**:

- ✅ Película aparece en Tab 2 sin refresh
- ✅ En consola ves: `⚡️ Realtime event received for watched_movie: PostgresChangeEvent.insert`

### 4. Test Favorites (30 segundos)

**Tab 1 (8080)**:

1. Ve a cualquier película
2. Haz clic en el ícono de favorito ❤️

**Tab 2 (8081)**:

1. Ve a "Favorites" o sección de favoritos
2. **Espera 1-3 segundos** (NO hagas refresh)
3. ✅ La película debe aparecer automáticamente

**Resultado Esperado**:

- ✅ Película aparece en Tab 2 sin refresh
- ✅ En consola ves: `⚡️ Realtime event received for favorite: PostgresChangeEvent.insert`

### 5. Test Delete (30 segundos)

**Tab 1 (8080)**:

1. En Favorites, haz clic en ❤️ de nuevo (para des-favoritar)

**Tab 2 (8081)**:

1. Mira la lista de Favorites
2. **Espera 1-3 segundos**
3. ✅ La película debe desaparecer automáticamente

**Resultado Esperado**:

- ✅ Película desaparece en Tab 2 sin refresh
- ✅ En consola ves: `⚡️ Realtime event received for favorite: PostgresChangeEvent.delete`

---

## 🔍 Verificar Logs

Abre DevTools Console en Chrome (F12) y busca:

### Al Iniciar la App

```
✅ BaseHybridRepository<watched_movie> initialized
⚡️ Realtime subscription setup for user_watched (user: abc123, channel: watched_movie-abc123)
⚡️ Realtime subscription setup for user_favorites (user: abc123, channel: favorite-abc123)
```

### Al Hacer Cambios en Tab 1

Tab 2 debe mostrar:

```
⚡️ Realtime event received for watched_movie: PostgresChangeEvent.insert
✅ Realtime INSERT processed: abc123_12345
```

---

## ❌ Si NO Funciona

### Problema: No veo eventos en Tab 2

**Verifica**:

1. ¿Estás logueado con el MISMO usuario en ambos tabs?
2. ¿Esperaste al menos 3 segundos?
3. ¿Ves errores en la consola?

**Soluciones**:

```powershell
# 1. Limpiar y reconstruir
flutter clean
flutter pub get
flutter run -d chrome

# 2. Verificar código
flutter analyze
```

### Problema: Veo errores en consola

**Errores comunes**:

1. **"Connection refused"** o **"WebSocket failed"**

   - Verifica tu conexión a internet
   - Verifica que Supabase esté accesible
   - Revisa archivo `.env` tiene las credenciales correctas

2. **"Unauthorized"** o **"RLS policy violation"**

   - Verifica que el usuario esté autenticado
   - Revisa las políticas RLS en Supabase

3. **"Channel already exists"**
   - Es normal si recargas la página
   - Los canales se limpian automáticamente

---

## 📊 Test de Rendimiento

### Latencia Esperada

| Conexión  | Tiempo de Sincronización |
| --------- | ------------------------ |
| Excelente | < 200ms                  |
| Buena     | 200-500ms                |
| Regular   | 500-1000ms               |
| Mala      | 1000-2000ms              |

### Cómo Medir

1. Tab 1: Anota la hora al hacer cambio (ej: 14:30:45.123)
2. Tab 2: Anota la hora al ver el cambio (ej: 14:30:45.456)
3. Diferencia: 456ms - 123ms = 333ms ✅ (Buena latencia)

---

## 🎯 Criterios de Éxito

Para considerar que el Real-Time Sync **FUNCIONA CORRECTAMENTE**:

- [x] ✅ Watched movies se sincronizan automáticamente
- [x] ✅ Favorites se sincronizan automáticamente
- [x] ✅ DELETE funciona (al des-favoritar)
- [x] ✅ Logs muestran eventos `⚡️ Realtime event received`
- [x] ✅ Latencia < 2 segundos
- [x] ✅ No hay errores en consola
- [x] ✅ Funciona en ambas direcciones (Tab 1→2 y Tab 2→1)

---

## 🚀 Script Automático

Si prefieres, usa el script automático que abre ambas instancias:

```powershell
.\scripts\validate_realtime_sync.ps1
```

Sigue las instrucciones en pantalla.

---

## 📚 Documentación Completa

Para más detalles técnicos:

- `docs/FIX_REALTIME_SYNC_2025_10_01.md` - Fix completo
- `docs/REALTIME_SYNC_FIX_SUMMARY.md` - Resumen ejecutivo

---

## ✅ Después del Testing

Si todo funciona:

1. Cierra ambos tabs
2. En ambos terminales: Ctrl+C para detener Flutter
3. ✅ **Real-Time Sync está funcionando correctamente!**

Si encuentras problemas:

1. Copia los logs de la consola
2. Describe qué no funcionó
3. Revisa la documentación completa en `docs/FIX_REALTIME_SYNC_2025_10_01.md`
