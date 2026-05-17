# agentmemory Mode Notes

This repository supports two modes:

## Basic mode

Works without an LLM API key:

- Persistent memory storage
- BM25/search
- Viewer UI
- MCP/REST helpers

But the viewer will warn that no LLM provider is configured, and these remain disabled:

- automatic LLM compression/summarization
- knowledge graph extraction

## Full LLM-backed mode

Requires a supported API key env var, not merely Jcode OAuth/session credentials.

Use:

```bash
~/.memory-wrapper/bin/configure-llm-provider
~/.memory-wrapper/bin/restart-agentmemory
```

See `MEMORY_LLM_FEATURES.md` for provider choices and the recommended cheap setup.

## Why this file changed

An earlier note called this “REST-only mode”. That was too strong. The correct behavior is:

- agentmemory can run normally with no LLM provider, using no-op LLM features.
- LLM-backed compression and graph extraction only turn on after a real provider API key is exported into the environment and persisted into `~/.memory-wrapper/.env`.
