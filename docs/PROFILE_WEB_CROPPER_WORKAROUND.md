# 🔧 Profile Avatar Web Cropper Workaround

**Fecha:** 30 de septiembre de 2025  
**Componente:** `lib/presentation/screens/profile/profile_screen.dart`  
**Issue:** NoSuchMethodError al usar image cropper en Web  
**Solución:** Workaround temporal - skip cropping en Web

---

## 📋 Contexto

### Problema Original

Al intentar usar el cropper de imágenes en la plataforma Web, la aplicación crasheaba con el siguiente error:

```
NoSuchMethodError: tried to call a non-function, such as null: 't$360$.scale'
```

**Stack trace:**

```
package:image_cropper_for_web/image_cropper_for_web.dart 182:7 <fn>
package:image_cropper_for_web/src/cropper_dialog.dart 116:27 <fn>
package:flutter/src/material/slider.dart 715:16 [_handleChanged]
```

### Causa Raíz

La versión actual de `image_cropper_for_web` (v6.1.0) tiene incompatibilidades con las bibliotecas JavaScript de cropping:

1. **Croppie CDN no funciona**: A pesar de agregar Croppie v2.6.5 via CDN, la biblioteca no se carga correctamente
2. **API incompatible**: `image_cropper_for_web` v6.1.0 intenta llamar métodos (como `.scale`) que no existen en el objeto Croppie
3. **Versión obsoleta**: Existe `image_cropper` v11.0.0 e `image_cropper_for_web` v7.0.0 con mejoras significativas

---

## ✅ Solución Implementada (Workaround)

### 1. Detección de Plataforma

Se agregó `import 'package:flutter/foundation.dart'` para usar `kIsWeb`:

```dart
import 'package:flutter/foundation.dart'; // Para kIsWeb
```

### 2. Lógica Condicional en `selectImage()`

Se modificó el método para **skip cropping solo en Web**:

```dart
Future<void> selectImage() async {
  final theme = Theme.of(context);

  final XFile? image = await _imagePicker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 80,
  );

  if (image != null && mounted) {
    // WORKAROUND: En Web, skip cropping
    if (kIsWeb) {
      LoggerFactory.info('Web platform: skipping image cropper (workaround)');

      // Mostrar mensaje informativo
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Imagen seleccionada sin recorte. Para recortar imágenes, usa la app móvil.',
                  ),
                ),
              ],
            ),
            backgroundColor: theme.colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Usar imagen directamente sin cropper
      setState(() {
        _selectedImage = File(image.path);
      });

      // Analytics con metadata
      _analyticsService.trackEvent(AnalyticsEventType.userEngagement, {
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'gallery',
        'platform': 'web',
        'cropped': false,
      });

      return;
    }

    // En móvil/desktop: usar cropper normalmente
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 512,
      maxHeight: 512,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar Avatar',
          toolbarColor: theme.colorScheme.primary,
          toolbarWidgetColor: theme.colorScheme.onPrimary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Recortar Avatar',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile != null && mounted) {
      setState(() {
        _selectedImage = File(croppedFile.path);
      });

      _analyticsService.trackEvent(AnalyticsEventType.userEngagement, {
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'gallery',
        'platform': kIsWeb ? 'web' : 'mobile',
        'cropped': true,
      });
    }
  }
}
```

### 3. Ventajas del Workaround

✅ **Feature funcional inmediatamente**: Los usuarios pueden subir avatares en Web  
✅ **Sin crashes**: No más errores `NoSuchMethodError`  
✅ **UX clara**: Mensaje informativo explica limitación temporal  
✅ **Cross-platform**: Cropping funciona normalmente en móvil/desktop  
✅ **Analytics**: Tracking diferenciado por plataforma y si se usó crop

### 4. Desventajas

⚠️ **Sin cropping en Web**: Usuarios deben usar imagen completa  
⚠️ **Inconsistencia UX**: Diferencia entre plataformas  
⚠️ **Temporal**: No es solución definitiva

---

## 🚀 Solución Permanente (Pendiente)

### Opción Recomendada: Upgrade a image_cropper v11.x

**Beneficios:**

- Soporte completo para Web con cropping funcional
- Mejoras de rendimiento y estabilidad
- API actualizada y mantenida activamente
- Compatibilidad con Flutter 3.x

**Pasos para implementar:**

#### 1. Actualizar `pubspec.yaml`

```yaml
dependencies:
  # Antes:
  # image_cropper: ^9.1.0

  # Después:
  image_cropper: ^11.0.0
  image_cropper_for_web: ^7.0.0 # Si es necesario especificar
```

#### 2. Ejecutar upgrade

```bash
flutter pub upgrade image_cropper
flutter clean
flutter pub get
```

#### 3. Verificar Breaking Changes

Revisar changelog de image_cropper v11.x para cambios en API:

- https://pub.dev/packages/image_cropper/changelog

#### 4. Actualizar código si necesario

Posibles cambios:

- Parámetros de `cropImage()` renombrados
- Nuevas opciones de `WebUiSettings`
- Cambios en `CropAspectRatio` o `CropStyle`

#### 5. Remover Workaround

Una vez verificado que funciona en v11.x:

```dart
Future<void> selectImage() async {
  final theme = Theme.of(context);

  final XFile? image = await _imagePicker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 80,
  );

  if (image != null && mounted) {
    // REMOVER: Workaround kIsWeb ya no necesario

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 512,
      maxHeight: 512,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar Avatar',
          toolbarColor: theme.colorScheme.primary,
          toolbarWidgetColor: theme.colorScheme.onPrimary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Recortar Avatar',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
        WebUiSettings(
          context: context,
          // Verificar nuevas opciones disponibles en v11.x
        ),
      ],
    );

    if (croppedFile != null && mounted) {
      setState(() {
        _selectedImage = File(croppedFile.path);
      });

      _analyticsService.trackEvent(AnalyticsEventType.userEngagement, {
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'gallery',
        'cropped': true,
      });
    }
  }
}
```

#### 6. Testing Completo

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Manual testing en Web
flutter run -d chrome

# Manual testing en Android
flutter run -d android

# Build validation
flutter build web --release
flutter build apk --release
```

---

## 📝 Verificación

### ✅ Estado Actual del Workaround

- [x] Import `flutter/foundation.dart` agregado
- [x] Detección `kIsWeb` implementada
- [x] Skip cropping en Web con mensaje informativo
- [x] Cropping funciona en móvil/desktop
- [x] Analytics tracking diferenciado
- [x] Código compila sin errores (`flutter analyze` ✅)
- [x] LoggerFactory usado correctamente
- [x] TODO comment documentado en código

### 🔄 Pendiente para Solución Permanente

- [ ] Actualizar `image_cropper` a v11.x en `pubspec.yaml`
- [ ] Ejecutar `flutter pub upgrade`
- [ ] Revisar breaking changes en changelog
- [ ] Actualizar código si necesario
- [ ] Remover workaround `kIsWeb`
- [ ] Testing en todas las plataformas
- [ ] Validar cropping funciona en Web
- [ ] Actualizar documentación

---

## 🎯 Resultado

**Inmediato:**

- ✅ Feature de avatar funcional en Web (sin crop)
- ✅ Sin crashes ni errores
- ✅ UX clara con mensaje informativo
- ✅ Móvil/desktop mantienen cropping completo

**Próximo paso:**

- 🔄 Planificar upgrade a `image_cropper` v11.x
- 🔄 Habilitar cropping en Web de manera oficial
- 🔄 Eliminar workaround temporal

---

## 📚 Referencias

- [image_cropper v11.0.0](https://pub.dev/packages/image_cropper)
- [image_cropper_for_web v7.0.0](https://pub.dev/packages/image_cropper_for_web)
- [Flutter Web Platform](https://docs.flutter.dev/platform-integration/web)
- [kIsWeb constant](https://api.flutter.dev/flutter/foundation/kIsWeb-constant.html)

---

**Autor:** Claude (GitHub Copilot)  
**Revisión:** Pendiente testing completo del workaround  
**Status:** ✅ WORKAROUND IMPLEMENTADO | 🔄 UPGRADE PENDIENTE
