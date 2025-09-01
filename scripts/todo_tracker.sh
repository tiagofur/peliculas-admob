#!/bin/bash

# TODO Progress Tracker Script
# Usage: ./scripts/todo_tracker.sh

echo "🔍 TODO Progress Tracker"
echo "========================="
echo ""

# Count current TODOs
TODO_COUNT=$(grep -r -n "TODO:" --include="*.dart" --include="*.js" --include="*.ts" lib/ test/ | wc -l)
echo "📊 Current TODO count: $TODO_COUNT"

# Check for new TODOs since last audit
echo ""
echo "🔍 Searching for new TODOs..."
grep -r -n "TODO:" --include="*.dart" --include="*.js" --include="*.ts" lib/ test/ > /tmp/current_todos.txt

# Display TODOs by category
echo ""
echo "📂 TODOs by Category:"
echo "--------------------"

# Gamification TODOs
GAMIFICATION_TODOS=$(grep -i "gamification\|achievement\|progress\|milestone" /tmp/current_todos.txt | wc -l)
echo "🎮 Gamification: $GAMIFICATION_TODOS TODOs"

# Navigation TODOs
NAVIGATION_TODOS=$(grep -i "navigation\|navigate\|pantalla" /tmp/current_todos.txt | wc -l)
echo "🧭 Navigation: $NAVIGATION_TODOS TODOs"

# Cache/Performance TODOs
CACHE_TODOS=$(grep -i "cache\|caching\|performance" /tmp/current_todos.txt | wc -l)
echo "⚡ Cache/Performance: $CACHE_TODOS TODOs"

# Notification TODOs
NOTIFICATION_TODOS=$(grep -i "notification\|notificación" /tmp/current_todos.txt | wc -l)
echo "🔔 Notifications: $NOTIFICATION_TODOS TODOs"

echo ""
echo "📈 Progress Since Last Audit:"
echo "-----------------------------"
BASELINE=36
RESOLVED=$((BASELINE - TODO_COUNT))
PERCENTAGE=$((RESOLVED * 100 / BASELINE))

echo "✅ Resolved: $RESOLVED TODOs ($PERCENTAGE%)"
echo "⏳ Remaining: $TODO_COUNT TODOs"

# Priority breakdown
echo ""
echo "🎯 Next Priority Actions:"
echo "------------------------"
echo "1. Check gamification storage implementation"
echo "2. Verify progress streams are working"
echo "3. Test notification navigation"
echo "4. Review recent achievements display"

echo ""
echo "📅 Generated: $(date)"
echo "📋 For detailed tracking, see: docs/TODO_TRACKING_MATRIX.md"

# Clean up
rm -f /tmp/current_todos.txt