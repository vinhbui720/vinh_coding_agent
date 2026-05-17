# Source this from ~/.bashrc or ~/.zshrc
export PATH="$HOME/.memory-wrapper/bin:$PATH"
alias jcode="$HOME/.memory-wrapper/bin/jc"
if [ -z "${AGENTMEMORY_STARTED:-}" ]; then
  export AGENTMEMORY_STARTED=1
  "$HOME/.memory-wrapper/bin/agentmemory-start" >/dev/null 2>&1 &
fi
