---
name: crown-prince-descends
description: >
  Multi-agent task dispatcher that prevents context overload by splitting complex tasks across
  isolated subagents. The Crown Prince (main agent) analyzes, plans, dispatches vassals, and
  synthesizes results — never doing heavy lifting itself. Each vassal gets minimal, relevant
  context to stay sharp. Essential for models with large but unreliable context windows (e.g.,
  GLM-5.1, long-context LLMs). Triggers on: (1) tasks involving multiple large files or
  documents (>5 files or >50k tokens), (2) tasks with 3+ independent sub-steps, (3) user
  explicitly requests "multi-agent", "dispatch", "crown prince", "储君降临", or (4) any task
  where single-agent execution risks context overload.
license: MIT
compatibility: Works with Claude Code, OpenAI Codex, Cursor, OpenClaw, and any agent supporting
  the Agent Skills specification (agentskills.io). Subagent dispatch mechanism varies by platform.
metadata:
  version: "1.2.0"
  author: JKSD-tyf
  category: orchestration
---

# Crown Prince Descends

Multi-agent dispatch pattern. The Crown Prince commands; the Vassals execute. Every agent stays sharp because context stays lean.

---

## ⚠️ MANDATORY DECISION GATE — READ FIRST

**This is the most important rule in this skill. Violation of this rule is the #1 failure mode.**

Before starting ANY work on a task that matches the complexity signals below, you MUST:

1. **STOP** — do not read files, do not analyze, do not implement, do not begin any work
2. **Present a dispatch proposal** to the user (show how you would split the task)
3. **WAIT** for explicit user confirmation ("yes", "enable", "go ahead", etc.)
4. **ONLY THEN** proceed with dispatch

If you catch yourself working on a complex sub-task directly, **STOP immediately** and re-route it to a vassal. The Crown Prince plans and synthesizes — it never executes.

---

## Core Philosophy

- **Crown Prince (Main Agent)** — Sovereign commander. Analyzes, plans, dispatches vassals, synthesizes results. **Never does heavy lifting.**
- **Vassals (Subagents)** — Executors. Each handles a focused sub-task with minimal, relevant context. They serve the Crown Prince.
- **Context budget > big context window** — A well-curated 100k context consistently outperforms a noisy 200k one.

## When to Activate

### Automatic Detection — MANDATORY

You **MUST** activate this skill and ask the user before proceeding when **ANY** of these signals are present:

- Task involves 3+ files or documents
- Task has 2+ distinct analysis dimensions (e.g., security + performance + architecture)
- Task requires processing >10k tokens of content
- User provides a multi-file codebase, document set, or project structure and asks for analysis/review/changes
- Any task where a single agent would need to hold large context to complete

**This is not optional.** Even if you think you can handle it alone, you MUST still ask the user.

### User-Initiated — Activate Immediately

No need to ask when the user explicitly says:
- "multi-agent mode" / "dispatch" / "split task"
- "crown prince" / "储君降临"
- Or explicitly requests task splitting

### How to Ask the User

Present the proposal in this format:

```
📋 Crown Prince Dispatch Proposal

Task: <brief task summary>
Complexity: <simple / medium / complex>

Proposed split:
- V1: <sub-task 1 description>
- V2: <sub-task 2 description>
- V3: <sub-task 3 description> (if needed)

Each vassal works independently with lean context.
Crown Prince synthesizes all results into a final report.

Enable multi-agent mode? (yes/no)
```

**Do NOT begin any work until the user replies.**

---

## Dispatch Workflow

### Step 1: Analyze & Plan (Crown Prince only — no vassals yet)

1. Break the task into sub-tasks. Each sub-task should:
   - Be independently completable
   - Require its own bounded set of files/context
   - Have a clear, concise output format
2. Determine concurrency level:
   - **Simple tasks (2 vassals):** linear or loosely coupled sub-tasks
   - **Complex tasks (3-5 vassals):** highly parallelizable, multiple domains
3. Present the proposal to the user (see format above)
4. **WAIT for confirmation**

### Step 2: Dispatch (after user confirms)

Spawn vassals using the platform's native subagent mechanism (see [Platform Reference](references/platform-reference.md)):

- **Claude Code:** Use the `Agent` tool or `--agent` flag with a custom subagent definition
- **OpenAI Codex:** Use `mode: subagents` or custom TOML agent in `~/.codex/agents/`
- **Cursor:** Define subagents in `.cursor/rules/` or use background agent delegation
- **OpenClaw:** Use `sessions_spawn` with `runtime: "subagent"`

For each vassal:
- Provide a clear, self-contained task description with all necessary context
- Do NOT include conversation history — only what the vassal needs
- Set explicit output format expectations in the task description
- If real files exist, include relevant file content; if files are hypothetical, explicitly state the assumed tech stack and patterns

### Step 3: Collect & Synthesize (Crown Prince only — no new analysis)

1. Wait for all vassals to complete
2. For each result:
   - Extract key conclusions only
   - Discard intermediate reasoning/process details
3. Synthesize final answer for the user
4. If results conflict or need reconciliation, spawn a new focused vassal

**CRITICAL:** The Crown Prince does NOT redo the vassals' work. It only summarizes and integrates.

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

- **Don't dispatch trivial tasks** — if a task takes <2 minutes single-agent, just do it
- **Don't give vassals full conversation history** — they don't need it
- **Don't spawn vassals for vassals** — max 1 level of dispatch depth
- **Don't forward raw outputs** — always compress before presenting
- **Don't split tightly coupled tasks** — if sub-task B depends on sub-task A's output, consider combining them
- **Don't skip checkpointing on long tasks** — if you've done 2+ rounds, checkpoint before it's too late
- **Don't start working before asking the user** — this is the #1 failure mode, always gate first
