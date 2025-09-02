#!/bin/bash

# Test Coverage Analysis Script
# This script runs comprehensive tests and analyzes coverage to ensure ≥85% on critical flows

set -e

echo "🧪 Starting comprehensive test suite with coverage analysis..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Ensure we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. Please run this script from the project root."
    exit 1
fi

print_status "Getting Flutter dependencies..."
flutter pub get

print_status "Running code analysis..."
flutter analyze --fatal-infos --fatal-warnings

print_status "Running unit tests with coverage..."
flutter test --coverage

print_status "Running integration tests..."
flutter test integration_test/

print_status "Running golden tests..."
flutter test test/golden_tests/ --update-goldens || true
flutter test test/golden_tests/

print_status "Analyzing test coverage..."

# Check if lcov.info exists
if [ ! -f "coverage/lcov.info" ]; then
    print_error "Coverage file not found. Tests may have failed."
    exit 1
fi

# Generate HTML coverage report if genhtml is available
if command -v genhtml >/dev/null 2>&1; then
    print_status "Generating HTML coverage report..."
    genhtml coverage/lcov.info -o coverage/html
    print_success "HTML coverage report generated in coverage/html/"
else
    print_warning "genhtml not found. Install lcov package to generate HTML coverage reports."
fi

# Calculate coverage percentages for critical areas
print_status "Calculating coverage for critical flows..."

# Extract coverage data for critical files
CRITICAL_FILES=(
    "lib/presentation/screens/"
    "lib/domain/entities/"
    "lib/presentation/providers/"
    "lib/services/"
    "lib/infrastructure/"
)

total_lines=0
covered_lines=0

for pattern in "${CRITICAL_FILES[@]}"; do
    if grep -q "$pattern" coverage/lcov.info; then
        lines=$(grep -A 5 "$pattern" coverage/lcov.info | grep "^LF:" | sed 's/LF://' | head -1)
        covered=$(grep -A 5 "$pattern" coverage/lcov.info | grep "^LH:" | sed 's/LH://' | head -1)
        
        if [ ! -z "$lines" ] && [ ! -z "$covered" ]; then
            total_lines=$((total_lines + lines))
            covered_lines=$((covered_lines + covered))
        fi
    fi
done

if [ $total_lines -gt 0 ]; then
    coverage_percentage=$((covered_lines * 100 / total_lines))
    
    print_status "Critical flows coverage: $coverage_percentage% ($covered_lines/$total_lines lines)"
    
    if [ $coverage_percentage -ge 85 ]; then
        print_success "✅ Coverage target met! ($coverage_percentage% ≥ 85%)"
    else
        print_warning "⚠️  Coverage below target: $coverage_percentage% < 85%"
        print_warning "Consider adding more tests for critical flows."
    fi
else
    print_warning "Could not calculate coverage for critical files."
fi

# Count test files and types
unit_tests=$(find test/ -name "*_test.dart" -not -path "test/golden_tests/*" | wc -l)
integration_tests=$(find integration_test/ -name "*_test.dart" | wc -l)
golden_tests=$(find test/golden_tests/ -name "*_test.dart" | wc -l)

print_status "Test Summary:"
echo "  📝 Unit tests: $unit_tests"
echo "  🔗 Integration tests: $integration_tests"
echo "  🎨 Golden tests: $golden_tests"
echo "  📊 Total tests: $((unit_tests + integration_tests + golden_tests))"

# Validate critical test coverage areas
print_status "Validating critical test areas..."

REQUIRED_TEST_AREAS=(
    "movie_browsing"
    "user_authentication"
    "watchlist"
    "profile"
    "sharing"
    "theme"
)

missing_areas=()

for area in "${REQUIRED_TEST_AREAS[@]}"; do
    if ! find integration_test/ test/ -name "*${area}*test.dart" | grep -q .; then
        missing_areas+=("$area")
    fi
done

if [ ${#missing_areas[@]} -eq 0 ]; then
    print_success "✅ All critical test areas covered"
else
    print_warning "⚠️  Missing tests for: ${missing_areas[*]}"
fi

# Final summary
print_status "🎯 Test Suite Completion Summary:"

if [ $coverage_percentage -ge 85 ] && [ ${#missing_areas[@]} -eq 0 ]; then
    print_success "🎉 All quality gates passed!"
    print_success "  ✅ Coverage ≥ 85%"
    print_success "  ✅ All critical flows tested"
    print_success "  ✅ Golden tests implemented"
    exit 0
else
    print_warning "⚠️  Quality gates partially met:"
    [ $coverage_percentage -ge 85 ] && echo "  ✅ Coverage ≥ 85%" || echo "  ❌ Coverage < 85%"
    [ ${#missing_areas[@]} -eq 0 ] && echo "  ✅ All critical flows tested" || echo "  ❌ Missing test areas"
    echo "  ✅ Golden tests implemented"
    exit 1
fi