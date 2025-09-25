# DEPRECATED CODE FIXER - PowerShell Version
# Fix deprecated Flutter methods automatically  
# Usage: .\scripts\fix_deprecated_today.ps1 [-DryRun] [-Fix]

param(
    [switch]$DryRun,
    [switch]$Fix
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

Write-ColorText "🔧 DEPRECATED CODE FIXER" $Blue
Write-Host "========================="

# 1. Count deprecated methods
Write-ColorText "`n📊 ANALYZING DEPRECATED CODE..." $Yellow

$withOpacityCount = (Select-String -Path "lib\*.dart" -Pattern "\.withOpacity\(" -Recurse).Count
$withAlphaCount = (Select-String -Path "lib\*.dart" -Pattern "\.withAlpha\(" -Recurse).Count
$printCount = (Select-String -Path "lib\*.dart" -Pattern "print\(" -Recurse | Where-Object { $_.Line -notmatch "LoggerFactory" }).Count
$debugPrintCount = (Select-String -Path "lib\*.dart" -Pattern "debugPrint\(" -Recurse).Count

Write-Host "withOpacity() methods found: $withOpacityCount"
Write-Host "withAlpha() methods found: $withAlphaCount"  
Write-Host "print() statements found: $printCount"
Write-Host "debugPrint() statements found: $debugPrintCount"

$totalDeprecated = $withOpacityCount + $withAlphaCount + $printCount + $debugPrintCount
Write-ColorText "⚠️  TOTAL DEPRECATED CODE INSTANCES: $totalDeprecated" $Red

if ($totalDeprecated -eq 0) {
    Write-ColorText "✅ No deprecated code found!" $Green
    exit 0
}

# 2. Show examples
Write-ColorText "`n📋 EXAMPLES TO BE FIXED:" $Yellow
Write-Host "withOpacity examples:"
(Select-String -Path "lib\*.dart" -Pattern "\.withOpacity\(" -Recurse | Select-Object -First 3) | ForEach-Object {
    Write-Host "  $($_.Filename):$($_.LineNumber): $($_.Line.Trim())"
}

Write-Host "print examples:"
(Select-String -Path "lib\*.dart" -Pattern "print\(" -Recurse | Where-Object { $_.Line -notmatch "LoggerFactory" } | Select-Object -First 3) | ForEach-Object {
    Write-Host "  $($_.Filename):$($_.LineNumber): $($_.Line.Trim())"
}

# 3. Apply fixes or show what would be done  
if ($DryRun -and -not $Fix) {
    Write-ColorText "`n🔍 DRY RUN MODE - No changes will be made" $Yellow
    Write-Host "To apply fixes, run: .\scripts\fix_deprecated_today.ps1 -Fix"
    exit 0
}

if ($Fix) {
    Write-ColorText "`n🔧 APPLYING FIXES..." $Green
    
    # Create backup
    $backupDir = "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Copy-Item -Path "lib" -Destination $backupDir -Recurse
    Write-Host "Backup created in: $backupDir"
    
    # Get all Dart files
    $dartFiles = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse
    
    # Fix 1: withOpacity() → withValues(alpha:)
    Write-Host "Fixing withOpacity() methods..."
    foreach ($file in $dartFiles) {
        $content = Get-Content $file.FullName -Raw
        $newContent = $content -replace '\.withOpacity\(([^)]+)\)', '.withValues(alpha: $1)'
        if ($content -ne $newContent) {
            Set-Content -Path $file.FullName -Value $newContent -NoNewline
        }
    }
    
    # Fix 2: withAlpha() → withValues(alpha: value/255.0)  
    Write-Host "Fixing withAlpha() methods..."
    foreach ($file in $dartFiles) {
        $content = Get-Content $file.FullName -Raw
        $newContent = $content -replace '\.withAlpha\(([^)]+)\)', '.withValues(alpha: $1/255.0)'
        if ($content -ne $newContent) {
            Set-Content -Path $file.FullName -Value $newContent -NoNewline
        }
    }
    
    # Fix 3: print() → LoggerFactory.debug()
    Write-Host "Fixing print() statements..."
    foreach ($file in $dartFiles) {
        $content = Get-Content $file.FullName -Raw
        $newContent = $content -replace 'print\(', 'LoggerFactory.debug('
        if ($content -ne $newContent) {
            Set-Content -Path $file.FullName -Value $newContent -NoNewline
        }
    }
    
    # Fix 4: debugPrint() → LoggerFactory.debug()
    Write-Host "Fixing debugPrint() statements..."  
    foreach ($file in $dartFiles) {
        $content = Get-Content $file.FullName -Raw
        $newContent = $content -replace 'debugPrint\(', 'LoggerFactory.debug('
        if ($content -ne $newContent) {
            Set-Content -Path $file.FullName -Value $newContent -NoNewline
        }
    }
    
    # Add LoggerFactory imports where needed
    Write-Host "Adding LoggerFactory imports where needed..."
    $filesWithLogger = Select-String -Path "lib\*.dart" -Pattern "LoggerFactory\." -Recurse | Select-Object -ExpandProperty Path | Sort-Object | Get-Unique
    
    foreach ($filePath in $filesWithLogger) {
        $content = Get-Content $filePath -Raw
        if ($content -notmatch "import.*logger_factory") {
            # Add import after existing imports
            $lines = Get-Content $filePath
            $importIndex = -1
            for ($i = 0; $i -lt $lines.Length; $i++) {
                if ($lines[$i] -match "^import ") {
                    $importIndex = $i
                }
            }
            if ($importIndex -ge 0) {
                $newLines = $lines[0..$importIndex] + "import '../../core/logging/logger_factory.dart';" + $lines[($importIndex+1)..($lines.Length-1)]
                Set-Content -Path $filePath -Value $newLines
            }
        }
    }
    
    # 4. Validate fixes
    Write-ColorText "`n📊 VALIDATION AFTER FIXES..." $Yellow
    
    $newWithOpacity = (Select-String -Path "lib\*.dart" -Pattern "\.withOpacity\(" -Recurse).Count
    $newWithAlpha = (Select-String -Path "lib\*.dart" -Pattern "\.withAlpha\(" -Recurse).Count
    $newPrint = (Select-String -Path "lib\*.dart" -Pattern "print\(" -Recurse | Where-Object { $_.Line -notmatch "LoggerFactory" }).Count
    $newDebugPrint = (Select-String -Path "lib\*.dart" -Pattern "debugPrint\(" -Recurse).Count
    
    Write-Host "withOpacity() remaining: $newWithOpacity (was $withOpacityCount)"
    Write-Host "withAlpha() remaining: $newWithAlpha (was $withAlphaCount)"
    Write-Host "print() remaining: $newPrint (was $printCount)"
    Write-Host "debugPrint() remaining: $newDebugPrint (was $debugPrintCount)"
    
    $totalFixed = ($withOpacityCount - $newWithOpacity) + ($withAlphaCount - $newWithAlpha) + ($printCount - $newPrint) + ($debugPrintCount - $newDebugPrint)
    $totalRemaining = $newWithOpacity + $newWithAlpha + $newPrint + $newDebugPrint
    
    Write-ColorText "✅ FIXED: $totalFixed deprecated instances" $Green
    if ($totalRemaining -eq 0) {
        Write-ColorText "🎉 ALL DEPRECATED CODE FIXED!" $Green
    } else {
        Write-ColorText "⚠️  REMAINING: $totalRemaining instances (may need manual review)" $Yellow
    }
    
    # 5. Generate report
    $reportFile = "documentation\2025-09-25-audit\DEPRECATED_FIXES_REPORT.md"
    $reportContent = @"
# DEPRECATED CODE FIXES REPORT
Generated: $(Get-Date)

## Summary
- **withOpacity() fixed**: $($withOpacityCount - $newWithOpacity) of $withOpacityCount
- **withAlpha() fixed**: $($withAlphaCount - $newWithAlpha) of $withAlphaCount  
- **print() fixed**: $($printCount - $newPrint) of $printCount
- **debugPrint() fixed**: $($debugPrintCount - $newDebugPrint) of $debugPrintCount

**TOTAL FIXED**: $totalFixed
**REMAINING**: $totalRemaining

## Changes Applied
1. `.withOpacity(x)` → `.withValues(alpha: x)`
2. `.withAlpha(x)` → `.withValues(alpha: x/255.0)`
3. `print()` → `LoggerFactory.debug()`
4. `debugPrint()` → `LoggerFactory.debug()`

## Next Steps
- Run `flutter analyze` to check for any issues
- Run `flutter test` to ensure no regressions  
- Review any remaining deprecated code manually

## Backup Location
Backup saved in: $backupDir
"@
    
    Set-Content -Path $reportFile -Value $reportContent
    Write-ColorText "📄 Report saved to: $reportFile" $Green
    
    # 6. Quick validation
    Write-ColorText "`n🔍 RUNNING QUICK VALIDATION..." $Yellow
    
    # Check if code still compiles
    try {
        $analyzeResult = & flutter analyze --no-fatal-infos 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorText "✅ Code analysis passed" $Green
        } else {
            Write-ColorText "❌ Code analysis failed - manual review needed" $Red
        }
    } catch {
        Write-ColorText "❌ Could not run flutter analyze" $Red  
    }
    
    Write-ColorText "`n🎯 NEXT STEPS:" $Blue
    Write-Host "1. Run: flutter analyze --fatal-warnings"
    Write-Host "2. Run: flutter test"
    Write-Host "3. Run: flutter build apk --release"
    Write-Host "4. Review any remaining deprecated code manually"
    
} else {
    Write-ColorText "`n💡 To fix deprecated code, run:" $Yellow
    Write-Host ".\scripts\fix_deprecated_today.ps1 -Fix"
    Write-Host ""
    Write-ColorText "💡 To see what would be changed, run:" $Yellow  
    Write-Host ".\scripts\fix_deprecated_today.ps1 -DryRun"
}