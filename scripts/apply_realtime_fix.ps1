# Script para aplicar el fix de Realtime Sync para Listas Personalizadas
# Este script ejecuta la migración 20250101_fix_realtime_sync_user_list_items.sql

Write-Host "🔧 Aplicando fix de Realtime Sync para Listas Personalizadas..." -ForegroundColor Cyan
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
$sqlFile = "supabase\migrations\20250101_fix_realtime_sync_user_list_items.sql"
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
Write-Host "  7. Verifica que veas el mensaje: '✅ All user_list_items have user_id populated'" -ForegroundColor Gray
Write-Host ""

Write-Host "OPCIÓN 2 - Supabase CLI:" -ForegroundColor White
Write-Host "  Si tienes Supabase CLI instalado:" -ForegroundColor Gray
Write-Host "  supabase db push" -ForegroundColor Yellow
Write-Host ""

Write-Host "OPCIÓN 3 - Verificar estado actual:" -ForegroundColor White
Write-Host "  Para verificar que la columna user_id existe:" -ForegroundColor Gray
Write-Host "  SELECT column_name FROM information_schema.columns WHERE table_name = 'user_list_items' AND column_name = 'user_id';" -ForegroundColor Yellow
Write-Host ""

Write-Host "⚡ Después de aplicar la migración:" -ForegroundColor Cyan
Write-Host "  1. Las listas personalizadas se sincronizarán en tiempo real" -ForegroundColor Gray
Write-Host "  2. Los cambios en las listas se reflejarán instantáneamente entre apps" -ForegroundColor Gray
Write-Host "  3. La eliminación y creación de listas funcionará correctamente" -ForegroundColor Gray
Write-Host "  4. No necesitas reiniciar la app" -ForegroundColor Gray
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
