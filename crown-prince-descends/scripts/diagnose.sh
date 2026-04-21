#!/usr/bin/env bash
# diagnose.sh — Quick test for MinGW bash compatibility
# Just run: bash diagnose.sh
echo "=== Crown Prince Engine — MinGW Diagnosis ==="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE=""
if [[ -f "$SCRIPT_DIR/crown-prince-engine.sh" ]]; then
    ENGINE="$SCRIPT_DIR/crown-prince-engine.sh"
fi

if [[ -z "$ENGINE" ]]; then
    echo "ERROR: crown-prince-engine.sh not found next to this script"
    exit 1
fi

echo "Engine path: $ENGINE"
echo "Bash: $BASH_VERSION"
echo ""

# Test 1: Direct call
echo "Test 1: Direct call..."
bash "$ENGINE" version 2>&1
echo ""

# Test 2: Function with "$@"
echo "Test 2: Function call..."
run_engine() { bash "$ENGINE" "$@" 2>&1; }
OUTPUT=$(run_engine version)
echo "OUTPUT='$OUTPUT'"
echo "$OUTPUT" | grep -q "3.0" && echo "PASS: version matched" || echo "FAIL: version not matched"
echo ""

# Test 3: Function with init
echo "Test 3: Init via function..."
OUTPUT=$(run_engine init diag-test "hello world")
echo "OUTPUT='$OUTPUT'"
echo "$OUTPUT" | grep -q "initialized" && echo "PASS: init worked" || echo "FAIL: init failed"
echo ""

# Test 4: State check
echo "Test 4: State file..."
if [[ -f .crown-prince/diag-test/state.json ]]; then
    echo "PASS: state.json exists"
    cat .crown-prince/diag-test/state.json
else
    echo "FAIL: state.json missing"
fi

rm -rf .crown-prince
echo ""
echo "=== Done ==="
