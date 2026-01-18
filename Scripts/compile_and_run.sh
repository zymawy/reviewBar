#!/bin/bash
# compile_and_run.sh - Quick development loop script
# Usage: ./Scripts/compile_and_run.sh

set -e

echo "🔨 Building ReviewBar..."
swift build

echo "🚀 Launching ReviewBar..."
swift run ReviewBar
