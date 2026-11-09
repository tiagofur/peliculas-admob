# Películas

Seguimiento de películas y series: descubrir, guardar, marcar episodios y saber dónde verlas.
Monorepo con las apps nativas, el backend y la app Flutter original.

| Carpeta | Qué es | Estado |
|---|---|---|
| [`native-ios/`](native-ios/README.md) | App iOS nativa (SwiftUI, Liquid Glass) | En App Store |
| [`native-android/`](native-android) | App Android nativa (Kotlin, Compose, Material 3 Expressive) | Reemplaza a la Flutter en Play (`mx.creapolis.peliculas`) |
| [`backend/`](backend/README.md) | API Go + Postgres: auth, sync de biblioteca, proxy TMDB, compras, push | Producción en `api-peliculas.creapolis.dev` |
| [`flutter/`](flutter/README.md) | App Flutter original (Supabase) y la web | Legado |
| [`docs/`](docs/README.md) | Planes, auditorías y guías (`docs/android`, `docs/ios`) | — |

Producto: [`PRODUCT.md`](PRODUCT.md) · Paridad Android ↔ iOS: [`docs/android/PARITY.md`](docs/android/PARITY.md)

## Secretos

Nada secreto va al repo. `.env` de la raíz (ignorado) alimenta `native-ios/scripts/sync-env.sh`;
la firma Android vive en `native-android/keystore.properties` (ignorado, ver `.example`).
