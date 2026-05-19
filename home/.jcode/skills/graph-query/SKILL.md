---
name: graph-query
description: Query knowledge graph trong agentmemory - tìm nodes, edges, relationships giữa concepts/classes/decisions
---


## Quy tắc bắt buộc: dùng agentmemory, không dùng Jcode built-in memory

Skill này liên quan tới **agentmemory**. Khi thực hiện skill này:

- **Không dùng** Jcode built-in `memory` tool / `memory.remember` / `memory(action=remember)` để lưu, đọc, crystallize, sync, hay query agentmemory.
- **Luôn dùng** `~/.memory-wrapper/bin/...` helper hoặc REST API `http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/...` với `$AGENTMEMORY_SECRET`.
- Sau mọi thao tác lưu, phải verify bằng đường agentmemory tương ứng, ví dụ `~/.memory-wrapper/bin/memory-search "<title or keyword>"`.
- Lý do: Jcode built-in memory và agentmemory wrapper có thể là hai backend khác nhau. Dùng sai tool sẽ làm `/load-context` không tìm thấy memory.

## Khi nào dùng skill này

Dùng `/graph-query` khi:
- Muốn xem các class/component liên quan đến một concept
- Tìm relationship giữa 2 entities trong knowledge graph
- Khám phá architecture dạng graph của một project
- Sau khi `/load-context` để drill-down vào relationships
- Muốn visualize knowledge base hiện tại

## Cách thực hiện

### Query graph theo text (semantic)
```bash
~/.memory-wrapper/bin/graph-query "<your query>" [limit]
```

Hoặc gọi REST trực tiếp:
```bash
source "$HOME/.memory-wrapper/.env"
curl -s -X POST "http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/graph/query" \
  -H "Authorization: Bearer $AGENTMEMORY_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"query": "<your query>", "limit": 10}'
```

### Xem stats tổng quan
```bash
~/.memory-wrapper/bin/graph-stats
```

### Xem toàn bộ graph (viewer)
Mở browser: http://localhost:3113 (tab Graph)

## Sau khi nhận kết quả

1. Hiển thị nodes và edges liên quan nhất
2. Nếu có ≥3 nodes liên quan, render mermaid diagram:
   ```mermaid
   graph LR
     A[NodeA] -- edge_type --> B[NodeB]
   ```
3. Gợi ý drill-down vào node thú vị nhất
4. Nếu graph quá thưa (< 5 nodes tổng), gợi ý chạy `/save-decision` để populate thêm
