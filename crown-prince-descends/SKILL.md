---
name: crown-prince-descends
description: >
  Multi-agent task dispatcher invoked ONLY by user command. Prevents context overload by
  splitting complex tasks across isolated subagents. The Crown Prince (main agent) analyzes,
  plans, dispatches vassals, and synthesizes results — never doing heavy lifting itself.
  Activation: user MUST say "储君降临" or "crown prince descends" (or close variants).
  Does NOT auto-activate on complex tasks — this is intentional to avoid slowing down simple work.
license: MIT
compatibility: Works with Claude Code, OpenAI Codex, Cursor, OpenClaw, and any agent supporting
  the Agent Skills specification (agentskills.io). Subagent dispatch mechanism varies by platform.
metadata:
  version: "3.1.0"
  author: JKSD-tyf
  category: orchestration
---

# Crown Prince Descends

Multi-agent dispatch pattern. The Crown Prince commands; the Vassals execute. Every agent stays sharp because context stays lean.

---

## 🔑 Activation — Summon Only

This skill is **NEVER auto-activated**. It only activates when the user explicitly summons it.

### Summon Words

Activate **immediately** (no confirmation needed) when the user says any of:
- `储君降临`
- `crown prince descends`
- `crown prince`
- Or a clear intent to invoke multi-agent mode (e.g., "用多Agent模式", "dispatch mode", "召唤储君")

### What This Means

- If the user does NOT say a summon word → **ignore this skill entirely**, work normally
- If the user DOES say a summon word → activate immediately, present the dispatch proposal, and wait for task confirmation
- **Do NOT** auto-detect complexity and suggest this mode — the user knows when they need it
- **Do NOT** mention this skill's existence unless the user asks about it

---

## Engine

The `scripts/crown-prince-engine.sh` script is the **single source of truth** for state management and phase gates. The LLM cannot bypass these gates — only this script controls transitions.

### Engine Commands

| Command | Usage | Description |
|---|---|---|
| `init` | `engine init <id> [desc]` | Initialize a new task |
| `status` | `engine status [id]` | Show task status or list all tasks |
| `dispatch` | `engine dispatch <id> <vid> <task> [type]` | Register a vassal (`read-only` or `write-capable`) |
| `collect` | `engine collect <id> <vid> [files...]` | Register vassal's output files |
| `verify` | `engine verify <id>` | Check all vassal outputs exist |
| `pass-gate` | `engine pass-gate <id> <phase>` | Advance to next phase (hard gate check) |
| `retro` | `engine retro <id>` | Generate retro document |
| `abort` | `engine abort <id>` | Reset to git baseline, clean untracked files |
| `complete` | `engine complete <id>` | Mark task done (auto-retro from `reviewing`) |
| `config` | `engine config [read\|write <k> <v>]` | Read/write config |
| `version` | `engine version` | Print version |

### Phase Flow

```
init → planning → dispatching → collecting → synthesizing → reviewing → retro → done
                                                                                      ↑
                                                                       complete from reviewing
                                                                       triggers auto-retro
```

**Hard gates** (engine enforces, LLM cannot bypass):
- **collecting**: requires ≥1 vassal dispatched
- **synthesizing**: requires all vassals completed
- **No backward transitions**: `planning → init` is blocked
- **No phase skipping**: `planning → collecting` is blocked
- **No operations after `done` or `aborted`**

### Engine Rules for Crown Prince

1. **Always run engine commands** — do NOT manually edit `.crown-prince/*/state.json`
2. **Reference the engine** — use `scripts/crown-prince-engine.sh` (or the absolute path if known)
3. **Read status** — before any action, run `engine status <id>` to know the current phase
4. **Gate errors are final** — if `pass-gate` fails with `PHASE_BLOCKED` or `GATE_BLOCKED`, do NOT retry blindly. Investigate why.

### Engine in SKILL_DIR

```
crown-prince-descends/
├── SKILL.md
├── scripts/
│   └── crown-prince-engine.sh    ← state machine (the Engine)
└── references/
    └── platform-reference.md
```

---

## Core Philosophy

- **Crown Prince (Main Agent)** — Sovereign commander. Analyzes, plans, dispatches vassals, synthesizes results. **Never does heavy lifting.**
- **Vassals (Subagents)** — Executors. Each handles a focused sub-task with minimal, relevant context. They serve the Crown Prince.
- **Context budget > big context window** — A well-curated 100k context consistently outperforms a noisy 200k one.
- **On-demand > always-on** — Only summon the Crown Prince when the task genuinely benefits from parallel dispatch.

---

## Task Type Detection

Before planning, determine if the task is **read-only** or **write-capable**:

| Type | Examples | Dispatch Mode |
|---|---|---|
| **Read-only** | Code review, analysis, audit, research, documentation | Parallel (safe — no file conflicts) |
| **Write-capable** | Writing code, refactoring, adding features, fixing bugs | Conflict-aware (see File Isolation rules below) |

A task is write-capable if any vassal will create, modify, or delete files.

---

## File Isolation (Write-Capable Tasks)

**This is critical.** When vassals write code, they must never touch the same files — the last writer wins and earlier work is silently lost.

### Rules

1. **Each vassal must have exclusive file ownership** — no two vassals may write to the same file
2. **If two sub-tasks require modifying the same file → merge them into one vassal**
3. **Shared integration points** (e.g., a central `routes.js` or `index.ts`) must be handled by the Crown Prince after all vassals complete — never delegated
4. **Vassals create new files in isolated scopes** (e.g., `src/auth/`, `src/payment/`) — they do NOT modify existing shared files

### Planning Checklist (for write-capable tasks)

For each vassal, declare:
- Files to **create** (new files, zero conflict)
- Files to **modify** (must not overlap with other vassals)
- Files that **must not be touched** (shared files reserved for Crown Prince)

### Dispatch Proposal (Write-Capable)

```
📋 Crown Prince Dispatch Proposal

Task: <brief task summary>
Type: Write-capable (conflict-aware)

Proposed split:
- V1: <sub-task>
  - Creates: auth.js, authMiddleware.js, auth.test.js
  - Modifies: (none)
- V2: <sub-task>
  - Creates: payment.js, paymentService.js, payment.test.js
  - Modifies: (none)
- V3: <sub-task>
  - Creates: admin.js, adminRoutes.js
  - Modifies: (none)

Crown Prince handles after all vassals complete:
- Integrate into routes.js (shared file)
- Update server.js imports
- Run integration check

Execution: V1, V2, V3 in parallel (no file overlap)
Enable? (yes/no)
```

### Sequential Fallback

If the task **cannot** be split into non-overlapping file scopes:
- Run vassals **sequentially** — each vassal sees the previous vassal's output files
- Explicitly chain: V1 completes → V2 starts with V1's results as context → V3 starts with V2's results
- Accept slower execution to guarantee correctness

---

## Dispatch Workflow

### Step 0: Initialize (engine required)

When the user confirms the task, the Crown Prince MUST initialize via engine:

```bash
bash scripts/crown-prince-engine.sh init <task-id> "<task description>"
```

Then advance to planning:

```bash
bash scripts/crown-prince-engine.sh pass-gate <task-id> planning
```

### Step 1: Analyze & Plan (Crown Prince only — no vassals yet)

1. **Determine task type** (read-only vs write-capable)
2. Break the task into sub-tasks. Each sub-task should:
   - Be independently completable
   - Require its own bounded set of files/context
   - Have a clear, concise output format
3. **For write-capable tasks:** Map file ownership, check for conflicts, resolve overlaps
4. Determine execution mode:
   - **Read-only:** Parallel (up to 5 vassals)
   - **Write-capable, no conflicts:** Parallel (up to 5 vassals)
   - **Write-capable, has conflicts:** Sequential or merged vassals
5. Present the proposal to the user (use the appropriate template above)
6. **WAIT for user confirmation**

### Step 2: Dispatch (after user confirms)

First, advance the engine gate:

```bash
bash scripts/crown-prince-engine.sh pass-gate <task-id> dispatching
```

Then register each vassal with the engine AND spawn them:

```bash
bash scripts/crown-prince-engine.sh dispatch <task-id> V1 "<task description>" read-only
bash scripts/crown-prince-engine.sh dispatch <task-id> V2 "<task description>" write-capable
```

Spawn vassals using the platform's native subagent mechanism (see [Platform Reference](references/platform-reference.md)):

- **Claude Code (read-only):** Use the `Task` tool with `run_in_background: true`
- **Claude Code (write-capable):** Use `Agent` tool with custom subagent + `bypassPermissions` (see platform-reference.md)
- **OpenAI Codex:** Use `mode: subagents` or custom TOML agent in `~/.codex/agents/`
- **Cursor:** Define subagents in `.cursor/rules/` or use background agent delegation
- **OpenClaw:** Use `sessions_spawn` with `runtime: "subagent"`

For each vassal:
- Provide a clear, self-contained task description with all necessary context
- Do NOT include conversation history — only what the vassal needs
- Set explicit output format expectations in the task description
- If real files exist, include relevant file content; if files are hypothetical, explicitly state the assumed tech stack and patterns

**IMPORTANT — Vassal Output Contract (ALL platforms):**

For **read-only tasks** (analysis, review, research):

Vassals MUST write a summary file. Place this instruction at the **top** of every vassal's task description:
```
MANDATORY FIRST STEP: Write your final summary to .crown-prince-vassal-{N}.md BEFORE doing anything else.
Keep it under 500 words. Bullet points only. Key findings and recommendations.
Update this file as you work. The Crown Prince reads this file to collect your results.
```

For **write-capable tasks** (creating/modifying code):

Vassals write code directly — no separate summary file needed. The **created files ARE the output**. Instead, the vassal's task description must include:
```
OUTPUT: Create the following files:
- <file path 1>
- <file path 2>
- <file path 3>
After creating all files, write a brief completion note to .crown-prince-vassal-{N}.md listing:
1. Files created
2. Dependencies required (npm packages, etc.)
3. Any integration notes for the Crown Prince
```

**File collection strategy:**

| Task Type | How Crown Prince Collects Results |
|---|---|
| Read-only | Read `.crown-prince-vassal-{N}.md` summary files |
| Write-capable | Verify created files exist + read `.crown-prince-vassal-{N}.md` for notes |

**Why separate strategies?** Read-only tasks produce text conclusions that need a file. Write-capable tasks produce code files directly — forcing a separate summary is redundant and often gets skipped by vassals.

**Do NOT use TaskOutput as the primary collection method** — it returns raw JSONL transcripts on Claude Code, defeating context isolation. Use TaskOutput only as a fallback (see Failure Handling).

### Step 3: Collect (engine required)

After all vassals report completion, advance the gate and register their outputs:

```bash
bash scripts/crown-prince-engine.sh pass-gate <task-id> collecting
```

For each vassal, register their output files:

```bash
# Read-only vassal (summary file)
bash scripts/crown-prince-engine.sh collect <task-id> V1 .crown-prince-vassal-1.md

# Write-capable vassal (created code files)
bash scripts/crown-prince-engine.sh collect <task-id> V2 src/auth/controller.js src/auth/routes.js
```

Then verify all outputs:

```bash
bash scripts/crown-prince-engine.sh verify <task-id>
```

If `VERIFY_FAILED`, investigate which vassals failed and retry or fall back (see Failure Handling).

### Step 4: Synthesize (Crown Prince only — no new analysis)

Advance the gate:

```bash
bash scripts/crown-prince-engine.sh pass-gate <task-id> synthesizing
```

Then:
1. **For read-only tasks:** Read `.crown-prince-vassal-{N}.md` summary files
2. **For write-capable tasks:**
   - Verify that expected files were created (glob/ls the target directories)
   - Read `.crown-prince-vassal-{N}.md` for dependency and integration notes
   - If expected files exist → vassal succeeded, proceed to integration
   - If expected files are missing → see Failure Handling
3. For read-only: extract key conclusions, discard intermediate reasoning
4. For write-capable: handle shared integration (mount routes, update imports, install deps)
5. Clean up: delete all `.crown-prince-vassal-*.md` files after synthesis
6. If results conflict or need reconciliation, spawn a new focused vassal

**CRITICAL: The Crown Prince does NOT redo the vassals' work. It only summarizes and integrates.**

**Do NOT assume vassal failure just because .crown-prince-vassal-*.md is missing** — for write-capable tasks, check if the actual code files were created. If they were, the vassal succeeded even without a summary note.

### Step 5: Review & Complete (engine required)

If the task benefits from a review pass:

```bash
bash scripts/crown-prince-engine.sh pass-gate <task-id> reviewing
```

Review the synthesis output, then complete:

```bash
bash scripts/crown-prince-engine.sh complete <task-id>
```

**Note:** `complete` from `reviewing` auto-triggers retro. `complete` from `synthesizing` skips directly to `done`.

### Step 6: Retro (optional, automatic from reviewing)

If the task went through `reviewing`, `complete` auto-advances to `retro` phase. Generate the retro document:

```bash
bash scripts/crown-prince-engine.sh retro <task-id>
```

This creates `.crown-prince/retro/<date>-<task-id>.md` with a template for:
- Issues encountered
- Lessons learned
- Improvement proposals

Complete the retro:

```bash
bash scripts/crown-prince-engine.sh complete <task-id>
```

---

## Checkpoint & Continuity

The engine automatically persists state to `.crown-prince/<task-id>/state.json`. A fresh session can resume by reading the engine status.

### Session Handoff

When a new session starts and the user summons the Crown Prince:
1. Run `engine status` to check for existing tasks
2. If an unfinished task exists, brief the user: "Detected an unfinished Crown Prince task: `<id>` at phase `<phase>`. Resume?"
3. If yes, resume from the current phase — do NOT replay old conversation
4. If the task is >24h old, ask user before resuming (requirements may have changed)

---

## Context Budget Rules

### Vassal Context Limits

Each vassal's task description should follow:
- **Task prompt:** max ~2000 words — describe the goal, inputs, and expected output
- **File content:** only include directly relevant files, truncate if needed
- **No conversation history:** vassals start fresh; include state as structured data if needed

### Crown Prince Context Protection

- Never forward raw vassal output directly into conversation — summarize first
- After synthesis, compress earlier task planning context if the conversation grows long
- Keep a running mental model: "Task → N vassals → key results → synthesis"

### Result Compression Pattern

When a vassal returns results, immediately compress:
```
Raw output (potentially 2000+ words)
→ Key findings (bullet points, <200 words)
→ Stored as compact reference
```

---

## Concurrency Control

| Complexity | Vassals | Use When |
|---|---|---|
| Simple | 2 | Sequential or loosely parallel tasks |
| Medium | 3 | Some independence between sub-tasks |
| Complex | 4-5 | Highly parallelizable, distinct domains |

**Hard limit: 5 vassals.** More adds coordination overhead that exceeds parallelism gains.

---

## Failure Handling

- If a vassal fails or times out, retry once with a simplified task
- If it fails again, fall back to Crown Prince handling that sub-task directly
- If 2+ vassals fail, abort via engine: `bash scripts/crown-prince-engine.sh abort <task-id>`
- Always inform the user about failures — transparency > perfection

### Vassal "No Output" Troubleshooting

If `.crown-prince-vassal-{N}.md` is missing after a vassal reports completion:

1. **Write-capable task?** → Check if the actual code files were created. If yes, vassal succeeded — skip the summary.
2. **Read-only task?** → Try reading TaskOutput as fallback (accept the noise). If empty/invalid, retry the vassal.
3. **Still nothing?** → Retry once with an explicit "you MUST write to .crown-prince-vassal-{N}.md" instruction.
4. **Still nothing after retry?** → Vassal genuinely failed. Fall back to Crown Prince handling.

### Abort Safety

The `abort` command resets the git repo to the baseline commit and removes all untracked files:
- All vassal output is discarded
- All new files created since `init` are deleted
- `.crown-prince/<task-id>/state.json` is preserved (phase set to `aborted`) for review

---

## Anti-Patterns to Avoid

- **Don't auto-activate** — this skill ONLY activates on explicit user summon
- **Don't let vassals write to overlapping files** — last writer wins = silent data loss
- **Don't delegate shared integration files** — Crown Prince handles routes.js, index.ts, etc.
- **Don't give vassals full conversation history** — they don't need it
- **Don't spawn vassals for vassals** — max 1 level of dispatch depth
- **Don't forward raw outputs** — always compress before presenting
- **Don't manually edit state.json** — always use engine commands
- **Don't mention this skill unprompted** — the user will summon when needed
