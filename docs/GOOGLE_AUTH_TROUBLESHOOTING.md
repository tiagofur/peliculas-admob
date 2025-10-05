# 🔧 Google Auth - Troubleshooting Guide

## Error: "Instance of UserFriendlyError"

Este error indica que la autenticación está fallando pero el mensaje específico no se está mostrando correctamente. Los cambios recientes en el código ya solucionaron esto.

## Errores Comunes y Soluciones

### 1. ❌ "Autenticación de Google cancelada"

**Causa**: El usuario canceló el flujo de Google Sign-In.

**Solución**: Intenta de nuevo. Si se cancela automáticamente, verifica:

- Las huellas SHA están configuradas en Google Cloud Console
- El `google-services.json` está actualizado
- El paquete `mx.creapolis.peliculas` coincide en todos lados

### 2. ❌ "Error al obtener tokens de Google"

**Causa**: El flujo de Google Sign-In no pudo obtener los tokens de acceso.

**Soluciones**:

#### A. Verifica las huellas SHA en Firebase Console

⚠️ **IMPORTANTE**: Usa **Firebase Console** (NO Google Cloud Console). Firebase permite múltiples SHA-1 fácilmente.

**URL correcta**: https://console.firebase.google.com/

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto
3. Haz clic en el ícono **⚙️ (engranaje)** → **Configuración del proyecto**
4. Desplázate hasta encontrar tu app Android: **mx.creapolis.peliculas**
5. En la sección **"Huellas digitales de certificado SHA"**, verás las SHA-1 actuales
6. **Agrega TODAS estas huellas SHA** haciendo clic en **"+ Agregar huella digital"** para cada una:

```
Debug SHA-1 (desarrollo en VS Code):
2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:8B:9C:10

Release SHA-1 (tu keystore local):
DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:5C:D2:8B

App Signing Key SHA-1 (Play Store - firma final):
E5:2D:55:5E:7D:FA:D4:C8:2B:8A:37:FF:0D:09:52:A6:66:D7:C2:87

Upload Key SHA-1 (Play Store - carga de updates):
9D:38:BB:B0:20:F1:3B:21:97:BB:A9:32:BF:B7:EA:ED:58:99:1F:E9
```

7. **Cómo agregar múltiples SHA-1 en Firebase**:

   - Haz clic en **"+ Agregar huella digital"**
   - Pega una SHA-1
   - Firebase la valida automáticamente
   - Repite el proceso para cada SHA-1
   - Puedes agregar tantas como necesites

8. **Importante**: Debes agregar las 4 huellas para que funcione en todos los escenarios:

   - Debug: Para desarrollo local
   - Release: Para builds locales de producción
   - App Signing: Para usuarios que descarguen de Play Store
   - Upload Key: Para el proceso de carga a Play Store

9. Los cambios se guardan automáticamente
10. Espera 5-10 minutos para que se propaguen

📖 **Guía detallada con capturas visuales**: [GOOGLE_AUTH_FIREBASE_VS_CLOUD.md](./GOOGLE_AUTH_FIREBASE_VS_CLOUD.md)

#### B. Descarga el `google-services.json` actualizado

1. En Google Cloud Console, ve a **Configuración del proyecto**
2. Descarga el archivo `google-services.json` actualizado
3. Reemplázalo en `android/app/google-services.json`
4. Haz un clean build:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --debug
   ```

### 3. ❌ "Error al autenticar con Supabase"

**Causa**: Supabase no puede validar los tokens de Google.

**Soluciones**:

#### A. Configura el Provider de Google en Supabase

1. Ve a [Supabase Dashboard](https://app.supabase.com/)
2. Selecciona tu proyecto
3. Ve a **Authentication** → **Providers**
4. Encuentra **Google** y haz clic en **Enable**
5. Ingresa:
   - **Client ID (for OAuth)**: Tu Client ID Web de Google
   - **Client Secret**: Tu Client Secret de Google
   - Marca **Enabled**
6. Guarda los cambios

#### B. Copia el Redirect URL

1. En la configuración de Google en Supabase, copia el **Redirect URL**
2. Debe verse así: `https://TU_PROYECTO.supabase.co/auth/v1/callback`
3. Ve a Google Cloud Console
4. Edita tu **Client ID Web** (no el de Android)
5. En **URIs de redirección autorizados**, agrega:
   - El Redirect URL de Supabase
   - `http://localhost:3000/auth/callback` (para desarrollo)

#### C. Verifica el Client ID Web

El Client ID que usas en Supabase debe ser el **Client ID Web**, no el de Android:

1. En Google Cloud Console → **Credenciales**
2. Busca el **Client ID tipo Web**
3. Cópialo (debe terminar en `.apps.googleusercontent.com`)
4. Pégalo en Supabase Dashboard → **Authentication** → **Providers** → **Google**

### 4. ❌ "PlatformException: sign_in_failed"

**Causa**: Problema con la configuración de Google Sign-In en Android.

**Soluciones**:

#### A. Verifica el package name

1. Abre `android/app/build.gradle`
2. Verifica que `applicationId` sea: `"mx.creapolis.peliculas"`
3. Este debe coincidir con el package name en Google Cloud Console

#### B. Verifica google-services.json

1. Abre `android/app/google-services.json`
2. Busca el `package_name` en la sección `client`
3. Debe ser: `"mx.creapolis.peliculas"`
4. Si no coincide, descarga el archivo correcto de Google Cloud Console

### 5. ❌ "Network error" o timeout

**Causa**: Problema de conectividad.

**Soluciones**:

1. Verifica tu conexión a internet
2. Intenta con WiFi si estás en datos móviles (o viceversa)
3. Verifica que el firewall no esté bloqueando:
   - `accounts.google.com`
   - `*.supabase.co`
4. Intenta más tarde si Google o Supabase están experimentando problemas

### 6. ❌ "Invalid OAuth client"

**Causa**: El Client ID o Client Secret son incorrectos.

**Soluciones**:

1. Ve a Google Cloud Console → **Credenciales**
2. Edita tu **Client ID Web**
3. Copia el **Client ID** y **Client Secret**
4. Ve a Supabase Dashboard → **Authentication** → **Providers** → **Google**
5. Pega el **Client ID** y **Client Secret**
6. Asegúrate de que no haya espacios al inicio o al final
7. Guarda y espera 1-2 minutos

## Verificación Paso a Paso

Si nada funciona, sigue esta checklist completa:

### ✅ Checklist Google Cloud Console

- [ ] Proyecto creado o seleccionado
- [ ] OAuth consent screen configurado
- [ ] Client ID de Android creado
- [ ] SHA-1 Debug agregada: `2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:8B:9C:10`
- [ ] SHA-1 Release agregada: `DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:5C:D2:8B`
- [ ] SHA-1 App Signing (Play Store) agregada: `E5:2D:55:5E:7D:FA:D4:C8:2B:8A:37:FF:0D:09:52:A6:66:D7:C2:87`
- [ ] SHA-1 Upload Key (Play Store) agregada: `9D:38:BB:B0:20:F1:3B:21:97:BB:A9:32:BF:B7:EA:ED:58:99:1F:E9`
- [ ] Package name: `mx.creapolis.peliculas`
- [ ] Client ID Web creado
- [ ] Redirect URL de Supabase agregado en Client ID Web
- [ ] `google-services.json` descargado

### ✅ Checklist Android

- [ ] `google-services.json` en `android/app/`
- [ ] `applicationId` en `build.gradle`: `"mx.creapolis.peliculas"`
- [ ] Google Services plugin habilitado en `build.gradle`
- [ ] Compilación exitosa (`flutter build apk --debug`)

### ✅ Checklist Supabase

- [ ] Proyecto creado
- [ ] Provider de Google habilitado
- [ ] Client ID Web agregado
- [ ] Client Secret agregado
- [ ] Redirect URL copiado y agregado en Google Cloud Console
- [ ] Cambios guardados

### ✅ Checklist Código

- [ ] Dependencia `google_sign_in: ^6.2.2` en `pubspec.yaml`
- [ ] `flutter pub get` ejecutado
- [ ] Archivos de código actualizados (ya están listos)
- [ ] App reiniciada después de cambios

## Testing

### Prueba en Debug

```bash
# Limpiar proyecto
flutter clean
flutter pub get

# Compilar y ejecutar en debug
flutter run
```

### Prueba en Release

```bash
# Compilar en release
flutter build apk --release

# Instalar manualmente
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Logs para Debugging

Para ver logs detallados cuando falla:

```bash
# Android logs
adb logcat | grep -E "GoogleSignIn|Supabase|Auth"

# Flutter logs
flutter logs
```

Busca líneas que contengan:

- `❌ Error de autenticación de Google:`
- `❌ Error inesperado en autenticación de Google:`
- `PlatformException`
- `sign_in_failed`

## Tiempos de Propagación

Después de hacer cambios en Google Cloud Console o Supabase:

- **SHA fingerprints**: 5-10 minutos
- **Redirect URLs**: 1-2 minutos
- **Client ID/Secret**: Inmediato
- **google-services.json**: Requiere rebuild de la app

⚠️ **Importante**: Después de cambios en Google Cloud, espera al menos 10 minutos antes de probar.

## Soporte Adicional

Si ninguna solución funciona:

1. **Revisa la documentación oficial**:

   - [Google Sign-In Flutter Plugin](https://pub.dev/packages/google_sign_in)
   - [Supabase Auth](https://supabase.com/docs/guides/auth)

2. **Verifica el estado de los servicios**:

   - [Google Cloud Status](https://status.cloud.google.com/)
   - [Supabase Status](https://status.supabase.com/)

3. **Busca ayuda**:
   - [Supabase Discord](https://discord.supabase.com/)
   - [Stack Overflow](https://stackoverflow.com/questions/tagged/google-signin)

## Siguiente Paso

Una vez que resuelvas el problema, actualiza `GOOGLE_AUTH_CHECKLIST.md` marcando los pasos completados.
