# CLAUDE.md

Monorepo de Películas. Cada carpeta es un proyecto independiente; trabaja dentro de la que toque.

- `native-android/` — Kotlin + Compose. Desde ahí: `./gradlew :app:testDebugUnitTest`, `:app:assembleDebug`,
  `:app:bundleRelease`. Con el JDK de Android Studio: `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`.
  Paquete de Play: `mx.creapolis.peliculas` (debug: `.debug`). Paridad con iOS en `docs/android/PARITY.md`.
- `native-ios/` — SwiftUI, proyecto generado con XcodeGen (`project.yml`). Ver `native-ios/README.md`.
- `backend/` — Go. `go test ./...` desde `backend/`. Deploy en el VPS Plesk (`backend/deploy/plesk`).
- `flutter/` — app Flutter legada (Supabase); su guía propia está en `flutter/CLAUDE.md`.

Las dos apps nativas hablan el mismo protocolo `/v1/sync` del backend: un cambio de modelo
de sync se hace en ambas a la vez.

Nunca subas secretos: `.env`, `*.jks`, `keystore.properties` y `key.properties` están ignorados.
