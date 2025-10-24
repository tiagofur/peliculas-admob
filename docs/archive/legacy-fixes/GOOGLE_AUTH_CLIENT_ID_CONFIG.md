# 🔑 Configurar Google Client ID Web en .env

## ⚠️ Error Común

```
"ClientID not set. Either set it on a <meta name="google-signin-client_id" content="CLIENT_ID" /> tag,
or pass clientId when initializing GoogleSignIn"
```

Este error significa que falta configurar el **Google Client ID Web** en tu archivo `.env`.

---

## ✅ Solución Rápida

### Paso 1: Obtener el Client ID Web

1. Ve a [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Selecciona tu proyecto
3. En la sección **"IDs de cliente de OAuth 2.0"**
4. Busca el **Client ID de tipo "Aplicación web"** (Web application)
5. Haz clic para ver los detalles
6. **Copia el "ID de cliente"** (termina en `.apps.googleusercontent.com`)

Ejemplo:

```
123456789012-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com
```

### Paso 2: Agregar al archivo .env

1. Abre el archivo `.env` en la raíz de tu proyecto
2. Si no existe, copia `.env.example` y renómbralo a `.env`
3. Agrega o actualiza esta línea:

```bash
GOOGLE_CLIENT_ID_WEB=TU_CLIENT_ID_AQUI.apps.googleusercontent.com
```

Ejemplo completo del archivo `.env`:

```bash
# Supabase Configuration
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu_anon_key_aqui

# Google OAuth Configuration
GOOGLE_CLIENT_ID_WEB=123456789012-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com

# Movie APIs (Pre-configured)
THE_MOVIEDB_KEY=pre_configured_key
TRAKT_CLIENT_ID=pre_configured_id
TRAKT_CLIENT_SECRET=pre_configured_secret
```

### Paso 3: Reiniciar la App

```powershell
# Detén la app si está corriendo (Ctrl+C)
# Luego ejecuta:
flutter run
```

---

## 🎯 ¿Qué es el Client ID Web?

### Diferencia entre Client IDs

Tu proyecto de Google tiene **3 tipos de Client IDs**:

| Tipo        | Uso                   | Dónde se configura           |
| ----------- | --------------------- | ---------------------------- |
| **Android** | App Android nativa    | Firebase Console (con SHA-1) |
| **Web**     | Navegadores + Backend | Google Cloud Console         |
| **iOS**     | App iOS nativa        | Google Cloud Console + Xcode |

**Para tu app con Supabase, necesitas el Client ID WEB** porque:

- ✅ Supabase valida tokens OAuth usando el Client ID Web
- ✅ Funciona tanto en Android como en Web
- ✅ Es el que configuraste en Supabase Dashboard

### ¿Por qué no el Client ID de Android?

El Client ID de Android se usa para:

- Validar que el APK fue firmado correctamente (con SHA-1)
- Iniciar el flujo de Google Sign-In nativo

Pero **Supabase necesita el Client ID Web** para validar los tokens OAuth.

---

## 🔍 Cómo Encontrar el Client ID Web

### Opción 1: Google Cloud Console

1. https://console.cloud.google.com/apis/credentials
2. Busca en la lista de **"IDs de cliente de OAuth 2.0"**
3. El tipo debe ser **"Aplicación web"** o **"Web application"**
4. Cópialo (termina en `.apps.googleusercontent.com`)

### Opción 2: Desde Supabase Dashboard

1. Ve a tu proyecto en https://app.supabase.com/
2. **Authentication** → **Providers** → **Google**
3. El **Client ID (for OAuth)** que configuraste ES el Client ID Web
4. Cópialo de ahí

### Opción 3: Desde android/app/google-services.json

Abre `android/app/google-services.json` y busca:

```json
{
  "oauth_client": [
    {
      "client_id": "123456...apps.googleusercontent.com",
      "client_type": 3  ← Este es tipo 3 = Web
    }
  ]
}
```

El que tiene `"client_type": 3` es el Client ID Web.

---

## 📝 Formato del Client ID Web

El Client ID Web tiene este formato:

```
[NÚMEROS]-[LETRAS_Y_NÚMEROS].apps.googleusercontent.com
```

Ejemplos válidos:

```
123456789012-abcdefghijklmnopqrstuvwxyz123456.apps.googleusercontent.com
987654321098-a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6.apps.googleusercontent.com
```

❌ **NO es válido**:

```
123456789012-abcd...android.com  ← Este es Android, no Web
com.google.android.gms           ← Esto es un package name
```

---

## 🐛 Troubleshooting

### Error: "ClientID not set"

**Causa**: No configuraste `GOOGLE_CLIENT_ID_WEB` en `.env`

**Solución**:

1. Verifica que el archivo `.env` existe en la raíz del proyecto
2. Verifica que tiene la línea `GOOGLE_CLIENT_ID_WEB=...`
3. Reinicia la app

### Error: "Invalid client ID"

**Causa**: El Client ID está incorrecto o mal copiado

**Solución**:

1. Verifica que copiaste el Client ID **Web** (no el de Android)
2. Asegúrate de que no haya espacios al inicio o al final
3. Debe terminar en `.apps.googleusercontent.com`

### Error: "Configuration not found"

**Causa**: El archivo `.env` no está en la ubicación correcta

**Solución**:

1. El archivo `.env` debe estar en la **raíz del proyecto**
2. No en `lib/`, no en `android/`, sino en la raíz
3. Al mismo nivel que `pubspec.yaml`

```
peliculas-admob/
├── .env              ← AQUÍ
├── .env.example
├── pubspec.yaml
├── android/
├── lib/
└── ...
```

### La app no lee el archivo .env

**Causa**: No reiniciaste la app después de modificar `.env`

**Solución**:

1. Detén la app completamente (Ctrl+C)
2. Ejecuta `flutter run` de nuevo
3. Los cambios en `.env` requieren reinicio

---

## ✅ Verificación

Después de configurar correctamente, verás en los logs:

```
🔑 Validating API configuration...
✅ Google Client ID: 123456789012-abc...
```

Si no lo ves, significa que falta configurar.

---

## 📚 Documentación Relacionada

- [GOOGLE_AUTH_CHECKLIST.md](./GOOGLE_AUTH_CHECKLIST.md) - Paso 3: Obtener Client ID Web
- [GOOGLE_AUTH_SUPABASE.md](./GOOGLE_AUTH_SUPABASE.md) - Configuración completa
- [GOOGLE_AUTH_TROUBLESHOOTING.md](./GOOGLE_AUTH_TROUBLESHOOTING.md) - Más soluciones

---

## 🎯 Resumen Ejecutivo

1. **Obtén el Client ID Web** de Google Cloud Console
2. **Agrégalo al .env**: `GOOGLE_CLIENT_ID_WEB=tu_client_id.apps.googleusercontent.com`
3. **Reinicia la app**: `flutter run`
4. **Prueba el login** con Google

**El Client ID Web debe ser el MISMO que configuraste en Supabase Dashboard**.

---

**Última actualización**: Octubre 4, 2025
