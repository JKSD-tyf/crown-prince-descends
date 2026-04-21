#!/usr/bin/env bash
# crown-prince-engine.sh — Crown Prince Descends v3.0 Engine
# Single source of truth for state management and phase gates.
# The LLM cannot bypass these gates — only this script controls transitions.

set -euo pipefail

# Python command detection (Windows: python, Linux/macOS: python3)
if command -v python3 &>/dev/null; then
    PYTHON="python3"
elif command -v python &>/dev/null; then
    PYTHON="python"
else
    echo "[CP] ERROR: python3 or python not found" >&2; exit 1
fi

CP_VERSION="3.0.0"
CP_DIR=".crown-prince"
STATE_FILE="state.json"
CONFIG_FILE="config.json"
RETRO_DIR="retro"
PHASES=(init planning dispatching collecting synthesizing reviewing retro done aborted)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[CP]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[CP]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[CP]${NC} $*"; }
log_error() { echo -e "${RED}[CP]${NC} $*" >&2; }
die()       { log_error "$*"; exit 1; }

require_git() { git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not a git repository"; }

# Use heredoc for all python to avoid quoting issues
_get_phase() {
    $PYTHON - "$1" <<'PY'
import json, sys
with open(f"{sys.argv[1]}/state.json") as f: print(json.load(f).get("phase","init"))
PY
}

_set_phase() {
    local dir="$1" phase="$2" ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    $PYTHON - "$dir" "$phase" "$ts" <<'PY'
import json, sys
p = f"{sys.argv[1]}/state.json"
with open(p) as f: s = json.load(f)
s["phase"] = sys.argv[2]
s["phase_updated_at"] = sys.argv[3]
with open(p, "w") as f: json.dump(s, f, indent=2, ensure_ascii=False)
PY
}

_get_config() {
    $PYTHON - "$CP_DIR/$CONFIG_FILE" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as f: print(json.dumps(json.load(f)))
except: print("{}")
PY
}

_phase_index() {
    local i=0
    for p in "${PHASES[@]}"; do
        [[ "$p" == "$1" ]] && echo "$i" && return
        i=$((i + 1))
    done
    echo "-1"
}

_validate_transition() {
    local cur=$(_phase_index "$1") tgt=$(_phase_index "$2")
    if [[ "$cur" == "-1" ]]; then die "Unknown phase: $1"; fi
    if [[ "$tgt" == "-1" ]]; then die "Unknown phase: $2"; fi
    if [[ "$tgt" -le "$cur" ]]; then die "PHASE_BLOCKED: $1 → $2 (backwards)"; fi
    if [[ "$tgt" -gt "$((cur + 1))" ]]; then die "PHASE_BLOCKED: cannot skip phases ($1 → $2)"; fi
    return 0
}

# ============================================================
# Commands
# ============================================================

cmd_init() {
    require_git
    local task_id="${1:?Usage: init <task-id> [description]}"
    local task_desc="${2:-}"
    local dir="$CP_DIR/$task_id"
    [[ -d "$dir" ]] && die "Task '$task_id' already exists"
    mkdir -p "$dir/checkpoints" "$CP_DIR/$RETRO_DIR"

    $PYTHON - "$dir" "$task_id" "$task_desc" "$CP_VERSION" <<'PY'
import json, sys, subprocess
dir, tid, desc, ver = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
sha = subprocess.check_output(["git","rev-parse","HEAD"], text=True).strip()
ts = subprocess.check_output(["date","-u","+%Y-%m-%dT%H:%M:%SZ"], text=True).strip()
state = {
    "version": ver, "task_id": tid, "task_description": desc,
    "phase": "init", "phase_updated_at": ts, "created_at": ts,
    "git_baseline_sha": sha, "vassals": {}, "checkpoints": [],
    "current_checkpoint": 0, "total_checkpoints": 0, "all_vassals_completed": False
}
with open(f"{dir}/state.json", "w") as f: json.dump(state, f, indent=2, ensure_ascii=False)
print(sha[:12])
PY

    grep -qxF ".crown-prince/$task_id/" .gitignore 2>/dev/null || echo ".crown-prince/$task_id/" >> .gitignore
    log_ok "Task '$task_id' initialized"
}

cmd_status() {
    local task_id="${1:-}"
    if [[ -z "$task_id" ]]; then
        [[ ! -d "$CP_DIR" ]] && { log_info "No tasks found."; return; }
        local found=0
        for d in "$CP_DIR"/*/; do
            [[ -f "$d/$STATE_FILE" ]] || continue
            $PYTHON - "$d" <<'PY'
import json, sys
with open(f"{sys.argv[1]}/state.json") as f:
    s = json.load(f)
print(f"  {s['task_id']:20s} [{s['phase']:15s}] {s.get('task_description','')[:50]}")
PY
            found=$((found + 1))
        done
        [[ $found -eq 0 ]] && log_info "No tasks found."
        return
    fi

    local dir="$CP_DIR/$task_id"
    [[ ! -f "$dir/$STATE_FILE" ]] && die "Task '$task_id' not found"
    $PYTHON - "$dir" <<'PY'
import json, sys
with open(f"{sys.argv[1]}/state.json") as f: s = json.load(f)
print(f"Task:        {s['task_id']}")
print(f"Phase:       {s['phase']}")
print(f"Created:     {s['created_at']}")
print(f"Baseline:    {s.get('git_baseline_sha','?')[:12]}")
print(f"Checkpoints: {s['current_checkpoint']}/{s['total_checkpoints']}")
print(f"Vassals:     {len(s.get('vassals',{}))}")
print(f"All done:    {s.get('all_vassals_completed', False)}")
vassals = s.get("vassals", {})
if vassals:
    print()
    print("Vassals:")
    for vid, v in vassals.items():
        print(f"  {vid:6s} [{v.get('status','?'):12s}] {v.get('task','')[:50]} ({v.get('type','read-only')})")
PY
}

cmd_dispatch() {
    local task_id="${1:?}" vassal_id="${2:?}" vassal_task="${3:?}" task_type="${4:-read-only}"
    local dir="$CP_DIR/$task_id"
    local phase
    phase=$(_get_phase "$dir")
    [[ "$phase" != "dispatching" ]] && die "PHASE_BLOCKED: need 'dispatching', got '$phase'"

    $PYTHON - "$dir" "$vassal_id" "$vassal_task" "$task_type" <<'PY'
import json, sys, subprocess
dir, vid, task, ttype = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
ts = subprocess.check_output(["date","-u","+%Y-%m-%dT%H:%M:%SZ"], text=True).strip()
p = f"{dir}/state.json"
with open(p) as f: s = json.load(f)
s["vassals"][vid] = {"task": task, "type": ttype, "status": "dispatched",
    "dispatched_at": ts, "output_files": [], "completed_at": None}
with open(p, "w") as f: json.dump(s, f, indent=2, ensure_ascii=False)
PY
    log_ok "Vassal '$vassal_id' dispatched ($task_type)"
}

cmd_collect() {
    local task_id="${1:?}" vassal_id="${2:?}"
    shift 2
    local dir="$CP_DIR/$task_id"
    local phase
    phase=$(_get_phase "$dir")
    [[ "$phase" != "dispatching" && "$phase" != "collecting" ]] && die "PHASE_BLOCKED: got '$phase'"

    for f in "$@"; do
        [[ ! -e "$f" ]] && log_warn "Missing file (silent failure?): $f"
    done

    # Build file list JSON
    local files_json="[]"
    if [[ $# -gt 0 ]]; then
        printf '%s\n' "$@" | $PYTHON -c "
import sys, json
print(json.dumps([l.strip() for l in sys.stdin]))
" > /tmp/cp-files.json
        files_json=$(cat /tmp/cp-files.json)
        rm -f /tmp/cp-files.json
    fi

    $PYTHON - "$dir" "$vassal_id" "$files_json" <<'PY'
import json, sys, subprocess
dir, vid, files = sys.argv[1], sys.argv[2], sys.argv[3]
ts = subprocess.check_output(["date","-u","+%Y-%m-%dT%H:%M:%SZ"], text=True).strip()
p = f"{dir}/state.json"
with open(p) as f: s = json.load(f)
if vid not in s["vassals"]: raise SystemExit(f"Vassal not found: {vid}")
s["vassals"][vid]["status"] = "completed"
s["vassals"][vid]["completed_at"] = ts
s["vassals"][vid]["output_files"] = json.loads(files)
s["all_vassals_completed"] = all(v["status"] == "completed" for v in s["vassals"].values())
with open(p, "w") as f: json.dump(s, f, indent=2, ensure_ascii=False)
if s["all_vassals_completed"]: print("ALL_VASSALS_COMPLETED")
PY
    log_ok "Vassal '$vassal_id' collected ($# files)"
}

cmd_verify() {
    local dir="$CP_DIR/${1:?}"
    $PYTHON - "$dir" <<'PY'
import json, os, sys
with open(f"{sys.argv[1]}/state.json") as f: s = json.load(f)
issues = []
for vid, v in s.get("vassals", {}).items():
    if v.get("status") != "completed":
        issues.append(f"{vid}: not completed ({v.get('status')})"); continue
    files = v.get("output_files", [])
    if v.get("type") == "write-capable":
        if not any(os.path.exists(f) for f in files):
            issues.append(f"{vid}: write-capable but NO files created")
    else:
        sf = v.get("summary_file")
        if sf and not os.path.exists(sf):
            issues.append(f"{vid}: summary missing: {sf}")
if issues:
    print("VERIFY_FAILED")
    for i in issues: print(f"  {i}")
else:
    print("VERIFY_PASSED")
PY
}

cmd_pass_gate() {
    local task_id="${1:?}" target="${2:?}" artifact="${3:-}"
    local dir="$CP_DIR/$task_id"
    local current
    current=$(_get_phase "$dir")
    _validate_transition "$current" "$target"

    case "$target" in
        dispatching)
            [[ -n "$artifact" && ! -f "$artifact" ]] && die "GATE_BLOCKED: dispatch plan not found: $artifact"
            ;;
        collecting)
            local n
            n=$($PYTHON - "$dir" <<'PY'
import json, sys
with open(f"{sys.argv[1]}/state.json") as f: print(len(json.load(f).get("vassals",{})))
PY
)
            [[ "$n" -eq 0 ]] && die "GATE_BLOCKED: no vassals dispatched"
            ;;
        synthesizing)
            local done_val
            done_val=$($PYTHON - "$dir" <<'PY'
import json, sys
with open(f"{sys.argv[1]}/state.json") as f: print(json.load(f).get("all_vassals_completed",False))
PY
)
            [[ "$done_val" != "True" ]] && die "GATE_BLOCKED: not all vassals completed"
            ;;
        reviewing)
            [[ -n "$artifact" && ! -f "$artifact" ]] && die "GATE_BLOCKED: synthesis not found: $artifact"
            ;;
    esac

    _set_phase "$dir" "$target"
    log_ok "Phase: $current → $target"
}

cmd_retro() {
    local dir="$CP_DIR/${1:?}"
    local phase
    phase=$(_get_phase "$dir")
    [[ "$phase" != "retro" ]] && die "PHASE_BLOCKED: need 'retro', got '$phase'"

    local retro_dir="$CP_DIR/$RETRO_DIR"
    mkdir -p "$retro_dir"

    $PYTHON - "$dir" "$retro_dir" <<'PY'
import json, sys, subprocess
dir, rdir = sys.argv[1], sys.argv[2]
with open(f"{dir}/state.json") as f: s = json.load(f)
date_str = subprocess.check_output(["date","-u","+%Y-%m-%d"], text=True).strip()
tid = s["task_id"]
lines = [f"# Crown Prince Retro: {tid}", "",
    f"**Date:** {date_str}", f"**Task:** {s.get('task_description','')}", "",
    "## Vassal Summary", ""]
for vid, v in s.get("vassals", {}).items():
    lines += [f"### {vid}", f"- Task: {v.get('task','')}", f"- Type: {v.get('type','')}",
        f"- Status: {v.get('status','')}", f"- Output files: {len(v.get('output_files',[]))}", ""]
lines += ["## Issues Encountered", "", "<!-- Retro agent fills this -->", "",
    "## Lessons Learned", "", "<!-- Retro agent fills this -->", "",
    "## Improvement Proposals", "", "<!-- Retro agent fills this -->", ""]
with open(f"{rdir}/{date_str}-{tid}.md", "w") as f: f.write("\n".join(lines))
print(f"{rdir}/{date_str}-{tid}.md")
PY
    log_ok "Retro created"
}

cmd_abort() {
    local dir="$CP_DIR/${1:?}"
    [[ ! -f "$dir/$STATE_FILE" ]] && die "Task not found"
    local baseline
    baseline=$($PYTHON - "$dir" <<'PY'
import json, sys
with open(f"{sys.argv[1]}/state.json") as f: print(json.load(f).get("git_baseline_sha",""))
PY
)
    if [[ -n "$baseline" ]]; then
        log_info "Resetting to baseline: ${baseline:0:12}"
        git reset --hard "$baseline" 2>/dev/null || log_warn "Git reset failed"
        git clean -fd 2>/dev/null || true
    fi
    _set_phase "$dir" "aborted"
    log_ok "Task aborted"
}

cmd_complete() {
    local dir="$CP_DIR/${1:?}"
    [[ ! -f "$dir/$STATE_FILE" ]] && die "Task not found"
    local phase
    phase=$(_get_phase "$dir")
    case "$phase" in
        synthesizing) _set_phase "$dir" "done" ;;
        reviewing)    _set_phase "$dir" "retro"; log_ok "Phase: $phase → retro (auto-retro)" ;;
        retro)        _set_phase "$dir" "done" ;;
        done)         log_warn "Already completed"; return ;;
        *)            die "PHASE_BLOCKED: cannot complete from '$phase'" ;;
    esac
    log_ok "Task completed"
}

cmd_config() {
    local action="${1:-read}"
    case "$action" in
        read) _get_config ;;
        write)
            local key="${2:?}" value="${3:?}"
            mkdir -p "$CP_DIR"
            $PYTHON - "$CP_DIR/$CONFIG_FILE" "$key" "$value" <<'PY'
import json, sys
p, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
c = {}
try:
    with open(p) as f: c = json.load(f)
except: pass
c[key] = True if val.lower() == "true" else False if val.lower() == "false" else int(val) if val.isdigit() else val
with open(p, "w") as f: json.dump(c, f, indent=2)
PY
            log_ok "Config: $key = $value"
            ;;
        *) die "Usage: config [read|write <key> <value>]" ;;
    esac
}

# ============================================================
case "${1:-help}" in
    init)       shift; cmd_init "$@" ;;
    status)     shift; cmd_status "$@" ;;
    dispatch)   shift; cmd_dispatch "$@" ;;
    collect)    shift; cmd_collect "$@" ;;
    verify)     shift; cmd_verify "$@" ;;
    pass-gate)  shift; cmd_pass_gate "$@" ;;
    retro)      shift; cmd_retro "$@" ;;
    abort)      shift; cmd_abort "$@" ;;
    complete)   shift; cmd_complete "$@" ;;
    config)     shift; cmd_config "$@" ;;
    version)    echo "Crown Prince Engine v$CP_VERSION" ;;
    help|*)
        echo "Crown Prince Engine v$CP_VERSION"
        echo ""
        echo "Usage: crown-prince-engine.sh <command> [options]"
        echo ""
        echo "Commands:"
        echo "  init <id> [desc]                  Initialize task"
        echo "  status [id]                       Show status / list tasks"
        echo "  dispatch <id> <vid> <task> [type] Register vassal (read-only|write-capable)"
        echo "  collect <id> <vid> [files...]     Register vassal results"
        echo "  verify <id>                       Verify vassal outputs exist"
        echo "  pass-gate <id> <phase> [artifact] Advance phase (hard gate check)"
        echo "  retro <id>                        Create retro input"
        echo "  abort <id>                        Abort & reset to baseline"
        echo "  complete <id>                     Mark done"
        echo "  config [read|write <k> <v>]       Config"
        echo "  version                           Version"
        echo ""
        echo "Phases: ${PHASES[*]}"
        ;;
esac
