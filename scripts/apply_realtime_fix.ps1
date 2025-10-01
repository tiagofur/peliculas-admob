# Script para aplicar el fix de Realtime a Supabase
# Este script ejecuta la migración 20251001_fix_realtime_publications.sql

Write-Host "🔧 Aplicando fix de Realtime Publications en Supabase..." -ForegroundColor Cyan
Write-Host ""

# Verificar que existe el archivo .env
if (-Not (Test-Path ".env")) {
    Write-Host "❌ Error: No se encontró el archivo .env" -ForegroundColor Red
    Write-Host "Por favor asegúrate de tener el archivo .env en la raíz del proyecto" -ForegroundColor Yellow
    exit 1
}

# Leer las variables de entorno
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+?)\s*=\s*(.+?)\s*$') {
        $name = $matches[1]
        $value = $matches[2]
        Set-Item -Path "env:$name" -Value $value
    }
}

# Verificar que tenemos las variables necesarias
if (-Not $env:SUPABASE_URL) {
    Write-Host "❌ Error: SUPABASE_URL no está configurado en .env" -ForegroundColor Red
    exit 1
}

if (-Not $env:SUPABASE_ANON_KEY) {
    Write-Host "❌ Error: SUPABASE_ANON_KEY no está configurado en .env" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Variables de entorno cargadas" -ForegroundColor Green
Write-Host "   URL: $env:SUPABASE_URL" -ForegroundColor Gray
Write-Host ""

# Leer el archivo SQL
$sqlFile = "supabase\migrations\20251001_fix_realtime_publications.sql"
if (-Not (Test-Path $sqlFile)) {
    Write-Host "❌ Error: No se encontró el archivo de migración: $sqlFile" -ForegroundColor Red
    exit 1
}

$sqlContent = Get-Content $sqlFile -Raw
Write-Host "✅ Archivo SQL leído: $sqlFile" -ForegroundColor Green
Write-Host ""

Write-Host "⚠️  IMPORTANTE: Este script requiere acceso de ADMINISTRADOR a Supabase" -ForegroundColor Yellow
Write-Host ""
Write-Host "📋 Opciones para aplicar la migración:" -ForegroundColor Cyan
Write-Host ""
Write-Host "OPCIÓN 1 - Supabase Dashboard (RECOMENDADO):" -ForegroundColor White
Write-Host "  1. Ve a: https://supabase.com/dashboard" -ForegroundColor Gray
Write-Host "  2. Selecciona tu proyecto" -ForegroundColor Gray
Write-Host "  3. Ve a 'SQL Editor'" -ForegroundColor Gray
Write-Host "  4. Crea una nueva query" -ForegroundColor Gray
Write-Host "  5. Copia y pega el siguiente SQL:" -ForegroundColor Gray
Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor DarkGray
Write-Host $sqlContent -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  6. Ejecuta la query (Run)" -ForegroundColor Gray
Write-Host "  7. Verifica que veas el mensaje: '✅ Publication supabase_realtime created successfully'" -ForegroundColor Gray
Write-Host ""

Write-Host "OPCIÓN 2 - Supabase CLI:" -ForegroundColor White
Write-Host "  Si tienes Supabase CLI instalado:" -ForegroundColor Gray
Write-Host "  supabase db push" -ForegroundColor Yellow
Write-Host ""

Write-Host "OPCIÓN 3 - Verificar estado actual:" -ForegroundColor White
Write-Host "  Para ver qué tablas tienen Realtime habilitado:" -ForegroundColor Gray
Write-Host "  SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';" -ForegroundColor Yellow
Write-Host ""

Write-Host "⚡ Después de aplicar la migración:" -ForegroundColor Cyan
Write-Host "  1. Las calificaciones se sincronizarán en tiempo real" -ForegroundColor Gray
Write-Host "  2. Los favoritos, watchlist, y watched seguirán funcionando" -ForegroundColor Gray
Write-Host "  3. No necesitas reiniciar la app" -ForegroundColor Gray
Write-Host ""

# Copiar SQL al portapapeles si es posible
try {
    $sqlContent | Set-Clipboard
    Write-Host "✅ SQL copiado al portapapeles!" -ForegroundColor Green
    Write-Host "   Puedes pegarlo directamente en Supabase Dashboard" -ForegroundColor Gray
} catch {
    Write-Host "⚠️  No se pudo copiar al portapapeles automáticamente" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Presiona cualquier tecla para salir..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
