#!/bin/bash
# MEMORY LEAK DETECTOR SCRIPT
# Detect potential memory leaks in Flutter code
# Usage: ./scripts/detect_memory_leaks.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 DETECTING MEMORY LEAKS IN PELICULAS ADMOB${NC}"
echo "=============================================="

# 1. StatefulWidgets without dispose()
echo -e "\n${YELLOW}📋 StatefulWidgets potentially missing dispose():${NC}"
STATEFUL_NO_DISPOSE=()
while IFS= read -r -d '' file; do
    if grep -q "StatefulWidget" "$file" && ! grep -q "dispose()" "$file"; then
        if grep -q "StreamSubscription\|AnimationController\|Timer\|_.*subscription\|_.*controller" "$file"; then
            STATEFUL_NO_DISPOSE+=("$file")
            echo -e "${RED}❌ $file${NC}"
        fi
    fi
done < <(find lib/ -name "*.dart" -print0)

# 2. StreamSubscriptions without cancel()
echo -e "\n${YELLOW}📋 StreamSubscriptions potentially not cancelled:${NC}"
STREAM_NO_CANCEL=()
while IFS= read -r -d '' file; do
    if grep -q "StreamSubscription" "$file" && ! grep -q "cancel()" "$file"; then
        STREAM_NO_CANCEL+=("$file")
        echo -e "${RED}❌ $file${NC}"
    fi
done < <(find lib/ -name "*.dart" -print0)

# 3. AnimationControllers without dispose()
echo -e "\n${YELLOW}📋 AnimationControllers potentially not disposed:${NC}"
ANIM_NO_DISPOSE=()
while IFS= read -r -d '' file; do
    if grep -q "AnimationController" "$file" && ! grep -q "dispose()" "$file"; then
        ANIM_NO_DISPOSE+=("$file")
        echo -e "${RED}❌ $file${NC}"
    fi
done < <(find lib/ -name "*.dart" -print0)

# 4. Timers without cancel()
echo -e "\n${YELLOW}📋 Timers potentially not cancelled:${NC}"
TIMER_NO_CANCEL=()
while IFS= read -r -d '' file; do
    if grep -q "Timer\." "$file" && ! grep -q "cancel()" "$file"; then
        TIMER_NO_CANCEL+=("$file")
        echo -e "${RED}❌ $file${NC}"
    fi
done < <(find lib/ -name "*.dart" -print0)

# 5. Generate detailed report
echo -e "\n${BLUE}📊 SUMMARY REPORT${NC}"
echo "===================="
echo "StatefulWidgets missing dispose: ${#STATEFUL_NO_DISPOSE[@]}"
echo "StreamSubscriptions not cancelled: ${#STREAM_NO_CANCEL[@]}"
echo "AnimationControllers not disposed: ${#ANIM_NO_DISPOSE[@]}"
echo "Timers not cancelled: ${#TIMER_NO_CANCEL[@]}"

TOTAL_LEAKS=$((${#STATEFUL_NO_DISPOSE[@]} + ${#STREAM_NO_CANCEL[@]} + ${#ANIM_NO_DISPOSE[@]} + ${#TIMER_NO_CANCEL[@]}))
echo -e "\n${RED}⚠️  TOTAL POTENTIAL MEMORY LEAKS: $TOTAL_LEAKS${NC}"

# 6. Generate detailed report file
REPORT_FILE="documentation/2025-09-25-audit/MEMORY_LEAKS_DETAILED.md"
cat > "$REPORT_FILE" << EOF
# MEMORY LEAKS DETAILED REPORT
Generated: $(date)

## Summary
- StatefulWidgets missing dispose: ${#STATEFUL_NO_DISPOSE[@]}
- StreamSubscriptions not cancelled: ${#STREAM_NO_CANCEL[@]}  
- AnimationControllers not disposed: ${#ANIM_NO_DISPOSE[@]}
- Timers not cancelled: ${#TIMER_NO_CANCEL[@]}
- **TOTAL POTENTIAL LEAKS: $TOTAL_LEAKS**

## StatefulWidgets Missing Dispose
EOF

for file in "${STATEFUL_NO_DISPOSE[@]}"; do
    echo "- \`$file\`" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" << EOF

## StreamSubscriptions Not Cancelled
EOF

for file in "${STREAM_NO_CANCEL[@]}"; do
    echo "- \`$file\`" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" << EOF

## AnimationControllers Not Disposed
EOF

for file in "${ANIM_NO_DISPOSE[@]}"; do
    echo "- \`$file\`" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" << EOF

## Timers Not Cancelled
EOF

for file in "${TIMER_NO_CANCEL[@]}"; do
    echo "- \`$file\`" >> "$REPORT_FILE"
done

echo -e "\n${GREEN}📄 Detailed report saved to: $REPORT_FILE${NC}"

# 7. Recommendations
if [ $TOTAL_LEAKS -gt 0 ]; then
    echo -e "\n${YELLOW}💡 RECOMMENDATIONS:${NC}"
    echo "1. Add dispose() method to StatefulWidgets"
    echo "2. Call subscription?.cancel() in dispose()"
    echo "3. Call controller.dispose() in dispose()"
    echo "4. Call timer?.cancel() in dispose()"
    echo ""
    echo -e "${BLUE}🔧 Auto-fix available: ./scripts/fix_memory_leaks.sh${NC}"
else
    echo -e "\n${GREEN}✅ No memory leaks detected!${NC}"
fi

exit 0