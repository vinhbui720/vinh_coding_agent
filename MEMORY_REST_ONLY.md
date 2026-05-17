# agentmemory REST-Only Setup

## Status: ✅ Ready to Use

After attempting to enable LLM features (graph extraction, compression), we found that agentmemory's dependency on `iii-engine` causes stability issues in standalone mode.

**Decision: Use REST-only approach** — provides 80% of value, 100% reliability.

## What's Available

### Memory Operations
```bash
# Save a memory
~/.memory-wrapper/bin/memory-save decision "title" "content"
~/.memory-wrapper/bin/memory-save bug_fix "title" "content"
~/.memory-wrapper/bin/memory-save lesson "title" "content"

# Search memories
~/.memory-wrapper/bin/memory-search "query" 5

# Or use aliases (in ~/.bashrc)
mem-save decision "title" "content"
mem-search "query" 5
```

### Web UI
- Open: `http://localhost:3113`
- Browse, search, edit, delete memories
- View memory stats

### Jcode Skills
- `/sync-memory` -- (REST fallback only)
- `/save-decision` -- (REST fallback only)
- `/load-context` -- (REST fallback only)
- `/bm25-search` -- (REST fallback only)

## Why REST-Only?

agentmemory's full feature set requires:
- `ANTHROPIC_API_KEY` for LLM calls
- `iii-engine` orchestration service for graph extraction, compression, summarization

The `iii-engine` process **crashes after initialization** in standalone mode. To use it would require:
- Kubernetes/Docker deployment
- Proper infrastructure setup
- Significant DevOps overhead

For a personal coding setup, the REST-only mode is sufficient:
- ✅ Persistent memory storage (SQLite)
- ✅ Keyword search (BM25 index)
- ✅ Web UI for management
- ✅ Shell helpers for quick save/search
- ❌ Automatic compression/summarization
- ❌ Knowledge graph extraction

## Next Steps

If you later want to enable graph extraction + LLM compression:
1. Set up proper `iii-engine` infrastructure
2. Or migrate to cloud-hosted agentmemory (when available)
3. Or use lighter alternative (LangChain + Pinecone)

For now, this setup is **stable and useful** for long-term memory across your Jcode sessions.
