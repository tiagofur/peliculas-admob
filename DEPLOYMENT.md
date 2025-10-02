# Guía de Deployment - Películas App

Esta guía explica cómo deployar correctamente la aplicación web de Películas en diferentes plataformas de hosting.

## 🎯 Problema Común: Rutas de Share y 404

La aplicación utiliza rutas como `/movie/123/share` para compartir películas. Es **crítico** que el servidor web esté configurado correctamente para que estas rutas funcionen.

### ¿Por qué ocurren errores 404?

Cuando un usuario accede directamente a `https://peliculas.creapolis.dev/movie/123/share`:

1. El navegador hace una petición HTTP al servidor
2. El servidor busca un archivo en `/movie/123/share`
3. Como no existe ese archivo físico, devuelve **404 Not Found**
4. Flutter nunca recibe la petición

### ✅ Solución

El servidor debe **redirigir todas las peticiones** al `index.html`, para que Flutter (GoRouter) maneje el routing.

---

## 📦 Build de Producción

Antes de deployar, construye la app:

```bash
flutter build web --release
```

El output estará en `build/web/`

---

## 🚀 Deployment por Plataforma

### Firebase Hosting

**Archivo:** `firebase.json` (ya incluido)

```bash
# Instalar Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Inicializar proyecto (solo la primera vez)
firebase init hosting

# Deploy
firebase deploy --only hosting
```

**Configuración clave:**
```json
{
  "rewrites": [
    {
      "source": "**",
      "destination": "/index.html"
    }
  ]
}
```

---

### Netlify

**Archivo:** `netlify.toml` (ya incluido)

**Opción 1: Deploy desde Git**
1. Conecta tu repositorio en Netlify
2. Build command: `flutter build web --release`
3. Publish directory: `build/web`
4. Deploy automático

**Opción 2: Deploy manual**
```bash
# Instalar Netlify CLI
npm install -g netlify-cli

# Deploy
netlify deploy --prod --dir=build/web
```

**Configuración clave:**
```toml
[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

---

### Vercel

**Archivo:** `vercel.json` (ya incluido)

```bash
# Instalar Vercel CLI
npm install -g vercel

# Deploy
vercel --prod
```

**Configuración clave:**
```json
{
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
}
```

---

### Apache (Hosting tradicional)

**Archivo:** `web/.htaccess` (ya incluido)

1. Sube el contenido de `build/web/` a tu servidor
2. Asegúrate de que `.htaccess` esté incluido
3. Verifica que `mod_rewrite` esté habilitado

**Habilitar mod_rewrite:**
```bash
sudo a2enmod rewrite
sudo systemctl restart apache2
```

**Configuración clave:**
```apache
RewriteRule ^ index.html [L]
```

---

### Nginx

**Archivo:** `nginx.conf` (plantilla incluida)

1. Copia la configuración a `/etc/nginx/sites-available/peliculas`
2. Ajusta las rutas y certificados SSL
3. Crea symlink: `ln -s /etc/nginx/sites-available/peliculas /etc/nginx/sites-enabled/`
4. Prueba: `sudo nginx -t`
5. Recarga: `sudo systemctl reload nginx`

**Configuración clave:**
```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

---

## 🧪 Pruebas Post-Deployment

Verifica que estas URLs funcionen correctamente:

1. **Home:** `https://tudominio.com/`
2. **Película:** `https://tudominio.com/movie/550`
3. **Share:** `https://tudominio.com/movie/550/share` ← **Crítico**
4. **Lista:** `https://tudominio.com/list/abc123/share`
5. **Navegación interna:** Navega normalmente y recarga (F5) en cualquier ruta

### ❌ Señales de Problemas

- Error 404 al recargar página
- URLs de share no funcionan
- Solo funciona la home (`/`)

### ✅ Todo Funciona

- Todas las URLs cargan correctamente
- Recargar (F5) en cualquier ruta funciona
- Compartir películas funciona
- El botón "atrás" del navegador funciona

---

## 📊 Analytics de Share

La app ahora trackea automáticamente:

1. **Accesos a URLs compartidas**
   - Evento: `share_link_accessed`
   - Datos: `movie_id`, `source`, `retry_count`

2. **Clicks en "Abrir en App"**
   - Evento: `open_in_app_clicked`
   - Datos: `movie_id`, `source`

3. **Re-compartir desde vista de share**
   - Evento: `reshare_from_share_view`
   - Datos: `movie_id`, `source`

Revisa estos eventos en Firebase Analytics o tu plataforma de analytics.

---

## 🔧 Troubleshooting

### Problema: 404 en rutas de share

**Causa:** Servidor no está redirigiendo a `index.html`

**Solución:**
1. Verifica que el archivo de configuración esté presente
2. Reinicia el servidor web
3. Limpia caché del CDN si aplica

### Problema: Funciona local pero no en producción

**Causa:** Configuración de servidor diferente

**Solución:**
1. Verifica que los archivos de configuración se hayan subido
2. Revisa logs del servidor
3. Compara con configuración de desarrollo

### Problema: Meta tags no se actualizan al compartir

**Causa:** Redes sociales cachean meta tags

**Solución:**
1. Facebook: https://developers.facebook.com/tools/debug/
2. Twitter: https://cards-dev.twitter.com/validator
3. LinkedIn: https://www.linkedin.com/post-inspector/

---

## 📚 Referencias

- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [Firebase Hosting](https://firebase.google.com/docs/hosting)
- [Netlify Docs](https://docs.netlify.com/)
- [Vercel Docs](https://vercel.com/docs)

---

## 🆘 Soporte

Si tienes problemas:

1. Verifica los logs del servidor
2. Prueba la URL en modo incógnito (sin caché)
3. Revisa la consola del navegador (F12)
4. Compara con los archivos de configuración incluidos

---

**Última actualización:** 2025-01-02
