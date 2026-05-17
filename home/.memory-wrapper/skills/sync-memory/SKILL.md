---
name: sync-memory
description: Sync long-term memory với các peer máy khác qua agentmemory mesh sync
---

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
