# Logo de Google para Sign-In

El botón de Google Sign-In en la aplicación usa un logo simple con la letra "G" como fallback si no se encuentra la imagen oficial.

## Agregar el logo oficial de Google (Opcional)

Si deseas usar el logo oficial de Google, sigue estos pasos:

1. Descarga el logo oficial de Google desde [Google Brand Resources](https://developers.google.com/identity/branding-guidelines)
2. Guarda el archivo como `google_logo.png` en la carpeta `assets/images/`
3. Actualiza el `pubspec.yaml` para incluir esta imagen (si aún no está incluida):

```yaml
flutter:
  assets:
    - assets/images/google_logo.png
```

## Uso actual

El widget `GoogleSignInButton` actualmente usa un fallback con la letra "G" estilizada en caso de que la imagen no exista. Esto es suficiente para el desarrollo y testing.

Para usar el logo oficial en producción, simplemente descarga y coloca el archivo en la ubicación mencionada.
