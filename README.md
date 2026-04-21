# 👑 Crown Prince Descends / 储君降临 / 皇太子降臨

> **Multi-Agent Task Dispatch Engine** — Commander-Vassal architecture with strict phase-gated state machine. The LLM cannot bypass the gates.

[English](#english) · [中文](#中文) · [日本語](#日本語)

---

<a id="english"></a>

## English

### What is Crown Prince Descends?

A universal **Agent Skill** ([agentskills.io](https://agentskills.io)) that implements multi-agent task dispatch with a **bash-based state machine engine**. Designed to keep AI agents sharp by keeping context lean — especially useful for models with large but unreliable context windows (e.g., GLM-5.1, long-context LLMs).

**v3.0 introduces the Engine** — a shell script that enforces strict phase transitions. The LLM cannot skip phases, fabricate state, or bypass quality gates. This is the single source of truth for task progression.

### Architecture

```
┌─────────────────────────────────────────────┐
│           Crown Prince (Main Agent)         │
│  Analyze → Plan → Dispatch → Synthesize     │
├─────────────────────────────────────────────┤
│     crown-prince-engine.sh (State Machine)  │
│  init → planning → dispatching → collecting │
│  → synthesizing → reviewing → retro → done  │
│                                             │
│  ⛔ LLM CANNOT bypass these gates           │
├──────────────┬──────────────┬───────────────┤
│   Vassal 1   │   Vassal 2   │   Vassal N   │
│  (subagent)  │  (subagent)  │  (subagent)  │
│  read-only   │ write-capable│  read-only   │
└──────────────┴──────────────┴───────────────┘
```

### The Engine (`crown-prince-engine.sh`)

A single bash script that **only the script** controls phase transitions. Not the LLM, not the user — the script.

**Phase Flow:**
```
init → planning → dispatching → collecting → synthesizing → reviewing → retro → done
                                                                                   ↑
                                                                               aborted
```

**Gate Checks (enforced per phase transition):**

| Transition | Gate Check |
|---|---|
| → `dispatching` | Dispatch plan artifact exists (if provided) |
| → `collecting` | At least 1 vassal dispatched |
| → `synthesizing` | All vassals completed |
| → `reviewing` | Synthesis artifact exists (if provided) |
| → `done` | Must be in `synthesizing`, `reviewing`, or `retro` |

**Commands:**

```bash
./crown-prince-engine.sh init <task-id> [description]      # Create task, snapshot git baseline
./crown-prince-engine.sh status [task-id]                  # Show task/list all tasks
./crown-prince-engine.sh dispatch <id> <vid> <task> [type] # Register vassal (read-only|write-capable)
./crown-prince-engine.sh collect <id> <vid> [files...]     # Mark vassal done, register output files
./crown-prince-engine.sh verify <id>                       # Check all vassal outputs exist
./crown-prince-engine.sh pass-gate <id> <phase> [artifact] # Advance phase (hard gate)
./crown-prince-engine.sh retro <id>                        # Generate retro template
./crown-prince-engine.sh abort <id>                        # Reset to git baseline + clean
./crown-prince-engine.sh complete <id>                     # Mark done (auto-retro if in reviewing)
./crown-prince-engine.sh config [read\|write <k> <v>]      # Read/write config
```

**State stored in:** `.crown-prince/<task-id>/state.json`

**Abort safety:** `abort` resets `git reset --hard` to baseline + `git clean -fd` to remove all untracked files. Nothing survives.

### Vassal Types

| Type | Concurrency | Output | Isolation |
|---|---|---|---|
| `read-only` | Parallel | Summary file | Shared read access |
| `write-capable` | Sequential | Code files | Exclusive file ownership |

### Activation — Summon Only

This skill does **NOT** auto-activate. It only activates when you explicitly say:

- `储君降临`
- `crown prince descends`
- `crown prince`

### Platform Support

| Platform | Subagent Mechanism | Status |
|---|---|---|
| Claude Code | `Task` / `Agent` tool | ✅ Tested |
| OpenAI Codex | `mode: subagents` + TOML agents | ✅ |
| Cursor | Background agents + `.cursor/rules/` | ✅ |
| OpenClaw | `sessions_spawn` | ✅ |
| Other agentskills.io clients | Compatible | ✅ |

### Installation

**Claude Code:** `.claude/skills/crown-prince-descends/`

**OpenAI Codex:** `.codex/skills/crown-prince-descends/`

**Cursor:** `.cursor/skills/crown-prince-descends/`

**OpenClaw:** `~/.openclaw/workspace/skills/crown-prince-descends/` or `openclaw skill install crown-prince-descends.skill`

### Quick Start

```bash
# 1. Summon
You: 储君降临 — help me analyze this codebase's security, performance, and architecture

# 2. Crown Prince creates task via engine, presents dispatch proposal
Crown Prince: 📋 Dispatch Proposal
  - V1: Security analysis (read-only)
  - V2: Refactor hot paths (write-capable)
  - V3: Architecture review (read-only)
  Enable? (yes/no)

# 3. Engine enforces each phase transition
# 4. Vassals execute in isolation, outputs verified
# 5. Crown Prince synthesizes → delivers final result
```

### Anti-Patterns

- ❌ Don't use for trivial tasks (<2 minutes single-agent)
- ❌ Don't nest dispatches (no vassal-of-vassal)
- ❌ Don't split tightly coupled tasks
- ❌ Don't manually edit `.crown-prince/` state files
- ❌ Don't expect auto-activation — you must summon

---

<a id="中文"></a>

## 中文

### 什么是储君降临？

一个通用的 **Agent Skill**（遵循 [agentskills.io](https://agentskills.io) 开放规范），实现多 Agent 任务调度，附带基于 **bash 状态机引擎**。通过保持每个 Agent 的上下文精简来维持输出质量——特别适用于上下文窗口大但不稳定的模型（如 GLM-5.1、长上下文 LLM）。

**v3.0 引入引擎** — 一个 shell 脚本强制执行严格的阶段转换。LLM 不能跳过阶段、不能伪造状态、不能绕过质量门控。引擎是任务进度的唯一事实来源。

### 架构

```
┌─────────────────────────────────────────────┐
│            储君（主 Agent）                  │
│  分析 → 规划 → 派发 → 汇总                  │
├─────────────────────────────────────────────┤
│     crown-prince-engine.sh（状态机）         │
│  init → planning → dispatching → collecting │
│  → synthesizing → reviewing → retro → done  │
│                                             │
│  ⛔ LLM 无法绕过这些门控                    │
├──────────────┬──────────────┬───────────────┤
│   仆从 1     │   仆从 2     │   仆从 N     │
│  (subagent)  │  (subagent)  │  (subagent)  │
│  只读        │ 可写         │  只读        │
└──────────────┴──────────────┴───────────────┘
```

### 引擎（`crown-prince-engine.sh`）

一个 bash 脚本，**只有脚本**能控制阶段转换。不是 LLM，不是用户——是脚本。

**阶段流程：**
```
init → planning → dispatching → collecting → synthesizing → reviewing → retro → done
                                                                                   ↑
                                                                               aborted
```

**门控检查（每次阶段转换强制执行）：**

| 转换 | 门控条件 |
|---|---|
| → `dispatching` | 派发计划文件存在（如提供） |
| → `collecting` | 至少已派发 1 个仆从 |
| → `synthesizing` | 所有仆从已完成 |
| → `reviewing` | 汇总产物存在（如提供） |
| → `done` | 必须处于 `synthesizing`、`reviewing` 或 `retro` |

**命令一览：**

```bash
./crown-prince-engine.sh init <任务id> [描述]         # 创建任务，快照 git 基线
./crown-prince-engine.sh status [任务id]              # 查看任务/列出所有任务
./crown-prince-engine.sh dispatch <id> <vid> <任务> [类型]  # 注册仆从 (read-only|write-capable)
./crown-prince-engine.sh collect <id> <vid> [文件...] # 标记仆从完成，注册输出文件
./crown-prince-engine.sh verify <id>                  # 检查所有仆从输出是否存在
./crown-prince-engine.sh pass-gate <id> <阶段> [产物] # 推进阶段（硬门控）
./crown-prince-engine.sh retro <id>                   # 生成复盘模板
./crown-prince-engine.sh abort <id>                   # 回退到 git 基线 + 清理
./crown-prince-engine.sh complete <id>                # 标记完成（reviewing 阶段自动复盘）
./crown-prince-engine.sh config [read|write <k> <v>]  # 读取/写入配置
```

**状态存储：** `.crown-prince/<任务id>/state.json`

**中止安全：** `abort` 执行 `git reset --hard` 回到基线 + `git clean -fd` 清理未跟踪文件。什么都留不下。

### 仆从类型

| 类型 | 并发 | 输出 | 隔离 |
|---|---|---|---|
| `read-only` | 并行执行 | 摘要文件 | 共享读权限 |
| `write-capable` | 顺序执行 | 代码文件 | 独占文件所有权 |

### 触发方式 — 仅限召唤

本 skill **不会自动激活**。只有在你明确说出以下口令时才会触发：

- `储君降临`
- `crown prince descends`
- `crown prince`

### 平台支持

| 平台 | Subagent 机制 | 状态 |
|---|---|---|
| Claude Code | `Task` / `Agent` tool | ✅ 已测试 |
| OpenAI Codex | `mode: subagents` + TOML agents | ✅ |
| Cursor | Background agents + `.cursor/rules/` | ✅ |
| OpenClaw | `sessions_spawn` | ✅ |
| 其他 agentskills.io 客户端 | 兼容 | ✅ |

### 安装

**Claude Code：** `.claude/skills/crown-prince-descends/`

**OpenAI Codex：** `.codex/skills/crown-prince-descends/`

**Cursor：** `.cursor/skills/crown-prince-descends/`

**OpenClaw：** `~/.openclaw/workspace/skills/crown-prince-descends/` 或 `openclaw skill install`

### 快速上手

```bash
# 1. 召唤
你：储君降临 — 帮我分析这个代码库的安全性、性能和架构

# 2. 储君通过引擎创建任务，展示派发方案
储君：📋 派发方案
  - 仆从1：安全性分析（只读）
  - 仆从2：重构热点路径（可写）
  - 仆从3：架构审查（只读）
  启用？（yes/no）

# 3. 引擎强制执行每个阶段转换
# 4. 仆从在隔离环境中执行，输出经过验证
# 5. 储君汇总 → 交付最终结果
```

### 反模式

- ❌ 不要用于简单任务（单 Agent 2 分钟内能搞定的）
- ❌ 不要嵌套调度（不在仆从中再派仆从）
- ❌ 不要拆分强耦合的任务
- ❌ 不要手动编辑 `.crown-prince/` 状态文件
- ❌ 不要期待自动激活 — 你必须主动召唤

---

<a id="日本語"></a>

## 日本語

### Crown Prince Descends（皇太子降臨）とは？

汎用 **Agent Skill**（[agentskills.io](https://agentskills.io) 仕様準拠）として実装されたマルチエージェント・タスクディスパッチパターン。**bash ベースのステートマシンエンジン**を搭載しています。各エージェントのコンテキストを最小限に保つことで出力品質を維持します。

**v3.0 でエンジンを導入** — シェルスクリプトが厳密なフェーズ遷移を強制します。LLM はフェーズをスキップできず、状態を偽造できず、品質ゲートをバイパスできません。エンジンがタスク進行の唯一の信頼できる情報源です。

### アーキテクチャ

```
┌─────────────────────────────────────────────┐
│            皇太子（メインエージェント）      │
│  分析 → 計画 → 派遣 → 統合                  │
├─────────────────────────────────────────────┤
│     crown-prince-engine.sh（ステートマシン） │
│  init → planning → dispatching → collecting │
│  → synthesizing → reviewing → retro → done  │
│                                             │
│  ⛔ LLM はこれらのゲートをバイパス不可       │
├──────────────┬──────────────┬───────────────┤
│   従者 1     │   従者 2     │   従者 N     │
│  (サブエージェント)              │
│  読取専用    │ 書込可能     │  読取専用    │
└──────────────┴──────────────┴───────────────┘
```

### エンジン（`crown-prince-engine.sh`）

1つのbashスクリプトが**スクリプトのみ**がフェーズ遷移を制御します。LLMでもユーザーでもありません。

**フェーズフロー：**
```
init → planning → dispatching → collecting → synthesizing → reviewing → retro → done
                                                                                   ↑
                                                                               aborted
```

**ゲートチェック（フェーズ遷移ごとに強制）：**

| 遷移 | ゲート条件 |
|---|---|
| → `dispatching` | 派遣計画ファイルの存在（指定時） |
| → `collecting` | 最低1人の従者が派遣済み |
| → `synthesizing` | 全従者が完了 |
| → `reviewing` | 統合成果物の存在（指定時） |
| → `done` | `synthesizing`、`reviewing`、または `retro` であること |

**コマンド：**

```bash
./crown-prince-engine.sh init <タスクID> [説明]         # タスク作成、git ベースライン保存
./crown-prince-engine.sh status [タスクID]               # タスク表示/一覧
./crown-prince-engine.sh dispatch <id> <vid> <タスク> [タイプ]  # 従者登録 (read-only|write-capable)
./crown-prince-engine.sh collect <id> <vid> [ファイル...] # 従者完了、出力ファイル登録
./crown-prince-engine.sh verify <id>                     # 全従者の出力存在確認
./crown-prince-engine.sh pass-gate <id> <フェーズ> [成果物]  # フェーズ進行（ハードゲート）
./crown-prince-engine.sh retro <id>                      # レトロスペクティブ生成
./crown-prince-engine.sh abort <id>                      # git ベースラインにリセット + クリーンアップ
./crown-prince-engine.sh complete <id>                   # 完了（reviewing時は自動レトロ）
./crown-prince-engine.sh config [read|write <k> <v>]     # 設定の読み書き
```

**状態保存先：** `.crown-prince/<タスクID>/state.json`

**中止の安全性：** `abort` は `git reset --hard` でベースラインに戻し、`git clean -fd` で未追跡ファイルを削除します。何も残りません。

### 従者のタイプ

| タイプ | 並行性 | 出力 | 分離 |
|---|---|---|---|
| `read-only` | 並列実行 | サマリーファイル | 共有読取アクセス |
| `write-capable` | 順次実行 | コードファイル | 排他的ファイル所有権 |

### 起動方法 — 召喚のみ

このスキルは**自動起動しません**。明示的に以下の言葉を言った時のみ起動します：

- `储君降临`
- `crown prince descends`
- `crown prince`

### プラットフォーム対応

| プラットフォーム | サブエージェント機構 | 状態 |
|---|---|---|
| Claude Code | `Task` / `Agent` tool | ✅ テスト済み |
| OpenAI Codex | `mode: subagents` + TOML agents | ✅ |
| Cursor | Background agents + `.cursor/rules/` | ✅ |
| OpenClaw | `sessions_spawn` | ✅ |
| その他 agentskills.io クライアント | 互換 | ✅ |

### インストール

**Claude Code：** `.claude/skills/crown-prince-descends/`

**OpenAI Codex：** `.codex/skills/crown-prince-descends/`

**Cursor：** `.cursor/skills/crown-prince-descends/`

**OpenClaw：** `~/.openclaw/workspace/skills/crown-prince-descends/` または `openclaw skill install`

### クイックスタート

```bash
# 1. 召喚
あなた：储君降临 — このコードベースのセキュリティ、パフォーマンス、アーキテクチャを分析して

# 2. 皇太子がエンジンでタスク作成、派遣提案を提示
皇太子：📋 派遣提案
  - 従者1：セキュリティ分析（読取専用）
  - 従者2：ホットパスのリファクタリング（書込可能）
  - 従者3：アーキテクチャレビュー（読取専用）
  有効にしますか？（yes/no）

# 3. エンジンが各フェーズ遷移を強制
# 4. 従者が分離環境で実行、出力を検証
# 5. 皇太子が統合 → 最終結果を提出
```

### アンチパターン

- ❌ 単純なタスク（単一エージェントで2分以内のもの）には使わない
- ❌ ディスパッチのネスト（従者の従者）はしない
- ❌ 密結合のタスクは分割しない
- ❌ `.crown-prince/` の状態ファイルを手動で編集しない
- ❌ 自動起動を期待しない — あなたが召喚しなければならない

---

## License

MIT
