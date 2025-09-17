# Solución para Listas Duplicadas

## Problema Identificado

El sistema estaba creando listas predeterminadas duplicadas cada vez que un usuario hacía login debido a una verificación de existencia incorrecta en `auto_default_lists_provider.dart`.

### Causa Raíz
- La verificación de existencia solo comparaba por `name` en lugar de usar `defaultType` y `userId`
- El método `createList` no aceptaba parámetros `isDefault` y `defaultType`
- Esto causaba que se crearan múltiples listas con el mismo nombre para el mismo usuario

## Solución Implementada

### 1. Corrección en `auto_default_lists_provider.dart`

**Antes:**
```dart
final existingList = existingLists.firstWhereOrNull(
  (list) => list.name == config.name,
);
```

**Después:**
```dart
final existingList = existingLists.firstWhereOrNull(
  (list) => list.defaultType == config.defaultType && list.isDefault == true,
);
```

### 2. Actualización en `custom_lists_providers.dart`

**Modificación del método `createList`:**
```dart
Future<void> createList({
  required String name,
  String? description,
  bool isDefault = false,
  String? defaultType,
}) async {
  final newList = CustomList(
    // ... otros campos
    isDefault: isDefault,
    defaultType: defaultType,
  );
  // ...
}
```

### 3. Actualización en `_createMissingDefaultLists`

**Llamada corregida:**
```dart
await listActions.createList(
  name: config.name,
  description: config.description,
  isDefault: true,
  defaultType: config.defaultType,
);
```

## Scripts de Mantenimiento

### Script de Limpieza SQL
Ubicación: `supabase/migrations/delete_user_lists_tiagofur.sql`

Este script elimina todas las listas de un usuario específico y puede ser adaptado para otros usuarios.

### Script de Verificación Node.js
Ubicación: `scripts/test_default_lists_fix.js`

Este script verifica que un usuario tenga exactamente una lista por cada `defaultType` sin duplicados.

### Script de Limpieza Node.js
Ubicación: `scripts/cleanup_user_lists.js`

Este script elimina todas las listas de un usuario específico usando la API de Supabase.

## Prevención de Futuros Problemas

1. **Verificación Correcta**: Siempre verificar existencia usando `defaultType` y `isDefault` para listas predeterminadas
2. **Parámetros Completos**: Asegurar que los métodos de creación acepten todos los parámetros necesarios
3. **Testing Regular**: Ejecutar el script de verificación periódicamente
4. **Logs Detallados**: Los logs ahora incluyen `defaultType` para mejor debugging

## Comandos de Mantenimiento

```bash
# Verificar estado de listas de un usuario
node scripts/test_default_lists_fix.js

# Limpiar todas las listas de un usuario específico
node scripts/cleanup_user_lists.js

# Aplicar limpieza SQL (modificar email en el archivo primero)
supabase db push --file supabase/migrations/delete_user_lists_tiagofur.sql
```

## Estado Actual

✅ **Problema Resuelto**: Las listas duplicadas del usuario `tiagofur@gmail.com` han sido eliminadas
✅ **Código Corregido**: La lógica de verificación ahora funciona correctamente
✅ **Scripts Disponibles**: Herramientas de mantenimiento creadas y probadas

## Notas Importantes

- Los scripts de limpieza son destructivos - usar con precaución
- Siempre hacer backup antes de ejecutar scripts de limpieza en producción
- La aplicación recreará automáticamente las listas predeterminadas en el próximo login del usuario