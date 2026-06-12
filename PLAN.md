# daily-work-log v2 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 daily-work-log 从扁平目录改为按日期分目录、按项目分文件的多项目日志体系，并增加智能过滤。

**架构：** 日志目录 `${LOG_DIR}/${DATE}/` 下按项目存 `*-sessions.md`，汇总时合并所有项目日志生成跨项目 report。记录时轻量过滤无意义条目，汇总时二次筛选。

**技术栈：** Shell script（hook）、Markdown（SKILL.md prompt）

**设计规格：** `/Users/zhangxiaotian/.claude/skills/daily-work-log/DESIGN.md`

---

## 文件结构

- 修改：`/Users/zhangxiaotian/.claude/skills/daily-work-log/bin/log-event.sh` — hook 脚本，调整 jsonl 输出路径 + 新增 project 字段
- 修改：`/Users/zhangxiaotian/.claude/skills/daily-work-log/SKILL.md` — skill 主文件，更新初始化/记录/总结/错误处理/约束全部章节

---

### 任务 1：更新 log-event.sh（jsonl 路径 + project 字段）

**文件：**
- 修改：`/Users/zhangxiaotian/.claude/skills/daily-work-log/bin/log-event.sh`

- [ ] **步骤 1：添加 PROJECT_NAME 提取逻辑**

在 `DATE=$(date +%Y-%m-%d)` 之后添加：

```bash
# Determine project name from CLAUDE_PROJECT_DIR basename
PROJECT_NAME=$(basename "${CLAUDE_PROJECT_DIR:-default}")
```

- [ ] **步骤 2：更新 mkdir 和 jsonl 输出路径**

将现有的：

```bash
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Append event to JSONL (one line per event)
printf '{"tool":"%s","time":"%s","input":%s}\n' "$TOOL_NAME" "$TIMESTAMP" "$TOOL_INPUT" >> "${LOG_DIR}/${DATE}.jsonl" 2>/dev/null || true
```

替换为：

```bash
# Create date subdirectory
DAY_DIR="${LOG_DIR}/${DATE}"
mkdir -p "$DAY_DIR" 2>/dev/null || true

# Append event to JSONL (one line per event, with project field)
printf '{"tool":"%s","time":"%s","project":"%s","input":%s}\n' "$TOOL_NAME" "$TIMESTAMP" "$PROJECT_NAME" "$TOOL_INPUT" >> "${DAY_DIR}/${DATE}.jsonl" 2>/dev/null || true
```

- [ ] **步骤 3：手动验证脚本语法**

运行：`bash -n /Users/zhangxiaotian/.claude/skills/daily-work-log/bin/log-event.sh`
预期：无输出（语法正确）

- [ ] **步骤 4：Commit**

```bash
cd /Users/zhangxiaotian/.claude && git add skills/daily-work-log/bin/log-event.sh && git commit -m "refactor(daily-work-log): update hook to use date subdirectory and add project field"
```

---

### 任务 2：更新 SKILL.md — 初始化 + 记录模式

**文件：**
- 修改：`/Users/zhangxiaotian/.claude/skills/daily-work-log/SKILL.md`

- [ ] **步骤 1：替换初始化章节**

将现有的 `## 初始化` 整个章节（从第 16 行 `收到触发指令后` 到第 41 行 `确认文件`）替换为：

```markdown
## 初始化

收到触发指令后，执行以下初始化：

1. 获取当前日期 `DATE=$(date +%Y-%m-%d)`
2. 获取项目名称 `PROJECT=$(basename ${CLAUDE_PROJECT_DIR:-default})`
3. 确定日志目录 `LOG_DIR`：
   - 优先级：skill 配置 > 项目配置 > 全局配置 > 默认值 `.work-log`
   - 配置位置（推荐使用 skill 配置文件）：
     - **推荐**：`~/.claude/daily-work-log.json`（skill 专用配置）
     - 项目：`.claude/settings.local.json`
     - 全局：`~/.claude/settings.json`
   - 配置格式（推荐）：
     ```json
     {
       "logDir": "<路径>"
     }
     ```
   - 路径解析规则：
     - `~/` 开头 → 用户主目录
     - `/` 开头 → 绝对路径
     - 其他 → 相对项目根目录
4. 创建日期目录 `DAY_DIR=${LOG_DIR}/${DATE}`，`mkdir -p ${DAY_DIR}`
5. 如果目录创建失败，输出提示："无法创建日志目录 `${DAY_DIR}`，日志记录功能已禁用"
6. 确认项目日志文件 `${DAY_DIR}/${PROJECT}-sessions.md` 是否存在
```

- [ ] **步骤 2：替换记录模式章节**

将现有的 `## 记录模式` 整个章节（从第 43 行 `当用户说` 到第 72 行代码块结束）替换为：

```markdown
## 记录模式

当用户说「记录工作」「开始记录」「daily log」时进入记录模式：

1. 输出："📝 记录模式已激活。项目：${PROJECT}，日志：${DAY_DIR}/${PROJECT}-sessions.md"

2. 在后续工作中，每当你识别到一个独立任务完成时，判断是否值得记录：

   **轻量过滤 — 以下类型直接跳过不记录：**
   - 纯 /init 且无实质改动
   - 纯代码格式化（prettier/lint fix 无逻辑变更）
   - 纯 git 操作（commit/push/branch 无代码改动）
   - 纯压缩/上下文管理
   - 判断标准：**该任务是否包含实质性的设计决策、代码逻辑变更、或问题排查**。如果没有，跳过。

3. 通过过滤后，立即追加摘要到 `${DAY_DIR}/${PROJECT}-sessions.md`。

4. 任务完成的识别信号：
   - 用户说"好了""完成""下一个""继续"
   - 用户切换到新的话题或任务
   - Bug 修复并通过验证
   - 功能实现并通过测试
   - 代码审查完成

5. 每条摘要格式严格遵循：

```
## HH:MM 任务标题

简要描述（1-2 句话，不超过 200 字）。说明做了什么、为什么做、关键决策。
```

6. 摘要追加使用 Edit 工具，在文件末尾追加。如果文件不存在，先用 Write 创建，写入头部：

```markdown
# 工作记录 YYYY-MM-DD — 项目名

（自动记录，由 daily-work-log skill 生成）

```
```

- [ ] **步骤 3：验证 Markdown 格式**

运行：`cat /Users/zhangxiaotian/.claude/skills/daily-work-log/SKILL.md | head -80`
预期：看到初始化和记录模式章节格式正确，新变量名（`${DAY_DIR}`、`${PROJECT}`）出现

- [ ] **步骤 4：Commit**

```bash
cd /Users/zhangxiaotian/.claude && git add skills/daily-work-log/SKILL.md && git commit -m "refactor(daily-work-log): update initialization and recording mode for multi-project support"
```

---

### 任务 3：更新 SKILL.md — 总结模式

**文件：**
- 修改：`/Users/zhangxiaotian/.claude/skills/daily-work-log/SKILL.md`

- [ ] **步骤 1：替换总结模式章节**

将现有的 `## 总结模式` 整个章节替换为：

```markdown
## 总结模式

当用户说「总结今日工作」「今日总结」「daily summary」时生成总结报告：

1. 确定目标日期：
   - 如果用户指定了日期（如 `--date 2026-05-28`），使用指定日期
   - 否则使用当前日期

2. 确定日期目录：`DAY_DIR=${LOG_DIR}/${DATE}`

3. 读取数据源（按优先级）：
   a. 遍历 `${DAY_DIR}/*-sessions.md`（glob 匹配所有项目日志）
   b. 如果存在 `${DAY_DIR}/${DATE}.jsonl`（hooks 采集的原始事件），读取并参考
   c. 回顾当前会话上下文（本轮完整工作内容）

4. 如果三个数据源均为空，输出："今日暂未检测到明确的工作任务。" 并停止。

5. **二次筛选**：分析所有项目的 sessions 内容，过滤掉轻量过滤阶段可能漏掉的低价值条目（无实质工作成果的条目）。

6. 按项目分组，归纳分类为独立任务。

7. 生成报告文件 `${DAY_DIR}/${DATE}-report.md`，严格遵循以下模板：

```markdown
# 工作日志 YYYY-MM-DD

## 精简说明

### 项目A
- **任务标题**：一句话概括

### 项目B
- **任务标题**：一句话概括

## 细节说明

### [项目A] 任务标题
- **背景**：为什么做这件事
- **操作**：
  1. 具体步骤 1
  2. 具体步骤 2
- **关键文件**：涉及的主要文件路径（如有）
- **关键决策**：做出的技术选择及原因（如有）

### [项目B] 任务标题
（同上结构）

## 今日统计

- 项目数：N
- 任务数：N
- 涉及文件：N 个
- 关键决策：N 个
```

8. 统计数据从数据源中实际计算得出，不估算。

9. 输出报告路径给用户："📄 今日工作日志已生成：`${DAY_DIR}/${DATE}-report.md`"
```

- [ ] **步骤 2：验证章节完整性**

运行：`grep -n '## 总结模式\|## 错误处理' /Users/zhangxiaotian/.claude/skills/daily-work-log/SKILL.md`
预期：总结模式章节存在，错误处理章节紧随其后

- [ ] **步骤 3：Commit**

```bash
cd /Users/zhangxiaotian/.claude && git add skills/daily-work-log/SKILL.md && git commit -m "refactor(daily-work-log): update summary mode for cross-project aggregation"
```

---

### 任务 4：更新 SKILL.md — 错误处理 + 约束

**文件：**
- 修改：`/Users/zhangxiaotian/.claude/skills/daily-work-log/SKILL.md`

- [ ] **步骤 1：替换错误处理章节**

将现有的 `## 错误处理` 整个章节替换为：

```markdown
## 错误处理

- 日期目录创建失败 → 提示"无法创建日志目录 `${DAY_DIR}`，日志记录功能已禁用"
- `*-sessions.md` 全部不存在 → 跳过该数据源，仅基于当前会话上下文生成
- 指定日期无目录 → 提示"该日期暂无工作记录"
- 指定日期有目录但无 sessions → 提示"该日期暂无工作记录"
```

- [ ] **步骤 2：替换约束章节**

将现有的 `## 约束` 整个章节替换为：

```markdown
## 约束

- 所有文件默认中文输出
- sessions 头部标注项目名：`# 工作记录 YYYY-MM-DD — 项目名`
- `sessions.md` 单个摘要条目不超过 200 字
- `report.md` 细节说明每个任务不超过 500 字
- 摘要追加时使用 Edit 工具而非 Write，避免覆盖已有内容
```

- [ ] **步骤 3：最终验证 — 完整读取 SKILL.md**

运行：`cat /Users/zhangxiaotian/.claude/skills/daily-work-log/SKILL.md`
预期：
- 初始化章节包含 `PROJECT`、`DAY_DIR`、`${PROJECT}-sessions.md`
- 记录模式章节包含轻量过滤规则
- 总结模式章节包含 glob 遍历、二次筛选、项目分组 report 模板
- 错误处理章节包含日期目录相关提示
- 约束章节包含项目名头部模板

- [ ] **步骤 4：Commit**

```bash
cd /Users/zhangxiaotian/.claude && git add skills/daily-work-log/SKILL.md && git commit -m "refactor(daily-work-log): update error handling and constraints for v2"
```

---

### 任务 5：清理旧 sessions 文件 + 验证端到端流程

**文件：**
- 无代码修改，纯验证

- [ ] **步骤 1：确认今日日志文件在新结构下工作**

手动检查：
- `/Users/zhangxiaotian/work/work-log/2026-06-12/` 目录是否存在
- 该目录下是否按项目分了 `*-sessions.md` 文件

- [ ] **步骤 2：记录本次 skill 改造任务到新结构**

按新 SKILL.md 的记录模式，将本次"改造 daily-work-log v2"任务记录到正确的项目文件中。

- [ ] **步骤 3：最终 Commit（如有遗漏修复）**

```bash
cd /Users/zhangxiaotian/.claude && git add -A skills/daily-work-log/ && git commit -m "feat(daily-work-log): complete v2 migration with design and plan docs"
```
