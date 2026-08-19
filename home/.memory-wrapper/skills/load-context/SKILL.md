---
name: load-context
description: Load long-term memory từ agentmemory cho project hoặc task hiện tại - memories, knowledge graph và crystals
---

## Quy tắc bắt buộc: dùng agentmemory, không dùng Jcode built-in memory

Skill này liên quan tới **agentmemory**. Khi thực hiện skill này:

- **Không dùng** Jcode built-in `memory` tool / `memory.remember` / `memory(action=remember)` để lưu, đọc, crystallize, sync, hay query agentmemory.
- **Ưu tiên dùng** `~/.memory-wrapper/bin/...` helper.
- **Default phải là flow gọn và rẻ context**. Chỉ mở rộng sang deep diagnostics khi fast path fail hoặc user yêu cầu.
- **Không kết luận “không có memory” nếu agentmemory chưa healthy hoặc endpoint trả 404/empty do service chưa ready.** Phải check health trước.
- Lý do: Jcode built-in memory và agentmemory wrapper có thể là hai backend khác nhau. Dùng sai tool sẽ làm `/load-context` không tìm thấy memory.

## Mục tiêu tối ưu

Mặc định `/load-context` phải:
- ít command hơn
- ít output hơn
- ít token tóm tắt hơn
- đủ để tiếp tục task ngay

## Fast path mặc định

Dùng **một helper compact** trước:

```bash
~/.memory-wrapper/bin/load-context-fast "<project or task query>" --json-pretty
```

Mặc định helper này sẽ:
1. check `agentmemory-status`
2. lấy top memory hits ngắn gọn
3. lấy graph nodes ngắn gọn
4. **không** tải crystals trừ khi thực sự cần

Nếu task đơn giản hoặc user chỉ muốn “load memory”, đây là path mặc định.

### Variant rẻ nhất

Nếu chỉ cần memory hits mà chưa cần graph:

```bash
~/.memory-wrapper/bin/load-context-fast "<query>" --skip-graph --json-pretty
```

### Khi nào mới bật crystals

Chỉ dùng khi:
- user hỏi explicit về crystal / permanent memory
- quyết định nền tảng rất quan trọng
- fast path cho thấy cần kiểm tra pinned knowledge

```bash
~/.memory-wrapper/bin/load-context-fast "<query>" --with-crystals --json-pretty
```

## Deep path: chỉ dùng khi fast path fail hoặc cần đào sâu

### Bước 0: kiểm tra agentmemory đã ready chưa

```bash
~/.memory-wrapper/bin/agentmemory-status
```

Nếu status fail hoặc service chưa ready, retry ngắn:

```bash
for i in 1 2 3; do
  if ~/.memory-wrapper/bin/agentmemory-status; then
    break
  fi
  sleep 2
done
```

Nếu vẫn fail, lúc đó mới chạy diagnostics persisted data:

```bash
find "$HOME/data/state_store.db" "$PWD/data/state_store.db" -maxdepth 1 -type f -name 'mem%3A*.bin' -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort -r | head
~/.memory-wrapper/bin/graph-stats || true
```

### Bước 1: search memories trực tiếp

```bash
~/.memory-wrapper/bin/memory-search "<query>" 3
```

Nếu query hẹp không ra kết quả, thử tối đa 1-2 variant rộng hơn:

```bash
~/.memory-wrapper/bin/memory-search "<broader project name>" 5
~/.memory-wrapper/bin/memory-search "<important symbol or filename>" 5
```

### Bước 2: query graph khi thật sự cần relationship

```bash
~/.memory-wrapper/bin/graph-query "<query>" 5
```

### Bước 3: crystals, only if needed

```bash
~/.memory-wrapper/bin/agentmemory-api GET /crystal-list
```

## Cách trả lời user để tiết kiệm context

Sau khi load xong:
1. Tóm tắt **3 memory hits quan trọng nhất**.
2. Chỉ nêu **2-5 graph nodes** nếu có ích cho task hiện tại.
3. Chỉ mention crystals nếu có và thật sự liên quan.
4. **Không dump raw JSON dài** trừ khi user yêu cầu.
5. **Không render mermaid** nếu graph ít giá trị thực tiễn cho task hiện tại.

Output mặc định nên ngắn dạng:
- status: healthy/not ready
- top memories
- key graph relations nếu có
- immediate next-step relevance

## Nếu kết quả search empty

Trước khi trả lời user “không có memory”, phải phân biệt 3 trường hợp:

1. **Service lỗi/not-ready**: `agentmemory-status` fail, health 404, hoặc no worker.
2. **Index/search empty nhưng data tồn tại**: persisted files còn nhưng API/index có vấn đề.
3. **Thật sự không có data**: status healthy, graph-stats 0, search empty, không có persisted memory files/backups.

Diagnostic nhanh:

```bash
~/.memory-wrapper/bin/agentmemory-status || true
~/.memory-wrapper/bin/graph-stats || true
find "$HOME/data/state_store.db" "$PWD/data/state_store.db" -maxdepth 1 -type f -name 'mem%3A*.bin' -printf '%s %p\n' 2>/dev/null | sort -nr | head
```

## Tips

- Bắt đầu với `load-context-fast`, không nhảy ngay vào nhiều lệnh rời.
- Ưu tiên `--skip-graph` cho task rất narrow.
- Dùng `/bm25-search` khi cần exact keyword như function/class/file name.
- Sau khi load xong, các decisions mới nên lưu bằng `/save-decision` để populate graph thêm.
- Chỉ dùng deep path khi fast path không đủ.
