# 🌐 Google Auth para Web vs Android

## Resumen Rápido

| Aspecto                       | Android               | Web                |
| ----------------------------- | --------------------- | ------------------ |
| **Necesita SHA-1**            | ✅ Sí (4 SHA-1)       | ❌ No              |
| **Necesita Client ID Web**    | ✅ Sí (para Supabase) | ✅ Sí              |
| **Necesita Redirect URLs**    | ❌ No                 | ✅ Sí              |
| **Configuración en Firebase** | ✅ Agregar SHA-1      | ✅ Agregar dominio |
| **Tiempo de propagación**     | 5-10 minutos          | Inmediato          |

---

## 🔧 Configuración para Web

### 1. Google Cloud Console - Client ID Web

Ya tienes el Client ID Web (el mismo que usas para Supabase), así que este paso está listo.

### 2. Supabase Dashboard

Ya configuraste el Google Provider en Supabase con:

- ✅ Client ID Web
- ✅ Client Secret
- ✅ Redirect URL

**Para Web, la configuración de Supabase es suficiente**. No necesitas SHA-1.

### 3. Firebase Console - Dominios Autorizados (Opcional)

Si quieres usar Firebase Authentication directamente en web (no es tu caso con Supabase):

1. Ve a https://console.firebase.google.com/
2. **Authentication** → **Settings** → **Authorized domains**
3. Agrega tus dominios:
   - `localhost` (ya está por defecto)
   - Tu dominio de producción (ej: `peliculas.mx`)
   - Tu dominio de Supabase (ya debería estar)

### 4. Google Cloud Console - URIs de Redirección

Para Web, necesitas configurar las **URIs de redirección autorizadas**:

1. Ve a https://console.cloud.google.com/apis/credentials
2. Edita tu **Client ID Web**
3. En **"URIs de redirección autorizados"**, agrega:

```
https://TU_PROYECTO.supabase.co/auth/v1/callback
http://localhost:3000/auth/callback (desarrollo local)
https://tu-dominio.com/auth/callback (producción)
```

---

## 🎯 Tu Caso Específico

### Para Android (lo que estás haciendo ahora):

```
✅ Firebase Console
   └─ Agregar 4 SHA-1
   └─ Descargar google-services.json

✅ Google Cloud Console
   └─ Obtener Client ID Web y Secret

✅ Supabase Dashboard
   └─ Configurar Google Provider
   └─ Agregar Client ID y Secret
```

### Para Web (ya está casi listo):

```
✅ Supabase Dashboard (ya configurado)
   └─ Google Provider habilitado
   └─ Client ID y Secret agregados

✅ Google Cloud Console
   └─ Agregar Redirect URL de Supabase en Client ID Web

⚠️ NO necesitas:
   ❌ SHA-1 (solo para Android)
   ❌ google-services.json (solo para Android)
```

---

## 🔍 Diferencias Clave

### Android (Apps Nativas)

**Por qué necesita SHA-1**:

- Android usa el SHA-1 para **verificar la identidad de tu app**
- Google valida que el APK fue firmado con tu keystore
- Previene que otras apps se hagan pasar por la tuya

**Flujo**:

```
Usuario → Google Sign-In nativo → Valida SHA-1 → Token → Supabase
```

### Web (Browser)

**Por qué NO necesita SHA-1**:

- Web usa **dominios y URLs** para validación
- Google valida el origen (URL) de la petición
- La seguridad se basa en HTTPS y CORS

**Flujo**:

```
Usuario → Popup de Google → Valida origen (URL) → Token → Supabase
```

---

## ⏱️ Tiempo de Propagación de SHA-1

Respondiendo a tu pregunta sobre el error en Android:

### Tiempo Normal de Propagación

Después de agregar SHA-1 en Firebase Console:

- **Mínimo**: 5 minutos
- **Normal**: 10-15 minutos
- **Máximo**: 30 minutos (raro)

### Cómo Verificar si ya se Propagó

**Opción 1: Intenta después de 10-15 minutos**

Espera ese tiempo y prueba de nuevo.

**Opción 2: Verifica en Firebase Console**

1. Ve a https://console.firebase.google.com/
2. Tu proyecto → **Configuración del proyecto**
3. Tu app Android
4. Verifica que las 4 SHA-1 estén listadas

**Opción 3: Descarga google-services.json actualizado**

Esto es **crítico**:

1. Después de agregar las SHA-1 en Firebase
2. **Descarga el google-services.json NUEVO**
3. Reemplázalo en `android/app/google-services.json`
4. Haz un clean build:
   ```powershell
   flutter clean
   flutter pub get
   flutter build apk --debug
   ```

### Errores Comunes

**Si ves estos errores, espera más tiempo o verifica configuración**:

```
❌ PlatformException(sign_in_failed)
   → SHA-1 aún no propagada O no descargaste google-services.json nuevo

❌ Error 10 (Developer Error)
   → SHA-1 incorrecta O package name no coincide

❌ Error 12500 (Sign In Cancelled)
   → SHA-1 no configurada O google-services.json desactualizado
```

---

## ✅ Checklist para Android (Tu Caso Actual)

### Antes de Probar

- [ ] Agregaste las 4 SHA-1 en Firebase Console
- [ ] Esperaste al menos 10-15 minutos
- [ ] Descargaste el **google-services.json NUEVO**
- [ ] Lo copiaste a `android/app/google-services.json`
- [ ] Ejecutaste `flutter clean`
- [ ] Ejecutaste `flutter pub get`
- [ ] Compilaste de nuevo: `flutter build apk --debug` o `flutter run`

### Si el Error Persiste

1. **Verifica el package name**:

   - `android/app/build.gradle` → `applicationId` debe ser `mx.creapolis.peliculas`
   - Firebase Console → debe coincidir exactamente

2. **Verifica las SHA-1**:

   - Copia-pega las SHA-1 de nuevo
   - Asegúrate de que no haya espacios extra

3. **Revisa los logs**:

   ```powershell
   flutter logs
   # O
   adb logcat | Select-String "GoogleSignIn"
   ```

4. **Espera más tiempo**:
   - A veces puede tomar hasta 30 minutos
   - Intenta mañana si no funciona hoy

---

## 🌐 Para Probar en Web (Más Rápido)

Si quieres probar el Google Auth más rápido, usa **Web** mientras esperas que se propaguen las SHA-1 de Android:

### Ejecutar en Web

```powershell
flutter run -d chrome
```

**Ventajas de probar en Web primero**:

- ✅ No necesita SHA-1
- ✅ Configuración más simple
- ✅ No requiere tiempo de propagación
- ✅ Mismo código de autenticación
- ✅ Mismo flujo con Supabase

### Configuración Adicional para Web (Si es necesario)

Solo necesitas agregar en `web/index.html` (probablemente ya esté):

```html
<meta
  name="google-signin-client_id"
  content="TU_CLIENT_ID_WEB.apps.googleusercontent.com"
/>
```

Pero con Supabase, el paquete `google_sign_in` maneja esto automáticamente.

---

## 🎯 Recomendación

### Para Ahora (Mientras esperas Android)

1. **Prueba en Web**:

   ```powershell
   flutter run -d chrome
   ```

   Esto te permite verificar que el Google Auth con Supabase funciona.

2. **Espera 15-20 minutos más para Android**

3. **Asegúrate de haber descargado google-services.json nuevo**

### Para Después

Una vez que funcione Android, tu configuración funcionará en:

- ✅ Android (con las 4 SHA-1)
- ✅ Web (sin necesidad de SHA-1)
- ✅ iOS (necesitará configuración adicional diferente)

---

## 📊 Resumen Visual

### Configuración Necesaria por Plataforma

```
┌─────────────────────────────────────────────────────────┐
│                     ANDROID                             │
├─────────────────────────────────────────────────────────┤
│ ✅ Firebase Console                                     │
│    └─ 4 SHA-1 agregadas                                │
│    └─ google-services.json descargado                  │
│                                                         │
│ ✅ Google Cloud Console                                 │
│    └─ Client ID Web (para Supabase)                    │
│                                                         │
│ ✅ Supabase Dashboard                                   │
│    └─ Google Provider configurado                      │
│                                                         │
│ ⏱️ Tiempo de propagación: 10-15 minutos               │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                       WEB                               │
├─────────────────────────────────────────────────────────┤
│ ✅ Google Cloud Console                                 │
│    └─ Client ID Web                                     │
│    └─ Redirect URLs configuradas                       │
│                                                         │
│ ✅ Supabase Dashboard                                   │
│    └─ Google Provider configurado                      │
│                                                         │
│ ❌ NO necesita:                                         │
│    └─ SHA-1                                             │
│    └─ google-services.json                             │
│                                                         │
│ ⏱️ Tiempo de propagación: Inmediato                   │
└─────────────────────────────────────────────────────────┘
```

---

## 💡 Consejo Final

**Para Android ahora mismo**:

1. Si ya agregaste las SHA-1 hace menos de 15 minutos: **espera más tiempo**
2. Si ya pasaron más de 30 minutos: **verifica que descargaste el google-services.json nuevo**
3. Mientras esperas: **prueba en Web** para confirmar que la configuración de Supabase está correcta

**Para Web**:

- Tu configuración actual de Supabase debería funcionar sin cambios adicionales
- Solo asegúrate de que el Redirect URL de Supabase esté agregado en Google Cloud Console → Client ID Web

---

¿Quieres que te ayude a verificar algo específico o a probar en Web mientras esperas?
