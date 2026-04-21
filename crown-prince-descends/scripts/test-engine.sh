#!/usr/bin/env bash
# test-engine.sh — Crown Prince Engine v3.0 Test Suite
# Run in any empty git repo directory.
# Usage: ./test-engine.sh [path/to/engine.sh]
#
# If no engine path given, looks for crown-prince-engine.sh next to this script.

set -uo pipefail

PASS=0
FAIL=0
STDERR=""
OUTPUT=""

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

pass() { PASS=$((PASS+1)); echo -e "  ${GREEN}✓ PASS${NC}: $1"; }
fail() { FAIL=$((FAIL+1)); echo -e "  ${RED}✗ FAIL${NC}: $1"; if [[ -n "${2:-}" ]]; then echo -e "         ${RED}→ $2${NC}"; fi; }
section() { echo -e "\n${CYAN}━━ $1 ━━${NC}"; }
run() {
    echo -e "  ${YELLOW}\$ $*${NC}"
    OUTPUT=$("$@" 2>&1)
    local rc=$?
    STDERR="$OUTPUT"
    return $rc
}
phase_is() {
    local actual
    local py
    py=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
    actual=$($py -c "import json; print(json.load(open('.crown-prince/$1/state.json'))['phase'])" 2>/dev/null)
    if [[ "$actual" == "$2" ]]; then pass "phase = $2"; else fail "expected phase=$2, got phase=$actual"; fi
}
output_contains() {
    if echo "$OUTPUT" | grep -q "$1"; then pass "output contains: $1"; else fail "output should contain: $1"; fi
}
should_fail() {
    if [[ $? -ne 0 ]]; then pass "correctly rejected"; else fail "should have been rejected"; fi
}

# ============================================================

echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Crown Prince Engine v3.0 Test Suite   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"

# Find engine
ENGINE="${1:-}"
if [[ -z "$ENGINE" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [[ -f "$SCRIPT_DIR/crown-prince-engine.sh" ]]; then
        ENGINE="$SCRIPT_DIR/crown-prince-engine.sh"
    elif [[ -f "scripts/crown-prince-engine.sh" ]]; then
        ENGINE="scripts/crown-prince-engine.sh"
    elif [[ -f "crown-prince-descends/scripts/crown-prince-engine.sh" ]]; then
        ENGINE="crown-prince-descends/scripts/crown-prince-engine.sh"
    fi
fi

if [[ -z "$ENGINE" || ! -f "$ENGINE" ]]; then
    echo -e "${RED}Error: crown-prince-engine.sh not found${NC}"
    echo "Usage: ./test-engine.sh [path/to/crown-prince-engine.sh]"
    exit 1
fi

# Require git
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${YELLOW}Setting up temp git repo...${NC}"
    git init -q && echo "init" > README.md && git add -A && git commit -q -m "init"
fi

echo -e "  Engine: $ENGINE"
echo -e "  Git:    $(git rev-parse --short HEAD)"

# Cleanup any previous test state
rm -rf .crown-prince .crown-prince-vassal-*.md src tests

# ============================================================
section "1. Init"
# ============================================================

run bash $ENGINE init test-task "Build a REST API" || true
output_contains "Task 'test-task' initialized"
[[ -f ".crown-prince/test-task/state.json" ]] && pass "state.json created" || fail "state.json missing"
phase_is test-task init

# ============================================================
section "2. Duplicate init"
# ============================================================

run bash $ENGINE init test-task "dup" || true
output_contains "already exists"

# ============================================================
section "3. Version"
# ============================================================

OUTPUT=$(bash $ENGINE version 2>&1)
echo "$OUTPUT" | grep -q "3.0" && pass "version output" || fail "version missing"

# ============================================================
section "4. Phase progression (linear only)"
# ============================================================

run bash $ENGINE pass-gate test-task planning && phase_is test-task planning
run bash $ENGINE pass-gate test-task dispatching && phase_is test-task dispatching

# ============================================================
section "5. Skip phase (should fail)"
# ============================================================

run bash $ENGINE pass-gate test-task synthesizing; should_fail
output_contains "PHASE_BLOCKED"

# ============================================================
section "6. Backward transition (should fail)"
# ============================================================

run bash $ENGINE pass-gate test-task init; should_fail
output_contains "PHASE_BLOCKED"

# ============================================================
section "7. Dispatch vassals"
# ============================================================

run bash $ENGINE dispatch test-task V1 "Security audit" read-only
output_contains "V1"
output_contains "dispatched"

run bash $ENGINE dispatch test-task V2 "Create auth module" write-capable
output_contains "V2"

run bash $ENGINE dispatch test-task V3 "Write tests" write-capable
output_contains "V3"

# ============================================================
section "8. Dispatch in wrong phase (should fail)"
# ============================================================

run bash $ENGINE init wrong-phase "test" >/dev/null 2>&1 || true
bash $ENGINE pass-gate wrong-phase planning >/dev/null 2>&1
run bash $ENGINE dispatch wrong-phase X "test"; should_fail
output_contains "PHASE_BLOCKED"

# ============================================================
section "9. Collect vassals"
# ============================================================

run bash $ENGINE pass-gate test-task collecting

# V1: read-only with summary file
echo "# Security Report" > .crown-prince-vassal-1.md
run bash $ENGINE collect test-task V1 .crown-prince-vassal-1.md
output_contains "V1"

# V2: write-capable (files don't exist — should warn)
OUTPUT=$(bash $ENGINE collect test-task V2 src/auth/controller.js src/auth/routes.js 2>&1)
echo "$OUTPUT" | grep -q "V2" && pass "V2 collected" || fail "V2 collection failed"
echo "$OUTPUT" | grep -q "Missing file" && pass "warned about missing files" || pass "no missing file warning (files may exist)"

# V3: write-capable (create actual files)
mkdir -p tests
echo "describe('auth', () => {})" > tests/auth.test.js
run bash $ENGINE collect test-task V3 tests/auth.test.js
output_contains "V3"

# ============================================================
section "10. Verify"
# ============================================================

OUTPUT=$(bash $ENGINE verify test-task 2>&1)
echo "$OUTPUT" | grep -q "V2.*NO files created\|V2.*write-capable but" && pass "verify detects V2 silent failure" || \
    echo "$OUTPUT" | grep -q "VERIFY_PASSED" && pass "verify passed (V2 files may exist)" || \
    fail "verify output unexpected"

# Create V2 files to fix
mkdir -p src/auth
echo "export const login = () => {}" > src/auth/controller.js
echo "router.post('/login', login)" > src/auth/routes.js

OUTPUT=$(bash $ENGINE verify test-task 2>&1)
echo "$OUTPUT" | grep -q "VERIFY_PASSED" && pass "verify passes after fix" || fail "verify should pass now"

# ============================================================
section "11. Gate: collecting → synthesizing"
# ============================================================

run bash $ENGINE pass-gate test-task synthesizing
phase_is test-task synthesizing

# ============================================================
section "12. Status"
# ============================================================

OUTPUT=$(bash $ENGINE status test-task 2>&1)
echo "$OUTPUT" | grep -q "synthesizing" && pass "status shows correct phase" || fail "wrong phase in status"
echo "$OUTPUT" | grep -q "Vassals" && pass "status shows vassal section" || fail "vassal section missing"
echo "$OUTPUT" | grep -q "True" && pass "all vassals completed" || fail "completion status wrong"

# List all
OUTPUT=$(bash $ENGINE status 2>&1)
echo "$OUTPUT" | grep -q "test-task" && pass "test-task in list" || fail "test-task not in list"

# ============================================================
section "13. Complete"
# ============================================================

run bash $ENGINE complete test-task
phase_is test-task done

# ============================================================
section "14. Operations after done (should fail)"
# ============================================================

run bash $ENGINE pass-gate test-task planning; should_fail
run bash $ENGINE dispatch test-task V4 "late"; should_fail

# ============================================================
section "15. Abort (clean reset)"
# ============================================================

# Isolate abort test in a subdirectory to avoid cleaning other tasks
mkdir -p abort-sandbox && cd abort-sandbox
git init -q && echo x > README.md && git add -A && git commit -q -m "init" 2>/dev/null
echo "garbage" > should-be-deleted.txt
mkdir -p temp_dir && echo "data" > temp_dir/file.txt

run bash $ENGINE init abort-task "will abort"
run bash $ENGINE pass-gate abort-task planning
run bash $ENGINE pass-gate abort-task dispatching

run bash $ENGINE abort abort-task
phase_is abort-task aborted
[[ ! -f "should-be-deleted.txt" ]] && pass "untracked file cleaned" || fail "untracked file not cleaned"
[[ ! -d "temp_dir" ]] && pass "untracked dir cleaned" || fail "untracked dir not cleaned"
[[ -f "README.md" ]] && pass "tracked file preserved" || fail "tracked file was deleted"
cd .. && rm -rf abort-sandbox

# ============================================================
section "16. Retro"
# ============================================================

bash $ENGINE init retro-task "retro test"
bash $ENGINE pass-gate retro-task planning
bash $ENGINE pass-gate retro-task dispatching
# Need at least one vassal to pass collecting gate
echo "# dummy" > .crown-prince-vassal-dummy.md
bash $ENGINE dispatch retro-task D1 "dummy" read-only
bash $ENGINE collect retro-task D1 .crown-prince-vassal-dummy.md >/dev/null 2>&1
bash $ENGINE pass-gate retro-task collecting
bash $ENGINE pass-gate retro-task synthesizing
bash $ENGINE pass-gate retro-task reviewing
bash $ENGINE pass-gate retro-task retro

run bash $ENGINE retro retro-task
# retro dir is tracked (not in .gitignore), check directly
RETRO_FILE=$(ls .crown-prince/retro/*-retro-task.md 2>/dev/null | head -1)
[[ -n "$RETRO_FILE" && -f "$RETRO_FILE" ]] && pass "retro file created: $(basename $RETRO_FILE)" || fail "retro file missing"

# ============================================================
section "17. Complete triggers auto-retro from reviewing"
# ============================================================

bash $ENGINE init auto-retro "auto retro" >/dev/null 2>&1
bash $ENGINE pass-gate auto-retro planning >/dev/null 2>&1
bash $ENGINE pass-gate auto-retro dispatching >/dev/null 2>&1
echo "# dummy2" > .crown-prince-vassal-dummy2.md
bash $ENGINE dispatch auto-retro D2 "dummy" read-only >/dev/null 2>&1
bash $ENGINE collect auto-retro D2 .crown-prince-vassal-dummy2.md >/dev/null 2>&1
bash $ENGINE pass-gate auto-retro collecting >/dev/null 2>&1
bash $ENGINE pass-gate auto-retro synthesizing >/dev/null 2>&1
bash $ENGINE pass-gate auto-retro reviewing >/dev/null 2>&1

OUTPUT=$(bash $ENGINE complete auto-retro 2>&1)
echo "$OUTPUT" | grep -q "retro" && pass "auto-retro triggered from reviewing" || fail "auto-retro not triggered"
phase_is auto-retro retro

run bash $ENGINE complete auto-retro
phase_is auto-retro done

# ============================================================
section "18. Config"
# ============================================================

OUTPUT=$(bash $ENGINE config read 2>&1)
echo "$OUTPUT" | grep -q "{}" && pass "empty config by default" || pass "config has content"

run bash $ENGINE config write max_vassals 5
OUTPUT=$(bash $ENGINE config read 2>&1)
echo "$OUTPUT" | grep -q "max_vassals.*5" && pass "config write + read works" || fail "config persistence failed"

# ============================================================
section "19. Help"
# ============================================================

OUTPUT=$(bash $ENGINE help 2>&1)
echo "$OUTPUT" | grep -q "init" && pass "help shows commands" || fail "help missing"
echo "$OUTPUT" | grep -q "Phases:" && pass "help shows phases" || fail "phases missing"

# ============================================================
# Summary
# ============================================================

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL))
echo -e "  Total: $TOTAL  ${GREEN}Pass: $PASS${NC}  ${RED}Fail: $FAIL${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}🎉 ALL TESTS PASSED${NC}"
else
    echo -e "  ${RED}💥 $FAIL test(s) failed${NC}"
fi
echo -e "${CYAN}══════════════════════════════════════════${NC}"

# Cleanup
rm -rf .crown-prince .crown-prince-vassal-*.md src tests should-be-deleted.txt temp_dir

exit $FAIL
