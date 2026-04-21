---
name: crown-prince-descends
description: >
  Multi-agent task dispatcher for OpenClaw. Splits complex tasks into sub-tasks handled by independent
  subagents, keeping each agent's context lean to prevent quality degradation on models with long but
  unreliable context windows (e.g., GLM-5.1). Use when: (1) a task involves processing large amounts
  of content (codebases, long documents, multi-step projects), (2) the user explicitly asks for multi-agent
  mode, (3) the agent detects that a single-agent approach would exceed safe context limits. Triggers on
  keywords like "dispatch", "multi-agent", "split task", "crown prince", or when task complexity warrants it.
---

# Crown Prince Descends — 储君降临

A multi-agent dispatch pattern that keeps every agent smart by keeping context lean.

## Core Philosophy

- **Main Agent = the Sovereign** — manages task splitting, dispatch, and result synthesis. Never does heavy lifting.
- **Subagents = the Crown Princes** — each handles a focused sub-task with minimal context. They descend to do the real work.
- **Context budget > big context window** — a 100k well-curated context outperforms a 200k noisy one.

## When to Activate

### Automatic Detection
Ask the user before activating when ANY of these signals are present:
- Task requires reading/processing multiple large files (>5 files or >50k tokens total)
- Task has 3+ independent or semi-independent sub-steps
- User provides a large codebase or document and asks for analysis/changes
- Single-agent execution would risk context overload

### User-Initiated
Activate immediately when the user says:
- "用多Agent模式" / "multi-agent mode" / "dispatch"
- "储君降临" / "crown prince"
- Or explicitly requests task splitting

### Ask the User
Present a brief proposal:
```
这个任务比较复杂，建议启用多 Agent 模式：
- 拆分为 N 个子任务
- 每个 subagent 只处理自己的部分，保持上下文精简
- 主 Agent 负责汇总

是否启用？
```

## Dispatch Workflow

### Step 1: Analyze & Plan

1. Break the task into sub-tasks. Each sub-task should:
   - Be independently completable
   - Require its own bounded set of files/context
   - Have a clear, concise output format
2. Determine concurrency level:
   - **Simple tasks (2 subagents):** linear or loosely coupled sub-tasks
   - **Complex tasks (3-5 subagents):** highly parallelizable, multiple domains

### Step 2: Dispatch

Use `sessions_spawn` with `runtime: "subagent"` for each sub-task:
- `mode: "run"` for one-shot sub-tasks
- `task`: Clear, self-contained description with all necessary context
- Do NOT include the full conversation history — only what the subagent needs
- Set explicit output format expectations in the task description

### Step 3: Collect & Synthesize

1. Wait for all subagents to complete (completion is push-based)
2. For each result:
   - Extract key conclusions only
   - Discard intermediate reasoning/process details
3. Synthesize final answer for the user
4. If results conflict or need reconciliation, spawn a new focused subagent for resolution

## Context Budget Rules

### Subagent Context Limits
Each subagent's task description should follow:
- **Task prompt**: max ~2000 words — describe the goal, inputs, and expected output
- **File content**: only include directly relevant files, truncate if needed
- **No conversation history**: subagents start fresh; include state as structured data if needed

### Main Agent Context Protection
- Never forward raw subagent output directly into conversation — summarize first
- After synthesis, compress earlier task planning context if the conversation grows long
- Keep a running mental model: "Task → N subagents → key results → synthesis"

### Result Compression Pattern
When a subagent returns results, immediately compress:
```
Raw output (potentially 2000+ words)
→ Key findings (bullet points, <200 words)
→ Stored as compact reference
```

## Concurrency Control

| Complexity | Subagents | Use When |
|---|---|---|
| Simple | 2 | Sequential or loosely parallel tasks |
| Medium | 3 | Some independence between sub-tasks |
| Complex | 4-5 | Highly parallelizable, distinct domains |

**Hard limit: 5 subagents.** More adds coordination overhead that exceeds parallelism gains.

## Failure Handling

- If a subagent fails or times out, retry once with a simplified task
- If it fails again, fall back to main agent handling that sub-task directly
- If 2+ subagents fail, abort multi-agent mode and warn the user
- Always inform the user about failures — transparency > perfection

## Anti-Patterns to Avoid

❌ **Don't dispatch trivial tasks** — if a task takes <2 minutes single-agent, just do it
❌ **Don't give subagents full conversation history** — they don't need it
❌ **Don't spawn subagents for sub-agents** — max 1 level of dispatch depth
❌ **Don't forward raw outputs** — always compress before presenting
❌ **Don't split tightly coupled tasks** — if sub-task B depends on sub-task A's output, consider combining them
