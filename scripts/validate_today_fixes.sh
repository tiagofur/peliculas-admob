#!/bin/bash
# TODAY'S CRITICAL FIXES VALIDATION SCRIPT
# Validate all P0 critical fixes implemented today
# Usage: ./scripts/validate_today_fixes.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}✅ VALIDATING TODAY'S CRITICAL FIXES${NC}"
echo "===================================="
echo "Date: $(date)"
echo ""

# Initialize counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${YELLOW}🔍 Testing: $test_name${NC}"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# TEST 1: HomeView Startup Performance
echo -e "\n${BLUE}📊 TEST 1: HOMEVIEW STARTUP PERFORMANCE${NC}"
run_test "HomeView initialization check" "grep -q 'WidgetsBinding.instance.addPostFrameCallback' lib/presentation/screens/home_view.dart"
run_test "No synchronous operations in initState" "! grep -A 10 'void initState()' lib/presentation/screens/home_view.dart | grep -E '_load.*\(\);'"

# TEST 2: Memory Leaks
echo -e "\n${BLUE}📊 TEST 2: MEMORY LEAKS${NC}"
STATEFUL_LEAKS=$(./scripts/detect_memory_leaks.sh 2>/dev/null | grep "TOTAL POTENTIAL MEMORY LEAKS:" | awk '{print $NF}' || echo "0")
if [ "$STATEFUL_LEAKS" -eq 0 ]; then
    echo -e "${GREEN}✅ PASSED: No memory leaks detected${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAILED: $STATEFUL_LEAKS memory leaks detected${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# TEST 3: Deprecated Code
echo -e "\n${BLUE}📊 TEST 3: DEPRECATED CODE${NC}"
WITHOPACITY_COUNT=$(grep -r "\.withOpacity(" lib/ --include="*.dart" 2>/dev/null | wc -l || echo "0")
PRINT_COUNT=$(grep -r "print(" lib/ --include="*.dart" 2>/dev/null | grep -v "LoggerFactory" | wc -l || echo "0")

if [ "$WITHOPACITY_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ PASSED: No withOpacity() methods found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAILED: $WITHOPACITY_COUNT withOpacity() methods remaining${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if [ "$PRINT_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ PASSED: No print() statements found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAILED: $PRINT_COUNT print() statements remaining${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# TEST 4: Code Analysis
echo -e "\n${BLUE}📊 TEST 4: STATIC ANALYSIS${NC}"
run_test "Dart format check" "dart format --set-exit-if-changed . >/dev/null 2>&1"
run_test "Flutter analyze" "flutter analyze --no-fatal-infos >/dev/null 2>&1"

# TEST 5: Build Validation  
echo -e "\n${BLUE}📊 TEST 5: BUILD VALIDATION${NC}"
echo "Building APK (this may take a few minutes)..."
run_test "Android APK build" "timeout 600 flutter build apk --release >/dev/null 2>&1"

echo "Building Web (this may take a few minutes)..."  
run_test "Web build" "timeout 600 flutter build web --release >/dev/null 2>&1"

# TEST 6: Unit Tests
echo -e "\n${BLUE}📊 TEST 6: UNIT TESTS${NC}"
run_test "Unit tests execution" "flutter test --no-sound-null-safety --suppress-analytics >/dev/null 2>&1"

# TEST 7: Performance Benchmarks
echo -e "\n${BLUE}📊 TEST 7: PERFORMANCE METRICS${NC}"

# Check APK size
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    APK_SIZE_MB=$(du -m build/app/outputs/flutter-apk/app-release.apk | cut -f1)
    if [ "$APK_SIZE_MB" -lt 20 ]; then
        echo -e "${GREEN}✅ PASSED: APK size is ${APK_SIZE_MB}MB (target <20MB)${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  WARNING: APK size is ${APK_SIZE_MB}MB (target <20MB)${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${YELLOW}⚠️  WARNING: APK not found, skipping size check${NC}"
fi

# Check Web bundle size
if [ -d "build/web" ]; then
    WEB_SIZE_MB=$(du -sm build/web | cut -f1)
    if [ "$WEB_SIZE_MB" -lt 15 ]; then
        echo -e "${GREEN}✅ PASSED: Web bundle is ${WEB_SIZE_MB}MB (target <15MB)${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  WARNING: Web bundle is ${WEB_SIZE_MB}MB (target <15MB)${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${YELLOW}⚠️  WARNING: Web build not found, skipping size check${NC}"
fi

# SUMMARY REPORT
echo -e "\n${BLUE}📋 VALIDATION SUMMARY${NC}"
echo "======================"
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED" 
TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
PASS_RATE=$((TESTS_PASSED * 100 / TOTAL_TESTS))

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! (100%)${NC}"
    STATUS="SUCCESS"
elif [ $PASS_RATE -ge 80 ]; then
    echo -e "${YELLOW}⚠️  MOSTLY PASSING (${PASS_RATE}%)${NC}"
    STATUS="PARTIAL_SUCCESS"
else
    echo -e "${RED}❌ VALIDATION FAILED (${PASS_RATE}%)${NC}"
    STATUS="FAILURE"
fi

# Generate detailed report
REPORT_FILE="documentation/2025-09-25-audit/VALIDATION_REPORT_$(date +%Y%m%d_%H%M%S).md"
cat > "$REPORT_FILE" << EOF
# CRITICAL FIXES VALIDATION REPORT
**Date**: $(date)  
**Status**: $STATUS  
**Pass Rate**: ${PASS_RATE}%  

## Summary
- ✅ Tests Passed: $TESTS_PASSED
- ❌ Tests Failed: $TESTS_FAILED  
- 📊 Total Tests: $TOTAL_TESTS

## Test Results Detail

### Performance Metrics
- APK Size: ${APK_SIZE_MB:-"N/A"}MB
- Web Bundle: ${WEB_SIZE_MB:-"N/A"}MB
- withOpacity() instances: $WITHOPACITY_COUNT
- print() statements: $PRINT_COUNT
- Memory leaks detected: $STATEFUL_LEAKS

### Builds Status
EOF

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    echo "- ✅ Android APK: Built successfully" >> "$REPORT_FILE"
else
    echo "- ❌ Android APK: Build failed" >> "$REPORT_FILE"
fi

if [ -d "build/web" ]; then
    echo "- ✅ Web Build: Built successfully" >> "$REPORT_FILE"
else
    echo "- ❌ Web Build: Build failed" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" << EOF

## Next Actions Required
EOF

if [ $TESTS_FAILED -gt 0 ]; then
    cat >> "$REPORT_FILE" << EOF
### Critical Issues to Fix:
- Memory leaks: $STATEFUL_LEAKS remaining  
- Deprecated code: $((WITHOPACITY_COUNT + PRINT_COUNT)) instances
- Build failures: Check build logs
- Test failures: Run individual test suites

### Commands to Run:
\`\`\`bash
# Fix remaining memory leaks
./scripts/detect_memory_leaks.sh
./scripts/fix_memory_leaks.sh --fix

# Fix remaining deprecated code  
./scripts/fix_deprecated_today.sh --fix

# Re-run validation
./scripts/validate_today_fixes.sh
\`\`\`
EOF
else
    cat >> "$REPORT_FILE" << EOF
### All Critical Issues Resolved! 🎉

**Phase 1 Complete**: All P0 critical fixes have been successfully implemented and validated.

**Next Steps**:
1. Proceed to Phase 2 (Performance Optimization)  
2. Monitor metrics in production
3. Schedule Phase 2 tasks for tomorrow

**Metrics Achieved**:
- ✅ Zero memory leaks
- ✅ Zero deprecated code  
- ✅ Builds successful
- ✅ Tests passing
EOF
fi

echo -e "\n${GREEN}📄 Detailed report saved to: $REPORT_FILE${NC}"

# Set exit code based on results
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🚀 READY FOR PHASE 2 TASKS!${NC}"
    exit 0
else
    echo -e "\n${RED}⚠️  PHASE 1 INCOMPLETE - ADDRESS FAILED TESTS${NC}"
    exit 1
fi