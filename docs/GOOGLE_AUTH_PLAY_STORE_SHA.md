# 🔐 Google Auth - SHA Fingerprints de Play Store

## 📋 Todas tus SHA-1 Fingerprints

Tu proyecto tiene **4 SHA-1 diferentes** que deben configurarse en Google Cloud Console:

### 1. Debug Keystore (Desarrollo Local)

```
SHA-1: 2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:8B:9C:10
```

**Uso**: Cuando ejecutas `flutter run` o `flutter build apk --debug`  
**Ubicación**: `%USERPROFILE%\.android\debug.keystore`

---

### 2. Release Keystore (Build Local de Producción)

```
SHA-1: DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:5C:D2:8B
```

**Uso**: Cuando ejecutas `flutter build apk --release` localmente  
**Ubicación**: `C:\src\peliculas_new.jks`  
**Password**: davidi

---

### 3. App Signing Key (Play Store - Firma Final)

```
SHA-1: E5:2D:55:5E:7D:FA:D4:C8:2B:8A:37:FF:0D:09:52:A6:66:D7:C2:87
```

**Uso**: Apps descargadas directamente de Google Play Store  
**Gestión**: Google Play Store (no tienes acceso a esta clave privada)  
**Descripción**: Google usa esta clave para firmar todas las versiones antes de distribuirlas

---

### 4. Upload Key (Play Store - Carga de Actualizaciones)

```
SHA-1: 9D:38:BB:B0:20:F1:3B:21:97:BB:A9:32:BF:B7:EA:ED:58:99:1F:E9
```

**Uso**: Para cargar nuevas versiones a Play Console  
**Gestión**: Tú (es tu clave de carga privada)  
**Descripción**: Usas esta clave para firmar los APK/AAB que subes a Play Console, luego Google re-firma con la App Signing Key

---

## 🎯 ¿Por qué tantas SHA-1?

### Flujo Normal de Play Store

```
1. DESARROLLO
   └─ Usas: Debug Keystore
   └─ SHA-1: 2C:9F:A2:... (debug)

2. BUILD LOCAL RELEASE
   └─ Usas: Release Keystore (peliculas_new.jks)
   └─ SHA-1: DF:D4:2D:... (release local)

3. SUBIR A PLAY CONSOLE
   └─ Firmas con: Upload Key
   └─ SHA-1: 9D:38:BB:... (upload)

4. DISTRIBUCIÓN EN PLAY STORE
   └─ Google firma con: App Signing Key
   └─ SHA-1: E5:2D:55:... (play store)
```

### ¿Cuándo se usa cada una?

| Escenario                      | SHA-1 Utilizada | Dónde Configurar     |
| ------------------------------ | --------------- | -------------------- |
| Desarrollo local (debug)       | `2C:9F:A2:...`  | Google Cloud Console |
| Build local (release)          | `DF:D4:2D:...`  | Google Cloud Console |
| Subir a Play Console           | `9D:38:BB:...`  | Google Cloud Console |
| Usuario descarga de Play Store | `E5:2D:55:...`  | Google Cloud Console |

**¡Todas deben estar configuradas en Google Cloud Console!**

---

## ✅ Cómo Configurar en Google Cloud Console

### Paso 1: Ir a Credenciales

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Selecciona tu proyecto
3. Menú lateral → **APIs y servicios** → **Credenciales**

### Paso 2: Editar Client ID de Android

1. Busca tu **Client ID de Android** (tipo: Android)
2. Haz clic en el icono de editar (lápiz) ✏️

### Paso 3: Agregar las 4 SHA-1

En la sección **Huellas digitales SHA-1**:

1. Haz clic en **"+ Agregar huella digital"**
2. Pega la primera SHA-1: `2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:8B:9C:10`
3. Haz clic en **"+ Agregar huella digital"** de nuevo
4. Pega la segunda SHA-1: `DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:5C:D2:8B`
5. Haz clic en **"+ Agregar huella digital"** de nuevo
6. Pega la tercera SHA-1: `E5:2D:55:5E:7D:FA:D4:C8:2B:8A:37:FF:0D:09:52:A6:66:D7:C2:87`
7. Haz clic en **"+ Agregar huella digital"** de nuevo
8. Pega la cuarta SHA-1: `9D:38:BB:B0:20:F1:3B:21:97:BB:A9:32:BF:B7:EA:ED:58:99:1F:E9`
9. Haz clic en **Guardar**

### Resultado Final

Deberías ver algo así en tu Client ID de Android:

```
Nombre del paquete: mx.creapolis.peliculas

Huellas digitales SHA-1:
• 2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:8B:9C:10 (Debug)
• DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:5C:D2:8B (Release Local)
• E5:2D:55:5E:7D:FA:D4:C8:2B:8A:37:FF:0D:09:52:A6:66:D7:C2:87 (App Signing)
• 9D:38:BB:B0:20:F1:3B:21:97:BB:A9:32:BF:B7:EA:ED:58:99:1F:E9 (Upload Key)
```

---

## ⏱️ Tiempo de Propagación

Después de agregar las SHA-1:

- **Espera 5-10 minutos** antes de probar
- Los cambios se propagan automáticamente
- No necesitas hacer nada más

---

## 🧪 Testing en Diferentes Escenarios

### Desarrollo Local (Debug)

```bash
flutter run
# Usará: SHA-1 Debug (2C:9F:A2:...)
```

### Build Local Release

```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
# Usará: SHA-1 Release Local (DF:D4:2D:...)
```

### Internal Testing en Play Store

```bash
# 1. Firma con upload key y sube
flutter build appbundle --release
# Upload a Play Console

# 2. Descarga desde Play Store Internal Testing
# Usará: SHA-1 App Signing (E5:2D:55:...)
```

### Producción en Play Store

```
# Los usuarios descargan de Play Store
# Usará: SHA-1 App Signing (E5:2D:55:...)
```

---

## ❓ Preguntas Frecuentes

### ¿Por qué Google usa una clave diferente para firmar?

**Respuesta**: Por seguridad. Google Play App Signing protege tu clave de firma principal. Si pierdes tu upload key, Google puede generar una nueva para ti sin afectar a los usuarios existentes.

### ¿Puedo usar solo la SHA-1 de Play Store?

**No**. Si solo agregas la SHA-1 de Play Store:

- ✅ Funcionará para usuarios que descarguen de Play Store
- ❌ NO funcionará en desarrollo local (debug)
- ❌ NO funcionará en builds locales (release)
- ❌ NO funcionará en internal testing

### ¿Cuál es la diferencia entre App Signing Key y Upload Key?

| Aspecto            | App Signing Key                  | Upload Key             |
| ------------------ | -------------------------------- | ---------------------- |
| **Quién la tiene** | Solo Google                      | Tú                     |
| **Para qué sirve** | Firma final de APKs distribuidos | Firma APKs que subes   |
| **Si la pierdes**  | Google la conserva               | Puedes pedir una nueva |
| **Dónde se usa**   | Play Store                       | Play Console           |

### ¿Necesito cambiar algo en mi código?

**No**. Las SHA-1 solo se configuran en Google Cloud Console. Tu código ya está listo.

---

## 🔍 Verificar tus SHA-1

### Desde Play Console

1. Ve a [Play Console](https://play.google.com/console/)
2. Selecciona tu app
3. **Configuración** → **Integridad de la app**
4. Sección **Detalles de la clave**
5. Verás:
   - **Certificado de firma de la app** (App Signing Key)
   - **Certificado de carga** (Upload Key)

### Desde keystores locales

```powershell
# Debug keystore
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# Release keystore
keytool -list -v -keystore "C:\src\peliculas_new.jks" -alias key0 -storepass davidi -keypass davidi
```

---

## ✅ Checklist Completa

- [ ] Obtuve las 4 SHA-1 fingerprints
- [ ] Abrí Google Cloud Console
- [ ] Edité el Client ID de Android
- [ ] Agregué SHA-1 Debug: `2C:9F:A2:...`
- [ ] Agregué SHA-1 Release: `DF:D4:2D:...`
- [ ] Agregué SHA-1 App Signing: `E5:2D:55:...`
- [ ] Agregué SHA-1 Upload Key: `9D:38:BB:...`
- [ ] Guardé los cambios
- [ ] Esperé 5-10 minutos
- [ ] Descargué `google-services.json` actualizado
- [ ] Reemplacé el archivo en `android/app/`
- [ ] Ejecuté `flutter clean && flutter pub get`
- [ ] Probé el login con Google

---

## 🎯 Resultado Esperado

Una vez configuradas las 4 SHA-1:

✅ **Google Sign-In funcionará en**:

- Desarrollo local (debug builds)
- Builds locales de release
- Internal testing de Play Store
- Producción de Play Store
- Todos los dispositivos y escenarios

---

## 🚨 Importante

**NUNCA** compartas o publiques:

- Tu archivo `peliculas_new.jks`
- La contraseña `davidi`
- Tu upload key privada

Las SHA-1 son **públicas** y está bien compartirlas.

---

## 📚 Referencias

- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Gestión de claves](https://developer.android.com/studio/publish/app-signing)
- [Google Sign-In Setup](https://developers.google.com/identity/sign-in/android/start-integrating)

---

**Última actualización**: Octubre 4, 2025
