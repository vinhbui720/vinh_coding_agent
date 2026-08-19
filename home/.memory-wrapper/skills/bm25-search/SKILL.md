---
name: bm25-search
description: Tìm exact keyword trong long-term memory khi semantic search không đủ chính xác
---

## Quy tắc bắt buộc: dùng agentmemory, không dùng Jcode built-in memory

Skill này liên quan tới **agentmemory**. Khi thực hiện skill này:

- **Không dùng** Jcode built-in `memory` tool / `memory.remember` / `memory(action=remember)` để lưu, đọc, crystallize, sync, hay query agentmemory.
- **Luôn dùng** `~/.memory-wrapper/bin/...` helper hoặc REST API `http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/...` với `$AGENTMEMORY_SECRET`.
- Lý do: Jcode built-in memory và agentmemory wrapper có thể là hai backend khác nhau. Dùng sai tool sẽ làm `/load-context` không tìm thấy memory.

## Khi nào dùng skill này

Dùng `/bm25-search` khi:
- Cần tìm chính xác tên function, class, file, hoặc error message
- Semantic search trả về kết quả không liên quan
- Tìm theo tên thư viện, version, config key, hoặc filename cụ thể
- `load-context-fast` không đủ precise

## Cách thực hiện

Ưu tiên query ngắn, exact, ít từ:

```bash
~/.memory-wrapper/bin/memory-search "jose JWT verify" 5
~/.memory-wrapper/bin/memory-search "generate_sdf_from_obj.py" 5
~/.memory-wrapper/bin/memory-search "CoACD" 5
```

## Rule tối ưu

- Query càng ngắn, exact-search càng rẻ và dễ chính xác.
- Không chạy nhiều variant dài dòng trước.
- Thử tối đa 2-3 exact keywords rồi mới quay lại semantic `/load-context` hoặc `/graph-query`.
