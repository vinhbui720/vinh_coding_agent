# agentmemory LLM Features

agentmemory can enable two advanced features when it has a real LLM API key:

- `AGENTMEMORY_AUTO_COMPRESS=true` — automatically compress/summarize observations into structured memories.
- `GRAPH_EXTRACTION_ENABLED=true` — extract entities/relations for the knowledge graph.

## Important: Jcode OAuth is not the same as an API key

Jcode may have Claude, Gemini, or ChatGPT/OAI OAuth/session credentials, but agentmemory upstream only auto-detects normal API-key environment variables:

- `GEMINI_API_KEY`
- `OPENROUTER_API_KEY`
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `MINIMAX_API_KEY`

So the portable wrapper setup intentionally does **not** copy Jcode OAuth tokens into agentmemory as if they were API keys.

## Recommended cheap setup

Use Gemini API key or OpenRouter cheap model:

```bash
# cheapest/simple option, usually has a generous free tier
export GEMINI_API_KEY='...'
~/.memory-wrapper/bin/configure-llm-provider
~/.memory-wrapper/bin/restart-agentmemory

# or OpenRouter cheap model
export OPENROUTER_API_KEY='...'
export OPENROUTER_MODEL='google/gemini-2.0-flash-001'
~/.memory-wrapper/bin/configure-llm-provider
~/.memory-wrapper/bin/restart-agentmemory

# or OpenAI small model
export OPENAI_API_KEY='...'
export OPENAI_MODEL='gpt-4o-mini'
~/.memory-wrapper/bin/configure-llm-provider
~/.memory-wrapper/bin/restart-agentmemory
```

The helper persists the selected key into `~/.memory-wrapper/.env`, which is ignored by git.

## Claude subscription fallback

agentmemory also supports an opt-in Claude Agent SDK fallback:

```bash
ALLOW_CLAUDE_SUBSCRIPTION_FALLBACK=true ~/.memory-wrapper/bin/configure-llm-provider
~/.memory-wrapper/bin/restart-agentmemory
```

This is **not recommended** as the default because upstream warns it can burn Claude subscription allocation and historically risked Stop-hook recursion. Prefer a cheap API key provider above.

## Verification

```bash
agentmemory status
curl http://localhost:3111/agentmemory/health
open http://localhost:3113
```

The viewer should stop showing the `No LLM provider key set` warning once a supported API key is configured and the server is restarted.
