# daily-work-log

> Claude Code 每日工作记录与总结技能

一个用于 Claude Code 的技能（skill），自动记录和总结你的每日工作内容，支持跨会话汇总。

## 功能特性

- 📝 **自动记录** — 完成任务后自动记录摘要
- 📊 **智能总结** — 一键生成结构化工作日志
- 🔄 **跨会话汇总** — 多次会话的工作内容自动聚合
- 🔌 **Hooks 增强** — 可选的原始事件采集

## 安装

```bash
# 复制技能文件到你的项目
cp -r ~/.claude/skills/daily-work-log .claude/skills/
```

## 使用方法

### 记录模式

在对话中输入以下任一指令激活记录模式：

- 「记录工作」
- 「开始记录」
- 「daily log」

激活后，每次完成任务时会自动记录摘要到 `.work-log/{日期}-sessions.md`。

### 总结模式

在对话中输入以下任一指令生成工作总结：

- 「总结今日工作」
- 「今日总结」
- 「daily summary`

生成的报告保存在 `.work-log/{日期}-report.md`，包含：

- 精简说明（所有任务的一句话概括）
- 细节说明（每个任务的背景、操作、关键文件和决策）
- 今日统计（任务数、文件数、决策数）

### 指定日期总结

可指定特定日期总结：

```bash
# 示例：总结 5 月 28 日的工作
总结今日工作 --date 2026-05-28
```

## Hooks（可选）

技能包含一个可选的 PostToolUse hook，自动采集工具调用事件：

- 自动记录 `Edit`、`Write`、`Bash` 等工具调用
- 异步执行，不消耗 token
- 数据保存到 `.work-log/{日期}.jsonl`

在 `SKILL.md` 中已配置 hook，需要你的 Claude Code 支持技能级 hooks。

## 工作日志存储

所有日志存储在项目根目录的 `.work-log/` 目录：

| 文件 | 说明 |
|------|------|
| `{日期}-sessions.md` | 跨会话任务摘要 |
| `{日期}-report.md` | 每日工作总结报告 |
| `{日期}.jsonl` | 原始工具调用事件（hooks 启用时） |

建议将 `.work-log/` 加入 `.gitignore`。

## 技术原理

### 日志采集机制

日志采集通过 **PostToolUse Hook** 实现，工作流程如下：

```
┌─────────────────┐
│ Claude Code     │
│ 工具调用        │
└────────┬────────┘
         │ 触发 Hook
         ▼
┌─────────────────┐
│ log-event.sh   │
│ (异步执行)      │
└────────┬────────┘
         │ 解析 JSON
         ▼
┌─────────────────┐
│ 提取关键信息    │
│ - tool_name     │
│ - command       │
│ - file_path     │
│ - changes       │
└────────┬────────┘
         │ 追加写入
         ▼
┌─────────────────┐
│ .work-log/     │
│ {日期}.jsonl   │
└─────────────────┘
```

### 数据流转

1. **触发阶段** — 当你执行 `Edit`、`Write`、`Bash` 等工具时
2. **采集阶段** — Hook 脚本从 stdin 接收工具调用数据（JSON 格式）
3. **解析阶段** — Python 提取关键字段，长度限制避免数据膨胀：
   - `command`: 前 500 字符
   - `old_string` / `new_string`: 前 200 字符
   - `content_length`: 内容长度计数
4. **存储阶段** — 以 JSONL 格式（每行一个 JSON）追加到当日日志文件

### 设计优势

| 特性 | 说明 |
|------|------|
| **零干扰** | 异步执行，stdout 完全静默，不消耗对话 token |
| **增量式** | JSONL 追加模式，无需读取已有内容 |
| **容错性** | 目录创建失败或写入失败均静默跳过 |
| **跨会话** | 按日期分文件，多次会话共享同一天的数据 |

### 数据示例

`.work-log/2026-05-31.jsonl` 内容示例：

```jsonl
{"tool":"Edit","time":"2026-05-31T08:15:30Z","input":{"file_path":"src/index.ts","old_string":"const foo = 1","new_string":"const foo = 2"}}
{"tool":"Bash","time":"2026-05-31T08:16:45Z","input":{"command":"npm test"}}
{"tool":"Write","time":"2026-05-31T09:20:10Z","input":{"file_path":"docs/api.md","content_length":1234}}
```

这些原始数据在总结模式下会被读取，用于生成更完整的工作日志报告。

## 项目结构

```
daily-work-log/
├── SKILL.md          # 技能定义和触发逻辑
└── bin/
    └── log-event.sh  # PostToolUse hook 脚本
```

## License

MIT
