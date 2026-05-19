---
name: sync-memory
description: Sync long-term memory với các peer máy khác qua agentmemory mesh sync
---


## Quy tắc bắt buộc: dùng agentmemory, không dùng Jcode built-in memory

Skill này liên quan tới **agentmemory**. Khi thực hiện skill này:

- **Không dùng** Jcode built-in `memory` tool / `memory.remember` / `memory(action=remember)` để lưu, đọc, crystallize, sync, hay query agentmemory.
- **Luôn dùng** `~/.memory-wrapper/bin/...` helper hoặc REST API `http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/...` với `$AGENTMEMORY_SECRET`.
- Sau mọi thao tác lưu, phải verify bằng đường agentmemory tương ứng, ví dụ `~/.memory-wrapper/bin/memory-search "<title or keyword>"`.
- Lý do: Jcode built-in memory và agentmemory wrapper có thể là hai backend khác nhau. Dùng sai tool sẽ làm `/load-context` không tìm thấy memory.

## Khi nào gọi skill này

Gọi `/sync-memory` khi:
- Bạn vừa boot máy và muốn kéo memory mới nhất
- Bạn muốn đồng bộ memory trước task quan trọng
- Bạn vừa làm xong task trên máy khác và muốn sync ngay

## Cách thực hiện

Chạy:

```bash
~/.memory-wrapper/bin/sync-memory --once
```

Báo cáo kết quả sync. Nếu sync xong, hỏi user có muốn load context cho project hiện tại không. Nếu có, gọi skill `load-context`.
