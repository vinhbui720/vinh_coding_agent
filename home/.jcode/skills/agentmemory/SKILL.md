---
name: agentmemory
description: Bộ kỹ năng đầy đủ để dùng agentmemory qua wrappers (save/search/graph/crystal/sync/health) cùng Jcode memory features.
---

# Agentmemory Umbrella Skill

Mục tiêu: tận dụng tối đa agentmemory, nhưng **không thay thế** memory features sẵn có của Jcode.

## Health & status

```bash
~/.memory-wrapper/bin/agentmemory-status
~/.memory-wrapper/bin/graph-stats
```

## Core memory operations

```bash
~/.memory-wrapper/bin/memory-save <type> "<title>" "<content>"
~/.memory-wrapper/bin/memory-search "<query>" [limit]
```

## Save + auto graph extraction

```bash
~/.memory-wrapper/bin/memory-save-and-extract <type> "<title>" "<content>"
```

## Knowledge graph

```bash
~/.memory-wrapper/bin/graph-query "<query>" [limit]
~/.memory-wrapper/bin/graph-stats
```

## Permanent crystals (non-decay)

```bash
~/.memory-wrapper/bin/crystallize "<title>" "<content>" [tag1,tag2,...]
```

## Sync mesh peers

```bash
~/.memory-wrapper/bin/sync-memory --once
```

## Direct API (advanced)

Dùng wrapper chung để gọi bất kỳ endpoint nào:

```bash
~/.memory-wrapper/bin/agentmemory-api GET /health
~/.memory-wrapper/bin/agentmemory-api POST /graph/query '{"query":"franka task manager","limit":10}'
```

## Recommended flow with Jcode

1. Bắt đầu task: `/load-context`
2. Trong task: `/save-decision` (hoặc trực tiếp `memory-save-and-extract`)
3. Khi cần rel graph: `/graph-query`
4. Kiến thức bất biến: `/crystallize`
5. Cuối task: lưu lesson + sync nếu multi-machine
