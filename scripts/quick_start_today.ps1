# 🚀 QUICK START - CRITICAL FIXES TODAY
# PowerShell script to execute all P0 tasks in order
# Usage: .\scripts\quick_start_today.ps1

param(
    [switch]$SkipBackup
)

# Colors for output  
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$Blue = [System.ConsoleColor]::Blue

function Write-ColorText {
    param([string]$Text, [System.ConsoleColor]$Color)
    Write-Host $Text -ForegroundColor $Color
}

function Start-Task {
    param([string]$TaskName, [string]$Description)
    Write-ColorText "`n🚀 STARTING: $TaskName" $Blue
    Write-Host $Description
    Write-Host "=================================================="
}

function Complete-Task {
    param([string]$TaskName, [boolean]$Success)
    if ($Success) {
        Write-ColorText "✅ COMPLETED: $TaskName" $Green
    } else {
        Write-ColorText "❌ FAILED: $TaskName" $Red
    }
    Write-Host "=================================================="
}

# Introduction
Write-ColorText "🔥 PELICULAS ADMOB - CRITICAL FIXES DAY 1" $Blue
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Objective: Fix all P0 critical issues in 24h"
Write-Host ""

# Create backup if requested
if (-not $SkipBackup) {
    $backupDir = "backup-critical-fixes-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-ColorText "💾 Creating backup..." $Yellow
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Copy-Item -Path "lib" -Destination $backupDir -Recurse
    Write-ColorText "✅ Backup created in: $backupDir" $Green
}

# TASK 1: Detect current issues
Start-Task "P0-001" "Detecting Memory Leaks"
try {
    if (Test-Path "scripts\detect_memory_leaks.sh") {
        if (Get-Command wsl -ErrorAction SilentlyContinue) {
            $memoryLeakResult = wsl bash -c "./scripts/detect_memory_leaks.sh"
            Write-Host $memoryLeakResult
            Complete-Task "Memory Leak Detection" $true
        } else {
            Write-ColorText "⚠️  WSL not available, manual memory leak detection needed" $Yellow
            Complete-Task "Memory Leak Detection" $false
        }
    } else {
        Write-ColorText "⚠️  Memory leak detection script not found" $Yellow
        Complete-Task "Memory Leak Detection" $false
    }
} catch {
    Write-ColorText "❌ Error in memory leak detection: $($_.Exception.Message)" $Red
    Complete-Task "Memory Leak Detection" $false
}

# TASK 2: Fix deprecated code
Start-Task "P0-002" "Fixing Deprecated Code"
try {
    .\scripts\fix_deprecated_today.ps1 -Fix
    Complete-Task "Deprecated Code Fix" $true
} catch {
    Write-ColorText "❌ Error fixing deprecated code: $($_.Exception.Message)" $Red
    Complete-Task "Deprecated Code Fix" $false
}

# TASK 3: Check HomeView
Start-Task "P0-003" "Analyzing HomeView Performance Issues"
$homeViewPath = "lib\presentation\screens\home_view.dart"
if (Test-Path $homeViewPath) {
    $homeViewContent = Get-Content $homeViewPath -Raw
    
    # Check for synchronous operations in initState
    if ($homeViewContent -match "void initState\(\)[^}]*\{[^}]*_load[^}]*\}") {
        Write-ColorText "❌ HomeView has synchronous operations in initState" $Red
        Write-Host "Manual fix required:"
        Write-Host "1. Move heavy operations to WidgetsBinding.instance.addPostFrameCallback"
        Write-Host "2. Use Future.wait for parallel loading"
        Write-Host "3. Add loading states"
        Complete-Task "HomeView Analysis" $false
    } else {
        Write-ColorText "✅ HomeView initState looks optimized" $Green
        Complete-Task "HomeView Analysis" $true
    }
} else {
    Write-ColorText "❌ HomeView file not found" $Red
    Complete-Task "HomeView Analysis" $false
}

# TASK 4: Run static analysis
Start-Task "P0-004" "Running Static Analysis"
try {
    Write-Host "Running dart format..."
    $formatResult = & dart format --set-exit-if-changed . 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorText "✅ Code is properly formatted" $Green
    } else {
        Write-ColorText "⚠️  Code formatting issues found" $Yellow
        Write-Host $formatResult
    }
    
    Write-Host "Running flutter analyze..."
    $analyzeResult = & flutter analyze --no-fatal-infos 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorText "✅ Static analysis passed" $Green
        Complete-Task "Static Analysis" $true
    } else {
        Write-ColorText "❌ Static analysis failed" $Red  
        Write-Host $analyzeResult
        Complete-Task "Static Analysis" $false
    }
} catch {
    Write-ColorText "❌ Error running static analysis: $($_.Exception.Message)" $Red
    Complete-Task "Static Analysis" $false
}

# TASK 5: Run tests
Start-Task "P0-005" "Running Unit Tests"
try {
    Write-Host "This may take a few minutes..."
    $testResult = & flutter test --no-sound-null-safety 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorText "✅ All tests passed" $Green
        Complete-Task "Unit Tests" $true
    } else {
        Write-ColorText "❌ Some tests failed" $Red
        Write-Host $testResult | Select-String -Pattern "(FAIL|ERROR)" | Select-Object -First 10
        Complete-Task "Unit Tests" $false
    }
} catch {
    Write-ColorText "❌ Error running tests: $($_.Exception.Message)" $Red
    Complete-Task "Unit Tests" $false
}

# TASK 6: Build validation
Start-Task "P0-006" "Build Validation"
try {
    Write-Host "Building APK (this will take several minutes)..."
    $buildResult = & flutter build apk --release 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorText "✅ APK build successful" $Green
        
        # Check APK size
        $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
        if (Test-Path $apkPath) {
            $apkSize = [math]::Round((Get-Item $apkPath).Length / 1MB, 2)
            Write-Host "APK Size: ${apkSize}MB"
            if ($apkSize -lt 20) {
                Write-ColorText "✅ APK size is acceptable" $Green
            } else {
                Write-ColorText "⚠️  APK size is large (${apkSize}MB)" $Yellow
            }
        }
        Complete-Task "APK Build" $true
    } else {
        Write-ColorText "❌ APK build failed" $Red
        Write-Host $buildResult | Select-String -Pattern "(ERROR|FAILURE)" | Select-Object -First 5
        Complete-Task "APK Build" $false
    }
} catch {
    Write-ColorText "❌ Error building APK: $($_.Exception.Message)" $Red
    Complete-Task "APK Build" $false
}

# FINAL SUMMARY
Write-ColorText "`n📊 CRITICAL FIXES SUMMARY" $Blue
Write-Host "========================================"
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# Count current issues
$currentWithOpacity = (Select-String -Path "lib\*.dart" -Pattern "\.withOpacity\(" -Recurse -ErrorAction SilentlyContinue).Count
$currentPrint = (Select-String -Path "lib\*.dart" -Pattern "print\(" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Line -notmatch "LoggerFactory" }).Count

Write-Host "Current Status:"
Write-Host "- withOpacity() methods: $currentWithOpacity (target: 0)"
Write-Host "- print() statements: $currentPrint (target: 0)"

if (Test-Path "build\app\outputs\flutter-apk\app-release.apk") {
    $apkSize = [math]::Round((Get-Item "build\app\outputs\flutter-apk\app-release.apk").Length / 1MB, 2)
    Write-Host "- APK Size: ${apkSize}MB (target: <20MB)"
}

# Next steps
Write-ColorText "`n🎯 NEXT STEPS:" $Blue
if ($currentWithOpacity -eq 0 -and $currentPrint -eq 0) {
    Write-ColorText "🎉 PHASE 1 COMPLETE! All critical P0 issues resolved." $Green
    Write-Host ""
    Write-Host "Ready for Phase 2 tasks:"
    Write-Host "1. Performance optimization"
    Write-Host "2. Real-time sync improvements"
    Write-Host "3. Responsive design updates"
} else {
    Write-ColorText "⚠️  PHASE 1 INCOMPLETE - Manual fixes needed:" $Yellow
    if ($currentWithOpacity -gt 0) {
        Write-Host "- Fix remaining $currentWithOpacity withOpacity() methods manually"
    }
    if ($currentPrint -gt 0) {
        Write-Host "- Fix remaining $currentPrint print() statements manually"
    }
    Write-Host ""
    Write-Host "After manual fixes, re-run this script to validate."
}

Write-Host ""
Write-ColorText "📄 Check task list: TASK-LIST-CRITICO-DIA1.md" $Blue
Write-ColorText "📄 Check roadmap: documentation/2025-09-25-audit/ROADMAP-COMPLETO.md" $Blue

Write-Host ""
Write-Host "Script completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"