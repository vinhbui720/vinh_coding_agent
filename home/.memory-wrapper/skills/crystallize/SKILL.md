---
name: crystallize
description: Promote memory quan trọng thành long-term crystal - pin vĩnh viễn, không bao giờ bị decay hay auto-evict
---


## Quy tắc bắt buộc: dùng agentmemory, không dùng Jcode built-in memory

Skill này liên quan tới **agentmemory**. Khi thực hiện skill này:

- **Không dùng** Jcode built-in `memory` tool / `memory.remember` / `memory(action=remember)` để lưu, đọc, crystallize, sync, hay query agentmemory.
- **Luôn dùng** `~/.memory-wrapper/bin/...` helper hoặc REST API `http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/...` với `$AGENTMEMORY_SECRET`.
- Sau mọi thao tác lưu, phải verify bằng đường agentmemory tương ứng, ví dụ `~/.memory-wrapper/bin/memory-search "<title or keyword>"`.
- Lý do: Jcode built-in memory và agentmemory wrapper có thể là hai backend khác nhau. Dùng sai tool sẽ làm `/load-context` không tìm thấy memory.

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

API hiện tại **không nhận raw title/content trực tiếp**. Phải:

1. `POST /agentmemory/actions` tạo action.
2. `POST /agentmemory/actions/update` mark action `done`.
3. `POST /agentmemory/crystals/create` với `actionIds`.
4. Verify bằng `GET /agentmemory/crystals`.

Prefer dùng helper `~/.memory-wrapper/bin/crystallize` vì helper đã làm đủ 4 bước và fail nếu verify không thấy crystal.

### Xem danh sách crystals hiện có
```bash
source "$HOME/.memory-wrapper/.env"
curl -s -H "Authorization: Bearer $AGENTMEMORY_SECRET" \
  "http://localhost:${AGENTMEMORY_PORT:-3111}/agentmemory/crystals"
```

## Sau khi crystallize

1. Confirm crystal ID đã được tạo
2. Gợi ý `/graph-query <title>` để xem crystal trong context knowledge graph
3. Nếu crystal liên quan đến nhiều components, gợi ý thêm tags để dễ tìm sau
