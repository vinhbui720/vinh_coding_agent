---
name: load-context
description: Load long-term memory từ agentmemory cho project hoặc task hiện tại - memories, knowledge graph và crystals
---

## Quy tắc bắt buộc: dùng agentmemory, không dùng Jcode built-in memory

Skill này liên quan tới **agentmemory**. Khi thực hiện skill này:

- **Không dùng** Jcode built-in `memory` tool / `memory.remember` / `memory(action=remember)` để lưu, đọc, crystallize, sync, hay query agentmemory.
- **Ưu tiên dùng** `~/.memory-wrapper/bin/...` helper. Các helper đã gọi REST đúng dạng `http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/...` với `$AGENTMEMORY_SECRET`.
- **Không kết luận “không có memory” nếu agentmemory chưa healthy hoặc endpoint trả 404/empty do service chưa ready.** Phải chạy health/status trước, retry ngắn, rồi mới search.
- Sau mọi thao tác lưu, phải verify bằng đường agentmemory tương ứng, ví dụ `~/.memory-wrapper/bin/memory-search "<title or keyword>"`.
- Lý do: Jcode built-in memory và agentmemory wrapper có thể là hai backend khác nhau. Dùng sai tool sẽ làm `/load-context` không tìm thấy memory.

## Khi nào gọi skill này

Gọi `/load-context` khi:
- Bắt đầu session mới trong một project
- Cần nhớ lại quyết định kiến trúc cũ
- Đang debug lại vấn đề tương tự trước đây

## Cách thực hiện an toàn

### Bước 0: Kiểm tra agentmemory đã ready chưa

Luôn chạy trước khi search:

```bash
~/.memory-wrapper/bin/agentmemory-status
```

Nếu status fail, 404, hoặc không healthy, **retry vài lần trước khi kết luận mất memory**:

```bash
for i in 1 2 3 4 5; do
  if ~/.memory-wrapper/bin/agentmemory-status; then
    break
  fi
  sleep 2
done
```

Nếu vẫn fail, kiểm tra dữ liệu persisted trước khi nói memory rỗng:

```bash
find "$HOME/data/state_store.db" "$PWD/data/state_store.db" -maxdepth 1 -type f -name 'mem%3A*.bin' -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort -r
~/.memory-wrapper/bin/graph-stats || true
```

Dấu hiệu lỗi service-not-ready từng gặp: `/agentmemory/health` hoặc `/agentmemory/smart-search` trả 404/empty trong lúc data vẫn còn ở `$HOME/data/state_store.db`. Khi đó không nói “lost memory”; nói service/API chưa ready và cần restart/wait.

### Bước 1: Search memories

```bash
~/.memory-wrapper/bin/memory-search "<project or task query>" 7
```

Nếu query hẹp không ra kết quả, thử variant rộng và exact keyword:

```bash
~/.memory-wrapper/bin/memory-search "<project>" 10
~/.memory-wrapper/bin/memory-search "<important symbol or filename>" 10
```

### Bước 2: Query knowledge graph

```bash
~/.memory-wrapper/bin/graph-query "<project or task query>" 10
```

Hoặc REST trực tiếp qua wrapper API, không tự ghép URL nếu không cần:

```bash
~/.memory-wrapper/bin/agentmemory-api POST /graph/query '{"query":"<query>","limit":10}'
```

Nếu cần curl trực tiếp:

```bash
source "$HOME/.memory-wrapper/.env"
curl -fsS -X POST "http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/graph/query" \
  -H "Authorization: Bearer $AGENTMEMORY_SECRET" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"<query>\", \"limit\": 10}"
```

### Bước 3: Kiểm tra crystals (pinned permanent knowledge)

```bash
~/.memory-wrapper/bin/agentmemory-api GET /crystal-list
```

Hoặc:

```bash
source "$HOME/.memory-wrapper/.env"
curl -fsS -H "Authorization: Bearer $AGENTMEMORY_SECRET" \
  "http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/crystal-list"
```

## Nếu kết quả search empty

Trước khi trả lời user “không có memory”, phải phân biệt 3 trường hợp:

1. **Service lỗi/not-ready**: `agentmemory-status` fail, health 404, hoặc no worker. Báo service issue, retry/restart, không kết luận mất data.
2. **Index/search empty nhưng data tồn tại**: có file như `$HOME/data/state_store.db/mem%3Amemories.bin` hoặc graph files. Báo data còn, API/index có vấn đề.
3. **Thật sự không có data**: status healthy, graph-stats 0, search empty, và không có persisted memory files/backups.

Diagnostic nhanh:

```bash
~/.memory-wrapper/bin/agentmemory-status || true
~/.memory-wrapper/bin/graph-stats || true
find "$HOME/data/state_store.db" "$PWD/data/state_store.db" -maxdepth 1 -type f -name 'mem%3A*.bin' -printf '%s %p\n' 2>/dev/null | sort -nr | head
```

## Sau khi nhận kết quả

1. **Memories**: Tóm tắt top 3-5 entries liên quan nhất.
2. **Graph**: Nếu có ≥3 nodes liên quan, render mermaid diagram ngắn gọn.
3. **Crystals**: Highlight crystals liên quan, đây là kiến thức được pin vĩnh viễn và ưu tiên cao nhất.
4. Hỏi user có muốn drill-down vào memory/crystal/node nào không.
5. Inject context phù hợp vào conversation.

## Tips

- Nếu context rộng, search broad query trước rồi narrow down.
- Nếu cần exact keyword như function/class/file name, dùng `/bm25-search` thay thế hoặc exact `memory-search` keyword.
- Sau khi load xong, các decisions mới nên lưu bằng `/save-decision` để populate graph thêm.
