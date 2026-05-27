#!/bin/bash
# Build Sleepless.app
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "Compiling Sleepless..."
swiftc -O -o Sleepless Sleepless.swift -framework AppKit -framework IOKit

mkdir -p Sleepless.app/Contents/MacOS
cp Sleepless Sleepless.app/Contents/MacOS/Sleepless

echo "Built Sleepless.app"
echo ""
echo "To install, run:"
echo "  cp -r Sleepless.app /Applications/"
echo ""
echo "To start on login: System Settings > General > Login Items > add Sleepless"
