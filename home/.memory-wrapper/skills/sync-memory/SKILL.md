---
name: sync-memory
description: Sync long-term memory với các peer máy khác qua agentmemory mesh sync
---

## Quy tắc bắt buộc: dùng agentmemory, không dùng Jcode built-in memory

Skill này liên quan tới **agentmemory**. Khi thực hiện skill này:

- **Không dùng** Jcode built-in `memory` tool / `memory.remember` / `memory(action=remember)` để lưu, đọc, crystallize, sync, hay query agentmemory.
- **Luôn dùng** `~/.memory-wrapper/bin/...` helper hoặc REST API `http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/...` với `$AGENTMEMORY_SECRET`.
- Lý do: Jcode built-in memory và agentmemory wrapper có thể là hai backend khác nhau. Dùng sai tool sẽ làm `/load-context` không tìm thấy memory.

## Khi nào gọi skill này

Gọi `/sync-memory` khi:
- Bạn vừa boot máy và muốn kéo memory mới nhất
- Bạn muốn đồng bộ memory trước task quan trọng
- Bạn vừa làm xong task trên máy khác và muốn sync ngay

## Cách thực hiện

```bash
~/.memory-wrapper/bin/sync-memory --once
```

## Follow-up tối ưu

Sau khi sync:
- nếu user chỉ muốn context nhanh, gọi:

```bash
~/.memory-wrapper/bin/load-context-fast "<project or task query>" --json-pretty
```

- nếu task rất narrow, dùng:

```bash
~/.memory-wrapper/bin/load-context-fast "<query>" --skip-graph --json-pretty
```

Không mặc định chạy nhiều query sâu ngay sau sync nếu user chưa cần.
