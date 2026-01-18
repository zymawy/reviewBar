#!/bin/bash
# run_tests.sh - Run all tests
# Usage: ./Scripts/run_tests.sh

set -e

echo "🧪 Running tests..."
swift test

echo "✅ All tests passed!"
