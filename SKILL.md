---
name: daily-work-log
description: 每日工作记录与总结。使用场景：开启对话时说「记录工作」启动记录模式，说「总结今日工作」生成当日工作日志报告。支持跨会话汇总，hooks 可选增强。
hooks:
  PostToolUse:
    - matcher: "Edit|Write|Bash"
      hooks:
        - type: command
          command: "bash ${CLAUDE_SKILL_DIR}/bin/log-event.sh"
          async: true
          statusMessage: "Recording work event..."
---

# daily-work-log — 每日工作记录与总结

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

## 错误处理

- 日期目录创建失败 → 提示"无法创建日志目录 `${DAY_DIR}`，日志记录功能已禁用"
- `*-sessions.md` 全部不存在 → 跳过该数据源，仅基于当前会话上下文生成
- 指定日期无目录 → 提示"该日期暂无工作记录"
- 指定日期有目录但无 sessions → 提示"该日期暂无工作记录"

## 约束

- 所有文件默认中文输出
- sessions 头部标注项目名：`# 工作记录 YYYY-MM-DD — 项目名`
- `sessions.md` 单个摘要条目不超过 200 字
- `report.md` 细节说明每个任务不超过 500 字
- 摘要追加时使用 Edit 工具而非 Write，避免覆盖已有内容
