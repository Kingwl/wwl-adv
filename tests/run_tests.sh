#!/bin/bash
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}}"
if [ ! -x "$GODOT" ]; then
	if command -v godot >/dev/null 2>&1; then
		GODOT="$(command -v godot)"
	else
		echo "Godot executable not found. Set GODOT_BIN=/path/to/godot." >&2
		exit 1
	fi
fi
echo "Running WWL Adventure integration tests..."
"$GODOT" --headless --path . res://tests/auto_test.tscn --quit-after 25000 2>&1
echo "Tests finished."
