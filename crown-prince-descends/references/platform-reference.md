# Platform Reference — Subagent Dispatch Mechanisms

Each platform implements subagents differently. The Crown Prince pattern works universally, but the dispatch call varies. This file documents the native mechanism for each supported platform.

## Claude Code

### Subagent Definition
Create a custom subagent file at `.claude/agents/<name>.md`:

```markdown
---
description: One-line description of what this agent does
prompt: |
  You are a vassal agent. Your task is to complete the assigned sub-task efficiently.
  Return ONLY a concise summary of your findings/results.
tools: Read Write Edit Bash
maxTurns: 20
---
```

### Dispatching
The Crown Prince (main agent) uses the built-in `Task` tool (background mode):

```
Use the Task tool to spawn a background agent:
- task: <self-contained sub-task description>
- run_in_background: true
```

### Result Collection — IMPORTANT

**Do NOT use `TaskOutput` to retrieve results.** Claude Code v2.0.77+ has a known bug where `TaskOutput` returns raw JSONL conversation transcripts instead of clean summaries. This defeats the purpose of context isolation and can cause the Crown Prince's context to explode.

**Instead, instruct each vassal to write results to a file:**
```
OUTPUT INSTRUCTIONS:
Write your final result to: .crown-prince-vassal-{N}.md
Format: Markdown, keep under 500 words, bullet points only.
```

The Crown Prince reads `.crown-prince-vassal-{N}.md` files after vassals complete.

### Key Details
- Subagents run in separate context windows
- Configure which tools each subagent can access via `tools` field
- Use `maxTurns` to prevent runaway agents
- Clean up vassal output files after synthesis

---

## OpenAI Codex

### Subagent Definition
Create TOML files in `~/.codex/agents/` or project `.codex/agents/`:

```toml
version = 2

[[agents]]
name = "vassal"
model = "o4-mini"
description = "General-purpose vassal for focused sub-tasks"
```

### Dispatching
Use `mode: subagents` in your config or via CLI:

```bash
codex task run \
  --mode subagents \
  --instruction "Break this task into sub-tasks and dispatch"
```

### Key Details
- Default subagents: "explorer", "worker", "default"
- `agents.max_spawn_depth` controls nesting (default: 2, but Crown Prince should stay at 1)
- Per-agent model selection supported
- Use `sandbox: { filesystem: scoped }` to limit vassal file access

---

## Cursor

### Subagent Definition
Create subagent rules in `.cursor/rules/`:

```markdown
---
description: Triggered when main agent delegates a focused sub-task
globs: 
alwaysApply: false
---
When you receive a delegated sub-task:
1. Focus only on the assigned scope
2. Return a concise summary of results
3. Do not attempt to coordinate other agents
```

### Dispatching
The main agent delegates via Cursor's built-in agent orchestration. Cursor uses git worktrees to isolate background agents — they work on separate copies of the codebase.

Configure in `.cursor/rules/` or via `.cursor/config.json`:
```json
{
  "subagents": {
    "enabled": true,
    "maxParallel": 5
  }
}
```

### Key Details
- Background agents run in parallel using git worktrees
- Each agent gets its own codebase snapshot
- Nested subagent spawning is supported but Crown Prince should limit to depth 1
- Model can be set per-agent (e.g., use cheaper model for vassals)

---

## OpenClaw

### Subagent Definition
No explicit definition file needed. Subagents are spawned on-the-fly via the `sessions_spawn` tool.

### Dispatching
```
sessions_spawn:
  runtime: "subagent"
  mode: "run"
  task: <self-contained task description with all necessary context>
```

### Key Details
- Subagents are isolated sessions with their own context
- Completion is push-based (no polling needed)
- No nested subagents — Crown Prince limits to 1 dispatch depth
- Use `subagents` tool to list/steer/kill running vassals

---

## Platform-Agnostic Tips

Regardless of platform, these principles apply to all vassal dispatch:

1. **Self-contained tasks** — Each vassal must have everything it needs in the task description
2. **Output contracts** — Tell each vassal exactly what format to return
3. **Context isolation** — Never pass conversation history to vassals
4. **Scope limiting** — Restrict file access, tools, and turns where possible
5. **Result compression** — Always summarize vassal output before Crown Prince uses it
