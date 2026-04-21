---
name: crown-prince-descends
description: >
  Multi-agent task dispatcher for OpenClaw. Splits complex tasks into sub-tasks handled by independent
  subagents (vassals), keeping each agent's context lean to prevent quality degradation on models with long
  but unreliable context windows (e.g., GLM-5.1). The Crown Prince (main agent) serves as the sovereign
  commander — it analyzes, plans, dispatches, and synthesizes, never doing heavy lifting itself. Use when:
  (1) a task involves processing large amounts of content (codebases, long documents, multi-step projects),
  (2) the user explicitly asks for multi-agent mode, (3) the agent detects that a single-agent approach would
  exceed safe context limits. Triggers on keywords like "dispatch", "multi-agent", "split task",
  "crown prince", "储君降临", or when task complexity warrants it.
---

# Crown Prince Descends

A multi-agent dispatch pattern. The Crown Prince commands; the Vassals execute. Every agent stays smart because context stays lean.

## Core Philosophy

- **Crown Prince (Main Agent)** — The sovereign commander. Analyzes, plans, dispatches tasks to vassals, and synthesizes results. Never does heavy lifting.
- **Vassals (Subagents)** — The executors. Each handles a focused sub-task with minimal, relevant context. They serve the Crown Prince.
- **Context budget > big context window** — A well-curated 100k context consistently outperforms a noisy 200k one.

## When to Activate

### Automatic Detection
Ask the user before activating when ANY of these signals are present:
- Task requires reading/processing multiple large files (>5 files or >50k tokens total)
- Task has 3+ independent or semi-independent sub-steps
- User provides a large codebase or document and asks for analysis/changes
- Single-agent execution would risk context overload

### User-Initiated
Activate immediately when the user says:
- "multi-agent mode" / "dispatch" / "split task"
- "crown prince" / "储君降临"
- Or explicitly requests task splitting

### Ask the User
Present a brief proposal before activating:
```
This task is complex. Recommend enabling multi-agent mode:
- Split into N sub-tasks
- Each vassal handles its own part with lean context
- Crown Prince synthesizes final result

Enable?
```

## Dispatch Workflow

### Step 1: Analyze & Plan

1. Break the task into sub-tasks. Each sub-task should:
   - Be independently completable
   - Require its own bounded set of files/context
   - Have a clear, concise output format
2. Determine concurrency level:
   - **Simple tasks (2 vassals):** linear or loosely coupled sub-tasks
   - **Complex tasks (3-5 vassals):** highly parallelizable, multiple domains

### Step 2: Dispatch

Use `sessions_spawn` with `runtime: "subagent"` for each sub-task:
- `mode: "run"` for one-shot sub-tasks
- `task`: Clear, self-contained description with all necessary context
- Do NOT include the full conversation history — only what the vassal needs
- Set explicit output format expectations in the task description

### Step 3: Collect & Synthesize

1. Wait for all vassals to complete (completion is push-based)
2. For each result:
   - Extract key conclusions only
   - Discard intermediate reasoning/process details
3. Synthesize final answer for the user
4. If results conflict or need reconciliation, spawn a new focused vassal for resolution

## Context Budget Rules

### Vassal Context Limits
Each vassal's task description should follow:
- **Task prompt**: max ~2000 words — describe the goal, inputs, and expected output
- **File content**: only include directly relevant files, truncate if needed
- **No conversation history**: vassals start fresh; include state as structured data if needed

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

## Concurrency Control

| Complexity | Vassals | Use When |
|---|---|---|
| Simple | 2 | Sequential or loosely parallel tasks |
| Medium | 3 | Some independence between sub-tasks |
| Complex | 4-5 | Highly parallelizable, distinct domains |

**Hard limit: 5 vassals.** More adds coordination overhead that exceeds parallelism gains.

## Failure Handling

- If a vassal fails or times out, retry once with a simplified task
- If it fails again, fall back to Crown Prince handling that sub-task directly
- If 2+ vassals fail, abort multi-agent mode and warn the user
- Always inform the user about failures — transparency > perfection

## Anti-Patterns to Avoid

- **Don't dispatch trivial tasks** — if a task takes <2 minutes single-agent, just do it
- **Don't give vassals full conversation history** — they don't need it
- **Don't spawn vassals for vassals** — max 1 level of dispatch depth
- **Don't forward raw outputs** — always compress before presenting
- **Don't split tightly coupled tasks** — if sub-task B depends on sub-task A's output, consider combining them
