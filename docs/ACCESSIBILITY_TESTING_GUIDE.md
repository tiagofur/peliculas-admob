# Accessibility Testing Guide

Esta guía describe cómo probar manualmente las mejoras de accesibilidad implementadas para cumplir con WCAG AA.

## 🎯 Características de Accesibilidad Implementadas

### 1. Modo Alto Contraste
- **Automático**: Se activa cuando el sistema tiene modo alto contraste habilitado
- **Colores**: Blanco puro sobre negro (modo oscuro) o negro puro sobre blanco (modo claro)
- **Textos**: Peso de fuente incrementado para mejor legibilidad

### 2. Escalado de Texto
- **Soporte**: Hasta 200% de escalado de texto
- **Elementos táctiles**: Se adaptan automáticamente manteniendo mínimo 44x44dp
- **Interfaz**: Se mantiene usable con texto grande

### 3. Etiquetas Semánticas
- **Botones**: Tooltips y etiquetas semánticas en español
- **Calificaciones**: Descripción completa de estrellas
- **Streaming**: Disponibilidad de plataformas con contexto
- **Estados**: Sincronización y estados del sistema

## 📱 Pruebas Manuales

### Prueba 1: Modo Alto Contraste
```
1. Activar modo alto contraste en el sistema operativo
2. Abrir la aplicación
3. Verificar:
   - Colores tienen máximo contraste (blanco/negro)
   - Textos son completamente legibles
   - Iconos se distinguen claramente
   - No hay elementos con contraste insuficiente
```

### Prueba 2: Escalado de Texto
```
1. Configurar escalado de texto al 150% o 200%
2. Navegar por la aplicación
3. Verificar:
   - Todo el texto escala correctamente
   - Elementos táctiles mantienen tamaño mínimo
   - Interfaz no se rompe con texto grande
   - Star ratings funcionan correctamente
```

### Prueba 3: Lector de Pantalla (Android/iOS)
```
1. Activar TalkBack (Android) o VoiceOver (iOS)
2. Navegar con gestos/teclado
3. Verificar:
   - Botones de tema y búsqueda tienen etiquetas claras
   - Calificaciones se anuncian correctamente
   - Plataformas de streaming incluyen disponibilidad
   - Orden de navegación es lógico
```

### Prueba 4: Navegación por Teclado (Web/Desktop)
```
1. Usar solo teclado para navegar
2. Verificar:
   - Todos los elementos interactivos son accesibles
   - Orden de tabulación es lógico
   - Focus visible en todos los elementos
   - Atajos de teclado funcionan
```

## 🎨 Validación de Contraste WCAG AA

### Ratios Mínimos Requeridos
- **Texto normal**: 4.5:1
- **Texto grande (18pt+)**: 3:1
- **Elementos gráficos**: 3:1

### Modo Normal
```css
/* Colores principales que cumplen WCAG AA */
Primary: Material 3 color scheme (automático 4.5:1+)
Background: System background
Text: System foreground
Icons: System primary with sufficient contrast
```

### Modo Alto Contraste
```css
/* Máximo contraste - supera WCAG AAA */
Light Mode:
  - Background: #FFFFFF (blanco puro)
  - Text: #000000 (negro puro)
  - Ratio: 21:1 ✅

Dark Mode:
  - Background: #000000 (negro puro)  
  - Text: #FFFFFF (blanco puro)
  - Ratio: 21:1 ✅
```

## 🔧 Herramientas de Validación

### Automáticas
```bash
# Ejecutar tests de accesibilidad
flutter test test/accessibility_*

# Tests específicos
flutter test test/accessibility_integration_test.dart
flutter test test/accessibility_theme_test.dart
flutter test test/accessibility_widgets_test.dart
```

### Manuales
1. **Contrast Checker**: https://webaim.org/resources/contrastchecker/
2. **Color Oracle**: Simulador de daltonismo
3. **Accessibility Scanner** (Android)
4. **Accessibility Inspector** (iOS)

## 📋 Checklist de Validación

### ✅ Cumplimiento WCAG AA - Nivel A
- [x] Imágenes tienen texto alternativo
- [x] Información por color también disponible por otros medios
- [x] Contraste suficiente (4.5:1 texto normal, 3:1 texto grande)
- [x] Texto redimensionable hasta 200% sin pérdida de funcionalidad
- [x] Navegación por teclado disponible
- [x] Elementos interactivos identificables

### ✅ Cumplimiento WCAG AA - Nivel AA
- [x] Contraste mejorado (modo alto contraste: 21:1)
- [x] Tamaños de toque mínimos (44x44dp)
- [x] Etiquetas semánticas en idioma nativo (español)
- [x] Navegación consistente
- [x] Identificación de errores clara
- [x] Soporte para tecnologías asistivas

### 🎯 Funcionalidades Específicas Validadas
- [x] **CustomAppbar**: Botones de tema y búsqueda accesibles
- [x] **StarRating**: Calificaciones con descripción completa
- [x] **StreamingIndicator**: Disponibilidad de plataformas clara
- [x] **SyncStatus**: Estados de sincronización descriptivos
- [x] **Theme**: Alto contraste automático
- [x] **TouchTargets**: Mínimo 44x44dp en todos los elementos

## 🚀 Próximos Pasos

Para continuar mejorando la accesibilidad:

1. **Añadir más widgets**: Aplicar los mismos principios a nuevos componentes
2. **Testing con usuarios**: Validar con usuarios que usan tecnologías asistivas
3. **Métricas**: Implementar tracking de uso de características de accesibilidad
4. **Documentación**: Crear guía de accesibilidad para desarrolladores

## 📖 Referencias

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Flutter Accessibility](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [Material Design Accessibility](https://material.io/design/usability/accessibility.html)