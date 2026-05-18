---
name: crystallize
description: Promote memory quan trọng thành long-term crystal - pin vĩnh viễn, không bao giờ bị decay hay auto-evict
---

## Khi nào dùng skill này

Dùng `/crystallize` khi:
- Quyết định kiến trúc **core** không bao giờ được phép thay đổi ngầm
- Convention team đã thống nhất và phải enforce lâu dài
- Bài học cực kỳ đắt giá từ production incident
- Pattern chuẩn của project muốn mọi session đều nhớ

## Sự khác biệt với /save-decision

| | save-decision | crystallize |
|---|---|---|
| Lifecycle | Có thể decay theo thời gian | Pin vĩnh viễn |
| Auto-evict | Có thể bị evict khi đầy | Không bao giờ bị xóa tự động |
| Use case | Decisions thông thường | Kiến thức nền tảng bất biến |

## Cách thực hiện

### Dùng helper script (khuyến nghị)
```bash
~/.memory-wrapper/bin/crystallize "<title>" "<content>" [tag1,tag2,tag3]
```

Ví dụ:
```bash
~/.memory-wrapper/bin/crystallize \
  "Wrapper-only rule for agentmemory" \
  "Never modify upstream agentmemory source. All fixes via wrappers/config in vinh_coding_agent repo only." \
  "convention,agentmemory,architecture"
```

### Hoặc gọi REST trực tiếp
```bash
source "$HOME/.memory-wrapper/.env"
curl -s -X POST "http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/crystallize" \
  -H "Authorization: Bearer $AGENTMEMORY_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "<nội dung>",
    "title": "<tiêu đề>",
    "tags": ["tag1", "tag2"]
  }'
```

### Xem danh sách crystals hiện có
```bash
source "$HOME/.memory-wrapper/.env"
curl -s -H "Authorization: Bearer $AGENTMEMORY_SECRET" \
  "http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/crystal-list"
```

## Sau khi crystallize

1. Confirm crystal ID đã được tạo
2. Gợi ý `/graph-query <title>` để xem crystal trong context knowledge graph
3. Nếu crystal liên quan đến nhiều components, gợi ý thêm tags để dễ tìm sau
