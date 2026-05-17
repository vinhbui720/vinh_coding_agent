---
name: save-decision
description: Lưu quyết định kiến trúc, convention, bug fix, hoặc lesson quan trọng vào long-term memory
---

## Khi nào gọi skill này

Gọi `/save-decision` sau khi:
- Chọn một pattern/library thay vì cái khác
- Fix một bug khó
- Thống nhất convention trong project
- Kết thúc task lớn và muốn ghi lại bài học

## Cách thực hiện

Ưu tiên dùng helper REST local:

```bash
~/.memory-wrapper/bin/memory-save decision "<title>" "<content>"
```

Các type nên dùng:
- `decision`
- `bug_fix`
- `convention`
- `lesson`

Nếu MCP bridge hoạt động, có thể dùng `memory_save` thay thế.
