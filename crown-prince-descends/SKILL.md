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

## Checkpoint & Continuity

The Crown Prince's context will grow during a long dispatch session. When it approaches the safe limit, persist state to disk so a fresh session can continue without losing progress.

### When to Checkpoint

After every dispatch round (all vassals returned + synthesis done), write a checkpoint file to `memory/crown-prince-checkpoint.md`:

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

Monitor context growth informally. If the conversation has accumulated:
- 3+ dispatch rounds, OR
- Multiple long vassal outputs that couldn't be fully compressed

Then after the current round, inform the user:

```
储君的精力快用完了（上下文接近安全上限）。
当前进度已保存到 checkpoint。
建议新开一个 session，我会自动读取 checkpoint 继续工作。
```

### Session Handoff

When a new session starts and detects an existing checkpoint (`memory/crown-prince-checkpoint.md`):
1. Read the checkpoint
2. Brief the user: "检测到未完成的储君任务，是否继续？"
3. If yes, resume from where it left off using the checkpoint state — do NOT replay old conversation
4. Update the checkpoint after each new round
5. On task completion, delete the checkpoint file

### Checkpoint Rules

- Keep it under 500 words — it must be lean enough to safely load into a fresh session
- One active checkpoint at a time — overwrite, never append
- Delete checkpoint only after task completion or explicit user cancellation
- If checkpoint is >24h old, ask user before resuming (requirements may have changed)

## Anti-Patterns to Avoid

- **Don't dispatch trivial tasks** — if a task takes <2 minutes single-agent, just do it
- **Don't give vassals full conversation history** — they don't need it
- **Don't spawn vassals for vassals** — max 1 level of dispatch depth
- **Don't forward raw outputs** — always compress before presenting
- **Don't split tightly coupled tasks** — if sub-task B depends on sub-task A's output, consider combining them
- **Don't skip checkpointing on long tasks** — if you've done 2+ rounds, checkpoint before it's too late
