#!/usr/bin/env bash
# log-event.sh — PostToolUse hook for /daily-work-log skill
# Reads JSON from stdin, extracts tool info, appends to daily JSONL file.
# Runs async — stdout is silent, zero token cost.
set -euo pipefail

# Read stdin (JSON with tool_name, tool_input)
INPUT=$(cat)

# Determine project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Extract tool_name from stdin JSON
TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("tool_name",""))' 2>/dev/null || echo "unknown")

# Extract key fields from tool_input based on tool type
TOOL_INPUT=$(printf '%s' "$INPUT" | python3 -c '
import sys, json
data = json.loads(sys.stdin.read())
ti = data.get("tool_input", {})
result = {}
if "command" in ti:
    result["command"] = ti["command"][:500]
if "file_path" in ti:
    result["file_path"] = ti["file_path"]
if "old_string" in ti:
    result["old_string"] = ti["old_string"][:200]
if "new_string" in ti:
    result["new_string"] = ti["new_string"][:200]
if "content" in ti:
    result["content_length"] = len(str(ti["content"]))
print(json.dumps(result, ensure_ascii=False))
' 2>/dev/null || echo '{}')

# Get current timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DATE=$(date +%Y-%m-%d)

# Ensure .work-log directory exists
LOG_DIR="${PROJECT_DIR}/.work-log"
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Append event to JSONL (one line per event)
printf '{"tool":"%s","time":"%s","input":%s}\n' "$TOOL_NAME" "$TIMESTAMP" "$TOOL_INPUT" >> "${LOG_DIR}/${DATE}.jsonl" 2>/dev/null || true

# Silent exit — no stdout output
exit 0