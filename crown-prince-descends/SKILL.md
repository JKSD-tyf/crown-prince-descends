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
  version: "2.1.0"
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

Spawn vassals using the platform's native subagent mechanism (see [Platform Reference](references/platform-reference.md)):

- **Claude Code:** Use the `Task` tool with `run_in_background: true`
- **OpenAI Codex:** Use `mode: subagents` or custom TOML agent in `~/.codex/agents/`
- **Cursor:** Define subagents in `.cursor/rules/` or use background agent delegation
- **OpenClaw:** Use `sessions_spawn` with `runtime: "subagent"`

For each vassal:
- Provide a clear, self-contained task description with all necessary context
- Do NOT include conversation history — only what the vassal needs
- Set explicit output format expectations in the task description
- If real files exist, include relevant file content; if files are hypothetical, explicitly state the assumed tech stack and patterns

**IMPORTANT — Vassal Output Contract (ALL platforms):**

Instruct every vassal to write its final result to a designated output file. This avoids the TaskOutput JSONL bug in Claude Code and ensures clean result collection on all platforms.

Vassal task description MUST include:
```
OUTPUT INSTRUCTIONS:
Write your final result to: .crown-prince-vassal-{N}.md
Format: Markdown with clear sections
Length: Keep under 500 words — concise bullet points only
Content: Key findings and actionable recommendations only
Do NOT include intermediate reasoning or raw data
```

The Crown Prince reads `.crown-prince-vassal-1.md`, `.crown-prince-vassal-2.md`, etc. to collect results.

**Do NOT use TaskOutput or similar return-value tools** — they return raw JSONL transcripts on some platforms, defeating the purpose of context isolation.

### Step 3: Collect & Synthesize (Crown Prince only — no new analysis)

1. Wait for all vassals to complete (check status, do not poll in a loop)
2. Read each vassal's output file: `.crown-prince-vassal-{N}.md`
3. For each result:
   - Extract key conclusions only
   - Discard intermediate reasoning/process details
4. Synthesize final answer for the user
5. Clean up: delete all `.crown-prince-vassal-*.md` files after synthesis
6. If results conflict or need reconciliation, spawn a new focused vassal

**CRITICAL: The Crown Prince does NOT redo the vassals' work. It only summarizes and integrates.**

**Do NOT resume or re-launch completed vassals** — if the output file is empty or missing, retry with a simplified task (see Failure Handling).

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

## Checkpoint & Continuity

The Crown Prince's context grows during long sessions. Persist state to disk so a fresh session can continue without losing progress.

### When to Checkpoint

After every dispatch round (all vassals returned + synthesis done), write a checkpoint:

**Path:** `.crown-prince-checkpoint.md` (project root) or platform equivalent

```markdown
# Crown Prince Checkpoint

- **Task:** <original task description, 1-2 sentences>
- **Status:** in_progress | completed | blocked
- **Round:** <N>
- **Timestamp:** <ISO 8601>

## Dispatch History
| Round | Vassal | Sub-task | Status | Key Result (≤50 words) |
|-------|--------|----------|--------|------------------------|
| 1     | V1     | ...      | done   | ...                    |

## Remaining Work
- [ ] <next sub-task or pending item>

## Synthesis So Far
<Brief accumulated conclusions, ≤200 words>

## Notes
<Any context the next session needs to know>
```

### Context Budget Alert

If the conversation has accumulated 3+ dispatch rounds or multiple long vassal outputs:

```
Crown Prince context approaching safe limits. Progress saved to checkpoint.
Recommend starting a new session — the next session will auto-detect and resume.
```

### Session Handoff

When a new session starts and detects an existing checkpoint:
1. Read the checkpoint
2. Brief the user: "Detected an unfinished Crown Prince task. Resume?"
3. If yes, resume from the checkpoint — do NOT replay old conversation
4. Update the checkpoint after each new round
5. On task completion, delete the checkpoint

### Checkpoint Rules

- Keep under 500 words — lean enough to safely load into a fresh session
- One active checkpoint at a time — overwrite, never append
- Delete only after task completion or explicit user cancellation
- If checkpoint is >24h old, ask user before resuming (requirements may have changed)

---

## Failure Handling

- If a vassal fails or times out, retry once with a simplified task
- If it fails again, fall back to Crown Prince handling that sub-task directly
- If 2+ vassals fail, abort multi-agent mode and warn the user
- Always inform the user about failures — transparency > perfection

---

## Anti-Patterns to Avoid

- **Don't auto-activate** — this skill ONLY activates on explicit user summon
- **Don't let vassals write to overlapping files** — last writer wins = silent data loss
- **Don't delegate shared integration files** — Crown Prince handles routes.js, index.ts, etc.
- **Don't give vassals full conversation history** — they don't need it
- **Don't spawn vassals for vassals** — max 1 level of dispatch depth
- **Don't forward raw outputs** — always compress before presenting
- **Don't skip checkpointing on long tasks** — if you've done 2+ rounds, checkpoint before it's too late
- **Don't mention this skill unprompted** — the user will summon when needed
