---
name: agentmemory
description: Lưu và tìm kiếm long-term memory qua agentmemory MCP. Dùng khi cần save fact/decision/bug_fix, hoặc recall thông tin cũ.
---

# AgentMemory Skill

Agentmemory backend chạy tại `http://localhost:3111`. Các helper scripts ở `~/.memory-wrapper/bin/`.

## Lưu memory

```bash
~/.memory-wrapper/bin/memory-save <type> "<title>" "<content>"
```

Types: `fact`, `decision`, `bug_fix`, `convention`, `lesson`

Ví dụ:
```bash
~/.memory-wrapper/bin/memory-save fact "OpenClaw gateway port" "Gateway chạy ở port 18789 trên vinhpi"
~/.memory-wrapper/bin/memory-save bug_fix "WatchdogSec fix" "Xóa WatchdogSec=120 vì openclaw không implement sd_notify"
~/.memory-wrapper/bin/memory-save decision "Model choice" "Dùng gpt-5.4-mini cho cron jobs nhẹ, gpt-5.5 cho deep dreaming"
```

## Tìm kiếm memory

```bash
# Semantic search
~/.memory-wrapper/bin/memory-search "<query>" [limit]

# Ví dụ
~/.memory-wrapper/bin/memory-search "OpenClaw gateway" 5
~/.memory-wrapper/bin/memory-search "vinhpi systemd service" 10
```

## Kết quả trả về

`memory-save` trả JSON với field `success: true` nếu thành công.  
`memory-search` trả JSON với array `results[]`, mỗi kết quả có `title`, `score`, `type`.

## Lưu ý

- Backend luôn chạy (systemd hoặc background process), gọi trực tiếp không cần khởi động
- Nếu backend down: `~/.memory-wrapper/bin/restart-agentmemory`
- Kiểm tra status: `~/.memory-wrapper/bin/agentmemory-status`
- Prefix `mcp__agentmemory__` là tên tool trong Jcode session (nếu MCP inject được)
