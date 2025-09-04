# Soluciones para el problema de Edge en modo debug

## Problema
Flutter no puede lanzar Microsoft Edge en modo debug con el error:
```
Failed to launch browser after 3 tries. Command used to launch it: 
C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe --user-data-dir=... 
Failed to launch browser. Make sure you are using an up-to-date Chrome or Edge.
```

## Soluciones

### 1. Usar Web Server (Recomendado)
Esta es la solución más confiable que permite abrir la aplicación en cualquier navegador:

```bash
flutter run -d web-server --web-port=3001
```

Después de ejecutar este comando:
1. Espera a que aparezca la URL (generalmente `http://localhost:3001`)
2. Abre manualmente tu navegador preferido (Edge, Chrome, Firefox, etc.)
3. Navega a la URL mostrada

### 2. Usar Chrome como alternativa
Si tienes Chrome instalado, puedes usarlo directamente:

```bash
flutter run -d chrome --web-port=3000
```

### 3. Configurar Edge como navegador por defecto
Puedes intentar configurar Edge como navegador por defecto del sistema:

```bash
# Verificar dispositivos disponibles
flutter devices

# Usar Edge específicamente (si aparece en la lista)
flutter run -d edge --web-port=3002
```

### 4. Limpiar caché de Flutter
Si el problema persiste, limpia la caché:

```bash
flutter clean
flutter pub get
flutter run -d web-server --web-port=3001
```

## Ventajas del Web Server

- ✅ Funciona con cualquier navegador
- ✅ No depende de configuraciones específicas del navegador
- ✅ Permite debugging completo
- ✅ Evita problemas de permisos y configuración
- ✅ Más estable y confiable

## Comandos útiles

```bash
# Ver todos los dispositivos disponibles
flutter devices

# Ejecutar en modo release (más rápido)
flutter run -d web-server --web-port=3001 --release

# Ejecutar con hot reload habilitado
flutter run -d web-server --web-port=3001 --debug
```

## Notas adicionales

- El web-server es la opción más confiable para desarrollo web con Flutter
- Puedes usar cualquier puerto disponible cambiando `--web-port=XXXX`
- El hot reload funciona perfectamente con web-server
- No necesitas configuraciones adicionales del navegador