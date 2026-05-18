---
name: save-decision
description: Lưu quyết định kiến trúc, convention, bug fix, hoặc lesson quan trọng vào long-term memory - tự động extract vào knowledge graph
---

## Khi nào gọi skill này

Gọi `/save-decision` sau khi:
- Chọn một pattern/library thay vì cái khác
- Fix một bug khó
- Thống nhất convention trong project
- Kết thúc task lớn và muốn ghi lại bài học

## Cách thực hiện (3 bước - luôn làm đủ cả 3)

### Bước 1 + 2 cùng lúc: Lưu memory VÀ extract graph

Dùng helper tích hợp (khuyến nghị):
```bash
~/.memory-wrapper/bin/memory-save-and-extract <type> "<title>" "<content>"
```

Hoặc tách riêng:

```bash
# Bước 1: lưu memory
~/.memory-wrapper/bin/memory-save <type> "<title>" "<content>"

# Bước 2: extract vào knowledge graph
source "$HOME/.memory-wrapper/.env"
curl -s -X POST "http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/graph/extract" \
  -H "Authorization: Bearer $AGENTMEMORY_SECRET" \
  -H "Content-Type: application/json" \
  -d "{\"observation\": \"[<type>] <title>: <content summary>\"}"
```

### Bước 3: Báo cáo kết quả

Sau khi hoàn thành, luôn báo:
- Memory ID đã lưu
- Số nodes/edges được extract vào graph
- Gợi ý `/graph-query <title>` để xem trong knowledge graph

## Các type nên dùng

- `decision` - lựa chọn architecture/library/approach
- `bug_fix` - nguyên nhân + cách fix bug
- `convention` - convention team thống nhất
- `lesson` - bài học từ task/incident
- `architecture` - thiết kế hệ thống
- `workflow` - quy trình lặp lại

## Khi nào nên crystallize thay vì save-decision?

Nếu đây là quyết định **không bao giờ được phép mất hoặc thay đổi ngầm** (team convention bất biến, critical architecture rule), dùng `/crystallize` thay thế - memory sẽ được pin vĩnh viễn.
