---
name: bm25-search
description: Tìm exact keyword trong long-term memory khi semantic search không đủ chính xác
---

## Khi nào dùng skill này

Dùng `/bm25-search` khi:
- Cần tìm chính xác tên function, class, file, hoặc error message
- Semantic search trả về kết quả không liên quan
- Tìm theo tên thư viện, version, hoặc config key cụ thể

## Cách thực hiện

Ưu tiên dùng helper REST local với exact query ngắn:

```bash
~/.memory-wrapper/bin/memory-search "jose JWT verify" 10
```

Nếu MCP bridge hoạt động, có thể dùng `memory_smart_search` thay thế.
