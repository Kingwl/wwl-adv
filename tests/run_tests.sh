#!/bin/bash
set -e
cd "$(dirname "$0")/.."
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
echo "Running WWL Adventure integration tests..."
$GODOT --headless --path . res://tests/auto_test.tscn --quit-after 25000 2>&1
echo "Tests finished."
