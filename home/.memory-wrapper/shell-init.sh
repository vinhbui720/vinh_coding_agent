# Source this from ~/.bashrc or ~/.zshrc
export PATH="$HOME/.memory-wrapper/bin:$PATH"
alias jc="$HOME/.memory-wrapper/bin/jc"
if [ -z "${AGENTMEMORY_STARTED:-}" ]; then
  export AGENTMEMORY_STARTED=1
  nohup "$HOME/.memory-wrapper/bin/agentmemory-start" >/dev/null 2>&1 &
  disown >/dev/null 2>&1 || true
fi
