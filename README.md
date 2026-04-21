# 👑 Crown Prince Descends / 储君降临 / 皇太子降臨

[English](#english) · [中文](#中文) · [日本語](#日本語)

---

<a id="english"></a>

## English

### What is Crown Prince Descends?

An **OpenClaw AgentSkill** that implements a multi-agent task dispatch pattern. Designed to keep AI agents smart by keeping their context lean — especially useful for models with large but unreliable context windows (e.g., GLM-5.1).

### The Problem

Many modern LLMs claim massive context windows (128k, 200k...), but stuffing them full degrades output quality — more hallucinations, weaker reasoning. A well-curated 100k context consistently outperforms a noisy 200k one.

### The Solution

**Crown Prince Descends** implements a Sovereign-Prince architecture:

- **Crown Prince (Main Agent)** — The sovereign commander. Analyzes, plans, dispatches vassals, synthesizes results. Never does heavy lifting.
- **Vassals (Subagents)** — The executors. Each handles a focused sub-task with minimal, relevant context. They serve the Crown Prince.

### How It Works

```
User Request (complex task)
        │
        ▼
  ┌──────────┐
  │   Crown  │
  │  Prince  │ ─── Analyze, Plan, Split
  └────┬─────┘
       │
   ┌───┼───┐
   ▼   ▼   ▼
  V1  V2  V3   ← Vassals (subagents)
  (2-5 agents, task-dependent)
   │   │   │
   ▼   ▼   ▼
  Results compressed & summarized
       │
       ▼
  ┌──────────┐
  │   Crown  │
  │  Prince  │ ─── Synthesize final answer
  └──────────┘
       │
       ▼
    User gets clean, accurate result
```

### Features

- **Automatic complexity detection** — Asks user before activating on complex tasks
- **Dynamic concurrency** — 2 subagents for simple tasks, up to 5 for complex ones
- **Context budget enforcement** — Each subagent gets only what it needs
- **Result compression** — Raw outputs are compressed before synthesis
- **Graceful failure handling** — Retries, fallbacks, and transparency

### Installation

1. Download `crown-prince-descends.skill`
2. Install via OpenClaw: `openclaw skill install crown-prince-descends.skill`
3. Or place in your skills directory

### Usage

The skill activates automatically when the agent detects a complex task, or when you say:
- "multi-agent mode"
- "dispatch this task"
- "crown prince"

### Anti-Patterns

- ❌ Don't use for trivial tasks
- ❌ Don't nest dispatches (no subagent-of-subagent)
- ❌ Don't split tightly coupled tasks

---

<a id="中文"></a>

## 中文

### 什么是储君降临？

一个 **OpenClaw AgentSkill**，实现多 Agent 任务调度模式。通过保持每个 Agent 的上下文精简来维持输出质量——特别适用于上下文窗口大但不稳定的模型（如 GLM-5.1）。

### 解决什么问题？

很多现代 LLM 声称拥有超大上下文窗口（128k、200k...），但塞满内容后反而降智——幻觉增多、推理变弱。精心筛选的 100k 上下文，效果往往优于杂乱的 200k。

### 解决方案

**储君降临**实现君王-储君架构：

- **Crown Prince (Main Agent)** — 调度员。拆分任务、派发仆从、汇总结果。不干脏活。
- **仆从 (Subagent)** — 执行者。每个只处理自己的子任务，上下文最小化、最相关。听命于储君。

### 工作流程

```
用户请求（复杂任务）
        │
        ▼
  ┌──────────┐
  │   储 君   │ ─── 分析、规划、拆分
  └────┬─────┘
       │
   ┌───┼───┐
   ▼   ▼   ▼
  仆从1 仆从2 仆从3  ← subagents（2-5个，视任务而定）
   │   │   │
   ▼   ▼   ▼
  结果压缩 & 总结
       │
       ▼
  ┌──────────┐
  │   储 君   │ ─── 汇总最终答案
  └──────────┘
       │
       ▼
    用户获得清晰、准确的回答
```

### 特性

- **自动复杂度检测** — 检测到复杂任务时主动询问用户
- **动态并发** — 简单任务 2 个 subagent，复杂任务最多 5 个
- **上下文预算控制** — 每个 subagent 只拿到必要信息
- **结果压缩** — 原始输出在汇总前自动压缩
- **优雅的失败处理** — 重试、降级、透明告知

### 安装

1. 下载 `crown-prince-descends.skill`
2. 通过 OpenClaw 安装：`openclaw skill install crown-prince-descends.skill`
3. 或直接放入 skills 目录

### 使用方式

Skill 会在检测到复杂任务时自动激活，也可以手动触发：
- "用多Agent模式"
- "dispatch这个任务"
- "储君降临"

### 反模式

- ❌ 不要用于简单任务
- ❌ 不要嵌套调度（不在 subagent 中再派 subagent）
- ❌ 不要拆分强耦合的任务

---

<a id="日本語"></a>

## 日本語

### Crown Prince Descends（皇太子降臨）とは？

**OpenClaw AgentSkill** として実装された、マルチエージェント・タスクディスパッチパターン。各エージェントのコンテキストを最小限に保つことで、出力品質を維持します。特に、コンテキストウィンドウが広いが安定性に欠けるモデル（GLM-5.1など）で有効です。

### 解決する問題

多くの最新LLMは巨大なコンテキストウィンドウ（128k、200k...）を謳っていますが、情報を詰め込みすぎると品質が低下します。ハルシネーションが増え、推論が弱くなります。厳選された100kコンテキストの方が、ノイズの多い200kコンテキストよりも一貫して優れた結果を出します。

### ソリューション

**皇太子降臨**は「君主・皇太子」アーキテクチャを実装します：

- **皇太子（メインエージェント）** — 統率者。タスクを分割し、従者を派遣し、結果を統合します。重い作業はしません。
- **従者（サブエージェント）** — 実行者。それぞれが最小限の関連コンテキストでフォーカスされたサブタスクを処理します。皇太子に仕えます。

### 動作フロー

```
ユーザーリクエスト（複雑なタスク）
        │
        ▼
  ┌──────────┐
  │  皇 太 子  │ ─── 分析・計画・分割
  └────┬─────┘
       │
   ┌───┼───┐
   ▼   ▼   ▼
  従者1 従者2 従者3  ← サブエージェント（2-5個、タスク依存）
   │   │   │
   ▼   ▼   ▼
  結果を圧縮・要約
       │
       ▼
  ┌──────────┐
  │  皇 太 子  │ ─── 最終回答を統合
  └──────────┘
       │
       ▼
    ユーザーに明確で正確な回答を提示
```

### 特徴

- **自動複雑度検出** — 複雑なタスクを検出するとユーザーに確認
- **動的並行性** — シンプルなタスクは2つ、複雑なタスクは最大5つのサブエージェント
- **コンテキスト予算管理** — 各サブエージェントには必要な情報のみ
- **結果圧縮** — 生の出力は統合前に自動圧縮
- **graceful な障害処理** — リトライ、フォールバック、透明性の確保

### インストール

1. `crown-prince-descends.skill` をダウンロード
2. OpenClaw でインストール：`openclaw skill install crown-prince-descends.skill`
3. または skills ディレクトリに配置

### 使い方

複雑なタスクを検出すると自動的にアクティブになります。手動でもトリガー可能：
- "multi-agent mode"
- "dispatch this task"
- "crown prince"

### アンチパターン

- ❌ 単純なタスクには使わない
- ❌ ディスパッチのネスト（サブエージェントのサブエージェント）はしない
- ❌ 密結合のタスクは分割しない

---

## License

MIT
