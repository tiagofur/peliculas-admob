🗑️ CÓDIGO OBSOLETO A ELIMINAR

1. Archivos Duplicados

# Encontrados en análisis:

lib/presentation/widgets/achievement_card.dart # DUPLICADO
lib/presentation/widgets/achievements/achievement_card.dart # MANTENER

lib/examples/\*.dart # MOVER A /examples (ya hecho parcialmente)

2. Dependencias No Utilizadas

# En pubspec.yaml - Sin uso detectado:

- flutter_in_app_pip: ^1.0.0 # Solo Android, implementación incompleta
- Some legacy packages

3. Código Comentado

// Múltiples bloques de código comentado encontrados:

- 50+ bloques en archivos de providers
- Código de debug no eliminado
- TODOs antiguos sin resolver (33+)
