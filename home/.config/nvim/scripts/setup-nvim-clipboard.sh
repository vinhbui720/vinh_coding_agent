#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: ./setup-nvim-clipboard.sh <remote-machine>"
  exit 1
fi

HOST=$1
echo "Installing Neovim clipboard config on $HOST..."

ssh "$HOST" "
mkdir -p ~/.config/nvim/lua/config

# 1. Add the Clipboard Provider (For 'p' pasting)
cat >> ~/.config/nvim/lua/config/options.lua << 'EOF'

-- Sync clipboard between OS and Neovim over SSH
vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = {
    ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
    ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
  },
}
EOF

# 2. Add the Foolproof Yank (For 'y' copying)
cat >> ~/.config/nvim/lua/config/autocmds.lua << 'EOF'

-- Force OSC52 clipboard over SSH (Bypasses linux clipboard issues)
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    if vim.v.event.operator == 'y' then
      require('vim.ui.clipboard.osc52').copy('+')(vim.v.event.regcontents)
    end
  end,
})
EOF
"

if [ $? -eq 0 ]; then
  echo "✅ Successfully set up foolproof clipboard sharing on $HOST!"
else
  echo "❌ Failed to connect or set up $HOST."
fi
