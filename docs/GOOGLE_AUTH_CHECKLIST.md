# ✅ Checklist - Configuración de Google Auth con SUPABASE

> **IMPORTANTE**: Esta app usa Supabase como backend, no solo Firebase.
> Por lo tanto, necesitas configurar 3 servicios: Google Cloud, Supabase Dashboard y descargar google-services.json

## Pasos que debes completar AHORA (Manual)

### 1. Firebase Console - Configurar Huellas SHA

⚠️ **USA FIREBASE CONSOLE** (permite múltiples SHA-1 fácilmente)

- [ ] Ir a https://console.firebase.google.com/
- [ ] Seleccionar tu proyecto
- [ ] Hacer clic en **⚙️ (engranaje)** → **Configuración del proyecto**
- [ ] Desplazarse hasta encontrar tu app: `mx.creapolis.peliculas`

**⚠️ IMPORTANTE: Debes agregar las 4 SHA-1 para que funcione en todos los escenarios**

**1. Agregar huella de DEBUG:**

```
SHA-1: 2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:8B:9C:10
```

- [ ] Hacer clic en **"+ Agregar huella digital"**
- [ ] Pegar la SHA-1 (Firebase la valida automáticamente)

**2. Agregar huella de RELEASE:**

```
SHA-1: DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:5C:D2:8B
```

- [ ] Hacer clic en **"+ Agregar huella digital"**
- [ ] Pegar la SHA-1

**3. Agregar huella de APP SIGNING KEY (Play Store):**

```
SHA-1: E5:2D:55:5E:7D:FA:D4:C8:2B:8A:37:FF:0D:09:52:A6:66:D7:C2:87
```

- [ ] Hacer clic en **"+ Agregar huella digital"**
- [ ] Pegar la SHA-1

**4. Agregar huella de UPLOAD KEY (Play Store):**

```
SHA-1: 9D:38:BB:B0:20:F1:3B:21:97:BB:A9:32:BF:B7:EA:ED:58:99:1F:E9
```

- [ ] Hacer clic en **"+ Agregar huella digital"**
- [ ] Pegar la SHA-1

📖 **¿Por qué 4 SHA-1?** Ver [GOOGLE_AUTH_PLAY_STORE_SHA.md](./GOOGLE_AUTH_PLAY_STORE_SHA.md)

### 2. Firebase Console - Descargar google-services.json

- [ ] En la misma página de **Configuración del proyecto**
- [ ] Buscar tu app Android: `mx.creapolis.peliculas`
- [ ] Hacer clic en el botón **"google-services.json"** para descargarlo
- [ ] Reemplazar el archivo en:
  ```
  android/app/google-services.json
  ```

### 3. Google Cloud Console - Obtener Client ID Web

- [ ] Ir a https://console.cloud.google.com/
- [ ] Seleccionar tu proyecto (el mismo de Firebase)
- [ ] Ir a **APIs y servicios** → **Credenciales**
- [ ] Buscar el **"Client ID de OAuth 2.0"** de tipo **Web application**
- [ ] Si no existe, crear uno:
  - [ ] Hacer clic en **"Crear credenciales"** → **"ID de cliente de OAuth 2.0"**
  - [ ] Tipo: **Aplicación web**
  - [ ] Nombre: "Web client (auto created by Google Service)"
  - [ ] Guardar
- [ ] **Copiar el Client ID** (termina en `.apps.googleusercontent.com`)
- [ ] **Copiar el Client Secret**

### 4. Supabase Dashboard - Configurar Google Provider

**CRÍTICO**: Este es el paso más importante para Supabase

- [ ] Ir a https://supabase.com/dashboard
- [ ] Seleccionar tu proyecto
- [ ] Ir a **Authentication** → **Providers**
- [ ] Buscar **Google** en la lista
- [ ] Hacer clic en **Google** para expandir
- [ ] Activar el toggle (Habilitar)
- [ ] Pegar el **Client ID (Web)** de Google Cloud
- [ ] Pegar el **Client Secret** de Google Cloud
- [ ] (Opcional) En **"Authorized Client IDs"**, agregar:
  - Client ID Web
  - Client ID Android (si lo tienes)
- [ ] Hacer clic en **Save**
- [ ] **Copiar la Redirect URL** que muestra (formato: `https://xxxxx.supabase.co/auth/v1/callback`)

### 5. Google Cloud Console - Agregar Redirect URL de Supabase

- [ ] Volver a Google Cloud Console → Credenciales
- [ ] Hacer clic en tu **Client ID Web**
- [ ] En **"URIs de redirección autorizados"**, hacer clic en **"+ Agregar URI"**
- [ ] Pegar la URL de Supabase: `https://TU_PROYECTO.supabase.co/auth/v1/callback`
- [ ] Hacer clic en **Guardar**

### 6. Verificar y Probar

- [ ] Ejecutar en terminal:

  ```powershell
  flutter clean
  flutter pub get
  ```

- [ ] Probar la app:

  ```powershell
  flutter run
  ```

- [ ] Verificar que aparezca el botón "Continuar con Google"
- [ ] Probar el login con Google
- [ ] Verificar en **Supabase Dashboard** → **Authentication** → **Users** que se creó el usuario
- [ ] Verificar que te redirija al Home después del login

## 🎯 Resultado Esperado

Después de completar todos los checkboxes:

1. ✅ El botón de Google aparece en Login y Registro
2. ✅ Al hacer clic, se abre el selector de cuenta de Google
3. ✅ Después de seleccionar una cuenta, se autentica
4. ✅ Te redirige automáticamente al Home
5. ✅ Tu sesión se guarda y persiste

## ❌ Si algo falla

Consulta la sección **Troubleshooting** en:

- `docs/GOOGLE_AUTH_SUMMARY.md`
- `docs/GOOGLE_AUTH_SETUP.md`

## 📞 Información de las Huellas SHA

Las huellas SHA fueron extraídas de:

- **Debug**: `%USERPROFILE%\.android\debug.keystore`
- **Release**: `C:\src\peliculas_new.jks`

Si necesitas volver a obtenerlas:

```powershell
# Debug
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android

# Release
keytool -list -v -keystore C:\src\peliculas_new.jks -alias peliculas -storepass davidi
```
