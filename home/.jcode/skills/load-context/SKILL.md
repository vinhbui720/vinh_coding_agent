---
name: load-context
description: Load long-term memory từ agentmemory cho project hoặc task hiện tại
---

## Khi nào gọi skill này

Gọi `/load-context` khi:
- Bắt đầu session mới trong một project
- Cần nhớ lại quyết định kiến trúc cũ
- Đang debug lại vấn đề tương tự trước đây

## Cách thực hiện

Ưu tiên dùng helper REST local:

```bash
~/.memory-wrapper/bin/memory-search "<project or task query>" 5
```

Nếu MCP bridge hoạt động, có thể dùng `memory_smart_search` thay thế.

Sau khi nhận kết quả:
1. Tóm tắt top 3-5 memory liên quan nhất
2. Hỏi user có muốn drill-down vào memory nào không
3. Inject context phù hợp vào conversation hiện tại
