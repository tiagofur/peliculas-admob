# 🚀 Quick Start - Testing del Sistema de Rating con Slider

**Status:** ✅ Código listo para probar  
**Build:** ✅ Completado exitosamente  
**Próximo paso:** Testing manual

---

## ⚡ Inicio Rápido (3 minutos)

### **1. Iniciar la Aplicación**

```powershell
# En la terminal de VS Code
cd C:\Users\tfurt\source\repos\peliculas-admob-clean
flutter run -d chrome
```

⏱️ **Tiempo estimado:** 30-60 segundos

### **2. Navegar a Detalles de Película**

1. Abrir la app en el navegador (se abrirá automáticamente)
2. Buscar o seleccionar cualquier película
3. Hacer clic para ver detalles

### **3. Probar Rating Slider**

**Test Rápido (2 minutos):**

1. ✅ **Quick Rate:**

   - Click en botón "Quick Rate"
   - Mover slider a 8.5
   - Verificar etiqueta dice "Excelente"
   - Verificar color es verde
   - Click en "Rate"
   - ✅ Verificar guardado exitoso

2. ✅ **Display:**

   - Verificar muestra ⭐ 8.5/10
   - Verificar no hay errores en consola

3. ✅ **Edit:**
   - Click en "Edit Rating"
   - Cambiar a 9.5
   - Verificar etiqueta "Obra Maestra"
   - Click en "Update"
   - ✅ Verificar actualización exitosa

---

## 📋 Checklist de 5 Minutos

```
[ ] App corre sin errores
[ ] Puedo abrir detalles de película
[ ] Botón "Rate" aparece
[ ] Slider se muestra correctamente
[ ] Puedo mover el slider
[ ] Etiquetas cambian según valor
[ ] Colores cambian según valor
[ ] Puedo guardar un rating
[ ] Rating se muestra después de guardar
[ ] Puedo editar el rating
```

**Si todos están ✅:** ¡Sistema funcionando! 🎉

---

## 🔍 Verificaciones Clave

### **1. Slider Funciona**

- Arrastre suave
- Valores de 1.0 a 10.0
- Incrementos de 0.5
- Tooltip muestra valor

### **2. Etiquetas Correctas**

| Rating | Etiqueta Esperada |
| ------ | ----------------- |
| 1.0    | Terrible          |
| 5.0    | Regular           |
| 8.5    | Excelente         |
| 9.5    | Obra Maestra      |

### **3. Colores Correctos**

- 1-3: Rojo
- 4-5: Naranja
- 6-7: Verde claro/Lima
- 8-10: Verde

### **4. Sin Errores**

- Consola del navegador limpia
- Sin warnings en terminal
- Guardado exitoso
- Carga correcta después de refresh

---

## 🐛 Problemas Comunes

### **"No puedo ver el slider"**

✅ Verificar que estás en la vista de detalles de película  
✅ Hacer scroll hacia abajo (puede estar más abajo)  
✅ Verificar que hiciste click en "Rate Movie"

### **"El slider no se mueve"**

✅ Verificar que no estás en modo readonly  
✅ Intentar click + drag (no solo click)  
✅ Probar en otro navegador

### **"No se guarda el rating"**

✅ Verificar conexión a internet  
✅ Verificar que estás logueado  
✅ Revisar consola para errores de Supabase  
✅ Verificar que el backend está corriendo

### **"Veo errores en consola"**

✅ Copiar el error completo  
✅ Verificar si es relacionado a rating  
✅ Compartir screenshot del error

---

## 📱 Test Responsive Rápido

### **Desktop** (ventana completa)

```
[ ] Slider se ve completo
[ ] Etiquetas legibles
[ ] Barra de progreso visible
```

### **Tablet** (redimensionar ventana ~800px)

```
[ ] Layout se ajusta
[ ] Slider sigue funcionando
```

### **Mobile** (redimensionar ventana ~400px)

```
[ ] Modo compacto activado
[ ] Sin overflow horizontal
[ ] Slider táctil funciona
```

**Tip:** En Chrome: F12 → Toggle device toolbar (Ctrl+Shift+M)

---

## 🎯 Escenarios Críticos (10 minutos)

### **Escenario 1: Primera Valoración**

```
1. Película sin rating
2. Click "Quick Rate"
3. Slider a 8.5
4. Guardar
5. ✅ Verificar ⭐ 8.5/10
```

### **Escenario 2: Editar Rating**

```
1. Película con rating 7.5
2. Click "Edit"
3. Cambiar a 9.0
4. Guardar
5. ✅ Verificar ⭐ 9.0/10
```

### **Escenario 3: Rating con Review**

```
1. Click "Rate and Review"
2. Slider a 8.0
3. Escribir review
4. Guardar
5. ✅ Verificar rating + review visible
```

### **Escenario 4: Eliminar Rating**

```
1. Película con rating
2. Click botón eliminar
3. Confirmar
4. ✅ Verificar vuelve a "Rate Movie"
```

---

## 📊 Validación de Base de Datos

Si tienes acceso a Supabase:

```sql
-- Ver tus ratings
SELECT movie_id, rating, review
FROM user_movie_ratings
WHERE user_id = 'tu_user_id'
ORDER BY rated_at DESC;

-- Verificar rango válido
SELECT COUNT(*) FROM user_movie_ratings
WHERE rating < 1.0 OR rating > 10.0;
-- Debe ser 0
```

---

## 🎬 Video Testing (Opcional)

Si quieres grabar el testing:

1. Abrir OBS / Screen recorder
2. Grabar pantalla completa
3. Narrar lo que haces
4. Mostrar cada escenario
5. Mostrar consola sin errores

**Útil para:** Documentación, reportes, demos

---

## 📸 Screenshots Importantes

Capturar pantallas de:

1. **Rating Dialog Full:**

   - Slider visible
   - Etiqueta visible
   - Colores correctos

2. **Compact Display:**

   - En lista de películas
   - Formato ⭐ 8.5/10

3. **Mobile View:**

   - Modo compacto
   - Sin overflow

4. **Console Limpia:**
   - Sin errores
   - Build exitoso

---

## ✅ Checklist Completo

Para testing exhaustivo, ver:  
📄 `docs/TESTING_CHECKLIST_RATING_SLIDER.md`

---

## 🆘 Ayuda

### **Documentación:**

- `RATING_SLIDER_IMPLEMENTATION.md` - Detalles técnicos
- `RESUMEN_RATING_SLIDER.md` - Resumen ejecutivo
- `TESTING_CHECKLIST_RATING_SLIDER.md` - Checklist completo

### **Comandos Útiles:**

```powershell
# Reiniciar app
Ctrl+C  # Detener
flutter run -d chrome  # Iniciar

# Ver logs
flutter logs

# Limpiar y rebuild
flutter clean
flutter pub get
flutter run -d chrome

# Analizar errores
flutter analyze
```

---

## 🎉 ¡Listo para Probar!

**Estado Actual:**

```
✅ Código implementado
✅ Build exitoso (68.4s)
✅ Documentación completa
⏳ Testing manual pendiente
```

**Próximo Paso:**

```powershell
flutter run -d chrome
```

**Tiempo estimado:** 10-15 minutos de testing básico

---

**¡Buena suerte con el testing!** 🚀⭐

Si encuentras problemas, revisa la consola del navegador y la terminal de Flutter para mensajes de error.
