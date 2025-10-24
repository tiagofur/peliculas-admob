# Solución Crítica - Cropper No Inicializado

**Fecha**: 30 de Septiembre, 2025  
**Error**: "cropper has not been initialized" / "Cropper is not a constructor"  
**Status**: 🔧 EN PROGRESO

---

## 🔴 Problema Crítico

Aunque agregamos los scripts de Croppie al `index.html`, la librería **NO se está cargando** correctamente en el navegador.

### Errores Actuales

```
1. cropper has not been initialized
2. dart.global.Cropper is not a constructor
3. setState() or markNeedsBuild() called during build
```

---

## 🔍 Diagnóstico Paso a Paso

### Paso 1: Verificar Carga de Croppie

**Una vez que la app cargue en Chrome**:

1. Abre **DevTools** (F12)
2. Ve a la pestaña **Console**
3. **Busca este mensaje**:

   - ✅ Si ves: `"✅ Croppie loaded successfully!"` → La librería cargó
   - ❌ Si ves: `"❌ Croppie failed to load from CDN"` → La librería NO cargó

4. **Ejecuta manualmente** en Console:

   ```javascript
   console.log("Croppie:", typeof Croppie);
   console.log("Cropper:", typeof Cropper);
   ```

   **Resultado esperado**:

   ```
   Croppie: "function"
   Cropper: "function"  (alias creado por nosotros)
   ```

### Paso 2: Verificar Red

En DevTools → pestaña **Network**:

1. Recarga la página (Ctrl+R)
2. **Busca estos archivos**:
   - `croppie.min.css`
   - `croppie.min.js`
3. **Verifica el Status**:
   - ✅ `200 OK` → Archivos se descargaron correctamente
   - ❌ `Failed` o `404` → CDN bloqueado o no disponible

---

## ✅ Soluciones Según Diagnóstico

### Solución A: CDN Bloqueado (Ad-blocker/Firewall)

Si los archivos no se descargan:

1. **Deshabilita ad-blockers** en Chrome
2. **Verifica firewall** corporativo
3. **Prueba CDN alternativo** (jsDelivr):

```html
<!-- Reemplazar en web/index.html -->
<link
  rel="stylesheet"
  href="https://cdn.jsdelivr.net/npm/croppie@2.6.5/croppie.min.css"
/>
<script src="https://cdn.jsdelivr.net/npm/croppie@2.6.5/croppie.min.js"></script>
```

### Solución B: Incompatibilidad de Versión

El paquete `image_cropper_for_web` puede esperar una API diferente.

**Opción 1: Usar Cropper.js en lugar de Croppie**

```html
<!-- Reemplazar scripts de Croppie con Cropper.js -->
<link
  rel="stylesheet"
  href="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.1/cropper.min.css"
/>
<script src="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.1/cropper.min.js"></script>
```

**Opción 2: Actualizar image_cropper**

En `pubspec.yaml`:

```yaml
dependencies:
  image_cropper: ^11.0.0 # Versión más reciente
  image_cropper_for_web: ^7.0.0 # Versión más reciente
```

Luego:

```bash
flutter pub upgrade image_cropper image_cropper_for_web
flutter clean
flutter run -d chrome
```

### Solución C: Bundling Local (Más Confiable)

Si los CDNs no funcionan, incluir Croppie localmente:

1. **Descargar archivos**:

   - https://cdnjs.cloudflare.com/ajax/libs/croppie/2.6.5/croppie.min.css
   - https://cdnjs.cloudflare.com/ajax/libs/croppie/2.6.5/croppie.min.js

2. **Crear carpeta**: `web/assets/croppie/`

3. **Copiar archivos** a esa carpeta

4. **Actualizar index.html**:

```html
<link rel="stylesheet" href="assets/croppie/croppie.min.css" />
<script src="assets/croppie/croppie.min.js"></script>
```

---

## 🔧 Fix Temporal - Deshabilitar Cropper en Web

Si necesitas que la app funcione YA mientras arreglamos el cropper:

**En `profile_screen.dart`**:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> selectImage() async {
  final theme = Theme.of(context);
  final currentContext = context;

  final XFile? image = await _imagePicker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 80,
  );

  if (image != null && mounted) {
    // En Web, usar imagen directamente sin cropping
    if (kIsWeb) {
      setState(() {
        _selectedImage = File(image.path);
      });
      return;
    }

    // En móvil, usar cropper normal
    final croppedFile = await ImageCropper().cropImage(
      // ... resto del código
    );
  }
}
```

**Esto permite subir avatars en Web SIN cropping** mientras arreglamos el issue.

---

## 📋 Checklist de Verificación

**Cuando la app cargue**:

- [ ] Abrir DevTools (F12)
- [ ] Ver Console → buscar mensaje de Croppie
- [ ] Ejecutar `typeof Croppie` en Console
- [ ] Verificar Network tab → croppie.min.js/css
- [ ] Intentar subir avatar
- [ ] Anotar EXACTAMENTE qué error aparece

**Información a reportar**:

- ¿Aparece "✅ Croppie loaded successfully!"?
- ¿Qué muestra `typeof Croppie`?
- ¿Los archivos .css/.js se descargaron (200 OK)?
- ¿Qué navegador/versión estás usando?
- ¿Hay ad-blockers o extensiones activas?

---

## 🎯 Plan de Acción

### Opción 1: Debugging (Actual)

1. ✅ Agregado script de verificación en index.html
2. ✅ Ejecutando rebuild (`flutter run -d chrome`)
3. ⏳ Esperar que compile
4. ⏳ Verificar logs en Console
5. ⏳ Decidir siguiente paso según resultados

### Opción 2: Cambiar a Cropper.js

Si Croppie no funciona, cambiar a Cropper.js (más compatible)

### Opción 3: Actualizar Paquetes

Upgrade a versiones más recientes de image_cropper

### Opción 4: Deshabilitar Crop en Web

Fix temporal para desbloquear otras funcionalidades

---

## 🚨 Nota Importante

**El error "setState() or markNeedsBuild() called during build"** es SECUNDARIO - ocurre porque el cropper falla. Una vez que Croppie cargue correctamente, este error debería desaparecer.

---

## 💡 Teoría del Problema

`image_cropper_for_web` v6.1.0 puede estar esperando:

- ✅ `window.Croppie` (la librería real)
- ❌ Pero busca `window.Cropper` (alias)

Nuestro script ahora crea el alias:

```javascript
window.Cropper = window.Croppie;
```

Esto debería resolver la incompatibilidad.

---

## 🎬 Siguiente Paso INMEDIATO

**ESPERA** a que termine el `flutter run` actual.

**LUEGO** abre Chrome DevTools y:

1. Busca el mensaje de Croppie en Console
2. Ejecuta `typeof Croppie` y `typeof Cropper`
3. Reporta los resultados

**Con esa información sabré exactamente qué solución aplicar.**

---

**Status**: 🕐 Esperando resultados del rebuild con debugging...
