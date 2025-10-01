# 📊 Diagramas de Arquitectura Unificada

## 🏗️ ARQUITECTURA GENERAL

```
┌─────────────────────────────────────────────────────────────────┐
│                         UI LAYER                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Favorites  │  │    Watched   │  │  Watchlist   │          │
│  │   Widget     │  │    Widget    │  │   Widget     │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
└─────────┼──────────────────┼──────────────────┼──────────────────┘
          │                  │                  │
          │ ref.watch/read   │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    PROVIDER LAYER                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Unified     │  │  Unified     │  │  Unified     │          │
│  │  Favorites   │  │  Watched     │  │  Watchlist   │          │
│  │  Notifier    │  │  Notifier    │  │  Notifier    │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
└─────────┼──────────────────┼──────────────────┼──────────────────┘
          │                  │                  │
          │ usa              │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                     SYNC LAYER                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Unified     │  │  Unified     │  │  Unified     │          │
│  │  Favorites   │  │  Watched     │  │  Watchlist   │          │
│  │  Sync        │  │  Sync        │  │  Sync        │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                  │
│         └──────────┬───────┴──────────────────┘                 │
│                    │ extends                                     │
│                    ▼                                             │
│         ┌────────────────────────┐                              │
│         │  UnifiedSyncBase<T>    │  ← LÓGICA COMPARTIDA         │
│         │  (Abstract)            │                              │
│         └────────────────────────┘                              │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          │ comunica con
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                   DATA LAYER                                     │
│                                                                  │
│  ┌─────────────────┐              ┌─────────────────┐          │
│  │  Local Storage  │              │    Supabase     │          │
│  │  (Hive/Isar)    │◄────────────►│   PostgreSQL    │          │
│  │                 │   sync       │   + Realtime    │          │
│  └─────────────────┘              └─────────────────┘          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 FLUJO DE TOGGLE FAVORITE

```
┌──────────────┐
│ User taps ❤️ │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ 1. OPTIMISTIC UPDATE                    │
│    → UI cambia inmediatamente           │
│    → state[movieId] = favorite          │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ 2. LOCAL STORAGE                        │
│    → _localDatasource.toggleFavorite()  │
│    → Guarda en Hive/Isar               │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ 3. SUPABASE SYNC                        │
│    → _unifiedSync.addOrUpdateItem()     │
│    → UPSERT en tabla                    │
└──────┬──────────────────────────────────┘
       │
       ├─────────► SUCCESS ─────┐
       │                         │
       │                         ▼
       │              ┌────────────────────┐
       │              │ ✅ Keep Changes    │
       │              │    Log success     │
       │              └────────────────────┘
       │
       └─────────► ERROR ──────┐
                                │
                                ▼
                     ┌────────────────────┐
                     │ ⚠️ ROLLBACK        │
                     │ → Revert UI        │
                     │ → Revert local     │
                     │ → Log error        │
                     └────────────────────┘
```

---

## 🌐 FLUJO DE REAL-TIME SYNC

```
┌─────────────────┐                    ┌─────────────────┐
│   Device A      │                    │   Device B      │
│   (Phone)       │                    │   (Web)         │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         │ 1. Toggle ❤️                         │
         ▼                                      │
    ┌────────┐                                  │
    │ Local  │                                  │
    │ Update │                                  │
    └───┬────┘                                  │
        │                                       │
        │ 2. Sync to Supabase                  │
        ▼                                       │
┌────────────────────────────────────────────┐ │
│           SUPABASE                         │ │
│  ┌──────────────────────────────────────┐ │ │
│  │  user_favorites table                │ │ │
│  │  → INSERT/UPDATE row                 │ │ │
│  │  → Trigger real-time event           │ │ │
│  └──────────────────────────────────────┘ │ │
│                                            │ │
│  ┌──────────────────────────────────────┐ │ │
│  │  Realtime Server                     │ │ │
│  │  → Broadcast to all listeners        │ │ │
│  └──────────────────────────────────────┘ │ │
└────────────────────────────────────────────┘ │
                                               │
        3. Real-time event                     │
        ↓                                      │
    ┌────────┐                                 ▼
    │ Device │                            ┌─────────┐
    │   A    │◄───────────────────────────│ Device  │
    │ Update │  4. Both devices           │    B    │
    │   UI   │     show change            │ Update  │
    └────────┘                             └─────────┘
```

---

## 💾 FLUJO DE SINCRONIZACIÓN BIDIRECCIONAL

```
┌─────────────────────────────────────────────────────────────────┐
│                    SYNC BIDIRECCIONAL                            │
└─────────────────────────────────────────────────────────────────┘

INICIO: syncWithRemote() llamado

    ┌──────────────────────────────────────┐
    │ 1. FETCH DATA                        │
    │                                       │
    │  Local ◄──── loadMovies()            │
    │  [A, B, C, X, Y]                     │
    │                                       │
    │  Remote ◄──── getUserItems()         │
    │  [A, B, C, D, E]                     │
    └───────────────┬──────────────────────┘
                    │
                    ▼
    ┌──────────────────────────────────────┐
    │ 2. COMPARE & ANALYZE                 │
    │                                       │
    │  Only Local:  [X, Y]   ────►  UPLOAD │
    │  Only Remote: [D, E]   ────►  DOWNLOAD│
    │  In Both:     [A, B, C] ────►  SKIP  │
    └───────────────┬──────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
    ┌─────┐    ┌──────┐    ┌──────┐
    │ UP  │    │ DOWN │    │ SKIP │
    │ [X,Y│    │ [D,E]│    │[A,B,C│
    └──┬──┘    └───┬──┘    └──────┘
       │           │
       ▼           ▼
┌────────────────────────────────────┐
│ 3. EXECUTE SYNC                    │
│                                     │
│ ┌────────────────────────────────┐│
│ │ UPLOAD (Batch)                 ││
│ │ → batchSync([X, Y])            ││
│ │ → UPSERT to Supabase           ││
│ └────────────────────────────────┘│
│                                     │
│ ┌────────────────────────────────┐│
│ │ DOWNLOAD (Batch)               ││
│ │ → saveFavorite(D)              ││
│ │ → saveFavorite(E)              ││
│ └────────────────────────────────┘│
└────────────────────────────────────┘
                    │
                    ▼
    ┌──────────────────────────────────────┐
    │ 4. RESULT                            │
    │                                       │
    │  Local:  [A, B, C, D, E, X, Y]       │
    │  Remote: [A, B, C, D, E, X, Y]       │
    │                                       │
    │  ✅ Sincronizado                     │
    └──────────────────────────────────────┘
```

---

## 🔀 RESOLUCIÓN DE CONFLICTOS

```
┌─────────────────────────────────────────────────────────────────┐
│              UPSERT WITH FALLBACK STRATEGY                       │
└─────────────────────────────────────────────────────────────────┘

CASO 1: Insert Nuevo
    ┌──────────────┐
    │ UPSERT       │
    │ (user_id=1,  │
    │  movie_id=1) │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ NO EXISTE    │
    │ → INSERT     │
    └──────┬───────┘
           │
           ▼
       ✅ SUCCESS

CASO 2: Update Existente
    ┌──────────────┐
    │ UPSERT       │
    │ (user_id=1,  │
    │  movie_id=1) │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ YA EXISTE    │
    │ → UPDATE     │
    └──────┬───────┘
           │
           ▼
       ✅ SUCCESS

CASO 3: Conflict (Fallback)
    ┌──────────────┐
    │ UPSERT       │
    │ (Falla)      │
    └──────┬───────┘
           │
           ▼
    ┌──────────────────┐
    │ ERROR DETECTADO  │
    │ duplicate/unique │
    └──────┬───────────┘
           │
           ▼
    ┌──────────────────┐
    │ FALLBACK         │
    │ 1. DELETE old    │
    │ 2. Wait 100ms    │
    │ 3. INSERT new    │
    └──────┬───────────┘
           │
           ├──► SUCCESS ──► ✅
           │
           └──► FAIL ─────► ❌ THROW ERROR
```

---

## 📱 OFFLINE → ONLINE SYNC

```
┌─────────────────────────────────────────────────────────────────┐
│                  OFFLINE → ONLINE FLOW                           │
└─────────────────────────────────────────────────────────────────┘

TIME: T0 (Online)
    ┌────────────────────────────────┐
    │ Local:  [A, B, C]              │
    │ Remote: [A, B, C]              │
    │ ✅ Synced                      │
    └────────────────────────────────┘

    🔌 User goes OFFLINE

TIME: T1 (Offline)
    ┌────────────────────────────────┐
    │ User adds [X, Y, Z]            │
    │ → Saved to Local only          │
    │                                 │
    │ Local:  [A, B, C, X, Y, Z]     │
    │ Remote: [A, B, C]              │
    │ ⚠️  Out of sync                │
    └────────────────────────────────┘

    🔌 User goes ONLINE

TIME: T2 (Online - Auto Sync)
    ┌────────────────────────────────┐
    │ PostLoginInitialization        │
    │ → Detect online                │
    │ → Trigger syncWithRemote()     │
    └───────────┬────────────────────┘
                │
                ▼
    ┌────────────────────────────────┐
    │ Compare:                       │
    │ Local:  [A, B, C, X, Y, Z]     │
    │ Remote: [A, B, C]              │
    │                                 │
    │ To Upload: [X, Y, Z]           │
    └───────────┬────────────────────┘
                │
                ▼
    ┌────────────────────────────────┐
    │ batchSync([X, Y, Z])           │
    │ → Upload to Supabase           │
    └───────────┬────────────────────┘
                │
                ▼
    ┌────────────────────────────────┐
    │ RESULT:                        │
    │ Local:  [A, B, C, X, Y, Z]     │
    │ Remote: [A, B, C, X, Y, Z]     │
    │ ✅ Synced                      │
    └────────────────────────────────┘
```

---

## 🏗️ JERARQUÍA DE CLASES

```
┌─────────────────────────────────────────────────────────────────┐
│                    UnifiedSyncBase<T>                            │
│                      (Abstract)                                  │
│                                                                  │
│  + getUserItems(userId): Future<List<Map>>                      │
│  + addOrUpdateItem(userId, movie): Future<void>                 │
│  + removeItem(userId, movieId): Future<void>                    │
│  + itemExists(userId, movieId): Future<bool>                    │
│  + watchUserItems(userId): Stream<List<T>>                      │
│  + batchSync(userId, movies): Future<void>                      │
│  + testConnection(): Future<bool>                               │
│                                                                  │
│  # movieToSupabaseData(): Map<String, dynamic> [ABSTRACT]       │
│  # supabaseDataToEntity(): T [ABSTRACT]                         │
│  # getUniqueId(): String [ABSTRACT]                             │
└───────────────────────┬─────────────────────────────────────────┘
                        │
            ┌───────────┴───────────┬─────────────────┐
            │                       │                 │
            ▼                       ▼                 ▼
┌──────────────────────┐ ┌──────────────────┐ ┌────────────────┐
│ UnifiedFavorites     │ │ UnifiedWatched   │ │ Unified???     │
│ Sync                 │ │ Sync             │ │ Sync           │
│                      │ │                  │ │ (Future)       │
│ + addFavorite()      │ │ + markAsWatched()│ │                │
│ + removeFavorite()   │ │ + removeWatched()│ │                │
│ + toggleFavorite()   │ │ + toggleWatched()│ │                │
│ + isFavorite()       │ │ + isWatched()    │ │                │
└──────────────────────┘ └──────────────────┘ └────────────────┘
```

---

## 🎯 ESTADO DEL PROVIDER

```
┌─────────────────────────────────────────────────────────────────┐
│           UnifiedFavoritesNotifier State                         │
│                                                                  │
│  state: Map<int, SyncableFavorite>                              │
│                                                                  │
│  Example:                                                        │
│  {                                                               │
│    550: SyncableFavorite(movieId: 550, title: "Fight Club"),   │
│    680: SyncableFavorite(movieId: 680, title: "Pulp Fiction"), │
│    27205: SyncableFavorite(movieId: 27205, title: "Inception") │
│  }                                                               │
│                                                                  │
│  Benefits:                                                       │
│  ✅ O(1) lookup: isFavorite(550) → instant                      │
│  ✅ O(1) add/remove                                             │
│  ✅ Easy to convert: state.values.toList()                      │
│  ✅ Easy to filter/map                                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 COMPARACIÓN: ANTES vs AHORA

```
╔═════════════════════════════════════════════════════════════════╗
║                    ANTES (Legacy)                                ║
╠═════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  FavoritesRepository          WatchedRepository                 ║
║         │                             │                          ║
║         ├─ Custom sync logic          ├─ Custom sync logic      ║
║         ├─ Custom conflict handling   ├─ Custom conflict        ║
║         ├─ Custom real-time           ├─ Custom real-time       ║
║         └─ Custom error handling      └─ Custom error           ║
║                                                                  ║
║  ❌ Code duplication                                            ║
║  ❌ Inconsistent behavior                                       ║
║  ❌ Hard to maintain                                            ║
║  ❌ Bugs in one != fixes in other                               ║
╚═════════════════════════════════════════════════════════════════╝

                            ↓
                       MIGRACIÓN
                            ↓

╔═════════════════════════════════════════════════════════════════╗
║                    AHORA (Unified)                               ║
╠═════════════════════════════════════════════════════════════════╣
║                                                                  ║
║                   UnifiedSyncBase<T>                            ║
║                   (Shared Logic)                                ║
║                          │                                       ║
║            ┌─────────────┼─────────────┐                        ║
║            │             │             │                         ║
║     UnifiedFavorites  UnifiedWatched  Unified???               ║
║            │             │             │                         ║
║         (3 methods)   (3 methods)  (3 methods)                  ║
║                                                                  ║
║  ✅ Single source of truth                                      ║
║  ✅ Consistent behavior                                         ║
║  ✅ Easy to maintain                                            ║
║  ✅ One fix → all benefit                                       ║
╚═════════════════════════════════════════════════════════════════╝
```

---

## 📈 PERFORMANCE OPTIMIZATIONS

```
┌─────────────────────────────────────────────────────────────────┐
│                  OPTIMIZACIÓN: BATCH SYNC                        │
└─────────────────────────────────────────────────────────────────┘

SIN Batch (Lento):
    movies = [M1, M2, M3, ... M100]

    for movie in movies:
        await sync(movie)  ← 100 requests!

    ⏱️  Time: ~50 segundos
    📡  Requests: 100
    ❌  Problemas: Timeouts, rate limits

CON Batch (Rápido):
    movies = [M1, M2, M3, ... M100]

    batches = split(movies, size=50)
    for batch in batches:
        await batchSync(batch)  ← 2 requests!

    ⏱️  Time: ~5 segundos
    📡  Requests: 2
    ✅  Beneficios: Rápido, confiable
```

```
┌─────────────────────────────────────────────────────────────────┐
│              OPTIMIZACIÓN: LOCAL-FIRST LOADING                   │
└─────────────────────────────────────────────────────────────────┘

SIN Local-First (Lento):
    User opens app
      ↓
    Load from Supabase  ← 2-5 seconds
      ↓
    Show data

    ⏱️  User waits 2-5 seconds
    😞 Bad UX

CON Local-First (Rápido):
    User opens app
      ↓
    Load from Local    ← 100ms
      ↓
    Show data immediately
      ↓
    Sync in background ← transparent

    ⏱️  User sees data in 100ms
    😊 Good UX
```

---

**Este documento contiene diagramas visuales para entender mejor la arquitectura unificada.**

Para documentación detallada, ver:

- `UNIFIED_SYNC_ARCHITECTURE.md` - Arquitectura completa
- `UNIFIED_SYNC_QUICK_REFERENCE.md` - Referencia rápida
- `UNIFIED_SYNC_QUICK_START.md` - Guía de inicio
