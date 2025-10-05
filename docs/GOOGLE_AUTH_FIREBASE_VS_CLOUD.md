# 🔥 Firebase Console vs Google Cloud Console - Diferencias Clave

## ✅ Solución Correcta

**Firebase Console permite agregar múltiples SHA-1** fácilmente. Google Cloud Console solo permite una.

---

## 📍 Usa Firebase Console (Correcto)

### Firebase Console ✅ USA ESTE

```
URL: https://console.firebase.google.com/
✅ Permite agregar MÚLTIPLES SHA-1
✅ Interfaz más simple y clara
✅ Botón "+ Agregar huella digital" para cada SHA-1
```

### Google Cloud Console (Limitado)

```
URL: https://console.cloud.google.com/
❌ Solo permite 1 SHA-1 en el Client ID de Android
❌ Interfaz más compleja
❌ No recomendado para este caso
```

---

## ✅ Solución: Usa Firebase Console

### Paso 1: Ir a Firebase Console

1. **Abre**: https://console.firebase.google.com/
2. **Inicia sesión** con tu cuenta de Google
3. **Selecciona tu proyecto**

### Paso 2: Ir a Configuración del Proyecto

1. Haz clic en el ícono de **⚙️ (engranaje)** en la parte superior izquierda
2. Selecciona **"Configuración del proyecto"**
3. Ve a la pestaña **"Tus apps"** o desplázate hacia abajo

### Paso 3: Encontrar tu App Android

Busca tu app Android:

```
┌─────────────────────────────────────────────────┐
│ 📱 mx.creapolis.peliculas                      │
│    Android                                      │
└─────────────────────────────────────────────────┘
```

Si no está, puedes agregarla haciendo clic en **"Agregar app"** → **Android**.

### Paso 4: Agregar Múltiples SHA-1

En tu app Android, busca la sección **"Huellas digitales de certificado SHA"**:

```
┌─────────────────────────────────────────────────────┐
│ Huellas digitales de certificado SHA               │
├─────────────────────────────────────────────────────┤
│ SHA-1                                               │
│ 2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:...     │
│                                                     │
│ [+ Agregar huella digital]  ← CLIC AQUÍ           │
└─────────────────────────────────────────────────────┘
```

**Para agregar cada SHA-1**:

1. Haz clic en **[+ Agregar huella digital]**
2. Se abrirá un campo de texto
3. Pega una SHA-1
4. El sistema la valida automáticamente
5. Repite para cada SHA-1 adicional

### Paso 5: Agregar las 4 SHA-1

Agrega estas en orden (haz clic en "+ Agregar huella digital" para cada una):

**SHA-1 #1 - Debug**

```
2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:8B:9C:10
```

**SHA-1 #2 - Release Local**

```
DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:5C:D2:8B
```

**SHA-1 #3 - App Signing Key (Play Store)**

```
E5:2D:55:5E:7D:FA:D4:C8:2B:8A:37:FF:0D:09:52:A6:66:D7:C2:87
```

**SHA-1 #4 - Upload Key (Play Store)**

```
9D:38:BB:B0:20:F1:3B:21:97:BB:A9:32:BF:B7:EA:ED:58:99:1F:E9
```

### Paso 6: Descargar google-services.json

1. En la misma página de configuración del proyecto
2. Busca tu app Android
3. Haz clic en el botón **"google-services.json"** para descargarlo
4. Reemplázalo en tu proyecto: `android/app/google-services.json`

---

## 🎯 Resultado Final

Deberías ver algo así en Firebase Console:

```
┌─────────────────────────────────────────────────────────────┐
│ 📱 mx.creapolis.peliculas                                   │
│                                                              │
│ Huellas digitales de certificado SHA                        │
│                                                              │
│ SHA-1                                                        │
│ 2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:...    │
│                                                              │
│ SHA-1                                                        │
│ DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:...    │
│                                                              │
│ SHA-1                                                        │
│ E5:2D:55:5E:7D:FA:D4:C8:2B:8A:37:FF:0D:09:52:A6:66:...    │
│                                                              │
│ SHA-1                                                        │
│ 9D:38:BB:B0:20:F1:3B:21:97:BB:A9:32:BF:B7:EA:ED:58:...    │
│                                                              │
│ [+ Agregar huella digital]                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## ❓ Preguntas Frecuentes

### ¿Cuántas SHA-1 puedo agregar en Firebase Console?

**Ilimitadas**. Firebase Console te permite agregar tantas SHA-1 como necesites para tu app.

### ¿Por qué Google Cloud Console solo permite una?

Google Cloud Console tiene una interfaz diferente orientada a credenciales OAuth más generales. Para Android específicamente, Firebase Console es la herramienta recomendada.

### ¿Los cambios se sincronizan?

Sí. Firebase y Google Cloud usan el mismo proyecto backend. Los cambios en Firebase se reflejan en Google Cloud y viceversa, aunque las interfaces sean diferentes.

### ¿Necesito hacer algo en Google Cloud Console?

**Sí, pero solo para el Client ID Web**:

- Firebase: Agregar las 4 SHA-1 en tu app Android
- Google Cloud: Obtener el Client ID Web y Client Secret para Supabase
- Google Cloud: Agregar el Redirect URL de Supabase en el Client ID Web

---

## 🚀 Resumen Ejecutivo

### Lo que debes hacer:

1. ✅ **Usa Firebase Console** (console.firebase.google.com)
2. ✅ **Ve a Configuración del proyecto** → Tu app Android
3. ✅ **Haz clic 4 veces en "+ Agregar huella digital"**
4. ✅ **Pega cada SHA-1**
5. ✅ **Descarga google-services.json actualizado**
6. ✅ **Reemplázalo en android/app/**

### URLs Clave:

- **Firebase Console**: https://console.firebase.google.com/
- **Tu proyecto**: Selecciónalo en la lista
- **Configuración**: Ícono ⚙️ → Configuración del proyecto

---

## 📊 Comparación

| Característica                     | Firebase Console            | Google Cloud Console     |
| ---------------------------------- | --------------------------- | ------------------------ |
| **Agregar múltiples SHA-1**        | ✅ Sí, ilimitadas           | ❌ No, solo 1            |
| **Interfaz para Android**          | ✅ Optimizada               | ⚠️ Genérica              |
| **Descargar google-services.json** | ✅ Fácil                    | ⚠️ Menos directo         |
| **Configurar Client ID Web**       | ⚠️ No disponible            | ✅ Requerido             |
| **URL**                            | console.firebase.google.com | console.cloud.google.com |

---

**Última actualización**: Octubre 4, 2025

---

## ✅ Solución: Migra a Google Cloud Console

### Paso 1: Ir a Google Cloud Console

1. **Abre**: https://console.cloud.google.com/
2. **Inicia sesión** con la misma cuenta de Google que usas en Firebase
3. **Verás tus proyectos** de Firebase (están vinculados automáticamente)

### Paso 2: Seleccionar tu Proyecto

1. En la parte superior, haz clic en el **selector de proyectos**
2. Busca tu proyecto (el mismo nombre que en Firebase)
3. Selecciónalo

### Paso 3: Ir a Credenciales

1. **Menú lateral izquierdo** (☰ tres líneas)
2. **APIs y servicios** → **Credenciales**
3. Verás la página de credenciales

### Paso 4: Encontrar tu Client ID de Android

En la sección **"IDs de cliente de OAuth 2.0"**, busca:

```
Nombre: Client ID de Android (mx.creapolis.peliculas)
Tipo: Android
```

Si no lo ves, puede tener un nombre diferente. Busca cualquier credencial de tipo **Android**.

### Paso 5: Editar el Client ID

1. **Haz clic en el nombre** del Client ID de Android (o en el icono de lápiz ✏️)
2. Verás la pantalla de edición

### Paso 6: Agregar Múltiples SHA-1

**Aquí es donde Google Cloud Console es diferente** ✨

En la sección **"Huellas digitales de certificado de firma SHA-1"**:

```
┌─────────────────────────────────────────────────────┐
│ Huellas digitales de certificado de firma SHA-1    │
├─────────────────────────────────────────────────────┤
│ [2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:...]   │  ← SHA-1 existente
│                                                      │
│ [+ Agregar huella digital]  ← CLIC AQUÍ            │
├─────────────────────────────────────────────────────┤
│ Nombre del paquete                                  │
│ mx.creapolis.peliculas                              │
└─────────────────────────────────────────────────────┘
```

**Para agregar cada SHA-1**:

1. Haz clic en **[+ Agregar huella digital]**
2. Se abrirá un campo de texto
3. Pega una SHA-1
4. Presiona Enter o haz clic fuera del campo
5. Repite para cada SHA-1

### Paso 7: Agregar las 4 SHA-1

Agrega estas en orden:

**SHA-1 #1 - Debug**

```
2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:8B:9C:10
```

- [ ] Clic en "+ Agregar huella digital"
- [ ] Pegar SHA-1
- [ ] Presionar Enter

**SHA-1 #2 - Release Local**

```
DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:5C:D2:8B
```

- [ ] Clic en "+ Agregar huella digital"
- [ ] Pegar SHA-1
- [ ] Presionar Enter

**SHA-1 #3 - App Signing Key (Play Store)**

```
E5:2D:55:5E:7D:FA:D4:C8:2B:8A:37:FF:0D:09:52:A6:66:D7:C2:87
```

- [ ] Clic en "+ Agregar huella digital"
- [ ] Pegar SHA-1
- [ ] Presionar Enter

**SHA-1 #4 - Upload Key (Play Store)**

```
9D:38:BB:B0:20:F1:3B:21:97:BB:A9:32:BF:B7:EA:ED:58:99:1F:E9
```

- [ ] Clic en "+ Agregar huella digital"
- [ ] Pegar SHA-1
- [ ] Presionar Enter

### Paso 8: Guardar Cambios

1. **Desplázate hacia abajo**
2. Haz clic en **[Guardar]**
3. Espera la confirmación

---

## 🎯 Resultado Final

Deberías ver algo así:

```
┌─────────────────────────────────────────────────────────────┐
│ Client ID de Android                                        │
├─────────────────────────────────────────────────────────────┤
│ Nombre del paquete: mx.creapolis.peliculas                 │
│                                                              │
│ Huellas digitales SHA-1:                                    │
│ • 2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:...  │
│ • DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:...  │
│ • E5:2D:55:5E:7D:FA:D4:C8:2B:8A:37:FF:0D:09:52:A6:66:...  │
│ • 9D:38:BB:B0:20:F1:3B:21:97:BB:A9:32:BF:B7:EA:ED:58:...  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Sincronización Firebase ↔ Google Cloud

**Importante**: Firebase y Google Cloud Console usan el **mismo proyecto** por detrás.

- ✅ Los cambios en Google Cloud Console **se reflejan** en Firebase
- ✅ Los cambios en Firebase **se reflejan** en Google Cloud Console
- ✅ Son **la misma configuración**, solo diferentes interfaces

Después de agregar las SHA-1 en Google Cloud Console:

1. Vuelve a Firebase Console
2. Refresca la página
3. Verás las 4 SHA-1 agregadas

---

## ❓ Preguntas Frecuentes

### ¿Por qué Firebase Console no me deja agregar múltiples SHA-1?

Firebase Console tiene una **interfaz simplificada** que puede tener limitaciones. Google Cloud Console es la **interfaz completa** con todas las opciones.

### ¿Puedo tener un solo Client ID de Android con múltiples SHA-1?

**Sí, exactamente**. Un Client ID de Android puede tener **múltiples SHA-1**. No necesitas crear varios Client IDs.

```
✅ CORRECTO:
   1 Client ID de Android
   └─ mx.creapolis.peliculas
      ├─ SHA-1 Debug
      ├─ SHA-1 Release
      ├─ SHA-1 App Signing
      └─ SHA-1 Upload Key

❌ INCORRECTO:
   4 Client IDs de Android (uno por SHA-1)
```

### ¿Qué pasa si ya tengo una SHA-1 en Firebase Console?

Perfecto. Cuando vayas a Google Cloud Console, **verás esa SHA-1 ya agregada**. Solo necesitas agregar las otras 3.

### ¿Necesito crear un nuevo Client ID?

**No**. Usa el Client ID de Android que ya existe. Solo edítalo para agregar las SHA-1 faltantes.

### ¿Los cambios son inmediatos?

- **En la consola**: Sí, se guardan de inmediato
- **Para que funcionen en la app**: Espera 5-10 minutos para propagación

---

## 🖼️ Guía Visual Paso a Paso

### Vista 1: Página Principal de Firebase

```
┌──────────────────────────────────────────────────────────────┐
│ Firebase Console                                             │
├──────────────────────────────────────────────────────────────┤
│  ⚙️  Configuración del proyecto                             │
│                                                              │
│  Tus apps                                                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 📱 mx.creapolis.peliculas                             │ │
│  │    Nombre del paquete Android                          │ │
│  │                                                         │ │
│  │    [google-services.json ⬇️]                          │ │
│  │                                                         │ │
│  │    Huellas digitales de certificado SHA                │ │
│  │    ┌──────────────────────────────────────────────┐   │ │
│  │    │ SHA-1                                         │   │ │
│  │    │ 2C:9F:A2:...                                  │   │ │
│  │    └──────────────────────────────────────────────┘   │ │
│  │    ┌──────────────────────────────────────────────┐   │ │
│  │    │ SHA-1                                         │   │ │
│  │    │ DF:D4:2D:...                                  │   │ │
│  │    └──────────────────────────────────────────────┘   │ │
│  │    ┌──────────────────────────────────────────────┐   │ │
│  │    │ SHA-1                                         │   │ │
│  │    │ E5:2D:55:...                                  │   │ │
│  │    └──────────────────────────────────────────────┘   │ │
│  │    ┌──────────────────────────────────────────────┐   │ │
│  │    │ SHA-1                                         │   │ │
│  │    │ 9D:38:BB:...                                  │   │ │
│  │    └──────────────────────────────────────────────┘   │ │
│  │                                                         │ │
│  │    [+ Agregar huella digital]  ← CLIC AQUÍ PARA MÁS  │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## 🚀 Resumen Ejecutivo

### Lo que debes hacer:

1. ✅ **Usa Google Cloud Console** en lugar de Firebase Console
2. ✅ **Edita el Client ID de Android existente** (no crees uno nuevo)
3. ✅ **Agrega las 4 SHA-1** haciendo clic en "+ Agregar huella digital"
4. ✅ **Guarda los cambios**
5. ✅ **Espera 5-10 minutos**
6. ✅ **Descarga google-services.json actualizado**

### URLs Clave:

- **Google Cloud Console**: https://console.cloud.google.com/apis/credentials
- **Tu proyecto**: Selecciónalo en el menú superior
- **Credenciales**: Menú lateral → APIs y servicios → Credenciales

---

## 📞 ¿Aún tienes problemas?

Si después de seguir estos pasos sigues sin poder agregar múltiples SHA-1:

1. **Comparte un screenshot** de la página de edición del Client ID
2. **Verifica que estás en** `console.cloud.google.com` (no `console.firebase.google.com`)
3. **Asegúrate de tener permisos** de editor en el proyecto

---

**Última actualización**: Octubre 4, 2025
