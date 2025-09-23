# Solución Definitiva para Errores de CMake en Windows

## Problema

Al abrir VS Code en este proyecto Flutter, aparecen errores de CMake relacionados con archivos faltantes en `windows/flutter/ephemeral/generated_config.cmake`.

## Causa

Los archivos de configuración de CMake para Windows se generan dinámicamente cuando Flutter hace build, pero VS Code intenta cargarlos antes de que existan.

## Solución Definitiva Implementada

### 1. Configuración de VS Code (`.vscode/settings.json`)

```json
{
  // Deshabilitar configuración automática de CMake
  "cmake.configureOnOpen": false,
  "cmake.automaticConfiguring": false,

  // Ignorar archivos ephemeral que se generan dinámicamente
  "files.exclude": {
    "**/windows/flutter/ephemeral/**": true,
    "**/build/**": true
  },

  // Deshabilitar IntelliSense de C++ para evitar conflictos
  "C_Cpp.errorSquiggles": "Disabled",
  "C_Cpp.intelliSenseEngine": "Disabled"
}
```

### 2. Scripts de Reparación Automática

#### PowerShell: `scripts/fix_windows_cmake.ps1`

Script completo que:

- Limpia archivos de build
- Reinstala dependencias
- Regenera archivos de Windows
- Instala NuGet si es necesario

#### Batch: `scripts/fix_windows_cmake.bat`

Versión alternativa en CMD para compatibilidad.

### 3. Task de VS Code

Disponible en la paleta de comandos: `Tasks: Run Task` → `Fix Windows CMake Issues`

## Uso

### Método 1: Automático (Recomendado)

Los errores deberían estar ocultos automáticamente con la configuración implementada.

### Método 2: Si Reaparecen los Errores

1. Abrir terminal en VS Code
2. Ejecutar: `.\scripts\fix_windows_cmake.ps1`
3. Reiniciar VS Code

### Método 3: Task de VS Code

1. Presionar `Ctrl+Shift+P`
2. Buscar "Tasks: Run Task"
3. Seleccionar "Fix Windows CMake Issues"

## Prevención Futura

### Al Clonar el Proyecto

1. Ejecutar `flutter pub get`
2. Ejecutar `flutter config --enable-windows-desktop`
3. Si aparecen errores, usar el script de reparación

### Al Cambiar de Branch

1. Ejecutar `flutter clean`
2. Ejecutar `flutter pub get`
3. Si es necesario, ejecutar el script de reparación

## Archivos Involucrados en la Solución

- `.vscode/settings.json` - Configuración principal
- `.vscode/c_cpp_properties.json` - IntelliSense de C++
- `.vscode/tasks.json` - Tasks automatizadas
- `scripts/fix_windows_cmake.ps1` - Script de reparación principal
- `scripts/fix_windows_cmake.bat` - Script alternativo
- `nuget.exe` - NuGet local para dependencias de Windows

## Notas Técnicas

1. **Los archivos `ephemeral` son temporales**: Se generan automáticamente y no deben editarse manualmente.

2. **NuGet es requerido**: Algunos plugins como `flutter_inappwebview_windows` requieren NuGet para Windows.

3. **Primer build es lento**: El primer build de Windows puede tomar 10-15 minutos.

4. **Visual Studio requerido**: Para builds de Windows se requiere Visual Studio 2019/2022 con herramientas de C++.

## Troubleshooting

### Si los errores persisten:

1. Verificar que Visual Studio esté instalado con herramientas de C++
2. Ejecutar `flutter doctor` para verificar configuración
3. Reiniciar VS Code completamente
4. Ejecutar el script de reparación

### Si falla el build de Windows:

1. Verificar que NuGet esté disponible
2. Verificar conectividad de internet para descargas
3. Verificar permisos de escritura en la carpeta del proyecto

Esta solución debería eliminar definitivamente los errores de CMake al abrir el proyecto.
