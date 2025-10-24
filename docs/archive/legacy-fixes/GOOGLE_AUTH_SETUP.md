# Configuración de Autenticación de Google para Android

## Huellas SHA obtenidas

### Keystore de Release (peliculas_new.jks)

- **SHA-1**: `DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:5C:D2:8B`
- **SHA-256**: `CC:BB:5D:3C:6E:54:69:8A:1F:80:B3:BA:D5:7A:0D:F4:C8:AD:42:AA:F9:B2:57:E1:EC:FD:6F:11:17:BD:17:5F`

### Keystore de Debug (desarrollo)

- **SHA-1**: `2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:8B:9C:10`
- **SHA-256**: `E3:B9:E7:2C:78:ED:8A:F7:FD:8C:59:98:C4:35:85:14:3E:6F:44:1E:E4:34:8E:22:2E:6A:0C:1F:7F:0C:56:4B`

## Pasos para configurar en Firebase Console

### 1. Acceder a Firebase Console

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto
3. Ve a **Configuración del proyecto** (ícono de engranaje)

### 2. Agregar las huellas SHA

1. En la pestaña **General**, busca la sección "Tus aplicaciones"
2. Encuentra tu aplicación Android (`mx.creapolis.peliculas`)
3. Haz clic en el botón **"Agregar huella digital"**
4. Agrega las siguientes huellas SHA-1 y SHA-256:

   **Para desarrollo (Debug):**

   ```
   SHA-1: 2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:8B:9C:10
   SHA-256: E3:B9:E7:2C:78:ED:8A:F7:FD:8C:59:98:C4:35:85:14:3E:6F:44:1E:E4:34:8E:22:2E:6A:0C:1F:7F:0C:56:4B
   ```

   **Para producción (Release):**

   ```
   SHA-1: DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:5C:D2:8B
   SHA-256: CC:BB:5D:3C:6E:54:69:8A:1F:80:B3:BA:D5:7A:0D:F4:C8:AD:42:AA:F9:B2:57:E1:EC:FD:6F:11:17:BD:17:5F
   ```

### 3. Habilitar Google Sign-In

1. Ve a **Authentication** en el menú lateral
2. En la pestaña **Sign-in method**
3. Habilita **Google** como proveedor
4. Configura el email de soporte del proyecto
5. Guarda los cambios

### 4. Descargar google-services.json actualizado

1. Después de agregar las huellas SHA, vuelve a **Configuración del proyecto**
2. En tu aplicación Android, haz clic en **Descargar google-services.json**
3. Reemplaza el archivo existente en: `android/app/google-services.json`

## Verificar configuración

Después de completar estos pasos:

1. Ejecuta `flutter pub get` para instalar las nuevas dependencias
2. Limpia el proyecto: `flutter clean`
3. Reconstruye la aplicación: `flutter build apk --debug` o `flutter run`

## Notas importantes

- **Dos keystores**: Necesitas configurar ambos keystores (debug y release) para que funcione tanto en desarrollo como en producción
- **Client ID**: Firebase genera automáticamente el Client ID de OAuth para Android cuando agregas las huellas SHA
- **Supabase**: Si estás usando Supabase con Google Sign-In, también deberás configurar el Client ID de Google en tu proyecto de Supabase

## Troubleshooting

### Error: "12500 - Developer Error"

- Verifica que las huellas SHA estén correctamente configuradas en Firebase
- Asegúrate de haber descargado el `google-services.json` actualizado

### Error: "10 - Developer Error"

- Verifica que el package name en Firebase coincida con `mx.creapolis.peliculas`
- Revisa que el `google-services.json` esté en la ubicación correcta

### Error: "Sign in failed"

- Verifica que Google Sign-In esté habilitado en Firebase Authentication
- Asegúrate de tener conexión a internet
