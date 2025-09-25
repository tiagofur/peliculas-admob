# 6. Despliegue y Publicación

## 6.1 Web (SPA)

1. Generar build web:

```powershell
flutter build web --release
```

2. Servir con un servidor estático (NGINX, Firebase Hosting, etc.)
3. Configurar CORS y rutas `/index.html` para SPA.

## 6.2 Android (Play Store)

1. Generar APK:

```powershell
flutter build apk --release
```

2. Firmar con keystore:

```powershell
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 \
    -keystore <keystore_path> build/app/outputs/flutter-apk/app-release.apk <alias>
```

3. Optimizar con `zipalign` y `apksigner`:

```powershell
& "${env:ANDROID_HOME}\build-tools\<version>\zipalign.exe" -v 4 app-release.apk app-release-aligned.apk;
& "${env:ANDROID_HOME}\build-tools\<version>\apksigner.exe" sign --ks <keystore_path> app-release-aligned.apk
```

4. Publicar APK/Bundle en Play Console.

## 6.3 iOS (App Store)

- Abrir `ios/Runner.xcworkspace` en Xcode.
- Configurar Signing & Capabilities.
- Product → Archive → Upload to App Store.
