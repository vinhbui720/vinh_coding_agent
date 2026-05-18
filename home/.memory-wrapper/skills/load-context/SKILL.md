---
name: load-context
description: Load long-term memory từ agentmemory cho project hoặc task hiện tại - memories, knowledge graph và crystals
---

## Khi nào gọi skill này

Gọi `/load-context` khi:
- Bắt đầu session mới trong một project
- Cần nhớ lại quyết định kiến trúc cũ
- Đang debug lại vấn đề tương tự trước đây

## Cách thực hiện (3 bước đầy đủ)

### Bước 1: Search memories
```bash
~/.memory-wrapper/bin/memory-search "<project or task query>" 7
```

### Bước 2: Query knowledge graph
```bash
~/.memory-wrapper/bin/graph-query "<project or task query>" 10
```

Hoặc REST trực tiếp:
```bash
source "$HOME/.memory-wrapper/.env"
curl -s -X POST "http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/graph/query" \
  -H "Authorization: Bearer $AGENTMEMORY_SECRET" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"<query>\", \"limit\": 10}"
```

### Bước 3: Kiểm tra crystals (pinned permanent knowledge)
```bash
source "$HOME/.memory-wrapper/.env"
curl -s -H "Authorization: Bearer $AGENTMEMORY_SECRET" \
  "http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/crystal-list"
```

## Sau khi nhận kết quả

1. **Memories**: Tóm tắt top 3-5 entries liên quan nhất
2. **Graph**: Nếu có ≥3 nodes liên quan - render mermaid diagram ngắn gọn
3. **Crystals**: Highlight crystals liên quan (đây là kiến thức được pin vĩnh viễn - ưu tiên cao nhất)
4. Hỏi user có muốn drill-down vào memory/crystal/node nào không
5. Inject context phù hợp vào conversation

## Tips

- Nếu context rộng (cả project), search broad query trước rồi narrow down
- Nếu cần exact keyword (function name, class name), dùng `/bm25-search` thay thế
- Sau khi load xong, các decisions mới nên lưu bằng `/save-decision` để populate graph thêm
