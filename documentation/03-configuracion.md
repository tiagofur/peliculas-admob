# 3. Configuración del Entorno de Desarrollo

## 3.1 Prerrequisitos

- Flutter SDK >= 3.0.0 (incluye Dart SDK)
- Git
- Node.js (para scripts opcionales)
- Acceso a Supabase (URL y ANON_KEY)

## 3.2 Clonar Repositorio y Configuración Inicial

```powershell
# Clonar
git clone https://github.com/tiagofur/peliculas-admob.git
cd peliculas-admob-clean

# Configurar variables de entorno
cp .env.example .env
# Editar .env con SUPABASE_URL y SUPABASE_ANON_KEY
```

## 3.3 Instalación de Dependencias

```powershell
# Obtener paquetes
flutter pub get

# Verificar instalación
flutter doctor
```

## 3.4 Scripts de Configuración

- `./scripts/setup_dev.sh` : configura herramientas y entornos locales
- `./scripts/quality_check.sh` : análisis, formateo y pruebas rápidas

## 3.5 Variables de Entorno

- `THEMOVIEDB_KEY`
- `TRAKT_CLIENT_ID`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
