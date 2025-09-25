#!/bin/bash
# DEPRECATED CODE FIXER SCRIPT  
# Fix deprecated Flutter methods automatically
# Usage: ./scripts/fix_deprecated_today.sh [--dry-run|--fix]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DRY_RUN=false
if [ "$1" == "--dry-run" ]; then
    DRY_RUN=true
fi

echo -e "${BLUE}🔧 DEPRECATED CODE FIXER${NC}"
echo "========================="

# 1. Count deprecated methods
echo -e "\n${YELLOW}📊 ANALYZING DEPRECATED CODE...${NC}"

WITHOPACITY_COUNT=$(grep -r "\.withOpacity(" lib/ --include="*.dart" | wc -l)
WITHALPHA_COUNT=$(grep -r "\.withAlpha(" lib/ --include="*.dart" | wc -l)
PRINT_COUNT=$(grep -r "print(" lib/ --include="*.dart" | grep -v "LoggerFactory" | wc -l)
DEBUGPRINT_COUNT=$(grep -r "debugPrint(" lib/ --include="*.dart" | wc -l)

echo "withOpacity() methods found: $WITHOPACITY_COUNT"
echo "withAlpha() methods found: $WITHALPHA_COUNT"
echo "print() statements found: $PRINT_COUNT"
echo "debugPrint() statements found: $DEBUGPRINT_COUNT"

TOTAL_DEPRECATED=$((WITHOPACITY_COUNT + WITHALPHA_COUNT + PRINT_COUNT + DEBUGPRINT_COUNT))
echo -e "${RED}⚠️  TOTAL DEPRECATED CODE INSTANCES: $TOTAL_DEPRECATED${NC}"

if [ $TOTAL_DEPRECATED -eq 0 ]; then
    echo -e "${GREEN}✅ No deprecated code found!${NC}"
    exit 0
fi

# 2. Show examples before fixing
echo -e "\n${YELLOW}📋 EXAMPLES TO BE FIXED:${NC}"
echo "withOpacity examples:"
grep -r "\.withOpacity(" lib/ --include="*.dart" | head -3 | while read line; do
    echo "  $line"
done

echo "print examples:"
grep -r "print(" lib/ --include="*.dart" | grep -v "LoggerFactory" | head -3 | while read line; do
    echo "  $line"
done

# 3. Apply fixes or show what would be done
if [ "$DRY_RUN" == "true" ] && [ "$1" != "--fix" ]; then
    echo -e "\n${YELLOW}🔍 DRY RUN MODE - No changes will be made${NC}"
    echo "To apply fixes, run: ./scripts/fix_deprecated_today.sh --fix"
    exit 0
fi

if [ "$1" == "--fix" ]; then
    echo -e "\n${GREEN}🔧 APPLYING FIXES...${NC}"
    
    # Create backup
    BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r lib/ "$BACKUP_DIR/"
    echo "Backup created in: $BACKUP_DIR"
    
    # Fix 1: withOpacity() → withValues(alpha:)
    echo "Fixing withOpacity() methods..."
    find lib/ -name "*.dart" -exec sed -i.bak 's/\.withOpacity(\([^)]*\))/.withValues(alpha: \1)/g' {} \;
    
    # Fix 2: withAlpha() → withValues(alpha: value/255.0)
    echo "Fixing withAlpha() methods..."
    find lib/ -name "*.dart" -exec sed -i.bak 's/\.withAlpha(\([^)]*\))/.withValues(alpha: \1\/255.0)/g' {} \;
    
    # Fix 3: print() → LoggerFactory.debug()
    echo "Fixing print() statements..."
    find lib/ -name "*.dart" -exec sed -i.bak 's/print(/LoggerFactory.debug(/g' {} \;
    
    # Fix 4: debugPrint() → LoggerFactory.debug()  
    echo "Fixing debugPrint() statements..."
    find lib/ -name "*.dart" -exec sed -i.bak 's/debugPrint(/LoggerFactory.debug(/g' {} \;
    
    # Clean up .bak files
    find lib/ -name "*.bak" -delete
    
    # Check if LoggerFactory import is needed
    echo "Adding LoggerFactory imports where needed..."
    grep -r "LoggerFactory\." lib/ --include="*.dart" -l | while read file; do
        if ! grep -q "import.*logger_factory" "$file"; then
            # Add import at the top after existing imports
            sed -i "1i import '../../core/logging/logger_factory.dart';" "$file"
        fi
    done
    
    # 4. Validate fixes
    echo -e "\n${YELLOW}📊 VALIDATION AFTER FIXES...${NC}"
    
    NEW_WITHOPACITY=$(grep -r "\.withOpacity(" lib/ --include="*.dart" | wc -l)
    NEW_WITHALPHA=$(grep -r "\.withAlpha(" lib/ --include="*.dart" | wc -l)  
    NEW_PRINT=$(grep -r "print(" lib/ --include="*.dart" | grep -v "LoggerFactory" | wc -l)
    NEW_DEBUGPRINT=$(grep -r "debugPrint(" lib/ --include="*.dart" | wc -l)
    
    echo "withOpacity() remaining: $NEW_WITHOPACITY (was $WITHOPACITY_COUNT)"
    echo "withAlpha() remaining: $NEW_WITHALPHA (was $WITHALPHA_COUNT)"
    echo "print() remaining: $NEW_PRINT (was $PRINT_COUNT)"
    echo "debugPrint() remaining: $NEW_DEBUGPRINT (was $DEBUGPRINT_COUNT)"
    
    TOTAL_FIXED=$((WITHOPACITY_COUNT - NEW_WITHOPACITY + WITHALPHA_COUNT - NEW_WITHALPHA + PRINT_COUNT - NEW_PRINT + DEBUGPRINT_COUNT - NEW_DEBUGPRINT))
    TOTAL_REMAINING=$((NEW_WITHOPACITY + NEW_WITHALPHA + NEW_PRINT + NEW_DEBUGPRINT))
    
    echo -e "\n${GREEN}✅ FIXED: $TOTAL_FIXED deprecated instances${NC}"
    if [ $TOTAL_REMAINING -eq 0 ]; then
        echo -e "${GREEN}🎉 ALL DEPRECATED CODE FIXED!${NC}"
    else
        echo -e "${YELLOW}⚠️  REMAINING: $TOTAL_REMAINING instances (may need manual review)${NC}"
    fi
    
    # 5. Generate report
    REPORT_FILE="documentation/2025-09-25-audit/DEPRECATED_FIXES_REPORT.md"
    cat > "$REPORT_FILE" << EOF
# DEPRECATED CODE FIXES REPORT
Generated: $(date)

## Summary
- **withOpacity() fixed**: $(($WITHOPACITY_COUNT - $NEW_WITHOPACITY)) of $WITHOPACITY_COUNT
- **withAlpha() fixed**: $(($WITHALPHA_COUNT - $NEW_WITHALPHA)) of $WITHALPHA_COUNT
- **print() fixed**: $(($PRINT_COUNT - $NEW_PRINT)) of $PRINT_COUNT
- **debugPrint() fixed**: $(($DEBUGPRINT_COUNT - $NEW_DEBUGPRINT)) of $DEBUGPRINT_COUNT

**TOTAL FIXED**: $TOTAL_FIXED
**REMAINING**: $TOTAL_REMAINING

## Changes Applied
1. \`.withOpacity(x)\` → \`.withValues(alpha: x)\`
2. \`.withAlpha(x)\` → \`.withValues(alpha: x/255.0)\`
3. \`print()\` → \`LoggerFactory.debug()\`
4. \`debugPrint()\` → \`LoggerFactory.debug()\`

## Next Steps
- Run \`flutter analyze\` to check for any issues
- Run \`flutter test\` to ensure no regressions
- Review any remaining deprecated code manually

## Backup Location
Backup saved in: $BACKUP_DIR
EOF
    
    echo -e "\n${GREEN}📄 Report saved to: $REPORT_FILE${NC}"
    
    # 6. Run quick validation
    echo -e "\n${YELLOW}🔍 RUNNING QUICK VALIDATION...${NC}"
    
    # Check if code still compiles
    if flutter analyze --no-fatal-infos >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Code analysis passed${NC}"
    else
        echo -e "${RED}❌ Code analysis failed - manual review needed${NC}"
    fi
    
    echo -e "\n${BLUE}🎯 NEXT STEPS:${NC}"
    echo "1. Run: flutter analyze --fatal-warnings"
    echo "2. Run: flutter test"  
    echo "3. Run: flutter build apk --release"
    echo "4. Review any remaining deprecated code manually"
    
else
    echo -e "\n${YELLOW}💡 To fix deprecated code, run:${NC}"
    echo "./scripts/fix_deprecated_today.sh --fix"
    echo ""
    echo -e "${YELLOW}💡 To see what would be changed, run:${NC}"
    echo "./scripts/fix_deprecated_today.sh --dry-run"
fi

exit 0