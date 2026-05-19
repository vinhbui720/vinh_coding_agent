---
name: bm25-search
description: Tìm exact keyword trong long-term memory khi semantic search không đủ chính xác
---


## Quy tắc bắt buộc: dùng agentmemory, không dùng Jcode built-in memory

Skill này liên quan tới **agentmemory**. Khi thực hiện skill này:

- **Không dùng** Jcode built-in `memory` tool / `memory.remember` / `memory(action=remember)` để lưu, đọc, crystallize, sync, hay query agentmemory.
- **Luôn dùng** `~/.memory-wrapper/bin/...` helper hoặc REST API `http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/...` với `$AGENTMEMORY_SECRET`.
- Sau mọi thao tác lưu, phải verify bằng đường agentmemory tương ứng, ví dụ `~/.memory-wrapper/bin/memory-search "<title or keyword>"`.
- Lý do: Jcode built-in memory và agentmemory wrapper có thể là hai backend khác nhau. Dùng sai tool sẽ làm `/load-context` không tìm thấy memory.

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
