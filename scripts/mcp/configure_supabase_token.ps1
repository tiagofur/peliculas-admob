param(
    [switch]$Persist
)

$workspaceRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$envFile = Join-Path $workspaceRoot ".env"

if (-not (Test-Path $envFile)) {
    Write-Host "❌ No se encontró el archivo .env en $workspaceRoot" -ForegroundColor Red
    exit 1
}

# Cargar líneas útiles del .env (sin comentarios ni espacios vacíos)
$envLines = Get-Content $envFile | Where-Object { $_ -and -not $_.Trim().StartsWith('#') }

function Get-EnvValue {
    param(
        [string]$Key
    )

    $line = $envLines | Where-Object { $_ -match "^$Key=" }
    if (-not $line) {
        return $null
    }

    return ($line -split '=', 2)[1].Trim()
}

$token = Get-EnvValue -Key 'SUPABASE_ACCESS_TOKEN'
if (-not $token) {
    # Intentar con clave legacy usada anteriormente
    $token = Get-EnvValue -Key 'SUPANASE_ACCESS_KEY'
}

if (-not $token) {
    Write-Host "❌ No se encontró ninguna variable SUPABASE_ACCESS_TOKEN (o SUPANASE_ACCESS_KEY) en .env" -ForegroundColor Red
    exit 1
}

$supabaseUrl = Get-EnvValue -Key 'SUPABASE_URL'
$projectRef = $null
if ($supabaseUrl) {
    try {
        $uri = [System.Uri]::new($supabaseUrl)
        $projectRef = $uri.Host.Split('.')[0]
    } catch {
        # Ignorar errores de parseo
    }
}

if ($Persist) {
    [System.Environment]::SetEnvironmentVariable('SUPABASE_ACCESS_TOKEN', $token, 'User')
    if ($projectRef) {
        [System.Environment]::SetEnvironmentVariable('SUPABASE_PROJECT_REF', $projectRef, 'User')
    }
    Write-Host "✅ Variables de entorno persistentes configuradas para el usuario actual." -ForegroundColor Green
    if ($projectRef) {
        Write-Host "   SUPABASE_PROJECT_REF=$projectRef" -ForegroundColor DarkGray
    }
    Write-Host "⚠️ Reinicia VS Code o tu terminal para que tomen efecto." -ForegroundColor Yellow
} else {
    $env:SUPABASE_ACCESS_TOKEN = $token
    if ($projectRef) {
        $env:SUPABASE_PROJECT_REF = $projectRef
    }
    Write-Host "✅ Variables de entorno disponibles en esta sesión de PowerShell." -ForegroundColor Green
    if ($projectRef) {
        Write-Host "   SUPABASE_PROJECT_REF=$projectRef" -ForegroundColor DarkGray
    }
    Write-Host "💡 Si necesitas persistirlas, ejecuta nuevamente con el parámetro -Persist." -ForegroundColor Yellow
    Write-Host "   Ejemplo: .\\scripts\\mcp\\configure_supabase_token.ps1 -Persist" -ForegroundColor DarkGray
}
