# 🔍 INSTRUCCIONES PARA DIAGNÓSTICO DEL PERFIL

## ⚠️ IMPORTANTE: Sigue estos pasos EN ORDEN

### PASO 1: Preparar el Script

1. **Abre el archivo**: `scripts/debug_profile_console.js`
2. **Selecciona TODO** el contenido (Ctrl+A)
3. **Copia** todo (Ctrl+C)
4. **Déjalo en el portapapeles** (no copies nada más hasta terminar)

---

### PASO 2: Abrir la Aplicación

1. **Abre Chrome**
2. **Ve a**: http://localhost:3000
3. **Espera** a que cargue completamente

---

### PASO 3: Login

1. **Haz login** con:
   - Email: `tiagofur@gmail.com`
   - Password: `Davidi81`
2. **Espera** a que termine de cargar
3. **Ve a la página de perfil** (donde ves los errores)

---

### PASO 4: Abrir DevTools

1. **Presiona F12** (o clic derecho → Inspeccionar)
2. **Ve a la pestaña "Console"**
3. **Limpia la consola** (clic en 🚫 o Ctrl+L)

---

### PASO 5: Ejecutar el Script

1. **Clic dentro del área de la consola** (donde dice "> ")
2. **Pega** el script (Ctrl+V)
3. **Presiona Enter**
4. **ESPERA** - el script se ejecutará automáticamente

---

### PASO 6: Copiar los Resultados

El script mostrará 7 pasos:

```
🔍 DIAGNÓSTICO DE PERFIL - DEBUG MODE
================================================================================
📋 PASO 1: Verificando localStorage y cache
📋 PASO 2: Verificando sessionStorage
📋 PASO 3: Verificando Supabase auth
📋 PASO 4: Consultando perfil en Supabase
📋 PASO 5: Verificando RLS y permisos
📋 PASO 6: Verificando avatar (si existe)
📋 PASO 7: Verificando cache del navegador
🎉 DIAGNÓSTICO COMPLETADO
```

**COPIA TODO** lo que aparezca en la consola:

1. **Clic derecho** en la consola
2. **"Save as..."** → Guarda como `diagnostico_resultado.txt`
3. **O** selecciona todo (Ctrl+A en la consola) y copia

---

### PASO 7: Compartir Resultados

**Compárteme el archivo** `diagnostico_resultado.txt` o **pega aquí** todo el texto que copiaste.

---

## 🆘 PROBLEMAS COMUNES

### "No puedo pegar en la consola"

- **Solución 1**: Escribe manualmente: `allow pasting` y presiona Enter, luego intenta pegar de nuevo
- **Solución 2**: Escribe: `permit console.paste` y presiona Enter
- **Solución 3**: Usa la opción alternativa (ver abajo)

### "El script no hace nada"

- Asegúrate de estar en la pestaña **Console** (no Elements, Network, etc)
- Verifica que pegaste **TODO** el script
- Presiona Enter después de pegar

### "Aparece un error"

- **¡PERFECTO!** Ese es el diagnóstico que necesito
- Copia el error completo y compártelo

---

## 📋 OPCIÓN ALTERNATIVA (Si no funciona el pegado)

Si definitivamente no puedes pegar en la consola:

1. **Abre DevTools** (F12)
2. **Ve a Console**
3. **Busca manualmente** estos mensajes:
   - Mensajes con "UserProfileNotifier"
   - Mensajes con "error" o "Error"
   - Mensajes con "profile"
   - Mensajes rojos (errores)
4. **Toma screenshots** de esos mensajes
5. **Compártelos** conmigo

---

## ✅ ¿QUÉ ESPERO VER?

El script me dirá:

- ✅ Si tu perfil existe en la base de datos
- ✅ Qué user_id tiene tu sesión
- ✅ Si hay cache viejo en el navegador
- ✅ Si tienes permisos correctos (RLS)
- ✅ Dónde está el problema exacto

Con esa información podré darte **la solución exacta**.

---

## 🚀 ¡ADELANTE!

Sigue los pasos 1-7 y compárteme los resultados.

**Tiempo estimado**: 2-3 minutos
