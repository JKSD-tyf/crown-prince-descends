# 👑 Crown Prince Descends / 储君降临 / 皇太子降臨

[English](#english) · [中文](#中文) · [日本語](#日本語)

---

<a id="english"></a>

## English

### What is Crown Prince Descends?

A universal **Agent Skill** ([agentskills.io](https://agentskills.io)) that implements multi-agent task dispatch. Designed to keep AI agents sharp by keeping context lean — especially useful for models with large but unreliable context windows (e.g., GLM-5.1, long-context LLMs).

### The Problem

Many modern LLMs claim massive context windows (128k, 200k...), but stuffing them full degrades output quality — more hallucinations, weaker reasoning. A well-curated 100k context consistently outperforms a noisy 200k one.

### The Solution

**Crown Prince Descends** implements a Commander-Vassal architecture:

- **Crown Prince (Main Agent)** — The sovereign commander. Analyzes, plans, dispatches vassals, synthesizes results. Never does heavy lifting.
- **Vassals (Subagents)** — The executors. Each handles a focused sub-task with minimal, relevant context. They serve the Crown Prince.

### Activation — Summon Only

This skill does **NOT** auto-activate. It only activates when you explicitly say:

- `储君降临`
- `crown prince descends`
- `crown prince`

No automatic complexity detection. No unsolicited suggestions. You decide when to summon.

### Platform Support

| Platform | Subagent Mechanism | Status |
|---|---|---|
| Claude Code | `Task` tool (background) | ✅ Tested |
| OpenAI Codex | `mode: subagents` + TOML agents | ✅ |
| Cursor | Background agents + `.cursor/rules/` | ✅ |
| OpenClaw | `sessions_spawn` | ✅ |
| Other agentskills.io clients | Compatible | ✅ |

### How It Works

```
User says "储君降临" (summon)
        │
        ▼
  ┌──────────┐
  │   Crown  │
  │  Prince  │ ─── Analyze, Plan, Split → Present proposal
  └────┬─────┘
       │ User confirms
       │
   ┌───┼───┐
   ▼   ▼   ▼
  V1  V2  V3   ← Vassals (subagents, 2-5)
   │   │   │
   ▼   ▼   ▼
  Results written to files
       │
       ▼
  ┌──────────┐
  │   Crown  │
  │  Prince  │ ─── Read files → Synthesize final answer
  └──────────┘
       │
       ▼
    User gets clean, accurate result
```

### Features

- **Summon-only activation** — No auto-detection, no performance overhead on simple tasks
- **File-based result collection** — Avoids TaskOutput bugs (Claude Code v2.0.77+ JSONL issue)
- **Dynamic concurrency** — 2 vassals for simple tasks, up to 5 for complex ones
- **Context budget enforcement** — Each vassal gets only what it needs (~2000 words max)
- **Result compression** — Raw outputs compressed to bullet points before synthesis
- **Checkpoint & continuity** — Auto-saves progress to `.crown-prince-checkpoint.md`; new sessions resume seamlessly
- **Graceful failure handling** — Retries, fallbacks, and transparency
- **Cross-platform** — Works with Claude Code, Codex, Cursor, OpenClaw, and more

### Installation

**Claude Code:** Copy skill folder to `.claude/skills/crown-prince-descends/`

**OpenAI Codex:** Copy skill folder to `.codex/skills/crown-prince-descends/`

**Cursor:** Copy skill folder to `.cursor/skills/crown-prince-descends/`

**OpenClaw:** Copy to `~/.openclaw/workspace/skills/crown-prince-descends/` or install via `openclaw skill install crown-prince-descends.skill`

**Any agentskills.io client:** Place in your platform's skills directory

### Usage

```
You: 储君降临 — help me analyze this codebase's security, performance, and architecture

Crown Prince: 📋 Dispatch Proposal
  - V1: Security analysis
  - V2: Performance analysis
  - V3: Architecture analysis
  Enable? (yes/no)

You: yes

[3 vassals dispatched in parallel → results synthesized → final report delivered]
```

### Anti-Patterns

- ❌ Don't use for trivial tasks (<2 minutes single-agent)
- ❌ Don't nest dispatches (no vassal-of-vassal)
- ❌ Don't split tightly coupled tasks
- ❌ Don't expect auto-activation — you must summon

---

<a id="中文"></a>

## 中文

### 什么是储君降临？

一个通用的 **Agent Skill**（遵循 [agentskills.io](https://agentskills.io) 开放规范），实现多 Agent 任务调度模式。通过保持每个 Agent 的上下文精简来维持输出质量——特别适用于上下文窗口大但不稳定的模型（如 GLM-5.1、长上下文 LLM）。

### 解决什么问题？

很多现代 LLM 声称拥有超大上下文窗口（128k、200k...），但塞满内容后反而降智——幻觉增多、推理变弱。精心筛选的 100k 上下文，效果往往优于杂乱的 200k。

### 解决方案

**储君降临**实现统帅-仆从架构：

- **储君（主 Agent）** — 统率者。分析、规划、派发仆从、汇总结果。不干脏活。
- **仆从（Subagent）** — 执行者。每个只处理自己的子任务，上下文最小化、最相关。听命于储君。

### 触发方式 — 仅限召唤

本 skill **不会自动激活**。只有在你明确说出以下口令时才会触发：

- `储君降临`
- `crown prince descends`
- `crown prince`

没有自动复杂度检测，没有主动建议。你决定何时召唤。

### 平台支持

| 平台 | Subagent 机制 | 状态 |
|---|---|---|
| Claude Code | `Task` tool (background) | ✅ 已测试 |
| OpenAI Codex | `mode: subagents` + TOML agents | ✅ |
| Cursor | Background agents + `.cursor/rules/` | ✅ |
| OpenClaw | `sessions_spawn` | ✅ |
| 其他 agentskills.io 客户端 | 兼容 | ✅ |

### 工作流程

```
用户说"储君降临"（召唤）
        │
        ▼
  ┌──────────┐
  │   储 君   │ ─── 分析、规划、拆分 → 展示方案
  └────┬─────┘
       │ 用户确认
       │
   ┌───┼───┐
   ▼   ▼   ▼
  仆从1 仆从2 仆从3  ← subagents（2-5个）
   │   │   │
   ▼   ▼   ▼
  结果写入文件
       │
       ▼
  ┌──────────┐
  │   储 君   │ ─── 读取文件 → 汇总最终答案
  └──────────┘
       │
       ▼
    用户获得清晰、准确的回答
```

### 特性

- **仅限召唤激活** — 没有自动检测，简单任务零性能损耗
- **基于文件的结果收集** — 避免了 TaskOutput 的 JSONL bug（Claude Code v2.0.77+）
- **动态并发** — 简单任务 2 个仆从，复杂任务最多 5 个
- **上下文预算控制** — 每个仆从只拿必要信息（最多 ~2000 词）
- **结果压缩** — 原始输出压缩为要点后再汇总
- **存档与续接** — 自动保存进度到 `.crown-prince-checkpoint.md`；新 session 无缝恢复
- **优雅的失败处理** — 重试、降级、透明告知
- **跨平台** — 支持 Claude Code、Codex、Cursor、OpenClaw 等

### 安装

**Claude Code：** 复制到 `.claude/skills/crown-prince-descends/`

**OpenAI Codex：** 复制到 `.codex/skills/crown-prince-descends/`

**Cursor：** 复制到 `.cursor/skills/crown-prince-descends/`

**OpenClaw：** 复制到 `~/.openclaw/workspace/skills/crown-prince-descends/` 或通过 `openclaw skill install` 安装

### 使用方式

```
你：储君降临 — 帮我分析这个代码库的安全性、性能和架构

储君：📋 派发方案
  - 仆从1：安全性分析
  - 仆从2：性能分析
  - 仆从3：架构分析
  启用？（yes/no）

你：yes

[3个仆从并行派发 → 结果汇总 → 交付最终报告]
```

### 反模式

- ❌ 不要用于简单任务（单 Agent 2 分钟内能搞定的）
- ❌ 不要嵌套调度（不在仆从中再派仆从）
- ❌ 不要拆分强耦合的任务
- ❌ 不要期待自动激活 — 你必须主动召唤

---

<a id="日本語"></a>

## 日本語

### Crown Prince Descends（皇太子降臨）とは？

汎用 **Agent Skill**（[agentskills.io](https://agentskills.io) 仕様準拠）として実装されたマルチエージェント・タスクディスパッチパターン。各エージェントのコンテキストを最小限に保つことで出力品質を維持します。特にコンテキストウィンドウが広いが安定性に欠けるモデル（GLM-5.1など）で有効です。

### 解決する問題

多くの最新LLMは巨大なコンテキストウィンドウ（128k、200k...）を謳っていますが、情報を詰め込みすぎると品質が低下します。ハルシネーションが増え、推論が弱くなります。厳選された100kコンテキストの方がノイズの多い200kよりも一貫して優れた結果を出します。

### ソリューション

**皇太子降臨**は「統率者・従者」アーキテクチャを実装します：

- **皇太子（メインエージェント）** — 統率者。タスクを分割し、従者を派遣し、結果を統合します。重い作業はしません。
- **従者（サブエージェント）** — 実行者。それぞれが最小限の関連コンテキストでフォーカスされたサブタスクを処理します。皇太子に仕えます。

### 起動方法 — 召喚のみ

このスキルは**自動起動しません**。明示的に以下の言葉を言った時のみ起動します：

- `储君降临`
- `crown prince descends`
- `crown prince`

自動複雑度検出はありません。未承諾の提案もありません。召喚するかどうかはあなたが決めます。

### プラットフォーム対応

| プラットフォーム | サブエージェント機構 | 状態 |
|---|---|---|
| Claude Code | `Task` tool (background) | ✅ テスト済み |
| OpenAI Codex | `mode: subagents` + TOML agents | ✅ |
| Cursor | Background agents + `.cursor/rules/` | ✅ |
| OpenClaw | `sessions_spawn` | ✅ |
| その他 agentskills.io クライアント | 互換 | ✅ |

### 動作フロー

```
ユーザーが「储君降临」と言う（召喚）
        │
        ▼
  ┌──────────┐
  │  皇 太 子  │ ─── 分析・計画・分割 → 提案を提示
  └────┬─────┘
       │ ユーザーが承認
       │
   ┌───┼───┐
   ▼   ▼   ▼
  従者1 従者2 従者3  ← サブエージェント（2-5個）
   │   │   │
   ▼   ▼   ▼
  結果をファイルに書き込み
       │
       ▼
  ┌──────────┐
  │  皇 太 子  │ ─── ファイルを読み込み → 最終回答を統合
  └──────────┘
       │
       ▼
    ユーザーに明確で正確な回答を提示
```

### 特徴

- **召喚のみ起動** — 自動検出なし、シンプルなタスクのパフォーマンス低下なし
- **ファイルベースの結果収集** — TaskOutputのJSONLバグを回避（Claude Code v2.0.77+）
- **動的並行性** — シンプルなタスクは2つ、複雑なタスクは最大5つの従者
- **コンテキスト予算管理** — 各従者には必要な情報のみ（最大約2000語）
- **結果圧縮** — 生の出力は箇条書きに圧縮してから統合
- **チェックポイント＆継続性** — 進捗を`.crown-prince-checkpoint.md`に自動保存、新セッションでシームレスに再開
- **graceful な障害処理** — リトライ、フォールバック、透明性の確保
- **クロスプラットフォーム** — Claude Code、Codex、Cursor、OpenClaw等に対応

### インストール

**Claude Code：** `.claude/skills/crown-prince-descends/` にコピー

**OpenAI Codex：** `.codex/skills/crown-prince-descends/` にコピー

**Cursor：** `.cursor/skills/crown-prince-descends/` にコピー

**OpenClaw：** `~/.openclaw/workspace/skills/crown-prince-descends/` にコピー、または `openclaw skill install` でインストール

**agentskills.io 準拠クライアント：** 各プラットフォームの skills ディレクトリに配置

### 使い方

```
あなた：储君降临 — このコードベースのセキュリティ、パフォーマンス、アーキテクチャを分析して

皇太子：📋 派遣提案
  - 従者1：セキュリティ分析
  - 従者2：パフォーマンス分析
  - 従者3：アーキテクチャ分析
  有効にしますか？（yes/no）

あなた：yes

[3つの従者が並列で実行 → 結果を統合 → 最終レポートを提出]
```

### アンチパターン

- ❌ 単純なタスク（単一エージェントで2分以内のもの）には使わない
- ❌ ディスパッチのネスト（従者の従者）はしない
- ❌ 密結合のタスクは分割しない
- ❌ 自動起動を期待しない — あなたが召喚しなければならない

---

## License

MIT
